/**
* Name: Parameters
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Parameters

import "Constants.gaml"
import "Model/Modes.gaml"

global {
	
	// **************************** //
	//								//
	//			  CITY				//
	//								//
	// **************************** //
	
	int nb_center_buisness_district <- 1;
	map<string,float> CBDA <- [WORK::10,LEISURE::4,RESIDENTIAL::2];
	float CBD_WIDTH <- 5.0;
	
	int nb_mixed_district <- 2;
	map<string,float> MDA <- [WORK::5,LEISURE::3,RESIDENTIAL::5];
	float MD_WIDTH <- 10.0;
	
	int nb_residential_district <- 3;
	map<string,float> RDA <- [WORK::2,LEISURE::4,RESIDENTIAL::7];
	float RD_WIDTH <- 15.0;
	
	// Public work 
	float PUBLICWORK_LAST_5KM_TRANSPORT <- 6#month;
	
	// **************************** //
	//								//
	//			HOUSEHOLD			//
	//								//
	// **************************** //
		
	int popsize <- 60000;
	
	// demo-couple-menage-struct-prop
	map<string,float> insee_menage <- [SINGLE::36.9,SINGLE+CHILD::9.3,
			COUPLE::25.4,COUPLE+CHILD::24.5,OTHER::3.9]; 			
	// T20F034
	map<int,float> insee_enfants <- [1::44.8,2::38.7,3::12.7,4::3.8];
	
	// RPM2021-F3
	map<string,float> insee_revenu <- [LOW_INCOMES::60,MEDIAN_INCOMES::30,HIGH_INCOMES::10];
	// donners_insee_analyses_n86_CARBURANT
	map<string,int> insee_budget <- [LOW_INCOMES::1510,MEDIAN_INCOMES::2209,HIGH_INCOMES::3324];
	
	// https://www.statistiques.developpement-durable.gouv.fr/edition-numerique/chiffres-cles-du-logement-2022/7-proprietaires-occupants#:~:text=Début%202021%2C%2017%2C6%20millions,(%2B%205%2C7%20points).
	float RATIO_OWNERS <- 0.577;
	
	// PSY PARAMS : actually more rates than probabilities
	float RATE_EVO_HABITS <- 0.05; // TODO : find a place to add habits drop off
	float PROBA_CHANGE_BEHAVIOR <- 0.01;
	
	// Probability modes ownership considering income
	map<string, float> LOW_INCOME_MODES <- [
		CARMODE::0.8,
		BIKEMODE::0.1,
		PUBLICTRANSPORTMODE::0.4
	]; 
	
	map<string,float> MIDDLE_INCOME_MODES <- [
		CARMODE::0.9,
		BIKEMODE::0.25,
		PUBLICTRANSPORTMODE::0.3
	];
	
	map<string,float> HIGH_INCOME_MODES <- [
		CARMODE::0.9,
		BIKEMODE::0.2,
		PUBLICTRANSPORTMODE::0.1
	];
	
	// Probability modes ownership considering household structure
	// TODO : add to init
	map<string,map<string,float>> MENAGE_MODES <- [
		SINGLE::[
			CARMODE::0.7,
			BIKEMODE::0.2,
			PUBLICTRANSPORTMODE::0.3
		],
		SINGLE+CHILD::[
			CARMODE::0.8,
			BIKEMODE::0.6,
			PUBLICTRANSPORTMODE::0.4
		],
		COUPLE::[
			CARMODE::0.9,
			BIKEMODE::0.1,
			PUBLICTRANSPORTMODE::0.2
		],
		COUPLE+CHILD::[
			CARMODE::0.9,
			BIKEMODE::0.6,
			PUBLICTRANSPORTMODE::0.1
		],
		OTHER::[
			CARMODE::0.8,
			BIKEMODE::0.1,
			PUBLICTRANSPORTMODE::0.4
		]];
	
	// Mobility profile
	// https://www.researchgate.net/publication/369524582_Modeling_sustainable_mobility_Impact_assessment_of_policy_measures
	list<int> RISKAVERS_ECOLO <- [6,5,8,3,8,8];
	list<int> INDIFFERENT <- [7,7,7,6,6,6];
	list<int> PRAGMATIC <- [9,7,4,5,5,9];
	list<int> CONFORT_ORIENTED <- [9,3,4,8,8,8];
	list<int> POOR_ECOLO <- [8,8,9,2,3,9];
	list<list<int>> MOBPROFILES <- [RISKAVERS_ECOLO,INDIFFERENT,PRAGMATIC,CONFORT_ORIENTED,POOR_ECOLO];
	
	// Population profiles
	// HOUSEHOLD PROFILE
	map<list<int>,int> LOW_INCOME_POP_PROFILE <- [
		RISKAVERS_ECOLO::2,
		INDIFFERENT::5,
		PRAGMATIC::6,
		CONFORT_ORIENTED::1,
		POOR_ECOLO::10
	];
	map<list<int>,int> HIGH_INCOME_POP_PROFILE <- [
		RISKAVERS_ECOLO::6,
		INDIFFERENT::2,
		PRAGMATIC::4,
		CONFORT_ORIENTED::10,
		POOR_ECOLO::2
	];
	map<list<int>,int> MIDDLE_INCOME_POP_PROFILE <- [
		RISKAVERS_ECOLO::1,
		INDIFFERENT::1,
		PRAGMATIC::1,
		CONFORT_ORIENTED::1,
		POOR_ECOLO::1
	];
	
	int CRITERIA_MINEVAL <- 1;
	int CRITERIA_MAXEVAL <- 10;
	
	// INCOME AGENDA PREFERENCES
	float HIGH_INCOME_PLayer <- 0.1; // how much high income are repelled by the suberb
	float MID_INCOME_PDistance <- 0.5; // how much middle income wants to live in their neighborhood (like a bobo) or like rich people
	float LOW_INCOME_PDistance <- 1.0; // how much low income dislike moving far (TODO : should be counter balanced by economic choice - they don't have)
	
	// **************************** //
	//								//
	//			   MODES			//
	//								//
	// **************************** //
	
	// Trafic index from TomTom
	// https://www.tomtom.com/traffic-index/france-country-traffic/
	// Worst and best small to large cities in france (Paris vs Reims)
	point car_congestion <- {26.0/103,109.0/246};
	// Arbitrary
	point bike_access <- {0.2,0.5};
	point bus_access <- {0.3,0.5};
	
	// Overall mode ratio
	// https://www.statistiques.developpement-durable.gouv.fr/edition-numerique/chiffres-cles-transports-2022/12-transport-interieur-de-voyageurs
	// https://www.statistiques.developpement-durable.gouv.fr/la-mobilite-locale-et-longue-distance-des-francais-enquete-nationale-sur-la-mobilite-des-0#:~:text=—%20La%20mobilité%20locale%20des%20Français,de%20plus%20qu%27en%202008.
	
	map<string,float> MODE_EXPECTED_RATIO <- [
		CARMODE::CARMOBEXP, BIKEMODE::BIKMOBEXP, PUBLICTRANSPORTMODE::PUBMOBEXP
	];
	
	float CARMOBEXP <- 0.628;
	float PUBMOBEXP <- 0.091;
	float BIKMOBEXP <- 0.027;
	float WALMOBEXP <- 0.237; // TODO add walk
	
	// MODE X DISTANCE
	//
	// Déplacement domicile-travail : https://www.insee.fr/fr/statistiques/5013868
	//
	// TODO : https://www.cerema.fr/fr/centre-ressources/boutique/donnees-mobilite-modelisation-deplacements
	map<string,map<float,float>> DISTPREF <- [
		CARMODE::[ // Combination of car and motorbike
			5#km::0.63,10#km::0.75,20#km::0.83,35#km::0.84,50#km::0.81
		],
		PUBLICTRANSPORTMODE::[
			5#km::0.16,10#km::0.18,20#km::0.14,35#km::0.13,50#km::0.16
		],
		BIKEMODE::[
			5#km::0.05,10#km::0.02,20#km::0.005,35#km::0.002,50#km::0.001
		]
	];
	
	
	// administration id adapting to mode ratio evolution
	float infrastructure_degradation <- 0.01;
	
	// Modes criterias
	// Try to have the same quantity summing the 6 dimensions for the 3 modes (30)
	map<string,int> BIKE_CRITS <- [
		ECOLO::10,
		PRICE::8,
		CONFORT::4,
		SAFE::2,
		EASY::4,
		TIME::2
	];
	map<string,int> CAR_CRITS <- [
		ECOLO::1,
		PRICE::1,
		CONFORT::9,
		SAFE::5,
		EASY::5,
		TIME::9
	];
	map<string,int> BUS_CRITS <- [
		ECOLO::7,
		PRICE::6,
		CONFORT::4,
		SAFE::4,
		EASY::5,
		TIME::4
	];
	
	// **************************** //
	//								//
	//			  BUDGET			//
	//								//
	// **************************** //
	
	int STARTING_BUDGET <- 100;
	
	// ##############################################################################
	// https://www.economie.gouv.fr/cedef/chiffres-cles-budgets-collectivites-locales
	// https://www.ecologie.gouv.fr/sites/default/files/bis_141_budget_du_maire.pdf
	// https://www.collectivites-locales.gouv.fr/collectivites-locales-chiffres-2023
	// ##############################################################################
	
	float INVEST_BUDGET_PER_INHABITANT <- 331; 
	
	// Part des dépenses d'investissement dans les équipement de transport 
	
	// Métropole de montpellier : investissement équipement transport / budget d'investissement
	// 1er budget d'investissement, 6* suppérieur au 2nd !!!!
	// Rapport : https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&ved=2ahUKEwj1m-zqmYOFAxUJRaQEHZXYDRQQFnoECBkQAQ&url=https%3A%2F%2Fwww.montpellier.fr%2Finclude%2FviewFile.php%3Fidtf%3D41603%26path%3D39%252F41603_694_Rapport-BP-2022-Ville-VF.pdf&usg=AOvVaw02g20wR3krcQR3i-H_0zop&opi=89978449
	float BUDGET_RATIO_EQUIPEMENT_TRANSPORT <- 146.4/640.0;
	
	/*
	 * Donne le montant des investissements annuels dans les équipements de transports
	 */
	int __actual_base_annual_budget(city c) { 
		return INVEST_BUDGET_PER_INHABITANT*c.total_population();
	}
	
	// !!!!!!!!!!!!!!!!!!!!!!!
	// !!!!!!!!!!!!!!!!!!!!!!!
	// L’Île-de-France concentre 75 % de la demande de transport collectif urbain de France métropolitaine
	// https://www.statistiques.developpement-durable.gouv.fr/sites/default/files/2018-11/datalab-essentiel-150-transport-collectif-urbain-septembre2018.pdf
	
	// bis_141_budget_du_maire.pdf
	float BUDGET_BALANCE_FUNCTIONING <- (37.6+16.7+8.6+4.6) / (52.3+14.1+13.4);
	float LOCAL_TAXE_RATIO_BALANCE <- 52.3 / (52.3+14.1+13.4);
	
	// Ratio of TICPE over budget input
	float FUEL_TAXE_RATIO_BALANCE <- 0.07; // ratio of TICPE input in budget balance see Chapitre 1 - Les chiffres clés des collectivités 2023
	
	// Ratio of "Versement mobilité" over budget input
	float PT_TAXE_RATIO_BALANCE <- 0.03;
	// Ratio of public transport cost payed with tickets
	// https://www.statistiques.developpement-durable.gouv.fr/sites/default/files/2018-11/datalab-essentiel-150-transport-collectif-urbain-septembre2018.pdf
	float PT_PAYMENT_RATIO <- 0.18;  
	
	// The ratio of car over bikes for households budget balance
	float __car_bike_ratio <- 0.95;
	
	// IP1855-donnees
	map<string,int> m_cost <- [
		PURCHASE::1428,
		MAINTENANCE::599,
		INSURANCE::671,
		FUEL::1064,
		COLLECTRANSPORT::352/2.0 // Part des transport en commun locaux
		// IMPONDERABLE::344
	];
	
	// TODO : les postes de dépenses (% par mode) sont quasiment les même pour chaque tranches de revenu
	//
	// ===> 3/4 = achat, maintenance, assurance et essence (les 2 premiers inclus le vélo - arbitrairement fixé à 5% des couts) 
	// ===> 1/4 = transport collectif (inclus train et avion), soit 1/8 pour les transports locaux
	//
	// Seul grande inégalité, les 1 et 10 décile sont à 21.3% et 11.5% de dépense transport dans leur budget 
	
	map<string,float> insee_mobility_budget_ratio <- [
		LOW_INCOMES::mean(21.3,14.9,13.7)/100,
		MEDIAN_INCOMES::mean(14.7,14.2,14.6,14.4)/100,
		HIGH_INCOMES::mean(13.5,12.5,11.5)/100
	]; 
	
	// References is french city of 200k to 700k inhabitants
	map<string,float> insee_mode_budget_ratio <- [
		CARMODE::(
				m_cost[PURCHASE] * __car_bike_ratio + 
				m_cost[MAINTENANCE] * __car_bike_ratio + 
				m_cost[INSURANCE] * __car_bike_ratio+
				m_cost[FUEL]
			) / sum(m_cost.values),
		BIKEMODE::(
			m_cost[PURCHASE] * (1 - __car_bike_ratio) + 
				m_cost[MAINTENANCE] * (1 - __car_bike_ratio) + 
				m_cost[INSURANCE] * (1 - __car_bike_ratio)
			) / sum(m_cost.values),
		PUBLICTRANSPORTMODE::m_cost[COLLECTRANSPORT]/sum(m_cost.values)
	];
	
	// https://www.impots.gouv.fr/sites/default/files/media/9_statistiques/0_etudes_et_stats/0_publications/dgfip_statistiques/2023/num16_05/dgfip_stat_16_2023.pdf
	int LOCAL_TAXE_HAB <- 95;
	int LOCAL_TAXE_FON <- 889;
	
	// **************************** //
	//								//
	//	   VARIABLES DE FORCAGE		//
	//								//
	// **************************** //
	
	float PWDISTURBANCE <- 0.05;
	
	pair WEATHER_RANGE <- 1.0::1.0;
	
	// How much good weither prevents to use car
	float MAX_GOOD_WEITHER_CAR_DIVIDER <- 0.9;
	// How much good weither drives toward using bike
	float MAX_GOOD_WEITHER_BIKE_MULTIPLIER <- 1.2;
	// How much weither impact public transport
	float MAX_PUBLIC_TRANSPORT_WEITHER_RANGE <- 0.1; 
	
	
}

