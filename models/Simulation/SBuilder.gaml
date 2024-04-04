/**
* Name: SimSwitch
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model SimSwitch

import "STest.gaml"

species SimBuilder parent:switchBuilder {
	
	city CITY_BUILDER {
		
		graph<district,unknown> citynetwork <- spatial_graph([]);
		
		world.shape <- square(CBD_WIDTH+MD_WIDTH*2+RD_WIDTH*2);

		// Creates center buisness district
		geometry cbdarea <- circle(CBD_WIDTH/2) at_location world.shape.centroid; 
		create district with:[name::CBD,layer::0,
			work_amenity::CBDA[WORK],
			leisure_amenity::CBDA[LEISURE],
			residential::CBDA[RESIDENTIAL]
		];
		district cbd <- first(district);
		cbd.location <- cbdarea.centroid;
		// Add a node to city network
		add node(cbd) to:citynetwork;
		
		// Mixed districts
		geometry mdarea <- (cbdarea buffer (MD_WIDTH/2)) - cbdarea;
		create district with:[name::MD,layer::1,
			work_amenity::MDA[WORK],
			leisure_amenity::MDA[LEISURE],
			residential::MDA[RESIDENTIAL]
		] number:nb_mixed_district returns:mixed;
		int idx <- 0;
		// Choose a location around city down town
		loop shp over:mdarea split_geometry (1,nb_mixed_district) { mixed[idx].location <- shp.location; idx <- idx+1; }
		// Add to city network, connecting middle neighborhoods to city downtown
		loop md over:mixed { 
			add node(md) to:citynetwork;
			add edge(md,cbd) to:citynetwork;
		}
		// TODO : how to connect Mixed districts ?
		// loop m over:mixed { connections <<+ (mixed-m) collect (line(each.location,m.location)); } 
		
		// Residential districts
		geometry rdarea <- circle(CBD_WIDTH/2+MD_WIDTH/2+RD_WIDTH/2) at_location world.shape.centroid;
		rdarea <- rdarea - (cbdarea + mdarea);
		list<geometry> areas <- rdarea split_geometry (nb_residential_district, nb_residential_district); 
		create district with:[name::RD,layer::2,
			work_amenity::RDA[WORK],
			leisure_amenity::RDA[LEISURE],
			residential::RDA[RESIDENTIAL]
		] number:nb_residential_district returns:residentials;
		idx <- 0;
		loop rd over:residentials { add node(rd) to:citynetwork; }
		
		list<district> residentialconnectors;
		loop shp over:nb_residential_district among areas { 
			residentials[idx].location <- shp.centroid; 
			
			residentialconnectors <+ district closest_to residentials[idx]; 
			add edge(last(residentialconnectors),residentials[idx]) to:citynetwork;
			
			idx <- idx+1; 
		}
		
		if residentialconnectors none_matches (each.layer < 2) {
			district rdo <- any(residentials);
			add edge(rdo,(district-residentials) closest_to rdo) to:citynetwork;
		}
				
		// Create city
		create city with:[q::list(district)];
		city ct <- first(city);
		
		// TODO : redraw the graph based on
		// 1. location of district as node
		// 2. add edges one by one
		// 3. use the dev version of gama if we do that !!!! 
		ct.access <- citynetwork;
		ask ct { do __init_accessibility_matrices(bike_access, bus_access, car_congestion); }
		
		ask district {
			c <- ct;
			dist <- (district - self) as_map (each::(topology(ct.access) distance_between [self,each]));
		}
		ask cbd {dist[self] <- CBD_WIDTH/2;}
		ask mixed {dist[self] <- MD_WIDTH/2;}
		ask residentials {dist[self] <- RD_WIDTH/2;}
		
		return ct;
	}
	
	// *************** //
	
	action INIT_UI  {
		spider_criteria <- world.critxhousehold();
	}
	
}