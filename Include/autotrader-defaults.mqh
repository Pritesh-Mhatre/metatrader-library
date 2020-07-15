/************************************************
* Contains default value functions.
*
* Author: Pritesh Mhatre
************************************************/


/*********************** CONSTANTS - START ***********************/

static string AT_COMMA = ",";
static string AT_BLANK = "";
static string AT_NA = "NA";

static string AT_PLACE_ORDER_CMD = "PLACE_ORDER";
static string AT_CANCEL_ORDER_CMD = "CANCEL_ORDER";
static string AT_MODIFY_ORDER_CMD = "MODIFY_ORDER";

static string AT_MARGIN_EQUITY = "EQUITY";
static string AT_MARGIN_COMMODITY = "COMMODITY";
static string AT_MARGIN_ALL = "ALL";

enum Exchange {
   NSE = 0, 		// NSE
   BSE = 1, 		// BSE
   MCX = 2 		// MCX
};

enum ProductType {
   INTRADAY = 0, 		// INTRADAY
   DELIVERY = 1, 		// DELIVERY
   NORMAL = 2 			// NORMAL
};

enum OrderType {
   MARKET = 0, 			// MARKET
   LIMIT = 1, 				// LIMIT
   STOP_LOSS = 2, 	// STOP_LOSS
   SL_MARKET = 3 		// SL_MARKET
};

enum TradeType {
   BUY = 0, 				// BUY
   SELL = 1, 				// SELL
   SHORT = 2, 			// SHORT
   COVER = 3 			// COVER
};

enum Variety {
   REGULAR = 0,   			// Regular Order
   BO = 1,  					// Bracket Order
   CO = 2	  					// Cover Order
};

enum Validity {
   DAY = 0,   			// Day
   IOC = 1				// Immediate or cancel
};

/*********************** CONSTANTS - END ***********************/

ProductType defaultProductType() {
	return INTRADAY;
}

bool defaultAmo() {
	return false;
}

Validity defaultValidity() {
	return DAY;
}

int defaultDisclosedQuantity() {
	return 0;
}

float defaultTriggerPrice() {
	return 0;
}

float defaultTarget() {
	return 0;
}

float defaultStoploss() {
	return 0;
}

float defaultTrailingStoploss() {
	return 0;
}

int defaultStrategyId() {
	return -1;
}

string defaultComments() {
	return AT_BLANK;
}

Variety defaultVariety() {
	return REGULAR;
}
