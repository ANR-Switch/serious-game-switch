/**
* Name: UI
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model UI

import "GBuilder.gaml"
import "GCity.gaml"

import "../AlphaSwitch.gaml"

global {
	
	district popup on_change:{
		if popup != nil { ask districtUI {popsup <- popup=self?true:false;} first(city_viewer).d <- popup;}
		else if not first(city_viewer).locked_district {ask districtUI {popsup <- false;}}
	};
	
	// COMMAND BUTTONS
	geometry lockeDis;
	
	geometry mode_plot;
	int mp <- 0;
	geometry wealth_plot;
	int wp <- 1;
	
	list<bool> cpbuttons <- [true,false]; 
	image happygradient;
	
	switchBuilder SWITCH_BUILDER { create gameBuilder; return first(gameBuilder); }
	
	// Choose the content of the plot
	action switch_plot(geometry button) {
		cpbuttons <- length(cpbuttons) list_with false;
		switch button {
			match mode_plot { cpbuttons[mp] <- true; }
			match wealth_plot {cpbuttons[wp] <- true; }
		}
	}
	
	// Create a gradient image to display as texture
	image gradient_image(list<rgb> grad, point resolution <- {100,100}) {
		matrix mm <- resolution matrix_with 0;  
		float gradlocation <- float(resolution.x) / length(grad);
		
		loop i from: 0 to: resolution.x-1 {
			int l <- i / gradlocation;
			rgb firstin; rgb firstout;
			if l < length(grad)-1 {
				firstin <- grad[l];
				firstout <- grad[l+1];
			} else {
				firstin <- grad[l-1];
				firstout <- grad[l];
			} 
			
			loop j from: 0 to: resolution.y - 1 {
				mm[j,i] <- blend(firstin,firstout,1 - float(i mod gradlocation) / gradlocation);
			}
		}
		
		return image(mm);
	}
	
}

species mayor_viewer mirrors:mayor {
	
	point location <- world.shape.centroid;
	
	geometry front;
	map<string,geometry> header;
	map<geometry,string> action_boxes;
	
	init {
		// Overall UI space
		geometry g <- rectangle({0,0}, {world.shape.width,world.shape.height}) * 0.95;
		front <- first(g to_rectangles (1,5));
		shape <- g-front;
		// 1) a header to recap budget & popularity
		geometry hdr <- first(shape to_rectangles (1,8));
		list<geometry> h <- hdr to_rectangles (2,1);
		header <- [BUDGET::first(h),POPULARITY::last(h)];
		// 2) actions to undergo 
		shape <- shape - hdr;
		action_boxes <- shape to_rectangles (2,2) as_map (each*0.7::"empty");
		action_boxes[first(action_boxes.keys)] <- INFRASTRUCTURE;
		
		// Utils 
		ask world {happygradient <- gradient_image(happypalette);}
		save image_file(happygradient) to:"../includes/test.png" format:"png";
	}
	
	action mayor_action(point push) {
		
		mayor pl <- target;
		
		geometry p <- action_boxes.keys first_with (push overlaps each);
		if p != nil {
			switch action_boxes[p] {
				match INFRASTRUCTURE {
					map<string,float> result <- user_input_dialog( 
						"Infrastructure investments - available budget: "+pl.budget, 
						mode collect (enter(each.name, 0)) + 
						[choose("Origin", string, first(district),list(district))] +
						[choose("Destination", string, first(district),list(district))]
					);
					// ask pl { loop m over:mode { do infrastructures(thecity, m, district(result['Origin']), district(result["Destination"]), result[m.name]); }}
				}
			}
		}
	}
	
	aspect cycle1 {
		draw "You play the role of urban representatives in the virtual city of ***. 
		The mayor you have been working with just start her
		political mandat. Hence, you have 6 years to help citizens to switch 
		to more sustainable mobility practices"  
		at:{0,0} anchor:#left_center font:font("Arial", 20, #bold) color:contemplative[0]; 
	}
			
	aspect default {
		draw shape border: contemplative[0] wireframe:true;
		draw front border: contemplative[0] color: contemplative[1];
		
		// Draw budget
		draw header[BUDGET] color:#white border:contemplative[0];
		draw BUDGET+" : "+mayor(target).budget color:blend(#gold,#black,0.4) font:font("Arial",15) at:header[BUDGET].points[1]+{header[BUDGET].width/4,-header[BUDGET].height/3};
		// Draw popularity
		// TODO : have a cursor on a palette from red to green
		draw header[POPULARITY] texture:happygradient border:contemplative[0];
		draw POPULARITY+" : NaN" color:#black font:font("Arial",15) at:header[POPULARITY].points[1]+{header[POPULARITY].width/4,-header[POPULARITY].height/3};
		
		loop b over:action_boxes.keys {
			draw b color:actionpalette[action_boxes.keys index_of b];
			draw action_boxes[b] font:font("Arial", 30, #italic) color:#white at:b.points[1]+{b.width/4,-b.height/3};
		}
		draw "CITY HALL" at:front.centroid+{0,0,1} font:font("Arial", 80, #bold) color:#white anchor:#center;
	}
	
}

species city_viewer mirrors:cityUI {
	
	bool locked_district;
	
	district d;
	
	float hboxes <- 0.8;
	float mh <- world.shape.height*0.95;
	float bspace <- 0.05;
	float mw <- world.shape.width*0.95;
	
	point location <- world.shape.centroid;
	int nbc <- 5;
	
	// Parameter
	bool relative <- true;
	
	aspect default {
		
		draw rectangle(mw, mh*hboxes) at:location-{0,mh/2*(1-hboxes)} border: main[0] wireframe:true;
		draw rectangle(mw, mh*(1-hboxes)) at:location+{0,mh/2*hboxes} border: main[0] color: main[1];
		
		if d!=nil {
			
			int dpop <- sum(d.pop.values);
			int dmaxpop <- sum((target.q with_max_of (sum(each.pop.values))).pop.values);
			
			float f <- relative ? dpop * 1.0 / dmaxpop : 1.0;
			
			// INCOMES
			float colx <- mw / (nbc*2);
			float coly <- mh*hboxes;
			
			loop k over:[LOW_INCOMES,MEDIAN_INCOMES,HIGH_INCOMES] {
				list hhs <- d.pop.keys where (each.incomes=k);
				float ch <- (mw * hboxes - mw * bspace) * sum(hhs collect (d.pop[each])) * f / dpop;
				
				draw rectangle(mw / nbc - mw*bspace, ch) at:{colx,coly-ch/2} color:incolor[k];
				draw string(sum(hhs collect (d.pop[each]))) font:font(40,#bold) color:#white at:{colx,coly-ch/2,1} anchor:#center;
				
				coly <- coly-ch;
				
			}
			draw line({0,2},{0,-2}) color:#white at:{colx,mh*hboxes};
			draw "INCOMES" font:font(80,#bold) color:#white at:{colx,mh*0.9,1} anchor:#center;
			
			// HAPPYNESS
			float colx <- mw / (nbc*2) * 3;
			float coly <- mh*hboxes;
			
			list<float> hhh <- list_with(length(HAPPYDIST),0);
			loop hh over:d.pop.keys {
				int i <- 0;
				loop hhl over:hh.happy_n_mobility { hhh[i] <- hhh[i] + hhl * d.pop[hh]; i <- i+1; }
			}
			
			int i <- 0;
			loop h over:hhh {
				float ch <- (mw * hboxes - mw * bspace) * h / sum(hhh);
				
				draw rectangle(mw / nbc - mw * bspace, ch) at:{colx,coly-ch/2} color:happypalette[i];
				//draw string(int(dpop*h/sum(hhh))) font:font(20,#bold) color:i>3?#white:#black at:{colx,coly-ch/2,1} anchor:#center;
				
				coly <- coly-ch; i <- i+1;
			}
			draw line({0,2},{0,-2}) color:#white at:{colx,mh*hboxes};
			draw "HAPPYNESS" font:font(80,#bold) color:#white at:{colx,mh*0.9,1} anchor:#center;
			
			// AMENITIES
			float colx <- mw / (nbc*2) * 5;
			float coly <- mh*hboxes;
			
			map<string,float> amenimap <- [WORK::d.work_amenity,LEISURE::d.leisure_amenity,RESIDENTIAL::d.residential];
			
			int i <- 0;
			loop a over: amenimap.keys {
				float ch <- (mw * hboxes - mw * bspace) * amenimap[a] / sum(amenimap.values);
				
				draw rectangle(mw / nbc - mw * bspace, ch) at:{colx,coly-ch/2} color:amenitypalette[i];
				draw a font:font(20,#bold) color:hot[0] at:{colx,coly-ch/2,1} anchor:#center;
				
				coly <- coly-ch; i <- i+1;
			}
			draw line({0,2},{0,-2}) color:#white at:{colx,mh*hboxes};
			draw "AMENITIES" font:font(80,#bold) color:#white at:{colx,mh*0.9,1} anchor:#center;
		}
	}
}

experiment FANCY type:gui {
	
	float w -> simulation.shape.width; 
	float h -> simulation.shape.height;
	
	font text <- font("Arial", 20, #bold);
	font chart <- font("Arial", 40, #bold);
	
	output {
		
		layout horizontal([vertical([0::1,1::8,2::2])::2,vertical([3::1,4::1])::1]) 
			toolbars: false tabs: false parameters: false consoles: false navigator: false tray: false background: bacolor;
		
		display commands axes:false type: opengl background:bacolor { 
			camera #default locked: true;
			overlay position: { 0.9, 0.1 } size: {0,0} background: # transparent
			{
				draw (string(current_date.year)+"/"+current_date.month+"/"+current_date.day) 
					at: {1200, 50} anchor: #top_right  color: #black font: text;
			}
			graphics ld {
				write first(city_viewer);
				draw lockeDis color:first(city_viewer).locked_district?#red:#grey;
				draw mode_plot color:#blue;
				draw wealth_plot color:#gold;
			}
			
			event #mouse_down { 
				using topology(simulation) {
					bool c <- first(city_viewer).locked_district;
					first(city_viewer).locked_district <- (lockeDis covers #user_location) ? not(c):c;
					if (mode_plot covers #user_location) { ask world {do switch_plot(mode_plot);} }
					else if (wealth_plot covers #user_location) { ask world {do switch_plot(wealth_plot);} }
				}
			}
		}
		
		// ================
		// BENCHMARK
		monitor "walkers management" value:with_precision(wlk_mng / (float(total_duration)/1000) * 100,2);
		monitor "mode choice" value:with_precision(md_ch / (float(total_duration)/1000) * 100,2);
		
		// ================
		// CITY DISPLAY
		display city axes:false camera:"fixed" background: bacolor {
			
			light #ambient intensity: 100;
			
		// ================
		// LEGEND
		
			overlay position: { 30#px,30#px} size: { 0#px, 0#px } background: # transparent 
            	{
            	//for each possible type, we draw a square with the corresponding color and we write the name of the type
                
                draw "Level of income" at: {0, 0} anchor: #top_left  color: #white font: chart;
                float y <- 70#px;
                loop i over: incolor.keys
                {
                    draw square(40#px) at: { 20#px, y } color: incolor[i] ;
                    draw i at: { 60#px, y} anchor: #left_center color: #white font: text;
                    y <- y + 40#px;
                }
                
                y <- y + 20#px;
                draw "Happiness" at: {0, y} anchor: #top_left  color: #white font: chart;
                y <- y + 50#px;
                draw rectangle(40#px, 90#px) at: {20#px, y + 50#px} wireframe: true color: #white;
                loop h over: happypalette
                {
                    draw rectangle(40#px,10#px) at: { 20#px, y } color: rgb(h, 0.8) ;
                    if h=first(happypalette) {draw "10" at: { 50#px, y} anchor: #left_center color: h font: text;}
                    if h=last(happypalette) {draw " 0" at: { 50#px, y} anchor: #left_center color: h font: text;}
                    y <- y + 10#px;
                }
                
            }
			
			// Camera to have a nice angle
			camera "fixed" locked: true location: {w / 1.8, h * 3, w * 2} target: {w / 2, h / 1.8, 0} distance:100#m; 
			
			// TODO add the amount of each mod on a graph below the city
			// TODO add costs variation (delta based on windows of costs) for households 
			// species modegraph;
			
			species cityUI;
			species districtUI;
			species walkers;
			
			// Move over district to highlight them in the city viewer
			event #mouse_move {
				if not first(city_viewer).locked_district {
					using topology(simulation) {
						popup <- districtUI first_with (each covers #user_location);
					}
				}
			}
			
			// When highlighted district is locked, used mouse down to switch
			event #mouse_down {
				if first(city_viewer).locked_district {
					using topology(simulation) {
						districtUI selected <- districtUI first_with (each covers #user_location); 
						popup <- selected=popup?nil:selected;
						if popup=nil {ask districtUI {popsup <- false;}}
					}
				}
			}
			
			event #mouse_exit {
				popup <- nil;
			}
		} 
		
		display statistics axes:false background: bacolor type:2D {
			chart "mode proportion" type: series background:bacolor visible:cpbuttons[0] memorize:false 
				title_visible:false y_tick_values_visible: false y_tick_line_visible: false 
				x_tick_values_visible: false x_tick_line_visible: false 
				axes: #transparent x_label:"" 
				x_range: 100 {
				loop m over:mode {
					data m.name value:sum(thecity._MODE[m]) color:modcolor[m];
				}
			}
		}
		
		// ===============
		// DISTRICT DISPLAYS
		display districts axes:false background: bacolor { species city_viewer; }
		display naratives axes:false background: bacolor { 
			species mayor_viewer;
			
			event #mouse_down { ask mayor_viewer { do mayor_action(#user_location); } }
			
			event #mouse_move {}
			
		}
	}
	
}

