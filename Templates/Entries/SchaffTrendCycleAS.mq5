input int       SchaffPeriod = 10;      
input int       FastEma      = 23;       
input int       SlowEma      = 50;      
input double    SmoothPeriod = 3;      


int OnInit()
{  
   entryHandle = iCustom(_Symbol, PERIOD_CURRENT, "SchaffTrendCycleAS", SchaffPeriod, FastEma, SlowEma, SmoothPeriod);
   if (entryHandle == INVALID_HANDLE) 
   {
      Print("Error creating handle");
   }
   
   return(INIT_SUCCEEDED);
}


#define ENTRY_BUFFER_INDEX 1
string GetEntrySignal() 
{
   double signalLine[]; 
   FillArrayFromBuffer(signalLine, entryHandle, 2 , ENTRY_BUFFER_INDEX);
   double signalValue = signalLine[1];
   double signalBefore = signalLine[0];
   
   string signal = "";
   if (signalValue == 1 && signalBefore == 2)
   {
      signal = "sell";
   } 
   else if (signalValue == 2 && signalBefore == 1)
   {
      signal = "buy";
   }
   
   return signal;
}