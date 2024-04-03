/**
* Name: GameBuilder
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model GameBuilder

import "GUI.gaml"

global {
	
}

species gameBuilder parent:switchBuilder {
	
	action INIT_UI {
		lockeDis <- square(50) at_location {-shape.width*6,shape.height/2};
		mode_plot <- square(50) at_location {-shape.width*4,shape.height/2};
		wealth_plot <- square(50) at_location {-shape.width*3,shape.height/2};
	}
	
	/**
	 * 
	 * Build a city with circular UI !
	 * 
	 */
	city CITY_BUILDER {
			
		list<geometry> lines;
		geometry l1;
		geometry l2;
		list<geometry> city_layout;
		
		point ct <- world.shape.centroid;
		
		float r <- 40#m;
		// Creates districts
		create districtUI with:[name::CBD,layer::0,work_amenity::10,leisure_amenity::10,residential::2];
		float r0 <- 10#m;
		create districtUI with:[name::MD,layer::1,work_amenity::rnd(3,7),leisure_amenity::rnd(2,4),residential::rnd(4,6)] number:4;
		float r1 <- 15#m;
		create districtUI with:[name::RD,layer::2,work_amenity::rnd(1,3),leisure_amenity::rnd(2,8),residential::rnd(5,10)] number:10;
		
		// Create city
		create cityUI with:[q::list(districtUI)];
		cityUI cui <- first(cityUI);
		ask districtUI {c <- cui;}
		
		// Create city shape
		cui.shape <- circle(r,ct);
		
		// City center
		districtUI cbd <- districtUI first_with (each.layer=0);
		cbd.shape <- circle(r0,ct);
		
		// Ring layers
		// -----------
		// shapes of rings
		lines <+ cbd.shape.contour;
		l1 <- (cbd.shape buffer r1) - cbd.shape;
		lines <+ l1.contour;
		l2 <- cui.shape - cbd.shape - l1;
		lines <+ l2.contour;
		
		// First ring
		int l1s <- districtUI count (each.layer = 1);
		loop i from: 1 to:l1s { 
			int cut <- rnd( 360/l1s * (i-1), 360/l1s * i );
			lines <+ line(
				{ct.x + r0 * cos_rad(cut * #pi/180), ct.y + r0 * sin_rad(cut * #pi/180)}, 
				{ct.x + (r0+r1) * cos_rad(cut * #pi/180), ct.y + (r0+r1) * sin_rad(cut * #pi/180)}
			);
		}
		
		// Second ring
		int l2s <- districtUI count (each.layer = 2);
		loop i from: 1 to:l2s { 
			int cut <- rnd( 360/l2s * (i-1), 360/l2s * i );
			lines <+ line(
				{ct.x + (r0+r1) * cos_rad(cut * #pi/180), ct.y + (r0+r1) * sin_rad(cut * #pi/180)}, 
				{ct.x + r * cos_rad(cut * #pi/180), ct.y + r * sin_rad(cut * #pi/180)}
			);
		} 
		
		list lines <- clean_network(lines,1#m,true,true);
		
		geometry environment <- copy(cui.shape);
		loop l over: lines {environment <- environment - (l + 1);}
		city_layout <- environment.geometries;
		
		// Create the districts
		list<districtUI> d1 <- districtUI where (each.layer=1);
		list<districtUI> d2 <- districtUI where (each.layer=2);
		loop d over:city_layout {
			if cbd.shape covers d.centroid { ask districtUI first_with (each.layer=0) {shape <- d;} }
			else if l1 covers d.centroid { districtUI cd <- any(d1); ask cd {shape <- d;} d1 >- cd; }
			else if l2 covers d.centroid { districtUI cd <- any(d2); ask cd {shape <- d;} d2 >- cd; }
		}
		
		// Create accessibility network
		cui.access <- as_edge_graph(lines);
		ask districtUI {
			dist <- (districtUI - self) as_map 
				(each::(topology(cui.access) distance_between [self,each]));
		}
	
		// Create mobility matrices between districts
		// -----
		// walkers matrice = to fake the movement of households
		cui._WALKERS <- {length(districtUI),length(districtUI)} matrix_with 0;
		// accessibility matrices
		ask cui { do __init_accessibility_matrices({0.2,0.8},{0.4,0.6}); }
				
		return cui;
	}
	
}