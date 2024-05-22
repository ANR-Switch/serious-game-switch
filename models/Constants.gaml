/**
* Name: Constants
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Constants

global {
	
	// CITY DISTRICT
	string CBD <- "city business district";
	string MD <- "mixed district";
	string RD <- "residential district";
	
	// MODES
	string BIKEMODE <- "BIKE";
	string CARMODE <- "CAR";
	string PUBLICTRANSPORTMODE <- "PUBLIC TRANSPORT";
	
	// HOUSEHOLDER TYPES
	string SINGLE <- "single";
	string COUPLE <- "couple";
	string CHILD <- "child";
	string OTHER <- "other";
	
	// HOUSEHOLD INCOMES
	string LOW_INCOMES <- "low incomes";
	string MEDIAN_INCOMES <- "median incomes";
	string HIGH_INCOMES <- "high incomes";
	list<string> INCOME_LEVEL <- [LOW_INCOMES,MEDIAN_INCOMES,HIGH_INCOMES];
	
	// Household satisfaction starting distribution
	// https://ourworldindata.org/happiness-and-life-satisfaction
	list<int> HAPPYDIST <- [1,1,2,4,5,10,6,5,5,1];
	list<int> HAPPYEST <- [1,1,1,2,3,6,10,10,5,2];
	list<int> HAPPYLESS <- [2,2,4,6,6,7,4,2,1,1];
	
	string WORK <- "WORK";
	string LEISURE <- "LEISURE";
	string RESIDENTIAL <- "HOUSING";
	list<string> AMENITIES <- [WORK,LEISURE,RESIDENTIAL];
	
	// Trip criterias
	string DISTANCE <- "DISTANCE";
	string WEITHER <- "WEITHER";
	string CYCLING_ROADS <- "CYCLING";
	string PUBLIC_TRANSPORT_OFFER <- "PT QUALITY";
	string TRAFIC_JAM <- "JAM";
	list<string> TRIPATTRIBUTES <- [DISTANCE,WEITHER,CYCLING_ROADS,PUBLIC_TRANSPORT_OFFER,TRAFIC_JAM];
	
	// MODE CHOICE CRITERIAS
	string ECOLO <- "ECOLOGIQUE";
	string PRICE <- "ECONOMIQUE";
	string CONFORT <- "CONFORTABLE";
	string SAFE <- "SECURE"; // Securité ? a quel point c'est dangereux
	string RELIABLE <- "FIABLE"; //TODO : mettre en ligne
	string EASY <- "FACILE";
	string TIME <- "RAPIDE";
	list<string> CRITERIAS <- [TIME, PRICE, ECOLO, CONFORT, SAFE, EASY];
	
	// EVALUATION AGGREGATION CRITERIAS
	string SUM <- "SUM";
	string MEAN <- "MEAN";
	string MEDIAN <- "MEDIAN";
	
	// MOBILITY COSTS
	string PURCHASE <- "vehicle purchase";
	string MAINTENANCE <- "maintenance";
	string INSURANCE <- "insurance";
	string FUEL <- "fuel";
	string COLLECTRANSPORT <- "collective mobility"; // public transport in general
	
	// PUBLIC WORK
	point PUBLICWORK_NOTARGET <- {-1,-1};
	
	// #####
	// UTILS
	
	// Materiel design palette
	rgb bacolor <- blend(#white,rgb(236, 253, 245),0.6);
	list<rgb> main <- [rgb(22, 163, 74),rgb(20, 83, 45),rgb(134, 239, 172)];
	list<rgb> hot <- [rgb(234, 88, 12),rgb(124, 45, 18),rgb(253, 186, 116)];
	list<rgb> contemplative <- [rgb(2, 132, 199),rgb(12, 74, 110),rgb(125, 211, 252)];
	list<rgb> happypalette <- reverse(brewer_colors("RdYlGn",10));
	list<rgb> amenitypalette <- brewer_colors("Paired",3);
	list<rgb> actionpalette <- brewer_colors("Dark2",8);
	//++++
	map<string,rgb> incolor <- [LOW_INCOMES::contemplative[0],MEDIAN_INCOMES::contemplative[1],HIGH_INCOMES::contemplative[2]];
	
	// UI Materials
	string NOBE;
	string SLIDER;
	string MULTI;
	list<string> mcontrols <- [SLIDER,"","",""];
	
}