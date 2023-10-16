#include <Trade/Trade.mqh>

#define OPEN_SLEEP_INTERVAL 10*60000

input float lossMultiplier;
input float profitMultiplier;

int atrHandle; 

CTrade trade;
ulong positionTicket;

double currentBid;
double currentAsk;
double openAtr;
double atr;

double margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
int leverage = (int) AccountInfoInteger(ACCOUNT_LEVERAGE);

bool FillArrayFromBuffer(double &from_buffer[], int ind_handle, int amount, int buffer_index) 
{ 
   ResetLastError(); 
   if(CopyBuffer(ind_handle, buffer_index, 0, amount, from_buffer)<0) 
   { 
      PrintFormat("Failed to copy data from the iMACD indicator, error code %d",GetLastError()); 
      return(false); 
   } 
   return(true); 
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

int OnInit()
{  
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if (atrHandle == INVALID_HANDLE) 
   {
      Print("Error creating handle");
   }
   
   return(INIT_SUCCEEDED);
}