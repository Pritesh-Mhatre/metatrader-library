//+----------------------------------------------------------------------+
//|                                                         demo.mq5 					|
//|                                                       AutoTrader Web 				|
//|                            http://stocksdeveloper.in/autotrader-web 	|
//+----------------------------------------------------------------------+
#property copyright "AutoTrader"
#property link      "http://stocksdeveloper.in/autotrader-web"
#property version   "1.00"

/*********************************************************************
* Include AutoTrader header file to make sure AutoTrader functions
* are available to your strategy code.
*********************************************************************/

#include <autotrader.mqh>

/*********************************************************************
* Standard MetaTrader Expert Advise Events. You will have your 
* strategy code here. Based on your requirements now you can use
* AutoTrader functions in your code simply like you use any other
* built-in MetaTrader functions.
*********************************************************************/

int OnInit()
  {
   // placeOrderAdvancedExample();
   
   // placeOrderExample();
   
   // placeBracketOrderExample();
   
   // placeCoverOrderExample();
   
   // modifyOrderPriceExample();
   
   // cancelOrderExample();
   
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
  }
void OnTick()
  {
  }

/*********************************************************************
* Given below are some examples of AutoTrader functions.
*********************************************************************/

void placeOrderAdvancedExample() {
   string id = placeOrderAdvanced(REGULAR, AT_ACCOUNT, 
	NSE, "SBIN", BUY, MARKET, INTRADAY, 1, 
	0.0, 0.0, 0, 0, 0, 0, DAY, false,
	defaultStrategyId(), "", true);
      
   Print("[placeOrderAdvancedExample] Order Id: ", id);
}

void placeOrderExample() {
   string id = placeOrder(AT_ACCOUNT, NSE, "SBIN", SELL, LIMIT, INTRADAY, 1, 
	192.44, 0.0, true);
      
   Print("[placeOrderExample] Order Id: ", id);
}

void placeBracketOrderExample() {
   string id = placeBracketOrder(AT_ACCOUNT, NSE, "SBIN", BUY, LIMIT, 1, 
	192, 0.0, 1, 1, 0, true);
      
   Print("[placeBracketOrderExample] Order Id: ", id);
}

void placeCoverOrderExample() {
   string id = placeCoverOrder(AT_ACCOUNT, NSE, "SBIN", BUY, LIMIT, 1, 
	192, 190.5, true);
      
   Print("[placeCoverOrderExample] Order Id: ", id);
}

void modifyOrderPriceExample() {
   modifyOrderPrice(AT_ACCOUNT, "1595251087-30714", 193.5);
}

void cancelOrderExample() {
   cancelOrder(AT_ACCOUNT, "1595251085-3681");
}