//+------------------------------------------------------------------+
//|                                                  EntryTester.mq5 |
//|                                      Copyright 2021, Luka Stupar |
//+------------------------------------------------------------------+

#property copyright "Copyright Luka Stupar"
#property link      ""
#property version   "1.00"

#include <Trade/Trade.mqh>

#define OPEN_SLEEP_INTERVAL 6*60000

input float lossMultiplier;
input float profitMultiplier;

input int indicatorPeriod;

//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
int entryHandle;
int atrHandle; 

CTrade trade;
ulong positionTicket;

double currentBid;
double currentAsk;
double openAtr;
double atr;

double margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
int leverage = (int) AccountInfoInteger(ACCOUNT_LEVERAGE);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{  
   entryHandle = iRSI(_Symbol, _Period, indicatorPeriod, PRICE_CLOSE);
//   entryHandle = iCustom(_Symbol, PERIOD_CURRENT, "Schaff_trend_cycle_as", 250, 120, 400, 3);
//   if (entryHandle == INVALID_HANDLE) 
//   {
//      Print("Error creating handle");
//   }
   
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if (atrHandle == INVALID_HANDLE) 
   {
      Print("Error creating handle");
   }
   
   Print("Initialization succesfull.");
   return(INIT_SUCCEEDED);
}

bool FillArrayFromBuffer(double &from_buffer[], int ind_handle, int amount, int buffer_index) 
{ 
   ResetLastError(); 
   if(CopyBuffer(ind_handle, buffer_index, 1, amount, from_buffer)<0) 
   { 
      PrintFormat("Failed to copy data from the iMACD indicator, error code %d",GetLastError()); 
      return(false); 
   } 
   return(true); 
} 

#define ENTRY_BUFFER_INDEX 0
string GetEntrySignal() 
{
   double signalLine[]; 
   FillArrayFromBuffer(signalLine, entryHandle, 2 , ENTRY_BUFFER_INDEX);
   double signalValue = signalLine[1];
   double signalBefore = signalLine[0];
   
   string signal = "";
   if (signalValue < 80 && signalBefore > 80)
   {
      signal = "sell";
   } 
   else if (signalValue > 20 && signalBefore < 20)
   {
      signal = "buy";
   }
   
   return signal;
}

double GetLastAtrValue() 
{
   double atrValues[]; 
   CopyBuffer(atrHandle, 0, 1, 1, atrValues);
   return atrValues[0];
}

double CalculateLotSize()
{
   double lot_price = (currentAsk + currentBid)/2;
   double lotSize = (margin*leverage*0.02)/(lot_price*100000);
   Print("Margin: ", margin, " Leverage: ", leverage, " Price: ", lot_price, " Lot Size: ", lotSize);
   return NormalizeDouble(lotSize, 1);
}

void Short()
{
   trade.Sell(CalculateLotSize(), _Symbol, 0, currentAsk + lossMultiplier*atr, currentAsk - profitMultiplier*atr);
   positionTicket = trade.ResultOrder();
   Sleep(OPEN_SLEEP_INTERVAL);
}

void Long()
{
   trade.Buy(CalculateLotSize(), _Symbol, 0, currentBid - lossMultiplier*atr, currentBid + profitMultiplier*atr);
   positionTicket = trade.ResultOrder();
   Sleep(OPEN_SLEEP_INTERVAL);
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
}