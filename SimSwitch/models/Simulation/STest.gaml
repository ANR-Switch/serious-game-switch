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
	
	// SCORING
	
	float CPS_POS; 
	float CPS_NEG;
	float SAT_POP; 
	
	// PARAMETERS
	
	// CogBias
	bool HL <- BHALO; // halo
	float HBT <- BHABIT; // habits 
	float SN <- BNORM; // social norm
	
	// taxes
	float FT;
	float PTT;
	float PP;
	float LT;
	
	// Launch subsidies for ebikes (or second life, maintenance, etc.)
	bool BS; // on_change:{ ask mayor {__bike_subsidies <- BS ? BSA : 0.0;} };
	float BSA;
	// Launch subsidies for ecars
	bool EV;
	float EVA;
	// Speed limit
	int SL;
	// Old car exclusion
	int ZFE;
	
	// Public transport services
	float PTC;
	float PTF;
	
	// Update policy of player based on parameters
	reflex __update_params {
		ask thecity.mayor {
			__taxe_fuel <- max(0, min(__MAXTF, FT));
			__bus_price <- max(0, min(__MAXBP, PTT));
			__parc_price <- max(0, min(__MAXPP, PP));
			__local_taxe <- max(0, min(__MAXLT, LT));
			__bike_subsidies <- BS ? BSA : 0.0;
			__ev_subsidies <- EV ? EVA : 0.0;
			if SL!=BASE_SPEED_LIMIT {do lowerspeedlimit(SL); BASE_SPEED_LIMIT <- SL;}
			if ZFE!=lowemitionzone {do forbidoldcar(ZFE);}
			do increasePTatractivness(PTC,PTF);
		}
		pair<float,float> score <- political_score();
		CPS_POS <- score.key; CPS_NEG <- score.value;
		SAT_POP <- mean(household collect (each.satlevel())); 
		// COGBIAS
		ask household { habit <- HBT; halo <- HL; norm <- SN;}
	}
	
	// INFRASTRUCTURE ACTIONS
	
	string Md;
	string DF;
	string DT;
	bool overall <- false;
	float amount;
	
	string CPT;
	int nbcarparks <- 0;
	
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
	
	// UTILS : Display revealed preferences
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
	parameter "Active mode subvention" var:BS category:"Public support actions" init:false enables:[BSA];
	parameter "eBike subsidies" var:BSA category:"Public support actions" min:0.1 max:1.0 init:0.2;
	parameter "Electric vehicles subvention" var:EV category:"Public support actions" init:false enables:[EVA];
	parameter "EV subsidies" var:EVA category:"Public support actions" min:0.01 max:1.0 init:0.05;
	
	// ----------------
	// NON STRUCTURED POLICY
	parameter "Speed limit" var:SL category:"Public support actions" min:20 max:70 init:50 step:10;
	parameter "Old car exclusion" var:ZFE category:"Public support actions" min:1 max:4 init:4;
	
	// ----------------
	// PUBLIC TRANSPORT SERVICES
	parameter "Public transport confort" var:PTC category:"Public transport sevices" min:0.0 max:1.0 init:0.0;
	parameter "Public transport frequency" var:PTF category:"Public transport sevices" min:0.0 max:1.0 init:0.0;
	
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
			pw <- thecity.mayor.invest_equipement(mode first_with (each.name=Md),nil,nil,amount);
		}
		else {
			district o <- district[_districts index_of DF];
			district d <- district[_districts index_of DT];
			geometry e <- thecity.access edge_between (o.location::d.location);
			if e = nil { d <- o; }
			pw <- thecity.mayor.invest_equipement(mode first_with (each.name=Md),o,d,amount);
		}
		
		string pwhere <- overall ? "at the scale of the city" : 
				(DF=DT? "within "+DF : "between "+DF+" and "+DT); 
		map  result <- user_input_dialog(
			"You are about to build "+Md+" infrastructure "+pwhere+
			"\nThe global cost will be "+with_precision(pw.costs()/1000000,2)+"M€ over "
			+with_precision(pw.duration()/#year,2)+" year(s)",[ 
				choose("accept?",bool,true,[true,false])
			]);	
		
		ask pw {if bool(result["accept?"]) {do register();} else {do die;}}
	} 
	
	// CARPARKS
	parameter "Target carpark management" var:CPT among:_districts init:_districts[0] category:"Carparks";
	parameter "Amount of carparks" var:nbcarparks min:-200 max:500 category:"Carparks";
	user_command "Launch carpark public work" category:"Carparks" {
		
		district distarget <- district[_districts index_of CPT];
		publicwork pw <- thecity.mayor.manage_carpark(distarget, nbcarparks);
		
		map  result <- user_input_dialog(
			"You are about to "+(nbcarparks<0?"remove ":"build ")
			+abs(nbcarparks)+" carpark "+(nbcarparks<0?"from ":"in ")+CPT+" (actual is "
			+district[_districts index_of CPT].parcapacity+")"+
			"\nThe global cost will be "+int(pw.costs()/1000)+"k€ over "
			+with_precision(pw.duration()/#year,2)+" year(s)",[ 
				choose("accept?",bool,true,[true,false])
			]);	
			
		ask pw {if bool(result["accept?"]) {do register();} else {do die;}}
		
	}
	
	// ====================
	// COGNITIVE BIAS & PSY
	
	parameter "Halo bias" var:HL category:"Cognitive bias";
	parameter "Strength of habits" var:HBT category:"Cognitive bias" min:1 max:5;
	parameter "Strength of norm" var:SN category:"Cognitive bias" min:1 max:5;
	parameter "Aggregation style" var:COG_EVAL_AGGREGATION category:"Cognitive bias";
	
	// ============================================== //
	// ============================================== //
	// ============================================== //
	
	output {
		monitor "Citizen political support" value:CPS_POS color:blend(#grey,#green,CPS_POS);
		monitor "Citizen political reject" value:CPS_NEG color:blend(#grey,#red,CPS_NEG);
		monitor "Citizen satisfaction" value:SAT_POP color:blend(#red,#green,SAT_POP);
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
			chart "household mode choice determinants" type: radar x_serie_labels: ["Habits","Norm","Potential"]+CRITERIAS 
			series_label_position: xaxis position: {0,0} size: {0.5,0.5} {
				data "Car" value:[
					mean(household collect (each.__habits[CAR]/each.__mode_scores_incr)),
					mean(household collect (each.__norms[CAR]/each.__mode_scores_incr)),
					mean(household collect (each.__potential[CAR]/each.__mode_scores_incr))] + 
					CRITERIAS collect (max(0,spider_criteria[each][CAR.name]))
					color:modcolor[CAR];
				data "Active mode" value:[
					mean(household collect (each.__habits[BIKE]/each.__mode_scores_incr)),
					mean(household collect (each.__norms[BIKE]/each.__mode_scores_incr)),
					mean(household collect (each.__potential[BIKE]/each.__mode_scores_incr))] + 
					CRITERIAS collect (max(0,spider_criteria[each][BIKE.name]))
					color:modcolor[BIKE];
				data "Public transport" value:[
					mean(household collect (each.__habits[PUBLICTRANSPORT]/each.__mode_scores_incr)),
					mean(household collect (each.__norms[PUBLICTRANSPORT]/each.__mode_scores_incr)),
					mean(household collect (each.__potential[PUBLICTRANSPORT]/each.__mode_scores_incr))] +
					CRITERIAS collect (max(0,spider_criteria[each][PUBLICTRANSPORT.name])) 
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
			chart "budget" type:series {data "budget" value:thecity.mayor.budget;}
		}
	}
	
}