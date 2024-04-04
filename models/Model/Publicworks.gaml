/**
* Name: Publicworks
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Publicworks

import "City.gaml"

/* Insert your model definition here */

/**
 * Public works for infrastructure
 */
species infrapw parent:publicwork {
	
	/*
	 * 
	 */
	action apply {
		matrix<float> infra;
		bool whole <- target=PUBLICWORK_NOTARGET;
		switch m {
			match CAR {
				infra <- c._CAROAD;
				// TODO : impact on bikes
			}
			match BIKE {
				infra <- c._BIKEROAD;
				// TODO : impact on cars
			}
			match PUBLICTRANSPORT {
				infra <- c._PUBLICTRANSPORT;
				// TODO : impact on cars / bikes
			}
		}
		// actual changes
		if whole {infra <- infra + infra * amount;}
		else { infra[target] <- max(0, (min(1, infra[target] + infra[target] * amount))); }
		
		// normalize [0:1] values
		loop x from:0 to:infra.columns-1 { loop y from:0 to:infra.rows-1 { 
					infra[{x,y}] <- max(0,min(1,infra[{x,y}]));
				}}
	}
	
	float costs {
		// TODO : add district specific costs
		return world.__actual_base_annual_budget(c)*amount
				*BUDGET_COST_RATIO_MODE[m.name]
				*duration()/1#year
				*(target=PUBLICWORK_NOTARGET ? 1.5 : 1); // penalty on global public work
	}
	
	float duration {
		float duration_pw_per_5km <- (target = PUBLICWORK_NOTARGET ?
			sum(first(district).dist.values) : 
			district[target.x].dist[district[target.y]]) / 5; // length of public works
		return PUBLICWORK_LAST_5KM_TRANSPORT * duration_pw_per_5km;
	}
	
}

/**
 * Public work on carparks
 */
species carparkpw parent:publicwork {
	
	int evol;
	float removalratio <- 1/2;
	
	init {
		amount <- 0.01; // TODO : parameter?
	}
	
	// =========================== //
	
	action apply {
		district d <- __distarget();
		d.parcapacity <- d.parcapacity + evol; 
	}
	
	float costs {
		return abs(evol) * CARPARK_PRICE / (ln(__distarget().layer+2)) * (evol<0?removalratio:1);
	}
	
	float duration {
		return abs(evol)/100 * PUBLICWORK_LAST_100CARPARK;
	}
	
	// =========================== //
	
	district __distarget {
		if target.x>=0 { return district[int(target.x)]; } 
		return district[int(target.y)];
	} 
}

/**
 * 
 Public work to adapt city mobility related infrastructure over time, with disturbances, compute costs, etc..
 * 
 */
species publicwork control:fsm virtual:true {
	mode m; // mode to act directly upon
	city c; 
	point target <- PUBLICWORK_NOTARGET; // specific section of the city to work on
	float amount; // overall effort in equipement improvement
	
	date startdate;
	date endate;
	
	float _disturbance;
	map<mode,matrix<float>> _disturbances;
	
	state start initial:true {
		enter { 
			if not (c.publicworks contains self) {
				error "Il faut enregistrer les travaux publiques dans les registres municipaux !!!";
			}
			startdate <- current_date;
			// Global end time depends on the size of the public work
			endate <- current_date + duration() * (amount+rnd(0.8,1.3));
		}
		transition to:ongoing when:true;
	}
	
	state ongoing {
		// disturbance is computed in between 0 and 0.2
		enter { _disturbance <- sqrt(amount*PWDISTURBANCE); }
		
		matrix<float> bm <- {length(c.q),length(c.q)} matrix_with 1.0;
		matrix<float> bm05 <- {length(c.q),length(c.q)} matrix_with 1.0;
		matrix<float> bm02 <- {length(c.q),length(c.q)} matrix_with 1.0;
		int weekremaining <- (current_date-endate)/1#week;
		float yearlong <- 1+duration()/#year;
		float actualD <- _disturbance * (1 - 2 * (1 - 1 / (1 + #e ^ (weekremaining/yearlong))));
		
		// OVERALL CITY ???
		if target=PUBLICWORK_NOTARGET { 
			 bm <- {length(c.q),length(c.q)} matrix_with 1-actualD;
			 bm05 <- copy(bm) * (1-actualD*0.5);
			 bm02 <- copy(bm) * (1-actualD*0.2);
		} else {
			list<point> dt;
			if target.x<0 or target.y<0 {
				// TOWARD/FROM ONE DISTRICT
				dt <- target.x<0 ? (district collect {target.x,int(each)}) : (district collect {int(each),target.y});
			} else {
				// ON A GIVEN OD SEGMENT
				dt <- [target,{target.y,target.x}];
			}
			loop d over:dt {
				bm[d] <- 1-actualD;
				bm05[d] <- 1-actualD*0.5;
				bm02[d] <- 1-actualD*0.2;
			}
		} 
		
		// Always max disturbances for cars
		_disturbances[CAR] <- bm;
		// Max disturbances if bike is targeted, otherwise mitigate disturbances 0.5
		_disturbances[BIKE] <- m=BIKE ? bm : bm05;
		// Max disturbances if public transport is targeted, otherwise minimal disturbances 0.2
		_disturbances[PUBLICTRANSPORT] <- m=PUBLICTRANSPORT ? bm05 : bm02;
		
		// DISTURBANCES ARE APPLIED IN : city.trip(o,d,m) method
		
		transition to:end when:current_date >= endate;
	}
	
	// APPLY INFRASTRUCTURE IMPROVEMENT AND CLOSE PUBLIC WORK
	state end final:true {
		enter {
			write "PUBLIC WORKS ON "+m+" ENDED !";
			do apply;
			c.publicworks >- self; // unregister
			ask self {do die;} // remove agent
		}
	}
	
	action apply virtual:true;
	float costs virtual:true;
	float duration virtual:true;
	
	/*
	 * Register public works in the city admin store
	 */
	action register { c.publicworks <+ self; }
	
}