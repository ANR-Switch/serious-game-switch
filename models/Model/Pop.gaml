/**
* Name: Pop
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Pop

import "../Parameters.gaml"
import "../Constants.gaml"
import "City.gaml"

global {
	
	household create_household(string householder, int nb_child, string income) {
		if not([SINGLE,COUPLE] contains householder) {
			error householder+" is not a proper head struture for households; should be within "+[SINGLE,COUPLE];
		}
		if not([LOW_INCOMES,MEDIAN_INCOMES,HIGH_INCOMES] contains income) {
			error income+" is not a proper income level; should be within "+[LOW_INCOMES,MEDIAN_INCOMES,HIGH_INCOMES];
		}
		create household with:[householder::householder,number_of_child::nb_child,incomes::income] {
			size <- (householder=SINGLE ? 1 : 2) + number_of_child;
			budget <- insee_budget[incomes];
		}
		
		return last(household);
	}
	
	/**
	 * Adjust satisfaction distribution of households
	 */
	reflex mobsatisfaction when:every(#week) {
		city c <- first(city);
		ask household {
			float w <- 1+abs(__mobemotion)+abs(__mobattitude);
			list<int> oldhnm <- copy(happy_n_mobility); // Keep old sum of sat
			
			// update satisfaction
			happy_n_mobility <- range(length(happy_n_mobility)-1) collect
				((happy_n_mobility[each] + 
					(__mobemotion>0?HAPPYEST[each]*__mobemotion:HAPPYLESS[each]*abs(__mobemotion)) +
					(__mobattitude>0?HAPPYEST[each]*__mobattitude:HAPPYLESS[each]*abs(__mobattitude))
				) / w);
			// control for same "sum of sat"
			int actualsum <- sum(happy_n_mobility);
			happy_n_mobility <- happy_n_mobility collect (round(each * sum(oldhnm)/actualsum));
			
			// integerisation regulation
			int amountregu <- sum(oldhnm) - sum(happy_n_mobility);
			if amountregu > 0 {
				list regu <-  range(length(happy_n_mobility)-1) sort_by (happy_n_mobility[each]-oldhnm[each]);
				loop i over:regu copy_between (0,amountregu) { happy_n_mobility[i] <- happy_n_mobility[i]+1; }
			} else if amountregu < 0 {
				list regu <-  range(length(happy_n_mobility)-1) sort_by (oldhnm[each]-happy_n_mobility[each]);
				loop i over:regu copy_between (0,abs(amountregu)) { happy_n_mobility[i] <- happy_n_mobility[i]-1; }
			}
			
			if sum(oldhnm) != sum(happy_n_mobility) { error "Integer regularisation has failed: old="+sum(oldhnm)+" | new="+sum(happy_n_mobility);}
			
			// Decrease emotion arising from event, slowly when strong, fast when soft
			__mobemotion <- (__mobemotion<0?-1:1)*(__mobemotion^2);
			__mobattitude <- (1-ATTITUDESHIFT) * __mobattitude + eval_infrastructure(c) * ATTITUDESHIFT;
		}
	}
	
}


// ********************************************************** //
//
// https://nausikaa.net/index.php/switch-simuler-la-mobilite/
//
// ********************************************************** //

/*
 * Represent a type of household, i.e. combination of the 4 demographics
 */
species household schedules:[] {
	
	float __weight;
	int __population;
	
	// Budget
	int budget;
	
	// Demographics
	int size;
	string householder;
	int number_of_child;
	string incomes;
	
	// Mobility
	map<string,int> prio_criterias; // Weight of mobility criteria - household POV
	map<mode,float> mod_potential; // synthesis habits and potential (e.g. number of vehicles owned)
	map<mode,matrix<float>> trip_habits; // passed mobilities
	
	// How happy this kind of household is regarding the state of the city they live in
	list<int> happy_n_mobility <- copy(HAPPYDIST);
	// Bad events (like in AET)
	float __mobemotion <- 0.0 min:-0.99 max:0.99;
	// Bad attitude alignment (I can't do what i want, what i need, what i desireved, etc.)
	float __mobattitude <- 0.0 min:-1.0 max:1.0;
	
	// ************
	// Cogntivie bias
	
	bool halo <- BHALO;
	float habit <- BHABIT;
	float reactance <- BREACT;
	float norm <- BNORM;
	
	// ************
	// reporting
	int __mode_scores_incr <- 1;
	map<mode,float> __mode_scores <- mode as_map (each::0.0);
	// inner decision determinants
	map<mode,float> __habits <- mode as_map (each::0.0);
	map<mode,float> __potential <- mode as_map (each::0.0);
	map<mode,float> __norms <- mode as_map (each::0.0);
	// raw scoring [-1;1]
	map<string,map<mode,float>> __criterias <- CRITERIAS as_map (each::mode as_map (each::0.0));

	
	// ########### //
	
	// Mode choice //
	
	// ########### //
	
	
	map<mode,float> mode_choices(district o, district d, string p) {
		
		// HABITUS
		map<mode,float> res <- mode as_map (each::trip_habits[each][{int(o),int(d)}]*habit);
		/* REPORT */ __habits <- mode as_map (each::(__habits[each]+res[each]));
		
		// POTENTIAL
		res <- mode as_map (each::(mod_potential[each] + res[each]));
		/* REPORT */ __potential <- mode as_map (each::(__potential[each]+mod_potential[each]));
		
		// SOCIAL NORM
		map<mode,float> snorm <- mode as_map (each::0.0);
		map<household,float> normalizers <- (household-self) as_map (each::hamming_dist(each)); 
		ask household-self {
			loop m over:mode { 
				snorm[m] <- snorm[m] + trip_habits[m][int(o),int(d)] * normalizers[self]/sum(normalizers.values);
			}
		}
		
		res <- mode as_map (each::(res[each] + snorm[each] * BNORM));
		/* REPORT */ __norms <- mode as_map (each::__norms[each]+snorm[each]);
		
		if res.values one_matches (each>10) {error "Mode score is way too high";}
		
		// Contextual aspect of the trip
		map<string,float> trip <- o.c.trip(o,d);
		map<mode,float> accessibility;
		accessibility[CAR] <- trip[TRAFIC_JAM] * d.parccupancy;
		accessibility[BIKE] <- trip[CYCLING_ROADS];
		accessibility[PUBLICTRANSPORT] <- trip[PUBLIC_TRANSPORT_OFFER];
		
		// CONTEXTUAL CRITERIA
		map<mode,map<string,float>> modecritval <- mode as_map (each::CRITERIAS as_map (each::0.0));
		string halotarget;
		
		mode pref <- halo ? mod_potential.keys with_max_of mod_potential[each] : nil;
		
		write "\n";
		loop m over:mode {
			
			//-------//
			// DEBUG //
			//-------//
			
			// eval of safe, easy and confort are all negative values
			// because around 5/6 in criteria pref & around the same for each mode
			// which is close to 0 in [-1,1] evaluation of criterias
			
			//write m.name+" > "+sample(accessibility[m]);
			
			// CRITERIAS x PREF :: [-1;1]
			map<string,float> modxcrit <- CRITERIAS as_map (each::mod_x_pref(m,each));
			
			modecritval[m][TIME] <- _time_eval(m,trip[DISTANCE]*#km,accessibility[m],modxcrit[TIME]);
			//write TIME+"|"+prio_criterias[TIME]+" = "+modecritval[m][TIME];
			
			modecritval[m][PRICE] <- _price_eval(m,o,modxcrit[PRICE]);
			//write PRICE+"|"+prio_criterias[PRICE]+" = "+modecritval[m][PRICE]; 
			
			// TODO : add impact of public communication
			modecritval[m][ECOLO] <- modxcrit[ECOLO];
			//write ECOLO+"|"+prio_criterias[ECOLO]+" "+m.name+"|"+m.criterias[ECOLO]+" = "+modecritval[m][ECOLO];
			
			modecritval[m][CONFORT] <- (modxcrit[CONFORT] + modxcrit[CONFORT] < 0 ? accessibility[m]-1 : accessibility[m]) / 2;
			// write CONFORT+"|"+prio_criterias[CONFORT]+" "+m.name+"|"+m.criterias[CONFORT] +" x "+accessibility[m]+" = "+modecritval[m][CONFORT];
			
			modecritval[m][SAFE] <- _secure_eval(m,accessibility[m],modxcrit[SAFE]);
			// write SAFE+"|"+prio_criterias[SAFE]+" "+m.name+"|"+m.criterias[SAFE] +" = "+modecritval[m][SAFE];
			
			// TODO : modify how accessibility modify evaluation
			modecritval[m][EASY] <- modxcrit[EASY] /* (m!=CAR ? accessibility[m] : 1)*/;
			// write EASY+"|"+prio_criterias[EASY]+" "+m.name+"|"+m.criterias[EASY] +(m!=CAR ? " x "+accessibility[m] : "")+" = "+modecritval[m][EASY];
			
			// =========
			// HALO BIAS
			if m=pref { 
				halotarget <- CRITERIAS with_min_of modecritval[m][each];
				// critxmod[halotarget] <- 1.0; // because it is a cumulative decision
			}
			
			/* REPORT */ loop c over:CRITERIAS { __criterias[c][m] <- __criterias[c][m] + modecritval[m][c]; }
			
		}
		
		// write "PREF["+int(self)+"] = "+pref.name+" halo bias = "+halotarget;
		
		map<mode,float> criteval <- [];
		loop m over:mode { 
			list<string> critlist <- CRITERIAS-halotarget;
			// TODO : decide if the aggregation of mode criterias evaluation should be made as a sum, mean or else ?
			switch COG_EVAL_AGGREGATION {
				match SUM {criteval[m] <- sum(critlist collect (modecritval[m][each]));}
				match MEAN {criteval[m] <- mean(critlist collect (modecritval[m][each]));}
				match MEDIAN {criteval[m] <- median(critlist collect (modecritval[m][each]));}
				default {error COG_EVAL_AGGREGATION+" should be implemented";}
			}
		}
		
		write "\t=> "+mode collect (each.name+":"+criteval[each]) ;
		
		res <- mode as_map (each::res[each] + criteval[each]);
		// if res.values one_matches (each < 0) {error "negative pref regarding contextual criteria";}
		
		// EVOLVE HABITS
		do update_habits(o,d,res);
		
		// WARNING : INNER UTILITY TO SEE SCORES
		__mode_scores <- res.keys as_map (each::__mode_scores[each]+res[each]);
		__mode_scores_incr <- __mode_scores_incr + 1;
		
		return res;
	}
	
	// -------------------
	// CRITERIA EVALUATION
	
	/*
	 * How household evaluates time criteria to choose a mode
	 */
	float _time_eval(mode m, float distance, float accessibility, float preference) {
		return (dist_to_decision(m, distance) + accessibility) / 2 * (preference+1);
	}
	
	/*
	 * How household evaluates price criteria to choose a mode
	 */
	float _price_eval(mode m, district o, float preference) {
		return (preference+1) / o.c.mayor.price_factor(m) * 
			(1 - MOBCOST[INCOME_LEVEL index_of incomes , int(m)]/budget) / 4;
	}
	
	/*
	 * How secure a mode is ! (CAR in general, BIKE relative to accessibility, PT relative to confort policy) 
	 */
	float _secure_eval(mode m, float accessibility, float preference, float boost <- 1.0) {
		switch m {
			match CAR { return preference; }
			match BIKE { return (2 * preference + preference < 0 ? accessibility-1 : accessibility) / 3; }
			match PUBLICTRANSPORT {
				float ptc <- first(mayor).__city_modes_policy[PUBLICTRANSPORT][CONFORT]; 
				return min(1, preference * preference < 0 ? 1/ptc : ptc);
			}
			default {error m.name+" should be implemented in household._secure_eval()";}
		}
	}
	
	// Based on data gives a score for a mode on a given distance
	// <5#km | <10#km | <20#km | <35#km | <50#km
	float dist_to_decision(mode m, float d) {
		map<float,float> distmap <- DISTPREF[m.name];
		loop k over:distmap.keys { if d <= k {return distmap[k];} }
	}
	
	// Impact of weather on mode choice
	float weather(mode m, float current_weather) {
		switch m {
			match CAR { return 1.0 / min(1, max(MAX_GOOD_WEITHER_CAR_DIVIDER, WEATHER_RANGE.value - current_weather)); }
			match BIKE { return min(MAX_GOOD_WEITHER_BIKE_MULTIPLIER, current_weather); }
			match PUBLICTRANSPORT {
				float midpoint <- (WEATHER_RANGE.key + WEATHER_RANGE.value) / 2;
				return current_weather > midpoint ? 
						min(midpoint+MAX_PUBLIC_TRANSPORT_WEITHER_RANGE, current_weather)
						: max(midpoint-MAX_PUBLIC_TRANSPORT_WEITHER_RANGE, current_weather);
			}
		}
	}
	
	// REVEALED PREFERENCES
	map<string,float> mode_revealed_preferences(mode m) { 
		return __criterias.keys as_map (each::__criterias[each][m]/__mode_scores_incr);
	}
	
	// ---------------------------------
	// MODE CRITERIA SCORE x PREFERENCES
	
	list<int> pref_to_argth <- [100,40,20,7,4,2.5,1.9,1.5,1.2,1];
	
	/**
	 * basically an activation function, as an argth(x)_w \p
	 * returns [-1,1]
	 */ 
	float mod_x_pref(mode m, string criteria) {
		float eval <- m.criterias[criteria];
		// Impact of policy on mode score
		float policy <- first(mayor).__city_modes_policy[m][criteria];
		eval <- min(CRITERIA_MAXEVAL,max(CRITERIA_MINEVAL,eval*policy));
		
		int midv <- round(CRITERIA_MAXEVAL/2);
		float activation <- ln(
			(1 + (eval-midv)/9.15) / (1 - (eval-midv-CRITERIA_MINEVAL)/9.45)
		) / pref_to_argth[prio_criterias[criteria]-1];
		if activation < -1 or activation > 1 {
			write m.name+ " x "+criteria+" ("+eval+"|"+prio_criterias[criteria]+") = "+activation;
		}
		return activation;
	}
	
	// ------------------
	// CHOOSE DESTINATION
	
	map<string,matrix<float>> __targets_pref <- AMENITIES as_map (each::matrix<float>([]));
	
	/*
	 * Return the district target score
	 */
	map<district,float> target_score(district origin, string purpose, bool refresh <- false) {
		
		// destinations
		list<district> diss <- origin.c.q;
		
		//
		// Init or refresh preferencies
		//
		if refresh or empty(__targets_pref[purpose]) {
			matrix cm <- {length(diss),length(diss)} matrix_with 0.0;
			loop o over:diss {
				loop d over:diss {
					float basic_attractivity <- purpose=WORK ? float(d.work_amenity) :
											(purpose=LEISURE ? float(d.leisure_amenity) :
																float(d.residential));
					switch incomes {
						match HIGH_INCOMES { cm[int(o),int(d)] <- basic_attractivity/(1+d.layer*HIGH_INCOME_PLayer); }
						match MEDIAN_INCOMES { 
							cm[int(o),int(d)] <- basic_attractivity/(1+(d.layer*(1-MID_INCOME_PDistance) + o.dist[d]/world.shape.width*MID_INCOME_PDistance));
						}
						match LOW_INCOMES { cm[int(o),int(d)] <- basic_attractivity/(1+o.dist[d]/world.shape.width*LOW_INCOME_PDistance); }
					}
				}
			}
			__targets_pref[purpose] <- cm;
		}
		
		// Retrieve stored preferences
		return diss as_map (each::__targets_pref[purpose][int(origin),int(each)]);
	}
	
	// ----------------------------
	// HABITS & POTENTIAL EVOLUTION
	
	/**
	 * Evoluation of habits : should be subject to bias
	 * Triggered each time a OD mode choice is made by the household
	 */
	action update_habits(district origin, district destination, map<mode,float> behavior, float rate <- RATE_EVO_HABITS) {
		
		map<mode,float> adjusted_behavior <- copy(behavior); 
		
		// If there is negative values
		float adjust <- min(behavior.values);
		if adjust<0 { adjusted_behavior <- mode as_map (each::behavior[each]+adjust);}
		// from behavior weights to a sum-to-one repartition
		float adjusum <- sum(adjusted_behavior.values);
		adjusted_behavior <- mode as_map (each::adjusted_behavior[each]/adjusum);
		
		map<mode,pair<float,float>> modechange;
		loop m over:adjusted_behavior.keys {
			// store old habits on mode m
			float old_habit <- trip_habits[m][{int(origin),int(destination)}]; 
			trip_habits[m][{int(origin),int(destination)}] <- adjusted_behavior[m] * rate + trip_habits[m][{int(origin),int(destination)}] * (1 - rate);
			// store old::new
			modechange[m] <- old_habit::trip_habits[m][{int(origin),int(destination)}];  
		}
	}
	
	/**
	 * Represent the contribution to a sub-population of this type of household
	 * to change mode ownership (i.e. sell/buy cars, bikes and public transport pass)
	 */
	action update_modpotential(district d, float rate <- MODE_POTENTIAL_INERTIA) {
		float localpotential <- d.pop[self]/__population;
		// GOTO CAR
		float carhabits <- mean(trip_habits[CAR]); // habits
		float carestriction <- d.c.mayor.__restricted_cars[incomes]; // restriction
		
		// CARESTRICTION
		if  carestriction > 0 and flip(1-carhabits) {
			__mobemotion <- (__mobemotion+carhabits)/2; // Add to unsatisfaction
			float newpotential <- mod_potential[CAR] * MODE_POTENTIAL_INERTIA + (mod_potential[CAR]-carestriction) * (1-MODE_POTENTIAL_INERTIA);
			mod_potential[CAR] <- (1-localpotential) * mod_potential[CAR] + newpotential * localpotential;  
		}
		
		// TODO : go for EV should be biased by household wealth
		if d.c.mayor.__ev_subsidies > 0.0 and mod_potential[CAR] < carhabits {
			float newpotential <- mod_potential[CAR] * MODE_POTENTIAL_INERTIA + carhabits * (1-MODE_POTENTIAL_INERTIA);
			// Ask for the subsidies
			ask d.c.mayor {do allow_subsidies_to(myself,d,CAR,newpotential-myself.mod_potential[CAR]);}
			// Apply new potential
			mod_potential[CAR] <- (1-localpotential) * mod_potential[CAR] + newpotential * localpotential;
		}
		
		// GOTO BIKE
		float bikehabits <- mean(trip_habits[BIKE]);
		if d.c.mayor.__bike_subsidies > 0.0 and mod_potential[BIKE] < bikehabits { 
			float newpotential <- mod_potential[BIKE] * MODE_POTENTIAL_INERTIA + bikehabits * (1-MODE_POTENTIAL_INERTIA);
			// Ask for the subsidies
			ask d.c.mayor {do allow_subsidies_to(myself,d,BIKE,newpotential-myself.mod_potential[BIKE]);}
			// Apply new potential
			mod_potential[BIKE] <- (1-localpotential) * mod_potential[BIKE] + newpotential * localpotential;  
		}
		
		// TODO : GOTO PT = Safety ???
	}
	
	/**
	 * Based on strenght of habits, how probable a reevaluation of mobility choices should be done by this type of household
	 */
	bool reevaluate_mobility_behavior(float ceiling <- MOBILITY_BEHAVIOR_INERTIA) { 
		return flip(1-(MOBILITY_BEHAVIOR_INERTIA+max(trip_habits collect mean(each)))/2);
	}
	
	// ------------
	// SATISFACTION
	
	// sum of above average amount (>5) divided by the sum of below average amount (<5)
	float satlevel { return sum(happy_n_mobility copy_between (5,9)) / sum(happy_n_mobility copy_between (0,4)); }
	
	// sum of difference between actual and global satisfaction
	float satrelativ { return sum(range(length(HAPPYDIST)-1) collect (happy_n_mobility[each]-HAPPYDIST[each])); }
	
	// ---------------------
	// NORMS & SOCIAL DETERMINANTS
	
	/*
	 * Return the hamming distance between current household and given household types
	 */
	float hamming_dist(household other) {
		float res;
		res <- householder = other.householder ? 1 : 0;
		res <- res + (number_of_child = other.number_of_child ? 1 : 0);
		res <- res + (incomes = other.incomes ? 1 : 0);
		res <- res + CRITERIAS count (
			prio_criterias[each] >= other.prio_criterias[each]-1 and
			prio_criterias[each] <= other.prio_criterias[each]+1
		)/length(CRITERIAS);
		return res / 4;
	}
	
	// ---------------------
	// EVALUATION OF ACTIONS
	
	// DIRECT IMPACT ON MOBILITY SATISFACTION
	// SHOULD BE BASED ON ACTUAL MOBILITY HABITS 
	
	float eval_infrastructure(city c) {
		float ei <- 0.0;
		loop m over:mode {
			// Potential + habits
			float wm <- (mod_potential[m]+mean(trip_habits[m]))/2;
			// Discrepancy between accessibility and desired/actual behavior
			ei <- ei + (c.overallaccess(m) - wm) / length(mode);
		}
		return ei;
	}
	
}

