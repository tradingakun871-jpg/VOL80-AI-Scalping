//+------------------------------------------------------------------+
//| VOL80 Headway Historical MTF Bridge V2.00 - READ ONLY           |
//+------------------------------------------------------------------+
#property strict
#property version "2.10"
input string ApiUrl="https://vol80-ai-scalping-production.up.railway.app/api/mt5/candles";
input string BridgeToken="";
input string ApiSymbol="VOL_80";
input int ServerUtcOffsetHours=0; // MT5 server time minus UTC; adjust DST if applicable
input int HistoryM5=500;
input int HistoryM15=500;
input int HistoryH1=500;
input int HistoryD1=250;
input int BatchSize=150;
datetime lastM5=0;
input int TickUploadSeconds=5;
datetime lastTickSent=0;
bool backfill=true;
int OnInit(){EventSetTimer(30);Print("VOL80 MTF bridge started READ ONLY. Allow WebRequest to https://vol80-ai-scalping-production.up.railway.app");return INIT_SUCCEEDED;}
void OnDeinit(const int reason){EventKillTimer();}
string Stamp(datetime t){return TimeToString(t-ServerUtcOffsetHours*3600,TIME_DATE|TIME_MINUTES)+":00Z";}
bool Upload(ENUM_TIMEFRAMES tf,string label,int requested){
 int total=MathMin(MathMax(requested,12),2000);
 MqlRates bars[];
 int got=CopyRates(_Symbol,tf,1,total,bars);
 if(got<1){Print("VOL80 ",label," no history ",GetLastError());return false;}
 int batch=MathMin(MathMax(BatchSize,12),400);
 for(int start=0;start<got;start+=batch){
  string body="{\"symbol\":\""+ApiSymbol+"\",\"tf\":\""+label+"\",\"candles\":[";
  int stop=MathMin(start+batch,got);
  for(int i=start;i<stop;i++){
   if(i>start)body+=",";
   body+="{\"time\":\""+Stamp(bars[i].time)+"\",";
   body+="\"open\":"+DoubleToString(bars[i].open,_Digits)+",\"high\":"+DoubleToString(bars[i].high,_Digits)+",\"low\":"+DoubleToString(bars[i].low,_Digits)+",\"close\":"+DoubleToString(bars[i].close,_Digits)+"}";
  }
  body+="]}";
  char data[],response[];
  StringToCharArray(body,data,0,WHOLE_ARRAY,CP_UTF8);
  ArrayResize(data,ArraySize(data)-1);
  string headers="Content-Type: application/json\r\nAuthorization: Bearer "+BridgeToken+"\r\n",replyHeaders;
  ResetLastError();
  int code=WebRequest("POST",ApiUrl,headers,15000,data,response,replyHeaders);
  if(code!=200){Print("VOL80 ",label," upload FAILED HTTP=",code," MT5=",GetLastError()," response=",CharArrayToString(response));return false;}
 }
 Print("VOL80 ",label," OK: ",got," closed candles uploaded");
 return true;
}
void SendTick(){if(BridgeToken=="")return;if(TimeLocal()-lastTickSent<TickUploadSeconds)return;MqlTick tick;if(!SymbolInfoTick(_Symbol,tick))return;string body="{\"symbol\":\""+ApiSymbol+"\",\"bid\":"+DoubleToString(tick.bid,_Digits)+",\"ask\":"+DoubleToString(tick.ask,_Digits)+",\"last\":"+DoubleToString(tick.last,_Digits)+"}";char data[],response[];StringToCharArray(body,data,0,WHOLE_ARRAY,CP_UTF8);ArrayResize(data,ArraySize(data)-1);string headers="Content-Type: application/json\r\nAuthorization: Bearer "+BridgeToken+"\r\n",replyHeaders;int code=WebRequest("POST","https://vol80-ai-scalping-production.up.railway.app/api/mt5/tick",headers,5000,data,response,replyHeaders);if(code==200)lastTickSent=TimeLocal();else Print("VOL80 tick error HTTP ",code);}
void OnTick(){SendTick();}
void OnTimer(){SendTick();
 if(BridgeToken==""){Print("VOL80 missing BridgeToken");return;}
 if(backfill){
  bool ok=Upload(PERIOD_D1,"D1",HistoryD1);
  ok=Upload(PERIOD_H1,"H1",HistoryH1)&&ok;
  ok=Upload(PERIOD_M15,"M15",HistoryM15)&&ok;
  ok=Upload(PERIOD_M5,"M5",HistoryM5)&&ok;
  if(ok){backfill=false;lastM5=iTime(_Symbol,PERIOD_M5,1);Print("VOL80 MTF HISTORY IMPORT COMPLETE");}
  return;
 }
 datetime current=iTime(_Symbol,PERIOD_M5,1);
 if(current<=0||current==lastM5)return;
 bool ok=Upload(PERIOD_D1,"D1",25);
 ok=Upload(PERIOD_H1,"H1",30)&&ok;
 ok=Upload(PERIOD_M15,"M15",40)&&ok;
 ok=Upload(PERIOD_M5,"M5",72)&&ok;
 if(ok)lastM5=current;
}
