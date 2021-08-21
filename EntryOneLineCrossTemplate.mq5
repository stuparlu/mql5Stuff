//+------------------------------------------------------------------+
//|                                                    RsiExpert.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright Parche"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>

#define OPEN_SLEEP_INTERVAL 60*60000
//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
int entryHandle;
int confirmationHandle;
int atrHandle; 
int baselineHandle;


CTrade trade;
ulong positionTicket;

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
   entryHandle = iCustom(_Symbol, PERIOD_CURRENT, "wpr.ex5", 14);
   if (entryHandle == INVALID_HANDLE) 
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
   double signalLine[]; 
   FillArrayFromBuffer(signalLine, entryHandle, 2 , ENTRY_BUFFER_INDEX);
   double signalValue = signalLine[1];
   double signalBefore = signalLine[0];

   string signal = "";
   if (signalValue > -20 && signalBefore <= -20)
   {
      signal = "buy";
   } 
   else if (signalValue < -80 && signalBefore >= -8)
   {
      signal = "sell";
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
    //Print("DOING PARTIAL CLOSE");
    bool retVal = trade.PositionClosePartial(positionTicket, positionSize/2);
    Sleep(60000);
    return retVal;
}

bool ClosePosition()
{
   //Print("DOING FULL CLOSE");
   bool retVal = trade.PositionClose(positionTicket);
   positionTicket = 0;
   positionData.stopsActivated = false;
   Sleep(300000);
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
   trade.Sell(CalculateLotSize(), _Symbol, 0, currentAsk + 1.5*atr, currentAsk - atr);

   positionTicket = trade.ResultOrder();
   Sleep(OPEN_SLEEP_INTERVAL);
}

void Long()
{
   //Print("PLACING LONG");
   //trade.Buy(CalculateLotSize(), _Symbol, 0, currentBid - 1.5*atr);
   trade.Buy(CalculateLotSize(), _Symbol, 0, currentBid - 1.5*atr, currentBid + atr);

   positionTicket = trade.ResultOrder();
   Sleep(OPEN_SLEEP_INTERVAL);
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
         positionData.stopLoss = latestOpenPrice + openAtr;
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
         positionData.stopLoss = latestOpenPrice - openAtr;
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
   atr = GetLastAtrValue();

   currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if (!PositionSelectByTicket(positionTicket))
   {
      positionTicket = 0;
   }
   
   if(positionTicket <= 0)
   {
      
      if (entry == "sell")
      {
        Short();
      }
      else if (entry == "buy")
      {
        Long();
      }
   }   
   else
   {
      //HandlePosition(exit);
   }
}