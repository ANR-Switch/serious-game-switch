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
		
		world.shape <- square(CBD_WIDTH+MD_WIDTH*2+RD_WIDTH*2);

		list<geometry> connections;

		// Creates center buisness district
		geometry cbdarea <- circle(CBD_WIDTH/2) at_location world.shape.centroid; 
		create district with:[name::CBD,layer::0,
			work_amenity::CBDA[WORK],
			leisure_amenity::CBDA[LEISURE],
			residential::CBDA[RESIDENTIAL]
		];
		district cbd <- first(district);
		cbd.location <- cbdarea.centroid;
		cbd.dist[cbd] <- CBD_WIDTH;
		
		// Mixed districts
		geometry mdarea <- (cbdarea buffer (MD_WIDTH/2)) - cbdarea;
		create district with:[name::MD,layer::1,
			work_amenity::MDA[WORK],
			leisure_amenity::MDA[LEISURE],
			residential::MDA[RESIDENTIAL]
		] number:nb_mixed_district returns:mixed;
		int idx <- 0;
		loop shp over:mdarea split_geometry (1,nb_mixed_district) { mixed[idx].location <- shp.location; idx <- idx+1; }
		connections <<+ mixed collect (line(each.location, cbd.location));
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
		loop shp over:nb_residential_district among areas { 
			residentials[idx].location <- shp.centroid; 
			connections <+ line((district closest_to residentials[idx]).location, residentials[idx].location);
			idx <- idx+1; 
		}
				
		// Create city
		create city with:[q::list(district)];
		city ct <- first(city);
		
		// TODO : redraw the graph based on
		// 1. location of district as node
		// 2. add edges one by one
		// 3. use the dev version of gama if we do that !!!! 
		ct.access <- as_edge_graph(connections);
		ask ct { do __init_accessibility_matrices(bike_access, bus_access, car_congestion); }
		
		ask district {
			c <- ct;
			dist <- (district - self) as_map (each::(topology(ct.access) distance_between [self,each]));
		}
		
		return ct;
	}
	
	// *************** //
	
	action INIT_UI  {
		spider_criteria <- world.critxhousehold();
	}
	
}