//+------------------------------------------------------------------+
//|                                                  EntryTester.mq5 |
//|                                      Copyright 2021, Luka Stupar |
//+------------------------------------------------------------------+

#property copyright "Copyright Luka Stupar"
#property link      ""
#property version   "1.00"

#include <Trade/Trade.mqh>

#define OPEN_SLEEP_INTERVAL 5*PeriodSeconds(PERIOD_CURRENT)*60000

input float betAmount = 100;
input float changeAmount = 10;

input int fastLength = 3;
input int slowLength = 7;


//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
int entryHandle;

CTrade trade;
ulong positionTicket;

double balance = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
int leverage = (int) AccountInfoInteger(ACCOUNT_LEVERAGE);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{  
   entryHandle = iCustom(_Symbol, PERIOD_CURRENT, "PTL2", fastLength, slowLength);
   if (entryHandle == INVALID_HANDLE) 
   {
      Print("Error creating handle");
   }
   
   
   Print("Initialization succesfull.");
   return(INIT_SUCCEEDED);
}

bool FillArraysFromBuffers(double &first_buffer[], double &second_buffer[], int ind_handle, int amount, int fastIndex, int slowIndex) 
{ 
   ResetLastError(); 
   if(CopyBuffer(ind_handle, fastIndex, 0, amount, first_buffer) < 0) 
   { 
    PrintFormat("Failed to copy data from the indicator, error code %d",GetLastError()); 
    return(false); 
   } 
   
   if(CopyBuffer(ind_handle, slowIndex, 0, amount, second_buffer) < 0)
   { 
      PrintFormat("Failed to copy data from the indicator, error code %d",GetLastError()); 
      return(false); 
   } 
   return(true); 
} 

#define ENTRY_FIRST_BUFF_INDEX 5
#define ENTRY_SECOND_BUFF_INDEX 6  
string GetEntrySignal() 
{
   double slowLine[]; 
   double fastLine[]; 
   FillArraysFromBuffers(slowLine, fastLine, entryHandle, 2 , ENTRY_FIRST_BUFF_INDEX, ENTRY_SECOND_BUFF_INDEX);
   double fastLineNow = fastLine[1];
   double fastLineBefore = fastLine[0];
   
   double slowLineNow = slowLine[1];
   double slowLineBefore = slowLine[0];
   
   string signal = "";
   if (fastLineNow < slowLineNow && fastLineBefore > slowLineBefore)
   {
      signal = "sell";
   } 
   else if (fastLineNow > slowLineNow && fastLineBefore < slowLineBefore)
   {
      signal = "buy";
   }
   
   return signal;
}

void Short()
{
   double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double contractSize = 100000;
   double lotSize = NormalizeDouble((betAmount * leverage) / (entryPrice * 100000), 1);
   double tradeCost = (contractSize * lotSize * entryPrice) / leverage;
   double priceChange = changeAmount / (tradeCost * leverage);
   double stopLossPrice = entryPrice + priceChange;
   double takeProfitPrice = entryPrice - priceChange;
   trade.Sell(lotSize, _Symbol, 0, stopLossPrice, takeProfitPrice);
   Sleep(OPEN_SLEEP_INTERVAL);
}

void Long()
{
   double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double contractSize = 100000;
   double lotSize = NormalizeDouble((betAmount * leverage) / (entryPrice * 100000), 1);
   double tradeCost = (contractSize * lotSize * entryPrice) / leverage;
   double priceChange = changeAmount / (tradeCost * leverage);
   double stopLossPrice = entryPrice - priceChange;
   double takeProfitPrice = entryPrice + priceChange;
   trade.Buy(lotSize, _Symbol, 0, stopLossPrice, takeProfitPrice);
   Sleep(OPEN_SLEEP_INTERVAL);
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+

void OnTick()
{
   string entry = GetEntrySignal();

   if (entry == "sell")
   {
     Short();
   }
   else if (entry == "buy")
   {
     Long();
   }
}