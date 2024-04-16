/**
* Name: NewModel
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model AlphaSwitch

import "Constants.gaml"
import "Parameters.gaml"

import "Model/Modes.gaml"
import "Model/Pop.gaml"
import "Model/City.gaml"
import "Model/Player.gaml"

global {
	
	date starting_date <- #now; 
	float step <- 6#h;
	
	city thecity;
	
	switchBuilder sb;
	
	// Simple city builder
	init {
		
		sb <- SWITCH_BUILDER();
		
		// Create the city
		thecity <- sb.CITY_BUILDER();
		write "The city has been built";
		
		ask sb {do MODES_BUILDER();}
		
		// Create player agent
		ask sb {do INIT_MAYOR(thecity);}
		write "You are the mayor !";
		
		// Create households
		ask sb {do POP_SYNTH(thecity);}
		write "Population has been initialized";
		
		ask sb {do AGENDA(thecity);}
		write "Basic mobility practices has been created";
		loop m over:mode {
			if thecity._MODE[m] one_matches (each < 0) {error "one mode has negative number of trips";}
			write "\t"+m.name+" trips: "+sum(thecity._MODE[m]);
		}
		
		// TODO move to the UI builder
		ask sb {do INIT_UI();}
		
	}
	
	switchBuilder SWITCH_BUILDER virtual:true;
	
}

species switchBuilder {
	
	city CITY_BUILDER virtual:true;
	action INIT_UI virtual:true;
	
	/**
	 * Generation of synthetic population
	 */
	action POP_SYNTH(city c) {
			
		// HH creation
		float weight <- 0.0;
		loop head over:[SINGLE,COUPLE] {
			loop child over:[0]+insee_enfants.keys {
				loop income over:insee_revenu.keys {
					if child=0 {
						weight <- head=SINGLE ? insee_menage[SINGLE] : insee_menage[COUPLE];
					} else {
						weight <- (head=SINGLE ? insee_menage[SINGLE+CHILD] : insee_menage[COUPLE+CHILD]+insee_menage[OTHER]) * insee_enfants[child] / 100;	
					}
					weight <- weight * insee_revenu[income] / 100;
					
					household hh;
					ask world {hh <- create_household(head, child, income);}
					ask hh { 
						__weight <- weight;
						if child=last(insee_enfants.keys) { 
							loop while:flip(0.10) {number_of_child <- number_of_child+1; size <- size+1;}
						}
					}
					
					ask c.q { pop[hh] <- 0; }
					
				}
			}
		}
		
		// Check weights
		float s <- sum(household collect (each.__weight));
		if abs(100 - s) > 0.001 { error "weights do not sum to one but to "+s; }
		
		// HH Localisation with uniform integerisation
		int hhunit <- sum(household collect (each.size * each.__weight));
		float hhfactor <- popsize * 1.0 / hhunit;
		
		// Overall population of households
		map<household,int> hhpop <- household as_map (each::round(hhfactor*each.__weight));

		// Pop weights for each district
		map<district,int> district_pop_weight;
		
		// CBD has low pop 
		district cbd <- c.q first_with (each.layer=0);
		district_pop_weight[cbd] <- (cbd.shape.area+1) * cbd.residential;
		
		// Ring districts get more pop (*2 factor)
		loop i over:remove_duplicates(c.q collect (each.layer)) {
			loop d over:c.q where (each.layer=i) {
				district_pop_weight[d] <- (d.shape.area+1)*round(rnd(0.5,1.5)*d.residential);
			}
		} 
		
		// HH Localisation revenu criteria
		// TODO : turn this into a parameter of income related spatial distribution people in the city
		list<list<int>> c2s_revenu <- [[1,3,6],[2,4,2],[4,2,1]];
		
		loop hh over:hhpop.keys {
			map<district,int> local_distribution <- copy(district_pop_weight);
			int ridx <- insee_revenu.keys index_of hh.incomes;
			local_distribution <- local_distribution.keys as_map (each::local_distribution[each] * c2s_revenu[each.layer][ridx]);
			loop times:hhpop[hh] { 
				ask rnd_choice(local_distribution) { pop[hh] <- pop[hh]+1; }
			}
		}
		
		ask household { __population <- sum(c.q collect (each.pop[self])); }
		write "Total population in the city is "+c.total_population();
		
		// Add parcking places, i.e. 1.85 / inhabitant
		// see https://www.banquedesterritoires.fr/la-fnaut-presente-laddition-salee-du-stationnement-automobile-en-france
		ask c.q { parcapacity <- sum(pop.values) * max(0.5, gauss(1.85,0.2)); }
		
	}
	
	/**
	 * 
	 * Build agenda
	 * 
	 */
	action AGENDA(city c) {
		
		map<mode,float> lim;
		map<mode,float> mim;
		map<mode,float> him;
		
		ask mode { 
			lim[self] <- LOW_INCOME_MODES[name];
			mim[self] <- MIDDLE_INCOME_MODES[name];
			him[self] <- HIGH_INCOME_MODES[name];
		}
		
		ask household {
			map<list<int>,int> with_kids <- [RISKAVERS_ECOLO::1,
				INDIFFERENT::min(2,number_of_child),PRAGMATIC::min(2,number_of_child),
				CONFORT_ORIENTED::max(2,number_of_child),POOR_ECOLO::min(2,number_of_child)
			];
			map<list<int>,int> localprofiles;
			
			// add the impact of household structure to mode ownership
			map<string,float> hsm <- MENAGE_MODES[householder + (number_of_child > 0 ? CHILD : "")];
			
			// HABITUS
			mod_potential <- mode as_map (each::MODE_EXPECTED_RATIO[each.name]);
			
			switch incomes {
				match LOW_INCOMES {
					// MODE POTENTIAL
					mod_potential <- lim.keys as_map (each::(lim[each] + hsm[each.name] + mod_potential[each])/3);
					// PROFILE
					localprofiles <- number_of_child = 0 ? LOW_INCOME_POP_PROFILE : MOBPROFILES as_map (each::LOW_INCOME_POP_PROFILE[each] * with_kids[each]);
				}
				match MEDIAN_INCOMES {
					// MODE POTENTIAL
					mod_potential <- mim.keys as_map (each::(mim[each] + hsm[each.name] + mod_potential[each])/3);
					// PROFILE
					localprofiles <- number_of_child > 0 ? with_kids : MIDDLE_INCOME_POP_PROFILE; 
				}
				match HIGH_INCOMES {
					// MODE POTENTIAL
					mod_potential <- him.keys as_map (each::(him[each] + hsm[each.name] + mod_potential[each])/3);
					// PROFILE
					localprofiles <- number_of_child = 0 ? HIGH_INCOME_POP_PROFILE : MOBPROFILES as_map (each::HIGH_INCOME_POP_PROFILE[each] * with_kids[each]);
				}
			}
			
			trip_habits <- mode as_map (each::{length(c.q),length(c.q)} matrix_with 0);
			loop o over:c.q { 
				loop d over:c.q { 
					loop m over:mode {
						float odmd <-  DISTPREF[m.name][DISTPREF[m.name].keys first_with (each > o.dist[d]*1#km)];
						trip_habits[m][{int(o),int(d)}] <- (mod_potential[m] + odmd) / 2;
					}
				}
			}
			
			// RATIONAL CRITERIAS
			list<int> profile <- rnd_choice(localprofiles);
			prio_criterias <- CRITERIAS as_map (each::profile[CRITERIAS index_of each]);
			
		}
		
		c._MODE <- mode as_map (each::{length(c.q),length(c.q)} matrix_with 0); 
		
		loop o over:c.q {
			map<mode,list<float>> districtOD <- o.__HOUSEHOLD_OD_MATRIX(hld::(o.pop.keys where (o.pop[each]>0) as_map (each::true)));
			loop m over:mode {
				loop d over:c.q {
					c._MODE[m][int(o),int(d)] <- districtOD[m][int(d)];
				}
			}
		}
	}
	
	/**
	 * Modes to be used for travel by households
	 */
	action MODES_BUILDER {
		
		create mode with:[name::BIKEMODE,criterias::BIKE_CRITS];
		BIKE <- last(mode);
		modcolor[BIKE] <- #teal;
		
		create mode with:[name::PUBLICTRANSPORTMODE,criterias::BUS_CRITS];
		PUBLICTRANSPORT <- last(mode);
		modcolor[PUBLICTRANSPORT] <- #orchid;
		
		create mode with:[name::CARMODE,criterias::CAR_CRITS];
		CAR <- last(mode);
		modcolor[CAR] <- #firebrick;
		
		// BUILD COST MATRIX BASED ON DATA REGARDING HOUSEHOLD TRANSPORT CONSUMPTION
		MOBCOST <- {length(insee_revenu),length(mode)} matrix_with 1.0;
		
		loop i over:INCOME_LEVEL {
			loop m over:mode {
				MOBCOST[INCOME_LEVEL index_of i, int(m)] <- insee_budget[i] * insee_mobility_budget_ratio[i] * insee_mode_budget_ratio[m.name];
			}
		}
		
	}
	
	/*
	 * Create the player 
	 */
	mayor INIT_MAYOR(city c) { 
		create mayor with:[mycity::c] {
			loop m over:mode { __city_modes_policy[m] <- CRITERIAS as_map (each::1.0); } // TODO : may be not initial 1.0 for every mode and criterias
		} 
		ask c {self.mayor <- first(mayor);}
		return c.mayor; 
	}
	
}