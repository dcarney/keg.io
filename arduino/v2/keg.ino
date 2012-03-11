// keg.io v2 Arduino Code
// Written By: Carl Krauss
//
// Header Files
#include <SPI.h>
#include <SC16IS750.h>
#include <WiFly.h>
#include <sha256.h>
#include <Regexp.h>
#include "Credentials.h"

// Globl Variable Definitions
String ap = "/api/kegerator/";
String applicationPath = ap+clientId;
String httpParameters = "id="+ String(clientId);
char domain[] = "dev.keg.io";

WiFlyClient client(domain, 80);

void printHash(uint8_t* hash) {
  int i;
  for (i=0; i<32; i++) {
    Serial.print("0123456789abcdef"[hash[i]>>4]);
    Serial.print("0123456789abcdef"[hash[i]&0xf]);
  }
  Serial.println();
}

String getHash(uint8_t* hash){
  String stringOne;
  int i;
  for (i=0; i<32; i++) {
    stringOne+=("0123456789abcdef"[hash[i]>>4]);
    stringOne+=("0123456789abcdef"[hash[i]&0xf]);
  }
  return stringOne;
}

void sendPut(String action, String actionValue){
    Serial.println("Connected: Sending PUT Request");
    actionValue.toLowerCase();
    action.toLowerCase();
    String sig;
    String payload = "PUT " + applicationPath + "/" + action + "/" + actionValue;
    Sha256.initHmac(clientSecret,clientSecretLength);
    Sha256.print("PUT "+String(domain) + applicationPath + "/" + action + "/" + actionValue);
    Serial.println("PUT "+String(domain) + applicationPath + "/" + action + "/" + actionValue);
    sig = getHash(Sha256.resultHmac());
    Serial.println(sig);
    String putHeader = payload + "?signature="+sig+" HTTP/1.1";
    client.println(putHeader);
    client.println("Host: " + String(domain));
    client.println("Content-type: application/x-www-form-urlencoded");
    client.println("Connection: close");
    client.print("Content-Length: ");
    client.println(httpParameters.length());
    client.println();
    client.println(httpParameters);
    client.println();
}

void sendGet(String action, String cardId){
    Serial.println("Connected: Sending GET Request");
    cardId.toLowerCase();
    action.toLowerCase();
    String getHeader = " ";
    String appPath = String(applicationPath);
    String appDomain = String(domain);
    String sig;
    String payload = "GET " + appPath + "/" + action +"/"+ cardId;
    Sha256.initHmac(clientSecret,clientSecretLength);
    Sha256.print("GET "+ appDomain + appPath + "/" + action +"/"+ cardId);
    Serial.println("GET "+ appDomain + appPath + "/" + action +"/"+ cardId);
    sig = getHash(Sha256.resultHmac());
    getHeader = "GET " + appPath + "/";
    getHeader += action+"/";
    getHeader += cardId+"?signature=";
    getHeader += sig;
    getHeader += " HTTP/1.1";
    Serial.println(getHeader);
    client.println(getHeader);
    Serial.println("Host: "+appDomain);
    client.println("Host: "+appDomain);
    client.println();
}

bool validResponse(){
  Serial.println("In valid response.");
    while (client.available()){
      char c = client.read();
      Serial.print(c);
    }
}

void setup() {
  //Setup variables
int requestType = 1;
  Serial.begin(9600);
  SC16IS750.begin();
  WiFly.setUart(&SC16IS750);
  WiFly.begin();
  
  if (!WiFly.join(ssid, passphrase)) {
    Serial.println("Association failed.");
    while (1) {
      // Hang on failure.
    }
  }  

  if (client.connect()) {
    Serial.println("Connected");
  } else {
    Serial.println("There was a connection error.");
  }   
}
int a=0;
void loop() {
 
  if (a == 0){
    //sendGet("scan","411231231231A");
    sendPut("temp","41");
    a++;
  }
  //if (client.available()) {
  //    validResponse();
  //}
  if (client.available()) {
    char c = client.read();
    Serial.print(c);
  }
  
  if (!client.connected()) {
    Serial.println();
    Serial.println("disconnecting.");
    client.stop();
    for(;;)
      ;
  }
}


