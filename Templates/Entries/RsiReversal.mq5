input int indicatorPeriod = 14;

int OnInit()
{  
   entryHandle = iRSI(_Symbol, _Period, indicatorPeriod, PRICE_CLOSE);
   if (entryHandle == INVALID_HANDLE) 
   {
      Print("Error creating handle");
   }
   return(INIT_SUCCEEDED);
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