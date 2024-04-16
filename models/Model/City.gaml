/**
* Name: SCity
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model City

import "Modes.gaml"
import "Pop.gaml"
import "Player.gaml"
import "../Parameters.gaml"

/**
 * 
 */
species city {
	
	mayor mayor;
	
	// TODO : use a agragated level, like month, may be with a year scenario
	float current_weither <- rnd(WEATHER_RANGE.key,WEATHER_RANGE.value) update:rnd(WEATHER_RANGE.key,WEATHER_RANGE.value);
	
	graph access;
	list<district> q;
	
	// Main transport matrices - number of trip per mode
	map<mode, matrix<int>> _MODE;
	
	// =============
	// Accessibility
	
	// Connectivity of public transport &
	// Dedicated public transport infrastructure 
	matrix<float> _PUBLICTRANSPORT;
	
	// Dedicated infrastructure for bikes : density of infrastructure compared to the overall network
	// https://www.notre-environnement.gouv.fr/themes/amenagement/transport-et-mobilite-ressources/article/les-francais-et-le-velo-en-2022#:~:text=Selon%20cette%20source%2C%20le%20réseau,voies%20de%20bus%20partagées%20(source
	matrix<float> _BIKEROAD;
	
	// https://www.tomtom.com/traffic-index/france-country-traffic/
	// French cities car time travel / time travel due to congestion 
	matrix<float> _CAROAD;
	
	// ==============
	// Infrastructure
	
	list<publicwork> publicworks;
	
	// TODO infrastructure modification should lower or increase expected infrastructure usage ratio
	float car_infrastructure_dimension <- CARMOBEXP min:0.01 max:1.0;
	float pt_infrastructure_dimension <- PUBMOBEXP min:0.01 max:1.0;
	float bike_infrastructure_dimension <- BIKMOBEXP min:0.01 max:1.0;
	
	// =========================
	
	/**
	 * Various aspect of a given trip including: <br/> 
	 * DISTANCE, WEITHER, CYCLING_ROAD, PUBLIC_TRANSPORT_OFFER & TRAFIC_JAM
	 */
	map<string,float> trip(district o, district d) {
		map<string,float> res;
		
		loop a over:TRIPATTRIBUTES {
			switch a {
				match DISTANCE {
					res[DISTANCE] <- o.dist[d];
					if res[DISTANCE]<1 or not(is_number(res[DISTANCE]))  {res[DISTANCE] <- 1;}
				}
				match WEITHER { res[WEITHER] <- current_weither; } 
				match CYCLING_ROADS {
					float sumofdisturbances <- sum(publicworks collect (each._disturbances[BIKE][int(o),int(d)]));
					res[CYCLING_ROADS] <- _BIKEROAD[int(o),int(d)] * sumofdisturbances;
				}
				match PUBLIC_TRANSPORT_OFFER { 
					float sumofdisturbances <- sum(publicworks collect (each._disturbances[PUBLICTRANSPORT][int(o),int(d)]));
					res[PUBLIC_TRANSPORT_OFFER] <- _PUBLICTRANSPORT[int(o),int(d)];
				}
				match TRAFIC_JAM {
					float sumofdisturbances <- sum(publicworks collect (each._disturbances[CAR][int(o),int(d)]));
					// TODO : a valider
					float infra_x_usage <- sum(_MODE[CAR])=0 ? 1 : sum(_MODE[CAR])/sum(_MODE.values collect (sum(each))); 
					res[TRAFIC_JAM] <- _CAROAD[int(o),int(d)] * infra_x_usage * sumofdisturbances;
				}
			}
		}
		
		return res;
	}
	
	/*
	 * Return the distribution of trips from district 'd' to all others
	 * (including trips inside the district), using a given mode 'm' 
	 */
	map<district,int> district_trip_distribution(district d, mode m) {
		list<int> trips <- rows_list(_MODE[m])[int(d)];
		return district as_map (each::trips[int(each)]);
	}
	// ===================================
	// UTILS TO COLLECT DATA ABOUT TRAFFIC
	
	/*
	 * Return the district from the geometry of the nodes of the _access_ the graph
	 */
	district __get_district_from_node(geometry node) { return district first_with (each.location=node); }
	
	/*
	 * Return origin / destination from the geometry of the edges of the _access_ graph
	 */
	pair<district,district> __get_district_from_edge(geometry edge) { return __get_district_from_node(access source_of edge)::__get_district_from_node(access target_of edge); }
	
	/*
	 * Get number of trips from the geometry of the edges of the _access_ graph
	 */
	int __get_traffic_from_edge(geometry edge, mode m <- nil) { 
		pair<district,district> od <- __get_district_from_edge(edge);
		if m=nil {return sum(_MODE.values collect (each[int(od.key),int(od.value)] + each[int(od.value),int(od.key)]));}
		return _MODE[m][int(od.key),int(od.value)]+_MODE[m][int(od.value),int(od.key)];
	}
	
	// =========================
	
	/**
	 * District attribute 'q' should be init before to call this action
	 */
	action __init_accessibility_matrices(point baccess <- {0.0,1.0}, point pt_access <- {0.0,1.0}, point carpacity <- {0.0,1.0}) {
		// bike roads matrics = how good is the bike dedicated infrastructures between districts
		_BIKEROAD <- {length(q),length(q)} matrix_with 0.0;
		loop x from:0 to:length(q)-1 { loop y from:0 to:length(q)-1 { _BIKEROAD[{x,y}] <- rnd(baccess.x,baccess.y); } }
		// public transport matrics = how good is the public transport offer between districts
		_PUBLICTRANSPORT <- {length(q),length(q)} matrix_with 0.0;
		loop x from:0 to:length(q)-1 { loop y from:0 to:length(q)-1 { _PUBLICTRANSPORT[{x,y}] <- rnd(pt_access.x,pt_access.y); } }
		// car road congestion factor
		_CAROAD <- {length(q),length(q)} matrix_with 0.0;
		loop x from:0 to:length(q)-1 { loop y from:0 to:length(q)-1 { _CAROAD[{x,y}] <- 1 - rnd(pt_access.x,pt_access.y); } }
	}
	
	// =========================
	// Generic accessor
	
	/*
	 * Mean of access matrix for a given mode
	 */
	float overallaccess(mode m) {
		switch m {
			match CAR { return mean(_CAROAD); }
			match BIKE { return mean(_BIKEROAD); }
			match PUBLICTRANSPORT { return mean(_PUBLICTRANSPORT); }
		}
	}
	
	/*
	 * Return the total population of the city
	 */
	int total_population {
		int totalpop;
		loop d over:q { loop h over:d.pop.keys { totalpop <- totalpop + d.pop[h] * h.size;} }
		return totalpop;
	}
	
}

/**
 * 
 */
species district {
	
	city c;
	
	int layer;
	map<household,int> pop;
	
	// ACTIVITY
	int work_amenity;
	int leisure_amenity;
	int residential;
	
	// DISTANCE MATRIX
	map<district,float> dist;
	
	// PARCKING CAPACITY
	int parcapacity;
	// Parcking rate of occupancy : the higher the value, the harder finding a parcking slot
	float parccupancy <- 1.0 update:(sum(columns_list(c._MODE[CAR])[int(self)]) + sum(pop.keys collect (each.mod_potential[CAR]*pop[each]))) / parcapacity;
	
	/**
	 * Reconstruct the OD matrix based on household preferences
	 */
	reflex update_mode_choice when:every(#day) {
		map<household,bool> lh <- (pop.keys where (pop[each] > 0)) as_map (each::false);
		// Except on monday / saturday more or less keep the same OD matrix
		if [1,2,3,4,6] contains current_date.day_of_week { 
			list<household> ml <- lh.keys where each.reevaluate_mobility_behavior();
			lh <- ml as_map (each::true);
		}
		map<mode,list<int>> districtOD <- __HOUSEHOLD_OD_MATRIX(current_date.day_of_week >= 5 ? LEISURE : WORK, lh);
		loop m over:mode {
			loop d over:district {
				// For each mode and each destination update the global city OD matrix
				c._MODE[m][int(self),int(d)] <- districtOD[m][int(d)];
			}
		}
		
	}
	
	// ################################## //
	// 		 INNER UTILZZZ METHODS		  //
	// ################################## //
	
	/**
	 * 
	 * Compute the OD matrix that summarize trips of all households living 
	 * in this district
	 * 
	 * return for each mode, the corresponding number of trips toward each district
	 * referenced with corresponding index in a list (entry one is nb trip, with given
	 * mode, toward the first district, entry one toward district two, etc.)
	 * 
	 */
	map<mode,list<int>> __HOUSEHOLD_OD_MATRIX(string purpose <- WORK, map<household,bool> hld <- []) {
		map<mode,list<float>> res <- map([]);
		// add matrices for each mode
		loop m over:mode {
			list<int> local_trip <- [];
			loop d over:c.q {
				local_trip <+ c._MODE[m][int(self),int(d)];
			}
			res[m] <- local_trip;
		}
		
		// for each households in this district
		loop hh over: hld.keys {
			// distribute them to other districts (inculding self) 
			map<district,float> dm <- hh.target_score(self, purpose, hld[hh]);
			float ts <- sum(dm.values);
			// In each destination district
			loop d over:c.q {
				// Compute mode preference toward it
				map<mode,float> mc <- hh.mode_choices(self, d, purpose);
				// dp = district proportion
				float dp <- dm[d] / ts;
				// For each mode, add corresponding quantity of trips
				loop m over:mc.keys where (mc[each] > 0) {
					// mp = mode proportion
					float mp <- mc[m] / sum(mc.values);
					// toadd = quantity of household hh to add for trip o::d (d from dp) with mode m (m from mp)
					float toadd <- pop[hh] * dp * mp;
					res[m][int(d)] <- res[m][int(d)] + toadd;
				}	
			}
			ask hh {do update_modpotential(myself);}
		}
		
		float sumoftrips <- sum(res.values collect sum(each));
		if sumoftrips = 0.0 { /* write "ZERO TRIP FROM A DISTRICT"; */ return res; }
		
		// Normalize trips, based on new mode choice from households
		float normalizer <- sum(pop.values) / sumoftrips;
		
		// Issue of integerization see https://stackoverflow.com/questions/792460/how-to-round-floats-to-integers-while-preserving-their-sum
		map<mode,list<int>> int_res <- mode as_map (each::length(c.q) list_with 0);
		float frt <- 0.0;
		int irt <- 0;
		loop m over:mode { 
			loop d over:c.q {
				frt <- frt + res[m][int(d)] * normalizer;
				int_res[m][int(d)] <- round(frt) - irt;
				irt <- irt + int_res[m][int(d)]; 
			} 
		}
		
		// check of the integerisation process
		if sum(int_res.values collect sum(each)) != sum(pop.values) {
			error "Discrepancy between district population ("
					+sum(pop.values)+") and number of trips ("
					+sum(int_res.values collect sum(each))+")";
		}
		
		return int_res;
	}
	
}
