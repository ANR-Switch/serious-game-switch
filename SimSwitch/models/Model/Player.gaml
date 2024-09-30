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
	pair<float,float> political_score {
		
		// Based on modes policy compare to household preferences 
		float splus;
		float smoins;
		mayor mm <- first(mayor);
		ask household {
			pair<float,float> score;
			loop m over:mode { 
				// WEIGHT OF MODE
				float mw <- mod_potential[m]/sum(mod_potential.values);
				map<string,float> mp <- mode_revealed_preferences(m);
				loop c over:m.criterias.keys {
					// WEIGHT OF CARACTERISTICS
					float critweight <- prio_criterias[c]/sum(prio_criterias.values);
					// Sum to 1
					float r <- (critweight+mw)/2;
					if (mp[c] < 0 and mm.__city_modes_policy[m][c] < 1.0) or 
						(mp[c] > 0 and mm.__city_modes_policy[m][c] > 1.0) { 
						score <- (score.key + r)::score.value;
					} else if (mp[c] < 0 and mm.__city_modes_policy[m][c] > 1.0) or 
						(mp[c] > 0 and mm.__city_modes_policy[m][c] < 1.0){
						score <- score.key::(score.value + r);
					}
				}
			}
			splus <- splus + score.key * __weight/100 * satlevel();
			smoins <- smoins + (score.value * __weight/100) / satlevel();
		}
		
		return splus::smoins;
		
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
	
	// CITY MODES POLICY
	map<mode,map<string,float>> __city_modes_policy; // TODO : init based on households preferences
	
	// Car restriction policies
	int lowemitionzone <- 4;
	map<string,float> __restricted_cars <- INCOME_LEVEL as_map (each::0.0);
	
	// Public transport overall quality
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
		
		// TODO : monitor city mode policy toward household, i.e. __city_mode_policy[mheu][?]
		
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
		
		// TODO : monitor city mode policy toward household, i.e. __city_mode_policy[CAR][?]
		
		return last(carparkpw); 
	}
	
	// Reduce speed limit, i.e. add a multiplicative factor lower than 1 to the criteria TIME on CAR
	action lowerspeedlimit(int speedlimit) {
		
		// équivaut au fait de passer de 50 à 40 TODO : explicit?
		__city_modes_policy[CAR][TIME] <- __city_modes_policy[CAR][TIME] * speedlimit/BASE_SPEED_LIMIT; 
		// TODO : put a price on it !!!
		
		mycity._CAROAD <- mycity._CAROAD collect (max(0,min(1,each * __city_modes_policy[CAR][TIME]))) as_matrix {length(district),length(district)};  
	}
	
	// Based on the strenght of car habits, households may (probabilistic) or may not switch toward other modes
	action forbidoldcar(int critair) {
		if critair < 0 { critair <- 0; } if critair > 4 { critair <- 4; }
		lowemitionzone <- critair;
		float level <- sum(CRITS copy_between (0,lowemitionzone));
		
		__city_modes_policy[CAR][PRICE] <- min(10,max(1,__city_modes_policy[CAR][PRICE] - __city_modes_policy[CAR][PRICE] * level));
		__city_modes_policy[CAR][ECOLO] <- min(10,max(1,__city_modes_policy[CAR][PRICE] + __city_modes_policy[CAR][PRICE] * level / CAR.criterias[ECOLO]));
		
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
	
	// Household that are willing to buy new modes using subsidies
	// WARNING : trigger each time a household habits switch toward concerned mode
	action allow_subsidies_to(household hh, district d, mode m, float diff) {
		float amount <- d.pop[hh]/mycity.total_population() * diff;
		if amount < 0 {error "Should not trigger subsidies when people mode shift is negative "+m+" = "+diff;}
		switch m {
			match BIKE { 
				if __bike_subsidies > 0 { 
					__accorded_bike_subsidies <- __accorded_bike_subsidies + amount;
					__city_modes_policy[BIKE][PRICE] <- __city_modes_policy[BIKE][PRICE] + __city_modes_policy[BIKE][PRICE] * amount / length(household); 
				}
			}
			match CAR { 
				if __ev_subsidies > 0 { 
					__accorded_ev_subsidies <- __accorded_ev_subsidies + amount;
					__city_modes_policy[CAR][PRICE] <- __city_modes_policy[CAR][PRICE] + __city_modes_policy[CAR][PRICE] * amount / length(household);
				}
			}
		}
		
	}
	
	/*
	 * Action that directly goes up/down on "objective" criteria of modes 
	 */
	action promote_criteria(mode m, string crit, float amount) {
		if not (CRITERIAS contains crit) {
			error crit+" should be one among "+CRITERIAS;
		}
		ask mode { criterias[crit] <- min(10,max(1,criterias[crit] + criterias[crit]*amount)); }
		__city_modes_policy[m][crit] <- __city_modes_policy[m][crit] + __city_modes_policy[m][crit]*amount; 
	}
	
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
		float __invest;
		
		// SUBSIDIES
		// Pay over a year subsidies when household switch toward more bike in mobility
		if __accorded_bike_subsidies > 0 {
			__accorded_bike_subsidies <- __accorded_bike_subsidies - __accorded_bike_subsidies * #day/#year; // Reduce the amount of people asking for subsidies
			__invest <- __invest + __accorded_bike_subsidies * __bike_subsidies * STARTING_BUDGET * #day/#year; // Add the amount of subsidies corresponding to the investment for this round
		}
		
		// Same amount of subsidies for CAR vs BIKE ????
		if __accorded_ev_subsidies > 0 {
			__accorded_ev_subsidies <- __accorded_ev_subsidies - __accorded_ev_subsidies * #day/#year; // Reduce the amount of people asking for subsidies
			__invest <- __invest + __accorded_ev_subsidies * __ev_subsidies * STARTING_BUDGET * #day/#year; // Add the amount of subsidies corresponding to the investment for this round
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
		
		// PUBLIC TRANSPORT 'OVER'FUNCTIONNING
		float overallinputratio <- sum(ALL_BUDGET_INPUT_RATIO);
		__invest <- __invest + (overallinputratio - overallinputratio / __pt_boost) * STARTING_BUDGET * #day/#year;
		
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
	 * 
	 * </li> CAR related budget balance = car rate * fuel taxes * parc occupancy rate * parc pricing policy
	 * </li> PUBLIC TRANSPORT related budget balance = public transport rate * pricing
	 * </li> BIKE NO pricing, but local subvention policies
	 * 
	 * It is used to compute how much budget input local authorities can have from mode taxation
	 * (sort of balance between cost - infrastructure dimension - and benefit - proportion of use) 
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
