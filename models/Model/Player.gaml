/**
* Name: Player
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Player

import "../Model/Modes.gaml"

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
	float budget <- STARTING_BUDGET;
	
	// TAXES
	float __taxe_fuel <- 1.0 min:0.0 max:__MAXTF; float __MAXTF <- 2.0;
	float __parc_price <- 1.0 min:0.0 max:__MAXPP; float __MAXPP <- 2.0; 
	float __bus_price <- 1.0 min:0.0 max:__MAXBP; float __MAXBP <- 2.0;
	
	float __local_taxe <- 1.0 min:0.0 max:2.0; // Adjustement criteria for budget equilibrium
	
	// INCITATIONS
	float __bike_subsidies <- 0.0 min:0.0 max:1.0;
	float __bs_prop <- 0.1;
	float __ev_subsidies <- 0.0 min:0.0 max:1.0;
	float __evs_prop <- 0.25;  
	float __old_cars_exclusion <- 0.0 min:0.0 max:1.0;
	
	// INVESTMENT
	int __invest;
	
	// CITY MODES POLICY
	map<mode,map<string,float>> __city_modes_policy; // TODO : init based on households preferences
	
	// **************
	// PLAYER ACTIONS
	// **************
	
	// Start / stop subsidies for EV or eBike and old cars hindrance
	action subsidies(mode m, float amount, bool startstop <- true) {
		switch m {
			match CAR {
				if amount > 0 { // EV subsidies
					if !startstop { __ev_subsidies <- 0.0; }
					else { __ev_subsidies <- amount;}
				} else { // Forbid older cars
					if !startstop { __old_cars_exclusion <- 0.0; }
					else { __old_cars_exclusion <- amount; }
				}
			}
			match BIKE { // eBike subsidies
				if !startstop { __bike_subsidies <- 0.0; }
				else { __bike_subsidies <- amount; }
			}
		}
	}
	
	// Launches work on infrastructure 
	publicwork invest_equipement(mode m, district o, district d, float amount) {
	
		create publicwork with:[
			m::m.name,c::mycity,amount::amount,
			target::o=nil or d=nil ? PUBLICWORK_NOTARGET : {int(o),int(d)}
		];
		
		return last(publicwork);
	}
	
	// ============================
	// TODO : Add budget costs for the 4 next actions
	
	
	action buildcarpark(district d, int amount) {
		d.parcapacity <- max(1, d.parcapacity + amount);
	}
	
	// Reduce speed limit, i.e. add a multiplicative factor lower than 1 to the criteria TIME on CAR
	action lowerspeedlimit {
		__city_modes_policy[CAR][TIME] <- __city_modes_policy[CAR][TIME] * 0.8; // équivaut au fait de passer de 50 à 40 TODO : explicit? 
	}
	
	// TODO : how to parametrize? if we just change potential, it means people are using other modes, which is not realistic at all
	action forbidoldcar {
		// TODO : Reduce potential
	}
	
	// more PT stops, increased freq. and passengers capacity/confort
	action increasePTatractivness(float confort <- 0.0, float morefreq <- 0.0, float morestops <- 0.0) {
		// passengers capacity/confort : increase directly confort criteria on PT
		__city_modes_policy[PUBLICTRANSPORT][CONFORT] <- __city_modes_policy[PUBLICTRANSPORT][CONFORT]+confort;
		// increase frequency or number of bus stops : increase fiability / time / ease criteria
		// TODO : does it increase SAFE?
		loop i over:[morefreq,morestops] {
			loop c over:[TIME,EASY] {
				__city_modes_policy[PUBLICTRANSPORT][c] <- __city_modes_policy[PUBLICTRANSPORT][c]+i;
			}
		}
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
		
		float __car_input <- carbalance * STARTING_BUDGET * FUEL_TAXE_RATIO_BALANCE * step / #year;
		float __pt_input <- publictransportbalance * STARTING_BUDGET * PT_TAXE_RATIO_BALANCE * PT_PAYMENT_RATIO;
		float __local_tax <- __local_taxe * STARTING_BUDGET * LOCAL_TAXE_RATIO_BALANCE * step / #year;
		
		// SUBSIDIES
		// TODO : make the bike subvention active, when people switch toward this mode
		// __invest <- round(__invest + STARTING_BUDGET * __bike_subsidies);
		
		// PUBLIC WORKS
		__invest <- __invest + sum(
			mycity.publicworks collect (each.costs() / each.duration() // actual costs per year 
				/ world.__actual_base_annual_budget(mycity) // per unit of actual yearly budget
				* step / #year // per step of simulation
			)
		);
		
		// budget has 4 main sources:
		// >> 7% taxe on fuel modulo usage/infrastructure dimension
		// >> 3/5% public transport pricing
		// >> ±50% taxe local (habitation, etc.)
		// >> expense of investment
		budget <- budget + __car_input + __pt_input + __local_tax - __invest;
		
		// RESET INVESTMENT
		__invest <- 0; 
		
//		write sample(__local_taxe);
//		write sample(carbalance);
//		write sample(__car_input);
//		write sample(publictransportbalance);
//		write sample(__pt_input);
//		write sample(__local_tax);
//		write sample(bikebalance);
		
	}
	
	// ************************
	// POPULATION COMMUNICATION
	
	/*
	 * Represent the taxation policy of the municipality, should be around 1 (lower is low taxation and vis versa)
	 * from /2 to x2 factor (i.e. [0.5;2.0]
	 */
	float price_factor(mode m) { 
		switch m { 
			match CAR {
				float mid <- (__taxe_fuel + __parc_price) / 2; 
				return mid < 1 ? mid/2+0.5 : mid;
			} // fuel tax and parcking pricing
			match BIKE {return 1 - __bike_subsidies;} // subvention or not
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
