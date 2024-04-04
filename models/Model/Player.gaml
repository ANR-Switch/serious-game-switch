/**
* Name: Player
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Player

import "Modes.gaml"
import "Publicworks.gaml"

global {
	
	// List of possible actions
	string INFRASTRUCTURE <- "INFRA";
	list<string> player_actions <- [INFRASTRUCTURE];
	
	// =============================
	
	string BUDGET <- "BUDGET";
	string POPULARITY <- "POPULARITY";
	
	// =============================
	
	// Vote could be of two kind = 
	// 1 - vote d'adhésion : proximité des préférences ménages avec la politique engagée 
	// 2 - vote barrage : niveau d'insatisfaction par rapport aux pratiques de mobilités (e.g. Hidalgo et ses travaux) !
	
	/*
	 * Between 0 and 1, how much households adhere to the policity regarding mode management in the city
	 */
	float political_score {
		
		// Based on modes policy compare to household preferences 
		float cmp;
		ask household {
			float score;
			loop m over:mode { 
				loop c over:m.criterias.keys {
					float critweight <- prio_criterias[c]/sum(prio_criterias.values);
					// TODO : value around 1.0 means no one will adhere, which is a problem
					if (__criterias[c][m] < 0 and first(mayor).__city_modes_policy[m][c] < 1.0) or 
						(__criterias[c][m] > 0 and first(mayor).__city_modes_policy[m][c] > 1.0){ 
						score <- score + critweight;
					}
				}
			}
			cmp <- cmp + score * __weight;
		}
		
		return cmp / length(household);
		
	}
	
}

species mayor {
	
	// THE BIG CITY
	city mycity;
	
	// The budget is made of credit (units) that represent a "token-of-action"
	// Renew of budget is based on recurrent costs and incomes from taxes
	float budget <- float(STARTING_BUDGET);
	
	// TAXES
	float __taxe_fuel <- 1.0 min:0.0 max:__MAXTF; float __MAXTF <- 2.0;
	float __parc_price <- 1.0 min:0.0 max:__MAXPP; float __MAXPP <- 2.0; 
	float __bus_price <- 1.0 min:0.0 max:__MAXBP; float __MAXBP <- 2.0;
	
	float __local_taxe <- 1.0 min:0.0 max:__MAXLT; float __MAXLT <- 2.0;// Adjustement criteria for budget equilibrium
	
	// INCITATIONS
	float __bike_subsidies <- 0.0 min:0.0 max:1.0;
	float __accorded_bike_subsidies;
	float __ev_subsidies <- 0.0 min:0.0 max:1.0;
	float __accorded_ev_subsidies;
	
	// INVESTMENT
	float __invest;
	
	// CITY MODES POLICY
	map<mode,map<string,float>> __city_modes_policy; // TODO : init based on households preferences
	map<string,float> __restricted_cars <- INCOME_LEVEL as_map (each::0.0);
	float __pt_boost <- 1.0;
	
	// **************
	// PLAYER ACTIONS
	// **************
	
	// Launches work on infrastructure 
	publicwork invest_equipement(mode mheu, district o, district d, float amount) {
	
		create infrapw with:[
			m::mheu,c::mycity,amount::amount,
			target::o=nil or d=nil ? PUBLICWORK_NOTARGET : {int(o),int(d)}
		];
		
		return last(infrapw);
	}
	
	/*
	 * Launches work on carpaks
	 * costs: ±8k / place modulo le prix de l'immo
	 */
	publicwork manage_carpark(district d, int amount) {
		
		create carparkpw with:[
			m::CAR,c::mycity,target::{int(d),-1},evol::amount
		];
		
		return last(carparkpw); 
	}
	
	// Reduce speed limit, i.e. add a multiplicative factor lower than 1 to the criteria TIME on CAR
	action lowerspeedlimit(int speedlimit) {
		__city_modes_policy[CAR][TIME] <- SPEED_FACTOR * speedlimit/BASE_SPEED_LIMIT + (1-SPEED_FACTOR); // équivaut au fait de passer de 50 à 40 TODO : explicit?
		// TODO : put a price on it !!!
		mycity._CAROAD <- mycity._CAROAD collect (max(0,min(1,each * __city_modes_policy[CAR][TIME]))) as_matrix {length(district),length(district)};  
	}
	
	// TODO : how to parametrize? if we just change potential, it means people are using other modes, which is not realistic at all
	action forbidoldcar(int critair <- 2) {
		float level <- critair<=2?ZFE_CRIT2:ZFE_CRIT3;
		loop income over:INCOME_LEVEL { __restricted_cars[income] <- (level + ZFE_X_ECONOMY[income])/2; }
	}
	
	// more PT stops, increased freq. and passengers capacity/confort
	action increasePTatractivness(float confort <- 0.0, float morefreq <- 0.0) {
		// passengers capacity/confort : increase directly confort criteria on PT
		__city_modes_policy[PUBLICTRANSPORT][CONFORT] <- __city_modes_policy[PUBLICTRANSPORT][CONFORT]+confort;
		// increase frequency or number of bus stops : increase fiability / time / ease criteria
		loop c over:[TIME,EASY] {
			__city_modes_policy[PUBLICTRANSPORT][c] <- __city_modes_policy[PUBLICTRANSPORT][c]+morefreq;
		}
		__pt_boost <- __pt_boost + confort + morefreq;
	}
	
	// Household 
	action allow_subsidies_to(household hh, district d, map<mode,pair<float,float>> switches) {
		float bikediff <- switches[BIKE].value - switches[BIKE].key;
		if __bike_subsidies > 0 and bikediff > 0 { 
			__accorded_bike_subsidies <- __accorded_bike_subsidies + d.pop[hh]/mycity.total_population() * bikediff;
		}
		if __ev_subsidies > 0 {} // TODO : dev subsidies toward EV
	}
	
	// TODO : promote ecology???
	
	// *************
	// INNER DYNAMIC
	// *************
	
	// BUDGET DYNAMIC
	
	// budget is seen as a balance compare to a base situation
	// 
	// if inhabitants is using less cars, buget is slowly adapting, but in the mean
	// times it means less income (e.g. taxes gain is lower) while still having to
	// maintain related infrastructure
	//
	reflex mobility_budget when:cycle>1 and every(#day) {
		
		float carbalance <- __get_taxes_coefficient(CAR);
		float publictransportbalance <- __get_taxes_coefficient(PUBLICTRANSPORT);
		
		float __car_input <- carbalance * STARTING_BUDGET * FUEL_TAXE_RATIO_BALANCE * #day / #year;
		float __pt_input <- publictransportbalance * STARTING_BUDGET * PT_TAXE_RATIO_BALANCE * PT_PAYMENT_RATIO * #day / #year;
		float __local_tax <- __local_taxe * STARTING_BUDGET * LOCAL_TAXE_RATIO_BALANCE * #day / #year;
		
		// write "CARS IN: "+__car_input;
		// write "PT IN: "+__pt_input;
		// write "LOCAL TAXE IN: "+__local_tax;
		
		// SUBSIDIES
		// Pay over a year subsidies when household switch toward more bike in mobility
		if __accorded_bike_subsidies > 0 {
			__accorded_bike_subsidies <- __accorded_bike_subsidies - __accorded_bike_subsidies * #day/#year; // Reduce the amount of people asking for subsidies
			__invest <- __invest + __accorded_bike_subsidies * __bike_subsidies * STARTING_BUDGET * #day/#year; // Add the amount of subsidies corresponding to the investment for this round
		}
		
		// write "SUBSIDIES COST: "+__invest; float ii <- __invest;
		
		// PUBLIC WORKS
		__invest <- __invest + sum(
			mycity.publicworks collect (each.costs() / (each.duration()/#year) // actual costs per year 
				/ world.__actual_base_annual_budget(mycity) // per unit of actual yearly budget
				* STARTING_BUDGET
				* #day / #year // per step of simulation
			)
		);
		
		// write "PUBLIC WORK COST: "+(__invest-ii);
		
		budget <- budget + __car_input + __pt_input + __local_tax - __invest;
		
		// RESET INVESTMENT
		__invest <- 0.0; 
		
	}
	
	// ************************
	// POPULATION COMMUNICATION
	
	/*
	 * Represent the taxation policy of the municipality, should be around 1 (lower is low taxation and vis versa)
	 * from /2 to x2 factor (i.e. [0.5;2.0]
	 */
	float price_factor(mode m) { 
		switch m {
			// fuel tax and parcking pricing 
			match CAR {
				float mid <- (__taxe_fuel + __parc_price) / 2; 
				return mid < 1 ? mid/2+0.5 : mid;
			} 
			// Bike subsidies
			match BIKE { return 1 - __bike_subsidies; } 
			match PUBLICTRANSPORT {return __bus_price<1 ? __bus_price/2+0.5 : __bus_price;} // public transport pricing 
		}
	}
	
	// ******************
	// UTILS
	
	/**
	 * Return coefficient of taxation corresponding to a given mode
	 * </li> CAR related budget balance = car rate * fuel taxes * parc occupancy rate * parc pricing policy
	 * </li> PUBLIC TRANSPORT related budget balance = public transport rate * pricing
	 * </li> BIKE NO pricing, but local subvention policies
	 */
	float __get_taxes_coefficient(mode m) {
		float all_trips <- float(sum(mycity._MODE.values collect (sum(each))));
		switch m { 
			match CAR {
				float parc_factor <- mean(mycity.q collect (each.parccupancy)) * __parc_price;
				return (1 + sum(mycity._MODE[CAR]) / all_trips - mycity.car_infrastructure_dimension) * __taxe_fuel * parc_factor;
			}
			match PUBLICTRANSPORT {
				float bus_trips_ratio <- sum(mycity._MODE[PUBLICTRANSPORT]) / all_trips;
				return (1 + bus_trips_ratio - mycity.pt_infrastructure_dimension) * __bus_price;
			}
			match BIKE { return 1.0; /* TODO : is there any taxing policy at all regarding active modes ?*/ }
		}
	} 
	
	/*
	 * Budget given in €
	 */
	float _actual_budget {
		return budget / STARTING_BUDGET * world.__actual_base_annual_budget(mycity);
	}
	
}
