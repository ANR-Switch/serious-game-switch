/**
* Name: STest
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model STest

import "../AlphaSwitch.gaml"
import "SBuilder.gaml"

global {
	
	// PARAMETERS
	
	float FT;
	float PTT;
	float PP;
	float LT;
	
	bool BS;
	bool EV;
	
	reflex __update_params {
		ask thecity.mayor {
			__taxe_fuel <- max(0, min(2.0, FT));
			__bus_price <- max(0, min(2.0, PTT));
			__parc_price <- max(0, min(2.0, PP));
			__local_taxe <- max(0, min(2.0, LT));
			__bike_subsidies <- BS ? 0.1 : 0.0;
			// __ev_subvention <- EV ? 0.5 : 0.0;
		}
	}
	
	// INFRASTRUCTURE ACTIONS
	
	string Md;
	string DF;
	string DT;
	bool overall <- false;
	float amount;
	
	list<string> _districts <- [CBD] + range(nb_mixed_district-1) collect (MD+" "+(each+1))
										+ range(nb_residential_district-1) collect (RD+" "+(each+1)) const:true;
	
	///////////////////////////////////////////////////////////////
	
	
	list<rgb> layerColor <- [#teal,#slateblue,#mediumorchid];
	switchBuilder SWITCH_BUILDER { create SimBuilder; return first(SimBuilder); }
	
	// OUTPUT
	map<string,list<float>> rad_income <- radar_fact() update:radar_fact();
	map<string,list<float>> rad_child <- radar_fact("nbchild") update:radar_fact("nbchild");
	map<string,list<float>> rad_householder <- radar_fact("head of household") update:radar_fact("head of household");
	
	map<string,list<float>> radar_fact(string rf <- "income") {
		map<string,list<float>> res;
		switch rf {
			match "income" {
				res <- [LOW_INCOMES,MEDIAN_INCOMES,HIGH_INCOMES] as_map (each::length(mode) list_with 0.0);
				loop i over:[LOW_INCOMES,MEDIAN_INCOMES,HIGH_INCOMES] {
					ask household where (each.incomes=i) {
						res[i] <- mode collect (res[i][int(each)] + __mode_scores[each] / __mode_scores_incr);
					} 
				}
			}
			match "nbchild" {
				res <- [0,1,2,3,4] as_map (each::length(mode) list_with 0.0);
				loop i over:[0,1,2,3,4] {
					ask household where (each.number_of_child = i or (i=4 and each.number_of_child >= i)) {
						res[string(i)] <- mode collect (res[string(i)][int(each)] + __mode_scores[each] / __mode_scores_incr);
					} 
				}
			}
			match "head of household" {
				res <- [SINGLE, COUPLE] as_map (each::length(mode) list_with 0.0);
				loop i over:[SINGLE, COUPLE] {
					ask household where (each.householder=i) {
						res[i] <- mode collect (res[i][int(each)] + __mode_scores[each] / __mode_scores_incr);
					} 
				}
			}
		}
		float mx <- max(res.values accumulate each);
		if mx=0 {return res;}
		loop k over:res.keys { res[k] <- res[k] collect (each/mx); }
		return res;
	}
	
	map<string, map<string,float>> spider_criteria update:critxhousehold();
	
	map<string, map<string,float>> critxhousehold {
		map<string, map<string,float>> res <- CRITERIAS as_map (each::map<string,float>([]));
		loop c over:CRITERIAS {
			loop m over:mode {
				res[c][m.name] <- mean(household collect (each.__criterias[c][m]/each.__mode_scores_incr));
			}
		}
		return res;
	}
	
}

experiment TEST type:gui {
	
	// ==============
	// PRICING POLICY
	parameter "Taxe on fuel" var:FT category:"Pricing" min:0.1 max:2.0 init:1.0;
	parameter "Public transport pricing" var:PTT category:"Pricing" min:0.1 max:2.0 init:1.0;
	parameter "Parcking pricing" var:PP category:"Pricing" min:0.1 max:2.0 init:1.0;
	parameter "Local taxes" var:LT category:"Pricing" min:0.1 max:2.0 init:1.0;
	
	// ----------------
	// SUBSIDIES POLICY
	// TODO turn it into a slider (amount of support) and cost based on potential change
	parameter "Active mode subvention" var:BS category:"Public support actions" init:false;
	// parameter "Electric vehicles subvention" var:EV category:"Public support actions" init:false;
	
	// ============================
	// INFRASTRUCTURE UPDATE POLICY
	parameter "Targeted infrastructure" var:Md among:[CARMODE,BIKEMODE,PUBLICTRANSPORTMODE] init:CARMODE category:"Infrastructure update";
	parameter "Over the whole network" var:overall category:"Infrastructure update" disables:[DF,DT];
	parameter "From" var:DF among:_districts init:_districts[0] category:"Infrastructure update";
	parameter "To" var:DT among:_districts init:_districts[0] category:"Infrastructure update";
	parameter "Amount of budget" var:amount min:0.05 max:0.4 init:0.1 category:"Infrastructure update";
	user_command "Launch public work" category:"Infrastructure update" {
		
		publicwork pw;
		
		if overall { 
			ask thecity.mayor {
				pw <- invest_equipement(mode first_with (each.name=Md),nil,nil,amount);
			}
		}
		else {
			district o <- district[_districts index_of DF];
			district d <- district[_districts index_of DT];
			geometry e <- thecity.access edge_between (o.location::d.location);
			if e = nil { d <- o; }
			ask thecity.mayor { 
				pw <- invest_equipement(mode first_with (each.name=Md),o,d,amount);
			}
		}
		
		string pwhere <- overall ? "at the scale of the city" : 
				(DF=DT? "within "+DF : "between "+DF+" and "+DT); 
		map  result <- user_input_dialog(
			"You are about to build "+Md+" infrastructure "+pwhere+
			"\nThe global cost will be "+with_precision(pw.costs()/1000000,2)+"M€",[ 
				choose("accept?",bool,true,[true,false])
			]);	
		
		ask pw {if bool(result["accept?"]) {do register();} else {do die;}}
	} 
	
	output {
		display main {
			graphics connections {
				loop e over:thecity.access.edges {
					draw geometry(e) buffer (4 * thecity.__get_traffic_from_edge(e) / sum(thecity._MODE.values collect (sum(each)))) color:#grey; 
					draw geometry(e) color:#black;
				}
				loop d over:thecity.q { 
					draw circle(10 * sum(d.pop.values) / sum(thecity.q accumulate (each.pop.values))) at:d.location color:layerColor[d.layer];
				}
			}
		}
		display choices type: 2d {
			chart "household mode choice determinants" type: radar x_serie_labels: ["Habits","Potential"]+CRITERIAS 
			series_label_position: xaxis position: {0,0} size: {0.5,0.5} {
				data "Car" value:[
					mean(household collect (each.__habits[CAR]/each.__mode_scores_incr)),
					mean(household collect (each.__potential[CAR]/each.__mode_scores_incr))] + 
					CRITERIAS collect (spider_criteria[each][CAR.name])
					color:modcolor[CAR];
				data "Bike" value:[
					mean(household collect (each.__habits[BIKE]/each.__mode_scores_incr)),
					mean(household collect (each.__potential[BIKE]/each.__mode_scores_incr))] + 
					CRITERIAS collect (spider_criteria[each][BIKE.name])
					color:modcolor[BIKE];
				data "Public transport" value:[
					mean(household collect (each.__habits[PUBLICTRANSPORT]/each.__mode_scores_incr)),
					mean(household collect (each.__potential[PUBLICTRANSPORT]/each.__mode_scores_incr))] +
					CRITERIAS collect (spider_criteria[each][PUBLICTRANSPORT.name]) 
					color:modcolor[PUBLICTRANSPORT];
			}
			chart "household inner preferences | income" type: radar x_serie_labels: mode collect each.name series_label_position: xaxis
			position: {0.5,0} size: {0.5,0.5} {
				data LOW_INCOMES value:rad_income[LOW_INCOMES];
				data MEDIAN_INCOMES value:rad_income[MEDIAN_INCOMES];
				data HIGH_INCOMES value:rad_income[HIGH_INCOMES];
			}
			chart "household inner preferences | nb child" type: radar x_serie_labels: mode collect each.name series_label_position: xaxis
			position: {0,0.5} size: {0.5,0.5} {
				data "0" value:rad_child["0"];
				data "1" value:rad_child["1"];
				data "2" value:rad_child["2"];
				data "3" value:rad_child["3"];
				data "4+" value:rad_child["4"];
			}
			chart "household inner preferences | householder" type: radar x_serie_labels: mode collect each.name series_label_position: xaxis
			position: {0.5,0.5} size: {0.5,0.5} {
				data SINGLE value:rad_householder[SINGLE];
				data COUPLE value:rad_householder[COUPLE];
			}
		}
		display graphs type:2d {
			chart "mode proportion" type: series memorize:false {
				loop m over:mode { data m.name value:sum(thecity._MODE[m]) color:modcolor[m]; }
			}
		}
		display heats type:2d {
			chart "cars" type:heatmap x_serie_labels:["D1","D2","D3","D4","D5","D6"] 
			position: {0,0} size: {1.0,0.5} {
				data "cars" value:rows_list(thecity._MODE[CAR]) color:[modcolor[CAR]] accumulate_values: false;
			}
			chart "bike" type:heatmap x_serie_labels:["D1","D2","D3","D4","D5","D6"] 
			position: {0,0.5} size: {0.5,0.5} {
				data "cars" value:rows_list(thecity._MODE[BIKE]) color:[modcolor[BIKE]] accumulate_values: false;
			}
			chart "public transport" type:heatmap x_serie_labels:["D1","D2","D3","D4","D5","D6"] 
			position: {0.5,0.5} size: {0.5,0.5} {
				data "public transport" value:rows_list(thecity._MODE[PUBLICTRANSPORT]) color:[modcolor[PUBLICTRANSPORT]] accumulate_values: false;
			}
		}
		display playerbudget type:2d {
			chart "budget" type:series {data "budget" value:first(mayor).budget;}
		}
	}
	
}