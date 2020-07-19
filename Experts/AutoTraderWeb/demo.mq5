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
   placeOrderAdvancedExample();
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
   string id = placeOrderAdvanced(REGULAR, "ACC", 
	NSE, "SBIN", BUY, MARKET, INTRADAY, 1, 
	0.0, 0.0, 0, 0, 0, 0, DAY, false,
	defaultStrategyId(), "", true);
      
   Print("[placeOrderAdvancedExample] Order Id: ", id);
}
