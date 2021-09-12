//+------------------------------------------------------------------+
//|                                                    RsiExpert.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright Parche"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>

//#define OPEN_SLEEP_INTERVAL 60*60000
//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
input double stopMultiplier;

int entryHandle;
int filterHandle;
int slowConfirmationHandle;
int volatilityHandle;
int atrHandle; 
int baselineHandle;


CTrade trade;
ulong positionTicket;
datetime lastDealTime;
long waitTime = 3*PeriodSeconds(PERIOD_CURRENT);

double currentBid;
double currentAsk;
double openAtr;
double atr;


struct tradeData
{
   bool stopsActivated;
   double stopLoss;
 //  double takeProfit;
};

tradeData positionData = {false, 0, /*9999*/};
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
//---
//---
   entryHandle = iRSI(_Symbol, PERIOD_CURRENT, 2, PRICE_CLOSE);
   if (entryHandle == INVALID_HANDLE) 
   {
      Print("Error creating handle");
   }
   
   filterHandle = iRSI(_Symbol, PERIOD_CURRENT, 25, PRICE_CLOSE);
   if (filterHandle == INVALID_HANDLE) 
   {
      Print("Error creating handle");
   }
   
   slowConfirmationHandle = iMA(_Symbol, PERIOD_CURRENT, 200, 0, MODE_SMA, PRICE_CLOSE);
   if (slowConfirmationHandle == INVALID_HANDLE) 
   {
      Print("Error creating handle");
   }
   
   volatilityHandle = iCustom(_Symbol, PERIOD_CURRENT, "normalized-volume-oscillator-indicator.ex5"/*, 20*/);
   if (volatilityHandle == INVALID_HANDLE) 
   {
      Print("Error creating handle");
   }
   
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if (atrHandle == INVALID_HANDLE) 
   {
      Print("Error creating handle");
   }
   
   Print("Initialization succesfull.");
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//---
   
}

bool FillArraysFromBuffers(double &first_buffer[],    // indicator buffer of MACD values 
                           double &second_buffer[],  // indicator buffer of the signal line of MACD  
                           int ind_handle,           // handle of the iMACD indicator 
                           int amount,                // number of copied values 
                           int fastIndex,
                           int slowIndex
                           ) 
  { 
//--- reset error code 
   ResetLastError(); 
//--- fill a part of the iMACDBuffer array with values from the indicator buffer that has 0 index 
   if(CopyBuffer(ind_handle, fastIndex, 1, amount, first_buffer) < 0) 
     { 
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iMACD indicator, error code %d",GetLastError()); 
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(false); 
     } 
  
//--- fill a part of the SignalBuffer array with values from the indicator buffer that has index 1 
   if(CopyBuffer(ind_handle, slowIndex, 1, amount, second_buffer) < 0) //Vrati na 1 posle didiIndeksa
     { 
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iMACD indicator, error code %d",GetLastError()); 
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(false); 
     } 
//--- everything is fine 
   return(true); 
  } 
  
bool FillArrayFromBuffer(double &from_buffer[],    // indicator buffer of MACD values 
                           int ind_handle,           // handle of the iMACD indicator 
                           int amount,                // number of copied values 
                           int buffer_index
                           ) 
{ 
//--- reset error code 
   ResetLastError(); 
//--- fill a part of the iMACDBuffer array with values from the indicator buffer that has 0 index 
   if(CopyBuffer(ind_handle, buffer_index, 1, amount, from_buffer)<0) 
     { 
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iMACD indicator, error code %d",GetLastError()); 
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(false); 
     } 
//--- everything is fine 
   return(true); 
} 

#define ENTRY_BUFFER_INDEX 0
string GetEntrySignal()    // For zero cross or one line indies
{
//---
   int candleNumber = 2;
   double signalLine[]; 
   FillArrayFromBuffer(signalLine, entryHandle, candleNumber , ENTRY_BUFFER_INDEX);
   //double signalValue = signalLine[1];
  // double signalBefore = signalLine[0];
   bool buyable = false;
   bool sellable = false;

   for (int i = candleNumber - 1; i > 0; i--) 
   {
      if (signalLine[i] > 95 && signalLine[i - 1] <= 95) 
      {
         sellable = true;
         break;
      }
      
      if (signalLine[i] < 5 && signalLine[i - 1] >= 5)
      {
         buyable = true;
         break;
      }
   }
   //Print("BUY ", buyable, " SELL ", sellable);
   string signal = "";
   if (buyable && !sellable) 
   {
      signal = "buy";
   }
   else if (sellable && !buyable)
   {
      signal = "sell";
   }
   
   return signal;
}

#define CONFIRMATION_BUFFER_INDEX 0
#define CANDLE_NUMBER 2
string GetConfirmationSignal()    // For zero cross or one line indies
{
//---
   int candleNumber = CANDLE_NUMBER;
   double signalLine[]; 
   double closePrices[CANDLE_NUMBER];
   for(int i = 0; i < candleNumber; i++)
   { 
      closePrices[i] = iClose(_Symbol, PERIOD_CURRENT, candleNumber - i);
   }
   FillArrayFromBuffer(signalLine, slowConfirmationHandle, candleNumber , CONFIRMATION_BUFFER_INDEX);
   //double signalValue = signalLine[1];
  // double signalBefore = signalLine[0];
   bool buyable = false;
   bool sellable = false;

   for (int i = candleNumber - 1; i > 0; i--) 
   {
      if (closePrices[i] > signalLine[i] /*&& closePrices[i] > fastLine[i]*/) 
      {
         buyable = true;
         break;
      }
      
      if (closePrices[i] < signalLine[i] /*&& closePrices[i] < fastLine[i]*/)
      {
         sellable = true;
         break;
      }
   }
   //Print("BUY ", buyable, " SELL ", sellable);
   string signal = "";
   if (buyable && !sellable) 
   {
      signal = "buy";
   }
   else if (sellable && !buyable)
   {
      signal = "sell";
   }
   
   return signal;
}

#define FILTER_BUFFER_INDEX 0
#define FILTER_CANDLE_NUMBER 2
string GetFilterSignal()    // For zero cross or one line indies
{
//---
   int candleNumber = FILTER_CANDLE_NUMBER;
   double signalLine[]; 
   double closePrices[FILTER_CANDLE_NUMBER];
   for(int i = 0; i < candleNumber; i++)
   { 
      closePrices[i] = iClose(_Symbol, PERIOD_CURRENT, candleNumber - i);
   }
   FillArrayFromBuffer(signalLine, filterHandle, candleNumber , FILTER_BUFFER_INDEX);
   //double signalValue = signalLine[1];
  // double signalBefore = signalLine[0];
   bool buyable = false;
   bool sellable = false;

   for (int i = candleNumber - 1; i > 0; i--) 
   {
      if (signalLine[i] > 55 ) 
      {
         buyable = true;
         break;
      }
      
      if (signalLine[i] < 45)
      {
         sellable = true;
         break;
      }
   }
   //Print("BUY ", buyable, " SELL ", sellable);
   string signal = "";
   if (buyable && !sellable) 
   {
      signal = "buy";
   }
   else if (sellable && !buyable)
   {
      signal = "sell";
   }
   
   return signal;
}

#define VOLATILITY_BUFFER_INDEX 0
string GetVolatilitySignal()    // For zero cross or one line indies
{
//---
   double signalLine[];
   FillArrayFromBuffer(signalLine, volatilityHandle, 2 , VOLATILITY_BUFFER_INDEX);
   string signal = "";
   if (signalLine[1] > 0)
   {
      signal = "trade";
   }
   return signal;
}

double GetLastAtrValue() 
{
//---
   double atrValues[]; 
   CopyBuffer(atrHandle, 0, 1, 1, atrValues);
   return atrValues[0];
}

bool CloseHalfPosition(double positionSize)
{
    bool retVal = trade.PositionClosePartial(positionTicket, positionSize/2);
    return retVal;
}

bool ClosePosition()
{
   bool retVal = trade.PositionClose(positionTicket);
   positionTicket = 0;
   positionData.stopsActivated = false;
   return retVal;
}

double CalculateLotSize()
{
   double margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double price = (currentAsk + currentBid)/2;
   int leverage = (int) AccountInfoInteger(ACCOUNT_LEVERAGE);
   double lotSize = (margin*leverage*0.02)/(price*100000);
   lotSize = NormalizeDouble(lotSize, 1);
   Print("Margin: ", margin, " Leverage: ", leverage, " Price: ", price, " Lot Size: ", lotSize);
   return lotSize;
}

void Short()
{
   //Print("PLACING SHORT");
   //trade.Sell(CalculateLotSize(), _Symbol, 0, currentAsk + 1.5*atr);
   trade.Sell(CalculateLotSize(), _Symbol, 0, currentAsk + stopMultiplier * atr, currentAsk - stopMultiplier * atr);
   positionTicket = trade.ResultOrder();
}

void Long()
{
   //Print("PLACING LONG");
   //trade.Buy(CalculateLotSize(), _Symbol, 0, currentBid - 1.5*atr);
   trade.Buy(CalculateLotSize(), _Symbol, 0, currentBid - stopMultiplier * atr, currentBid + stopMultiplier * atr);
   positionTicket = trade.ResultOrder();
}

bool CheckExit(int positionType, string exit)
{
   bool retVal = false;
   if (positionType == POSITION_TYPE_BUY)
   {
      if(exit == "sell") 
      {
         //Print("EXITING WITH INDICATOR");
         ClosePosition();
         retVal = true;
      }
   }
         
   if (positionType == POSITION_TYPE_SELL)
   {
      if(exit == "buy") 
      {
         //Print("EXITING WITH INDICATOR");
         ClosePosition();
         retVal = true;
      }
   }
   return retVal;
}

bool checkTPSL(int positionType) 
{
   bool retVal = false;
   if (positionType == POSITION_TYPE_BUY)
   {
      if(currentBid < positionData.stopLoss)
      {
         ClosePosition();
         retVal = true;
      }
   }
   else if(positionType == POSITION_TYPE_SELL)
   {

      if (currentAsk > positionData.stopLoss)
      {
         ClosePosition();
         retVal = true;
      }
   }
   return retVal;
}

bool CheckHalfClose(int positionType, double positionSize, double latestOpenPrice)
{
   bool retVal = false;
   if(positionType == POSITION_TYPE_BUY)
   {  
      //Print("CHECKING TPSL FOR BUY");
      if(currentBid > latestOpenPrice + openAtr)
      {
         CloseHalfPosition(positionSize);
         positionData.stopsActivated = true;
         positionData.stopLoss = latestOpenPrice + 1.5*openAtr;
         //positionData.takeProfit = latestOpenPrice + 2*openAtr;
         retVal = true;
      }
   }
   else if(positionType == POSITION_TYPE_SELL)
   {
      //Print("CHECKING TPSL FOR SELL");
      if(currentAsk < latestOpenPrice - openAtr)
      {
         CloseHalfPosition(positionSize);
         positionData.stopsActivated = true;
         positionData.stopLoss = latestOpenPrice - 1.5*openAtr;
         //positionData.takeProfit = latestOpenPrice - 2*openAtr;
         retVal = true;
      }
   }
   return retVal;
}
void HandlePosition(string exit)
{
   //Print("ORDER PLACED");
   int positionType = (int) PositionGetInteger(POSITION_TYPE);
   double positionSize = (double) PositionGetDouble(POSITION_VOLUME);
   double latestOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   
   if(CheckExit(positionType, exit))
   {
      return;
   }/*
   else if (positionData.stopsActivated)
   {
     // if(checkTPSL(positionType))
      //{
     //    return;
     // }
   }
   else
   {
      if(CheckHalfClose(positionType, positionSize, latestOpenPrice))
      {
         return;
      }
   }*/
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+

void OnTick()
{
   string entry = GetEntrySignal();
   string confirmation = GetConfirmationSignal();
   string filter = GetFilterSignal();
   string volatility = GetVolatilitySignal();
   atr = GetLastAtrValue();

   currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if (!PositionSelectByTicket(positionTicket))
   {
      positionTicket = 0;
   }
   
   if(positionTicket <= 0)
   {  
      long secondsElapsed = (long)((long)TimeTradeServer() - lastDealTime);
      if (secondsElapsed >= waitTime)
      {
         if (entry == "sell" && confirmation == "sell" && filter != "buy" && volatility == "trade")
          {
            Short();
          }
          else if (entry == "buy" && confirmation == "buy" && filter != "sell" && volatility == "trade")
          {
            Long();
          }
      }
   }   
   else
   {
      //HandlePosition(exit);
   }
}
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
//---
     datetime timeEnd = TimeTradeServer(); //calculated server time (TimeCurrent() may not suffice for multi-currency logic)
     datetime timeStart = timeEnd - PeriodSeconds(500*PERIOD_CURRENT); //use smaller period if logic does not need to look back so far as 1 day
     HistorySelect(timeStart, timeEnd);  
     long deal_time;
     HistoryDealGetInteger(trans.deal, DEAL_TIME, deal_time);
     lastDealTime = (datetime)deal_time; 
  
}
//+------------------------------------------------------------------+
