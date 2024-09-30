/**
* Name: Modes
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Modes

import "../Constants.gaml"
import "../Parameters.gaml"
import "City.gaml"

global {
	
	mode BIKE;
	mode PUBLICTRANSPORT;
	mode CAR;
	
	map<mode,rgb> modcolor;
	
	// INCOMES X MODES = cost
	matrix<float> MOBCOST; 
}

species mode { 
	map<string,float> criterias;
}

