/**
* Name: City
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model City

import "../Constants.gaml"
import "../Parameters.gaml"

import "../Model/Modes.gaml"
import "../Model/Pop.gaml"
import "../Model/City.gaml"

global {
	
	// #################
	// BENCHMARK
	float wlk_mng;
	float md_ch;
	
}

species cityUI parent:city {
	
	// Fake movement in the city
	int __WALKERSCALE <- 20;
	matrix<int> _WALKERS;
	
	reflex manage_walkers when:every(#day) {
		float ct <- machine_time;
		loop o over:q { 
			loop d over:q {
				map<mode,int> modes <- _MODE.keys as_map (each::_MODE[each][int(o),int(d)]);
				int total <- sum(modes.values);
				int diff <- total - _WALKERS[int(o),int(d)] * __WALKERSCALE;
				// Create new walkers
				if diff > __WALKERSCALE { 
					create walkers number:diff / __WALKERSCALE 
						with:[c::self,location::any(o.shape.contour.points),sp::o,ep::d,mod::rnd_choice(modes)] 
						returns:nw;
					_WALKERS[int(o),int(d)] <- _WALKERS[int(o),int(d)] + length(nw);
				}
				// Remove walkers
				else if diff < 0 {
					// TODO try to remove the oldest one first
					ask (1 + round(diff * -1 / __WALKERSCALE)) among (walkers where (each.sp=o and each.ep=d)) {
						c._WALKERS[int(o),int(d)] <- c._WALKERS[int(o),int(d)] - 1; 
						do die;
					}
				} 
			}
		}
		wlk_mng <- wlk_mng + with_precision((machine_time - ct) / 1000,2);
	}
	
	// =========================
	
	aspect default { 
		draw shape at:location-{0,0,0.5} color:rgb(contemplative[0],0.2);
	}
	
}

species walkers skills:[moving] {
	float speed <- 0.1#m/step; 
	mode mod;
	cityUI c;
	district sp;
	district ep;
	reflex move_along {
		
		if sp != ep { 
			do goto target:ep on:c.access; 
			if location distance_to ep < 1#m {location <- c.access.vertices closest_to sp;}
		}
		else { 
			do follow path:path(sp.shape.points+first(sp.shape.points));
		}
		
	}
	aspect default {draw circle(0.5#m) color:modcolor[mod];}
}

species districtUI parent:district {
	
	// VIZZZ
	bool popsup <- false;
	rgb rndc <- rnd_color(255);
	aspect default {
		if popsup { 
			draw shape at:location+{0,0,1#m} color:main[1];
			draw shape at:location+{0,0.7#m,2#m} color:main[2];
		}
		draw shape color:blend(main[0],#transparent,0.4) depth:popsup?1#m:0;
	}
	
}
