/******************************************************************************
*
* AutoTrader automated trading API functions.
* DO NOT MODIFY THIS FILE
* Version: 1.0
*
******************************************************************************/

/* Import public metatrader libraries */

#include <file-util.mqh>
#include <conversion-util.mqh>

/* Import AutoTrader specific metatrader libraries */

#include <autotrader-ipc.mqh>
#include <autotrader-defaults.mqh>

/***************************** CONSTANTS - START *****************************/

static string AT_LAST_ORDER_TIME_KEY = "AT_LAST_ORDER_TIME";
static string AT_LAST_ORDER_TRADE_TYPE_KEY = "AT_LAST_ORDER_TRADE_TYPE";

/****************************** CONSTANTS - END ******************************/


/***************************** PARAMETERS - START ****************************/

input string AT_ACCOUNT = "Pseudo Account";	// Pseudo account

input Exchange AT_EXCHANGE = NSE;	// Exchange

input string AT_SYMBOL = "SYMBOL"; 	// Order symbol

input int AT_QUANTITY = 1; 					// Order quantity

input ProductType AT_PRODUCT_TYPE = INTRADAY;	// Product type

input bool AT_DEBUG = false; 				// Print Additional Logs

input int AT_PRICE_PRECISION = 4; 		// Price precision, used for rounding price

/*
* Used for avoiding repeat orders. Repeat orders are back to back buy or 
* sell orders. The system will not accept an order in this many seconds, 
* if an order for same stock, tradeType was sent earlier from the same chart.
* If you want to execute back to back order then you can set this 
* parameter to 0.
* If you want to avoid repeat orders generated due to duplicate signals 
* then set this parameter to a value higher than your candle interval.
* 
* Example: 
* 1. Assume AT_AVOID_REPEAT_ORDER_DELAY value is set for 120 seconds & 
* 		your chart uses 1-minute (60 seconds) candle.
* 2. System receives a BUY order for SBIN at time 10:15:15.
* 3. System will place it.
* 4. After 15 seconds, system receives another BUY order for SBIN 
* 		at time 10:15:30.
* 5. The system will NOT place this order, as the symbol & tradeType 
* 		are same and the order came with 120 seconds of previous order.
*/
input int AT_AVOID_REPEAT_ORDER_DELAY = 26000; 	// Avoid repeat orders (in seconds)

/***************************** PARAMETERS - END *****************************/

static datetime AT_LAST_ORDER_TIME;

static TradeType AT_LAST_ORDER_TRADE_TYPE;

static string AT_LAST_ORDER_SYMBOL = "";


/*
* Order number for id.
*/
string generateUniqueOrderId() {
	string random = IntegerToString(MathRand());
	string time = IntegerToString(TimeLocal());

	return time + "-" + random;
}

/*
* Saves last order time, in a static variable.
*/
void saveLastOrderTradeType(TradeType tradeType) {
   AT_LAST_ORDER_TRADE_TYPE = tradeType;
}

/*
* Fetches the last order trade type (if available).
*/
TradeType readLastOrderTradeType() {
	return AT_LAST_ORDER_TRADE_TYPE;
}

/*
* Saves last order trade type, in a static variable.
*/
void saveLastOrderTime(datetime time) {
   AT_LAST_ORDER_TIME = time;
}

/*
* Fetches the last order time (if available).
*/
datetime readLastOrderTime() {
	return AT_LAST_ORDER_TIME;	
}

/*
* Converts order to easy to read text format.
*/
string orderString(Variety variety, string symbol, TradeType tradeType, 
	OrderType orderType, int quantity, double price, double triggerPrice=0, 
	double target=0, double stoploss=0, double trailingStoploss=0) {
	string qty = IntegerToString(quantity);
	string prc = DoubleToString(price, 2);
	string trigPrc = DoubleToString(triggerPrice, 2);
	string t = DoubleToString(target, 2);
	string sl = DoubleToString(stoploss, 2);
	string tsl = DoubleToString(trailingStoploss, 2);
	string tradeTypeStr = EnumToString(tradeType);
	string orderTypeStr = EnumToString(orderType);
	string separator = "|";

	string conciseForm = symbol + "|" + tradeTypeStr + "|" + orderTypeStr + "|" + 
		qty + "@" + prc;

	string result;

	if(variety == BO) {
		result = "Bracket Order [" + conciseForm + "|" + 
			"t=" + t + "|" + "sl=" + sl + "|" + 
			"tr. sl=" + tsl + "]";
	} else if (variety == CO) {
		result = "Cover Order [" + conciseForm + "|" + "trigger=" + 
			trigPrc +  "]";
	} else {
		result = "Regular Order [" + conciseForm + "]";
	}
	
	return result;
}

/*
* Checks whether we have a duplicate signal. This is done to overcome a limitation 
* in AmiBroker, which keeps on giving same signal for every tick 
* until the candle is complete.
*/
bool isDuplicateSignal(TradeType tradeType) {
	bool duplicate = false;
	
	datetime time = readLastOrderTime();
	TradeType lastTradeType = readLastOrderTradeType();
	
	if(time != NULL) {
		long difference = TimeLocal() - time;
		
		if(difference < AT_AVOID_REPEAT_ORDER_DELAY && 
			lastTradeType == tradeType) {
			   
			Print("ERROR: Duplicate signal. Previous order = ",
				EnumToString(lastTradeType) , ", Current order = " , 
				EnumToString(tradeType));
			
			if(AT_DEBUG) {
				Print("Last order time is = ", TimeToString(time, TIME_SECONDS));
				Print("Difference of [", difference,
					"] seconds is less than avoid duplicate order duration of [",
					IntegerToString(AT_AVOID_REPEAT_ORDER_DELAY) + "] seconds.");
			}
			
			duplicate = true;
		}
	}
	
	return duplicate;
}

/*****************************************************************************/
/*********************** PLACE ORDER FUNCTIONS - START ***********************/
/*****************************************************************************/

/*
* An advanced function to place orders.
* Returns order id in case of success, else blank.
*/
string placeOrderAdvanced(Variety variety, string account, 
	Exchange exchange, string symbol, 
	TradeType tradeType, OrderType orderType, 
	ProductType productType, int quantity, 
	double price, double triggerPrice, double target, 
	double stoploss, double trailingStoploss,
	int disclosedQuantity, Validity validity, bool amo,
	int strategyId, string comments, bool validate) {

	// Initially order id is blank
	string orderId = "";
	
	string orderStr = orderString(variety, symbol, tradeType, orderType, quantity, 
		price, triggerPrice, target, stoploss, trailingStoploss);
		
	if(AT_DEBUG) {
		Print("Placing order: ", orderStr);
	}	

	bool proceed = true;
	if(validate) {
		// Perform validation
		
		// Perform duplicate signal check
		if(isDuplicateSignal(tradeType)) {
			Print("Order failed validation: ", orderStr);
			proceed = false;
		}
	}

	if(proceed) {
	
		// Generate unique order id
		orderId = generateUniqueOrderId();
		
		// Save order generation time
		string publishTime = IntegerToString(
			convertDateTimeToMillisSinceEpoch(TimeLocal()));
		
		// Convert data into text in order to write it to a CSV file		
		string priceStr = DoubleToString(price, AT_PRICE_PRECISION);
		string triggerPriceStr = DoubleToString(triggerPrice, AT_PRICE_PRECISION);
		string targetStr = DoubleToString(target, AT_PRICE_PRECISION);
		string stoplossStr = DoubleToString(stoploss, AT_PRICE_PRECISION);
		string trailingStoplossStr = DoubleToString(trailingStoploss, AT_PRICE_PRECISION);
		
		// Handling for a comma in comments
		StringReplace(comments, AT_COMMA, ";" );
	
		string amoStr = amo ? "true" : "false";

		string csv = 
			AT_PLACE_ORDER_CMD 		+ AT_COMMA +
			account 								+ AT_COMMA +
			orderId 									+ AT_COMMA +
			EnumToString(variety)			+ AT_COMMA +
			EnumToString(exchange)		+ AT_COMMA +
			symbol 									+ AT_COMMA +
			EnumToString(tradeType)		+ AT_COMMA +
			EnumToString(orderType) 		+ AT_COMMA +
			EnumToString(productType)	+ AT_COMMA +
			IntegerToString(quantity)		+ AT_COMMA +
			priceStr 								+ AT_COMMA +
			triggerPriceStr 						+ AT_COMMA +
			targetStr 								+ AT_COMMA +
			stoplossStr 							+ AT_COMMA +
			trailingStoplossStr 				+ AT_COMMA +
			IntegerToString(disclosedQuantity)		+ AT_COMMA +
			EnumToString(validity) 			+ AT_COMMA +
			amoStr									+ AT_COMMA +
			publishTime							+ AT_COMMA +
			IntegerToString(strategyId)	+ AT_COMMA +
			comments;

		if(AT_DEBUG) {
			Print("Order csv data: ", csv);
		}	
		
		bool written = fileWriteLine(COMMANDS_FILE, csv);
		
		if(written) {
			saveLastOrderTradeType(tradeType);
			saveLastOrderTime(TimeLocal());
			Print("Order placed: [", orderStr, "], order id: ", orderId);
		} else {
			Print("ERROR: Order placement failed: [", orderStr, "]");
			orderId = "";
		}
	}
	
	return orderId;
}

/*
* A function to place regular orders. Returns order id on successful 
* order placement; otherwise returns blank.
*/
string placeOrder(string account, Exchange exchange, string symbol, 
	TradeType tradeType, OrderType orderType, ProductType productType, 
	int quantity, double price, double triggerPrice, bool validate) {

	return placeOrderAdvanced(defaultVariety(), account, exchange, symbol, 
		tradeType, orderType, productType, 
		quantity, price, triggerPrice,
		defaultTarget(), defaultStoploss(), defaultTrailingStoploss(),
		defaultDisclosedQuantity(), defaultValidity(), defaultAmo(),
		defaultStrategyId(), defaultComments(), validate);

}

/*
* A function to place bracket orders. Returns order id on successful 
* order placement; otherwise returns blank.
* 
* If a parameter is not applicable, then either pass blank (for text parameter) 
* or zero (for numeric parameter).
*/
string placeBracketOrder(string account, Exchange exchange, string symbol, 
	TradeType tradeType, OrderType orderType, int quantity, 
	double price, double triggerPrice, double target, double stoploss, 
	double trailingStoploss, bool validate) {

	return placeOrderAdvanced(BO, account, exchange, symbol, 
		tradeType, orderType, INTRADAY, 
		quantity, price, triggerPrice,
		target, stoploss, trailingStoploss,
		defaultDisclosedQuantity(), defaultValidity(), defaultAmo(),
		defaultStrategyId(), defaultComments(), validate);

}

/*
* A function to place cover orders. Returns order id on successful 
* order placement; otherwise returns blank.
*/
string placeCoverOrder(string account, Exchange exchange, string symbol, 
	TradeType tradeType, OrderType orderType, int quantity, 
	double price, double triggerPrice, bool validate) {

	return placeOrderAdvanced(CO, account, exchange, symbol, 
		tradeType, orderType, INTRADAY, 
		quantity, price, triggerPrice,
		defaultTarget(), defaultStoploss(), defaultTrailingStoploss(),
		defaultDisclosedQuantity(), defaultValidity(), defaultAmo(),
		defaultStrategyId(), defaultComments(), validate);

}

/*****************************************************************************/
/************************ PLACE ORDER FUNCTIONS - END ************************/
/*****************************************************************************/


/*****************************************************************************/
/*********************** MODIFY ORDER FUNCTIONS - START **********************/
/*****************************************************************************/

void printOrderModification(string account, string orderId, OrderType orderType, 
	int quantity, double price, double triggerPrice) {
	
	string message = "Modification: ";
	message = message + "[Account = " + account + "]";
	message = message + "[Order Id = " + orderId + "]";
	
	if(orderType != NULL) {
		message = message + "[OrderType = " + EnumToString(orderType) + "]";
	}
	
	if(quantity > 0) {
		message = message + "[Quantity = " + IntegerToString(quantity) + "]";
	}
	
	if(price > 0) {
		message = message + "[Price = " + DoubleToString(price) + "]";
	}
	
	if(triggerPrice > 0) {
		message = message + "[Trigger Price = " + DoubleToString(triggerPrice) + "]";
	}
	
	Print(message);	
}

/**
* Modifies the order. Returns true on successful modification request;
* otherwise returns false.
* 
* If a parameter is not applicable, then either pass NULL or zero (for numeric parameter).
*/
bool modifyOrder(string account, string orderId, OrderType orderType, 
	int quantity, double price, double triggerPrice) {
	
	string priceStr = DoubleToString(price, AT_PRICE_PRECISION);
	string triggerPriceStr = DoubleToString(triggerPrice, AT_PRICE_PRECISION);
	string orderTypeStr = (orderType == NULL) ? "" : EnumToString(orderType);
	
	string csv = 
		AT_MODIFY_ORDER_CMD			+ AT_COMMA +
		account 									+ AT_COMMA + 
		orderId 										+ AT_COMMA + 
		orderTypeStr								+ AT_COMMA +  
		IntegerToString(quantity)			+ AT_COMMA +  
		priceStr 									+ AT_COMMA +  
		triggerPriceStr;
	
	if(AT_DEBUG) {
		Print("Sending order modify request: ", csv);
	}
		
	bool written = fileWriteLine(COMMANDS_FILE, csv);
	
	if(written) {
		Print("Order modify request sent.");
	} else {
		Print("Order modify request failed.");
	}
	
	printOrderModification(account, orderId, orderType, quantity, price, 
		triggerPrice);
	
	return written;
}

bool modifyOrderPrice(string account, string orderId, double price) {
	return modifyOrder(account, orderId, NULL, 0, price, 0);
}

bool modifyOrderQuantity(string account, string orderId, int quantity) {
	return modifyOrder(account, orderId, NULL, quantity, 0, 0);
}

/*****************************************************************************/
/************************ MODIFY ORDER FUNCTIONS - END ***********************/
/*****************************************************************************/


/*****************************************************************************/
/*********************** CANCEL/EXIT ORDER FUNCTIONS - START **********************/
/*****************************************************************************/

/*
* Sends cancel order request to AutoTrader. Pass account & order id. Returns true on success.
*/
bool cancelOrder(string account, string id) {
	if(AT_DEBUG) {
		Print("Cancelling order, order id = ", id);
	}

	string csv = 
			AT_CANCEL_ORDER_CMD 		+ AT_COMMA +
			account 								+ AT_COMMA +
			id;
	
	bool written = fileWriteLine(COMMANDS_FILE, csv);
	
	if(written) {
		Print("Order cancel request sent.");
	} else {
		Print("Order cancel request failed.");
	}
	
	return written;
}

/*
* Cancels child orders of a bracket or cover order. 
* This function is useful for exiting from bracket and cover order.
* Pass the account & id you received after placing a bracket or cover order.
* Returns true on success.
*/
bool cancelOrderChildren(string account, string id) {
	if(AT_DEBUG) {
		Print("Cancelling child orders, order id = ", id);
	}

	string csv = 
			AT_CANCEL_CHILD_ORDER_CMD 	+ AT_COMMA +
			account 										+ AT_COMMA +
			id;
	
	bool written = fileWriteLine(COMMANDS_FILE, csv);
	
	if(written) {
		Print("Order cancel children request sent.");
	} else {
		Print("Order cancel children request failed.");
	}
	
	return written;
}

/*
* Cancels or exits from order. This function is useful for exiting from bracket and cover order.
* If the order is OPEN, it will be cancelled. If it is executed, system will cancel it's child orders;
* which will result in exiting the position.
* Pass account & id you received after placing a bracket or cover order.
*/
bool cancelOrExitOrder(string account, string id) {
	if(AT_DEBUG) {
		Print("Inside cancelOrExitOrder, order id = ", id);
	}

	// Cancel the Bracket order if it is open
	bool a = cancelOrder(account, id);

	// Exit from bracket order
	bool b = cancelOrderChildren(account, id);
	
	return (a && b);
}

/*
* Cancels all open orders for the given account. Returns true on success.
*/
bool cancelAllOrders(string account) {
	if(AT_DEBUG) {
		Print("Cancelling all open orders for account: ", account);
	}

	string csv = AT_CANCEL_ALL_ORDERS_CMD + AT_COMMA + account;
	
	bool written = fileWriteLine(COMMANDS_FILE, csv);
	
	if(written) {
		Print("Cancel all open orders request sent, account: ", account);
	} else {
		Print("Cancel all open orders request failed, account: ", account);
	}
	
	return written;
}

/*****************************************************************************/
/************************ CANCEL/EXIT ORDER FUNCTIONS - END ***********************/
/*****************************************************************************/


/*****************************************************************************/
/************************ SQUARE OFF FUNCTIONS - START ***********************/
/*****************************************************************************/

/**
* Submits a square-off request for the given position.
*
* pseudoAccount - account to which the position belongs
* category - position category (DAY, NET). Pass DAY if you are not sure.
* type - position type (MIS, NRML, CNC, BO, CO) 
* exchange - broker independent exchange
* independentSymbol - broker independent symbol
*/
bool squareOffPosition(string pseudoAccount, string category, 
	string type, Exchange exchange, string independentSymbol) {
	
	string positionStr = pseudoAccount 				+ AT_PIPE +
								category							+ AT_PIPE +
								type									+ AT_PIPE +
								EnumToString(exchange)	+ AT_PIPE +
								independentSymbol;
	
	if(AT_DEBUG) {
		Print("Inside squareOffPosition, position: [", positionStr, "]");
	}

	string csv = AT_SQUARE_OFF_POSITION 		+ AT_COMMA +
			pseudoAccount 							+ AT_COMMA +
			category									+ AT_COMMA +
			type											+ AT_COMMA +
			EnumToString(exchange)			+ AT_COMMA +
			independentSymbol;

	bool written = fileWriteLine(COMMANDS_FILE, csv);
	
	if(written) {
		Print("Square-off position request sent. Position: [", positionStr, "]");
	} else {
		Print("Square-off position request failed. Position: [", positionStr, "]");
	}
	
	return written;
}

/**
* Submits a square-off request for the given account.
* Server will square-off all open positions in the given account.
*
* pseudoAccount - account to which the position belongs
* category - position category (DAY, NET). Pass DAY if you are not sure.
*/
bool squareOffPortfolio(string pseudoAccount, string category) {
	
	string portfolioStr = pseudoAccount 	+ AT_PIPE +
						category;
	
	if(AT_DEBUG) {
		Print("Inside squareOffPortfolio, portfolio: [", portfolioStr, "]");
	}

	string csv = AT_SQUARE_OFF_PORTFOLIO 	+ AT_COMMA +
					pseudoAccount 							+ AT_COMMA +
					category;

	bool written = fileWriteLine(COMMANDS_FILE, csv);
	
	if(written) {
		Print("Square-off portfolio request sent. Portfolio: [", portfolioStr, "]");
	} else {
		Print("Square-off portfolio request failed. Portfolio: [", portfolioStr, "]");
	}
	
	return written;
}

/*****************************************************************************/
/************************ SQUARE OFF FUNCTIONS - END ***********************/
/*****************************************************************************/


/*****************************************************************************/
/************************ ORDER DETAIL FUNCTIONS - START ***********************/
/*****************************************************************************/

/*
* Reads orders file and returns a column value for the given order id.
*/
string readOrderColumn(string pseudoAccount, string orderId, int columnIndex) {
	string filePath = getPortfolioOrdersFile(pseudoAccount);
	return fileReadCsvColumnByRowId( filePath, orderId, 3, columnIndex );
}

/*
* Retrieve order's trading account.
*/
string getOrderTradingAccount(string pseudoAccount, string orderId) {
	return readOrderColumn(pseudoAccount, orderId, 2);
}

/*
* Retrieve order's trading platform id.
*/
string getOrderId(string pseudoAccount, string orderId) {
	return readOrderColumn(pseudoAccount, orderId, 4);
}

/*
* Retrieve order's exchange id.
*/
string getOrderExchangeId(string pseudoAccount, string orderId) {
	return readOrderColumn(pseudoAccount, orderId, 5);
}

/*
* Retrieve order's variety (REGULAR, BO, CO).
*/
Variety getOrderVariety(string pseudoAccount, string orderId) {
	Variety v;
	return StringToEnum(readOrderColumn(pseudoAccount, orderId, 6), v);
}

/*
* Retrieve order's (platform independent) exchange.
*/
Exchange getOrderIndependentExchange(string pseudoAccount, string orderId) {
	Exchange e;
	return StringToEnum(readOrderColumn(pseudoAccount, orderId, 7), e);
}

/*
* Retrieve order's (platform independent) symbol.
*/
string getOrderIndependentSymbol(string pseudoAccount, string orderId) {
	return readOrderColumn(pseudoAccount, orderId, 8);
}

/*
* Retrieve order's trade type (BUY, SELL).
*/
TradeType getOrderTradeType(string pseudoAccount, string orderId) {
	TradeType t;
	return StringToEnum(readOrderColumn(pseudoAccount, orderId, 9), t);
}

/*
* Retrieve order's order type (LIMIT, MARKET, STOP_LOSS, SL_MARKET).
*/
OrderType getOrderOrderType(string pseudoAccount, string orderId) {
	OrderType o;
	return StringToEnum(readOrderColumn(pseudoAccount, orderId, 10), o);
}

/*
* Retrieve order's product type (INTRADAY, DELIVERY, NORMAL).
*/
ProductType getOrderProductType(string pseudoAccount, string orderId) {
	ProductType p;
	return StringToEnum(readOrderColumn(pseudoAccount, orderId, 11), p);
}

/*
* Retrieve order's quantity.
*/
long getOrderQuantity(string pseudoAccount, string orderId) {
	return StringToInteger(readOrderColumn(pseudoAccount, orderId, 12));
}

/*
* Retrieve order's price.
*/
double getOrderPrice(string pseudoAccount, string orderId) {
	return StringToDouble(readOrderColumn(pseudoAccount, orderId, 13));
}

/*
* Retrieve order's trigger price.
*/
double getOrderTriggerPrice(string pseudoAccount, string orderId) {
	return StringToDouble(readOrderColumn(pseudoAccount, orderId, 14));
}

/*
* Retrieve order's filled quantity.
*/
long getOrderFilledQuantity(string pseudoAccount, string orderId) {
	return StringToInteger(readOrderColumn(pseudoAccount, orderId, 15));
}

/*
* Retrieve order's pending quantity.
*/
long getOrderPendingQuantity(string pseudoAccount, string orderId) {
	return StringToInteger(readOrderColumn(pseudoAccount, orderId, 16));
}

/*
* Retrieve order's (platform independent) status.
* (OPEN, COMPLETE, CANCELLED, REJECTED, TRIGGER_PENDING, UNKNOWN)
*/
string getOrderStatus(string pseudoAccount, string orderId) {
	return readOrderColumn(pseudoAccount, orderId, 17);
}

/*
* Retrieve order's status message or rejection reason.
*/
string getOrderStatusMessage(string pseudoAccount, string orderId) {
	return readOrderColumn(pseudoAccount, orderId, 18);
}

/*
* Retrieve order's validity (DAY, IOC).
*/
Validity getOrderValidity(string pseudoAccount, string orderId) {
	Validity v;
	return StringToEnum(readOrderColumn(pseudoAccount, orderId, 19), v);
}

/*
* Retrieve order's average price at which it got traded.
*/
double getOrderAveragePrice(string pseudoAccount, string orderId) {
	return StringToDouble(readOrderColumn(pseudoAccount, orderId, 20));
}

/*
* Retrieve order's parent order id. The id of parent bracket or cover order.
*/
string getOrderParentOrderId(string pseudoAccount, string orderId) {
	return readOrderColumn(pseudoAccount, orderId, 21);
}

/*
* Retrieve order's disclosed quantity.
*/
long getOrderDisclosedQuantity(string pseudoAccount, string orderId) {
	return StringToInteger(readOrderColumn(pseudoAccount, orderId, 22));
}

/*
* Retrieve order's exchange time as a string (YYYY-MM-DD HH:MM:SS.MILLIS).
*/
string getOrderExchangeTime(string pseudoAccount, string orderId) {
	return readOrderColumn(pseudoAccount, orderId, 23);
}

/*
* Retrieve order's platform time as a string (YYYY-MM-DD HH:MM:SS.MILLIS).
*/
string getOrderPlatformTime(string pseudoAccount, string orderId) {
	return readOrderColumn(pseudoAccount, orderId, 24);
}

/*
* Retrieve order's AMO (after market order) flag. (true/false)
*/
bool getOrderAmo(string pseudoAccount, string orderId) {
	string flag = readOrderColumn(pseudoAccount, orderId, 25);
	return (flag == "true" || flag == "True" || flag == "TRUE");	
}

/*
* Retrieve order's comments.
*/
string getOrderComments(string pseudoAccount, string orderId) {
	return readOrderColumn(pseudoAccount, orderId, 26);
}

/*
* Retrieve order's raw (platform specific) status.
*/
string getOrderRawStatus(string pseudoAccount, string orderId) {
	return readOrderColumn(pseudoAccount, orderId, 27);
}

/*
* Retrieve order's (platform specific) exchange.
*/
string getOrderExchange(string pseudoAccount, string orderId) {
	return readOrderColumn(pseudoAccount, orderId, 28);
}

/*
* Retrieve order's (platform specific) symbol.
*/
string getOrderSymbol(string pseudoAccount, string orderId) {
	return readOrderColumn(pseudoAccount, orderId, 29);
}

/*
* Retrieve order's date (DD-MM-YYYY).
*/
string getOrderDay(string pseudoAccount, string orderId) {
	return readOrderColumn(pseudoAccount, orderId, 30);
}

/*
* Retrieve order's trading platform.
*/
string getOrderPlatform(string pseudoAccount, string orderId) {
	return readOrderColumn(pseudoAccount, orderId, 31);
}

/*
* Retrieve order's client id (as received from trading platform).
*/
string getOrderClientId(string pseudoAccount, string orderId) {
	return readOrderColumn(pseudoAccount, orderId, 32);
}

/*
* Retrieve order's stock broker.
*/
string getOrderStockBroker(string pseudoAccount, string orderId) {
	return readOrderColumn(pseudoAccount, orderId, 33);
}

/*
* Checks whether order is open.
* orderId - should be the id returned by placeOrder function when you place an order.
*/
bool isOrderOpen(string pseudoAccount, string orderId) {
	string oStatus = getOrderStatus(pseudoAccount, orderId);
	
	return (StringCompare("OPEN", oStatus, false) == 0) || 
	   (StringCompare("TRIGGER_PENDING", oStatus, false) == 0);
}

/*
* Checks whether order is complete.
* orderId - should be the id returned by placeOrder function when you place an order.
*/
bool isOrderComplete(string pseudoAccount, string orderId) {
	string oStatus = getOrderStatus(pseudoAccount, orderId);
	
	return StringCompare("COMPLETE", oStatus, false) == 0;
}

/*
* Checks whether order is rejected.
* orderId - should be the id returned by placeOrder function when you place an order.
*/
bool isOrderRejected(string pseudoAccount, string orderId) {
	string oStatus = getOrderStatus(pseudoAccount, orderId);
	
	return StringCompare("REJECTED", oStatus, false) == 0;
}

/*
* Checks whether order is cancelled.
* orderId - should be the id returned by placeOrder function when you place an order.
*/
bool isOrderCancelled(string pseudoAccount, string orderId) {
	string oStatus = getOrderStatus(pseudoAccount, orderId);
	
	return StringCompare("CANCELLED", oStatus, false) == 0;
}

/*****************************************************************************/
/************************ ORDER DETAIL FUNCTIONS - END ***********************/
/*****************************************************************************/


/*****************************************************************************/
/************************ POSITION DETAIL FUNCTIONS - START ***********************/
/*****************************************************************************/

/*
* Reads positions file and returns a column value for the given position id.
* Position id is a combination of category, type, independentExchange & independentSymbol.
*/
string readPositionColumnInternal(string pseudoAccount, 
	string category, uint categoryColumnIndex,	
	string type, uint typeColumnIndex,
	Exchange independentExchange, uint independentExchangeColumnIndex,
	string independentSymbol, uint independentSymbolColumnIndex, 
	uint columnIndex) {
	
	string filePath = getPortfolioPositionsFile(pseudoAccount);
	string exchange = EnumToString(independentExchange);
	string result = NULL;

	ushort uSep = StringGetCharacter(AT_COMMA, 0);     
	int handle = FileOpen(filePath, FILE_DEFAULT_READ_FLAGS);
 	
	if(handle != INVALID_HANDLE) {
		while(!FileIsEnding(handle)) {
			string line = FileReadString(handle);
			StringTrimRight(line);
			StringTrimLeft(line);
			if(line == "") {
				break;
			}

			string cols[];
			int splitCnt = StringSplit(line, uSep, cols);			
			if(	(splitCnt > 0) && 
				(StringCompare(category, cols[categoryColumnIndex - 1]) == 0) &&
				(StringCompare(type, cols[typeColumnIndex - 1]) == 0) &&
				(StringCompare(exchange, cols[independentExchangeColumnIndex - 1]) == 0) &&
				(StringCompare(independentSymbol, cols[independentSymbolColumnIndex - 1]) == 0) ) {
				
				result = cols[columnIndex - 1];
				break;
			}			
		}
		
		FileClose(handle);
	}
	else
	{
	   Print("ERROR: file can not be found ", filePath);
	}
	
	return result;
}

/*
* Reads positions file and returns a column value for the given position id.
* Position id is a combination of category, type, independentExchange & independentSymbol.
*/
string readPositionColumn(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol, uint columnIndex) {
	
	return readPositionColumnInternal(pseudoAccount, category, 4, type, 3,
		independentExchange, 5, independentSymbol, 6, columnIndex);
}

/*
* Retrieve positions's trading account.
*/
string getPositionTradingAccount(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 2);
}

/*
* Retrieve positions's MTM (Mtm calculated by your stock broker).
*/
double getPositionMtm(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return StringToDouble(readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 7));
}

/*
* Retrieve positions's PNL (Pnl calculated by your stock broker).
*/
double getPositionPnl(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return StringToDouble(readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 8));
}

/*
* Retrieve positions's AT PNL (Pnl calculated by AutoTrader Web).
*/
double getPositionAtPnl(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return StringToDouble(readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 31));
}

/*
* Retrieve positions's buy quantity.
*/
long getPositionBuyQuantity(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return StringToInteger(readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 9));
}

/*
* Retrieve positions's sell quantity.
*/
long getPositionSellQuantity(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return StringToInteger(readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 10));
}

/*
* Retrieve positions's net quantity.
*/
long getPositionNetQuantity(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return StringToInteger(readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 11));
}

/*
* Retrieve positions's buy value.
*/
double getPositionBuyValue(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return StringToDouble(readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 12));
}

/*
* Retrieve positions's sell value.
*/
double getPositionSellValue(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return StringToDouble(readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 13));
}

/*
* Retrieve positions's net value.
*/
double getPositionNetValue(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return StringToDouble(readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 14));
}

/*
* Retrieve positions's buy average price.
*/
double getPositionBuyAvgPrice(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return StringToDouble(readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 15));
}

/*
* Retrieve positions's sell average price.
*/
double getPositionSellAvgPrice(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return StringToDouble(readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 16));
}

/*
* Retrieve positions's realised pnl.
*/
double getPositionRealisedPnl(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return StringToDouble(readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 17));
}

/*
* Retrieve positions's unrealised pnl.
*/
double getPositionUnrealisedPnl(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return StringToDouble(readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 18));
}

/*
* Retrieve positions's overnight quantity.
*/
long getPositionOvernightQuantity(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return StringToInteger(readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 19));
}

/*
* Retrieve positions's multiplier.
*/
double getPositionMultiplier(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return StringToDouble(readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 20));
}

/*
* Retrieve positions's LTP.
*/
double getPositionLtp(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return StringToDouble(readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 21));
}

/*
* Retrieve positions's (platform specific) exchange.
*/
string getPositionExchange(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 22);
}

/*
* Retrieve positions's (platform specific) symbol.
*/
string getPositionSymbol(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 23);
}

/*
* Retrieve positions's date (DD-MM-YYYY).
*/
string getPositionDay(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 24);
}

/*
* Retrieve positions's trading platform.
*/
string getPositionPlatform(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 25);
}

/*
* Retrieve positions's account id as received from trading platform.
*/
string getPositionAccountId(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 26);
}

/*
* Retrieve positions's stock broker.
*/
string getPositionStockBroker(string pseudoAccount, 
	string category, string type, Exchange independentExchange,	
	string independentSymbol) {
	return readPositionColumn(pseudoAccount, 
		category, type, independentExchange,	independentSymbol, 28);
}

/*****************************************************************************/
/************************ POSITION DETAIL FUNCTIONS - END ***********************/
/*****************************************************************************/


/*****************************************************************************/
/************************ MARGIN DETAIL FUNCTIONS - START ***********************/
/*****************************************************************************/

/*
* Reads margins file and returns a column value for the given margin category.
*/
string readMarginColumn(string pseudoAccount, string category, uint columnIndex) {
	string filePath = getPortfolioMarginsFile(pseudoAccount);
	return fileReadCsvColumnByRowId( filePath, category, 3, columnIndex );
}

/*
* Retrieve margin funds.
*/
double getMarginFunds(string pseudoAccount, string category) {
	return StringToDouble(readMarginColumn(pseudoAccount, category, 4));
}

/*
* Retrieve margin utilized.
*/
double getMarginUtilized(string pseudoAccount, string category) {
	return StringToDouble(readMarginColumn(pseudoAccount, category, 5));
}

/*
* Retrieve margin available.
*/
double getMarginAvailable(string pseudoAccount, string category) {
	return StringToDouble(readMarginColumn(pseudoAccount, category, 6));
}

/*
* Retrieve margin funds for equity category.
*/
double getMarginFundsEquity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_EQUITY, 4));
}

/*
* Retrieve margin utilized for equity category.
*/
double getMarginUtilizedEquity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_EQUITY, 5));
}

/*
* Retrieve margin available for equity category.
*/
double getMarginAvailableEquity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_EQUITY, 6));
}

/*
* Retrieve margin funds for commodity category.
*/
double getMarginFundsCommodity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_COMMODITY, 4));
}

/*
* Retrieve margin utilized for commodity category.
*/
double getMarginUtilizedCommodity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_COMMODITY, 5));
}

/*
* Retrieve margin available for commodity category.
*/
double getMarginAvailableCommodity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_COMMODITY, 6));
}

/*
* Retrieve margin funds for entire account.
*/
double getMarginFundsAll(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_ALL, 4));
}

/*
* Retrieve margin utilized for entire account.
*/
double getMarginUtilizedAll(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_ALL, 5));
}

/*
* Retrieve margin available for entire account.
*/
double getMarginAvailableAll(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_ALL, 6));
}

/*
* Retrieve margin total for equity category.
*/
double getMarginTotalEquity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_EQUITY, 9));
}

/*
* Retrieve margin total for commodity category.
*/
double getMarginTotalCommodity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_COMMODITY, 9));
}

/*
* Retrieve margin total for entire account.
*/
double getMarginTotalAll(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_ALL, 9));
}

/*
* Retrieve margin net for equity category.
*/
double getMarginNetEquity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_EQUITY, 10));
}

/*
* Retrieve margin net for commodity category.
*/
double getMarginNetCommodity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_COMMODITY, 10));
}

/*
* Retrieve margin net for entire account.
*/
double getMarginNetAll(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_ALL, 10));
}

/*
* Retrieve margin span for equity category.
*/
double getMarginSpanEquity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_EQUITY, 11));
}

/*
* Retrieve margin span for commodity category.
*/
double getMarginSpanCommodity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_COMMODITY, 11));
}

/*
* Retrieve margin span for entire account.
*/
double getMarginSpanAll(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_ALL, 11));
}

/*
* Retrieve margin exposure for equity category.
*/
double getMarginExposureEquity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_EQUITY, 12));
}

/*
* Retrieve margin exposure for commodity category.
*/
double getMarginExposureCommodity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_COMMODITY, 12));
}

/*
* Retrieve margin exposure for entire account.
*/
double getMarginExposureAll(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_ALL, 12));
}

/*
* Retrieve margin collateral for equity category.
*/
double getMarginCollateralEquity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_EQUITY, 13));
}

/*
* Retrieve margin collateral for commodity category.
*/
double getMarginCollateralCommodity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_COMMODITY, 13));
}

/*
* Retrieve margin collateral for entire account.
*/
double getMarginCollateralAll(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_ALL, 13));
}

/*
* Retrieve margin payin for equity category.
*/
double getMarginPayinEquity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_EQUITY, 14));
}

/*
* Retrieve margin payin for commodity category.
*/
double getMarginPayinCommodity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_COMMODITY, 14));
}

/*
* Retrieve margin payin for entire account.
*/
double getMarginPayinAll(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_ALL, 14));
}

/*
* Retrieve margin payout for equity category.
*/
double getMarginPayoutEquity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_EQUITY, 15));
}

/*
* Retrieve margin payout for commodity category.
*/
double getMarginPayoutCommodity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_COMMODITY, 15));
}

/*
* Retrieve margin payout for entire account.
*/
double getMarginPayoutAll(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_ALL, 15));
}

/*
* Retrieve margin adhoc for equity category.
*/
double getMarginAdhocEquity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_EQUITY, 16));
}

/*
* Retrieve margin adhoc for commodity category.
*/
double getMarginAdhocCommodity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_COMMODITY, 16));
}

/*
* Retrieve margin adhoc for entire account.
*/
double getMarginAdhocAll(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_ALL, 16));
}

/*
* Retrieve margin realised mtm for equity category.
*/
double getMarginRealisedMtmEquity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_EQUITY, 17));
}

/*
* Retrieve margin realised mtm for commodity category.
*/
double getMarginRealisedMtmCommodity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_COMMODITY, 17));
}

/*
* Retrieve margin realised mtm for entire account.
*/
double getMarginRealisedMtmAll(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_ALL, 17));
}

/*
* Retrieve margin unrealised mtm for equity category.
*/
double getMarginUnrealisedMtmEquity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_EQUITY, 18));
}

/*
* Retrieve margin unrealised mtm for commodity category.
*/
double getMarginUnrealisedMtmCommodity(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_COMMODITY, 18));
}

/*
* Retrieve margin unrealised mtm for entire account.
*/
double getMarginUnrealisedMtmAll(string pseudoAccount) {
	return StringToDouble(readMarginColumn(pseudoAccount, AT_MARGIN_ALL, 18));
}
/*****************************************************************************/
/************************ MARGIN DETAIL FUNCTIONS - END ***********************/
/*****************************************************************************/


/*****************************************************************************/
/************************ HOLDING DETAIL FUNCTIONS - START ***********************/
/*****************************************************************************/

/*
* Reads holding file and returns a column value for the given symbol.
*/
string readHoldingColumn(string pseudoAccount, string symbol, uint columnIndex) {
	string filePath = getPortfolioHoldingsFile(pseudoAccount);
	return fileReadCsvColumnByRowId( filePath, symbol, 3, columnIndex );
}

/*
* Retrieve holding exchange.
*/
string getHoldingExchange(string pseudoAccount, string symbol) {
	return readHoldingColumn(pseudoAccount, symbol, 4);
}

/*
* Retrieve holding ISIN.
*/
string getHoldingIsin(string pseudoAccount, string symbol) {
	return readHoldingColumn(pseudoAccount, symbol, 6);
}

/*
* Retrieve holding quantity.
*/
long getHoldingQuantity(string pseudoAccount, string symbol) {
	return StringToInteger(readHoldingColumn(pseudoAccount, symbol, 7));
}

/*
* Retrieve holding T1 quantity.
*/
long getHoldingT1Quantity(string pseudoAccount, string symbol) {
	return StringToInteger(readHoldingColumn(pseudoAccount, symbol, 8));
}

/*
* Retrieve holding PNL.
*/
double getHoldingPnl(string pseudoAccount, string symbol) {
	return StringToDouble(readHoldingColumn(pseudoAccount, symbol, 9));
}

/*
* Retrieve holding product.
*/
string getHoldingProduct(string pseudoAccount, string symbol) {
	return readHoldingColumn(pseudoAccount, symbol, 10);
}

/*
* Retrieve holding collateral type.
*/
string getHoldingCollateralType(string pseudoAccount, string symbol) {
	return readHoldingColumn(pseudoAccount, symbol, 11);
}

/*
* Retrieve holding collateral quantity.
*/
long getHoldingCollateralQuantity(string pseudoAccount, string symbol) {
	return StringToInteger(readHoldingColumn(pseudoAccount, symbol, 12));
}

/*
* Retrieve holding haircut.
*/
double getHoldingHaircut(string pseudoAccount, string symbol) {
	return StringToDouble(readHoldingColumn(pseudoAccount, symbol, 13));
}

/*
* Retrieve holding average price.
*/
double getHoldingAvgPrice(string pseudoAccount, string symbol) {
	return StringToDouble(readHoldingColumn(pseudoAccount, symbol, 14));
}

/*
* Retrieve holding instrument token.
*/
string getHoldingInstToken(string pseudoAccount, string symbol) {
	return readHoldingColumn(pseudoAccount, symbol, 15);
}

/*
* Retrieve holding symbol LTP.
*/
double getHoldingLtp(string pseudoAccount, string symbol) {
	return StringToDouble(readHoldingColumn(pseudoAccount, symbol, 21));
}

/*
* Retrieve holding current value.
*/
double getHoldingCurrentValue(string pseudoAccount, string symbol) {
	return StringToDouble(readHoldingColumn(pseudoAccount, symbol, 22));
}

/*****************************************************************************/
/************************ HOLDING DETAIL FUNCTIONS - END ***********************/
/*****************************************************************************/


/*****************************************************************************/
/********************* PORTFOLIO SUMMARY FUNCTIONS - START ********************/
/*****************************************************************************/

/*
* Reads summary file and returns a column value.
*/
string readSummaryColumn(string pseudoAccount, uint columnIndex) {
	string filePath = getPortfolioSummaryFile(pseudoAccount);
	return fileReadCsvColumnByRowId( filePath, pseudoAccount, 1, columnIndex );
}

/*
* Retrieve portfolio M2M (Position category = DAY).
*/
double getPortfolioMtm(string pseudoAccount) {
	return StringToDouble(readSummaryColumn(pseudoAccount, 2));
}

/*
* Retrieve portfolio PNL (Position category = DAY).
*/
double getPortfolioPnl(string pseudoAccount) {
	return StringToDouble(readSummaryColumn(pseudoAccount, 3));
}

/*
* Retrieve portfolio position count (Position category = DAY).
*/
long getPortfolioPositionCount(string pseudoAccount) {
	return StringToInteger(readSummaryColumn(pseudoAccount, 4));
}

/*
* Retrieve portfolio OPEN position count (Position category = DAY).
*/
long getPortfolioOpenPositionCount(string pseudoAccount) {
	return StringToInteger(readSummaryColumn(pseudoAccount, 5));
}

/*
* Retrieve portfolio CLOSED position count (Position category = DAY).
*/
long getPortfolioClosedPositionCount(string pseudoAccount) {
	return StringToInteger(readSummaryColumn(pseudoAccount, 6));
}

/*
* Retrieve portfolio open short quantity (Position category = DAY).
*/
long getPortfolioOpenShortQuantity(string pseudoAccount) {
	return StringToInteger(readSummaryColumn(pseudoAccount, 7));
}

/*
* Retrieve portfolio open long quantity (Position category = DAY).
*/
long getPortfolioOpenLongQuantity(string pseudoAccount) {
	return StringToInteger(readSummaryColumn(pseudoAccount, 8));
}

/*
* Retrieve portfolio order count.
*/
long getPortfolioOrderCount(string pseudoAccount) {
	return StringToInteger(readSummaryColumn(pseudoAccount, 9));
}

/*
* Retrieve portfolio "open" order count.
*/
long getPortfolioOpenOrderCount(string pseudoAccount) {
	return StringToInteger(readSummaryColumn(pseudoAccount, 10));
}

/*
* Retrieve portfolio "complete" order count.
*/
long getPortfolioCompleteOrderCount(string pseudoAccount) {
	return StringToInteger(readSummaryColumn(pseudoAccount, 11));
}

/*
* Retrieve portfolio "cancelled" order count.
*/
long getPortfolioCancelledOrderCount(string pseudoAccount) {
	return StringToInteger(readSummaryColumn(pseudoAccount, 12));
}

/*
* Retrieve portfolio "rejected" order count.
*/
long getPortfolioRejectedOrderCount(string pseudoAccount) {
	return StringToInteger(readSummaryColumn(pseudoAccount, 13));
}

/*
* Retrieve portfolio "trigger pending" order count.
*/
long getPortfolioTriggerPendingOrderCount(string pseudoAccount) {
	return StringToInteger(readSummaryColumn(pseudoAccount, 14));
}

/*
* Retrieve portfolio M2M (Position category = NET).
*/
double getPortfolioMtmNET(string pseudoAccount) {
	return StringToDouble(readSummaryColumn(pseudoAccount, 15));
}

/*
* Retrieve portfolio PNL (Position category = NET).
*/
double getPortfolioPnlNET(string pseudoAccount) {
	return StringToDouble(readSummaryColumn(pseudoAccount, 16));
}

/*
* Retrieve portfolio position count (Position category = NET).
*/
long getPortfolioPositionCountNET(string pseudoAccount) {
	return StringToInteger(readSummaryColumn(pseudoAccount, 17));
}

/*
* Retrieve portfolio OPEN position count (Position category = NET).
*/
long getPortfolioOpenPositionCountNET(string pseudoAccount) {
	return StringToInteger(readSummaryColumn(pseudoAccount, 18));
}

/*
* Retrieve portfolio CLOSED position count (Position category = NET).
*/
long getPortfolioClosedPositionCountNET(string pseudoAccount) {
	return StringToInteger(readSummaryColumn(pseudoAccount, 19));
}

/*
* Retrieve portfolio open short quantity (Position category = NET).
*/
long getPortfolioOpenShortQuantityNET(string pseudoAccount) {
	return StringToInteger(readSummaryColumn(pseudoAccount, 20));
}

/*
* Retrieve portfolio open long quantity (Position category = NET).
*/
long getPortfolioOpenLongQuantityNET(string pseudoAccount) {
	return StringToInteger(readSummaryColumn(pseudoAccount, 21));
}

/*****************************************************************************/
/********************** PORTFOLIO SUMMARY FUNCTIONS - END *********************/
/*****************************************************************************/