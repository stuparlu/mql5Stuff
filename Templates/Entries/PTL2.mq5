input int fastLength = 3;
input int slowLength = 7;

int OnInit()
{  
   entryHandle = iCustom(_Symbol, PERIOD_CURRENT, "PTL2", fastLength, slowLength);
   if (entryHandle == INVALID_HANDLE) 
   {
      Print("Error creating handle");
   }
   
   return(INIT_SUCCEEDED);
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