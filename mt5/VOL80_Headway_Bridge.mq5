//+------------------------------------------------------------------+
//| VOL80 Headway M5 Closed Candle Bridge (signals only, no orders) |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"
input string ApiUrl="https://vol80-ai-scalping-production.up.railway.app/api/mt5/candles";
input string BridgeToken="";
input string ApiSymbol="VOL_80";
input int UploadBars=60;
datetime lastSent=0;
int OnInit(){EventSetTimer(30);Print("Allow WebRequest for: https://vol80-ai-scalping-production.up.railway.app");return INIT_SUCCEEDED;}
void OnDeinit(const int reason){EventKillTimer();}
string JsonNum(double n){return DoubleToString(n,Digits());}
void OnTimer(){
 if(BridgeToken==""){Print("BridgeToken missing");return;}
 datetime t=iTime(_Symbol,PERIOD_M5,1);
 if(t<=0||t==lastSent)return;
 int count=MathMin(MathMax(12,UploadBars),500);
 MqlRates bars[];
 int got=CopyRates(_Symbol,PERIOD_M5,1,count,bars);
 if(got<12)return;
 string payload="{\"symbol\":\""+ApiSymbol+"\",\"tf\":\"M5\",\"candles\":[";
 for(int i=0;i<got;i++){
   if(i>0)payload+=",";
   payload+="{\"time\":\""+TimeToString(bars[i].time,TIME_DATE|TIME_MINUTES)+":00Z\",";
   payload+="\"open\":"+DoubleToString(bars[i].open,_Digits)+",\"high\":"+DoubleToString(bars[i].high,_Digits)+",\"low\":"+DoubleToString(bars[i].low,_Digits)+",\"close\":"+DoubleToString(bars[i].close,_Digits)+"}";
 }
 payload+="]}";
 char data[],response[];StringToCharArray(payload,data,0,WHOLE_ARRAY,CP_UTF8);ArrayResize(data,ArraySize(data)-1);
 string headers="Content-Type: application/json\r\nAuthorization: Bearer "+BridgeToken+"\r\n",replyHeaders;
 ResetLastError();
 int status=WebRequest("POST",ApiUrl,headers,10000,data,response,replyHeaders);
 if(status==200){lastSent=t;Print("VOL80 M5 sent ",got," candles");}
 else Print("VOL80 bridge error HTTP ",status," MT5 ",GetLastError()," ",CharArrayToString(response));
}
