// keg.io v2 Arduino Code
// Written By: Carl Krauss
//
// Header Files
#include <SPI.h>
#include <SC16IS750.h>
#include <WiFly.h>
#include <sha256.h>
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

void sendPut(char* action, char* actionValue){
    Serial.println("Connected: Sending PUT Request");
    String getHeader;
    String sig;
    String payload = "PUT " + applicationPath + "/" + action + "/" + actionValue;
    Sha256.initHmac(clientSecret,clientSecretLength);
    Sha256.print("PUT "+String(domain) + applicationPath + "/" + action + "/" + actionValue);
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

void sendGET(char* action, char* cardId){
    Serial.println("Connected: Sending GET Request");
    String getHeader;
    String sig;
    String payload = "GET " + String(applicationPath) + "/" + action +"/"+ cardId;
    Sha256.initHmac(clientSecret,clientSecretLength);
    Sha256.print("GET "+String(domain) + String(applicationPath) + "/" + action +"/"+ cardId);
    sig = getHash(Sha256.resultHmac());
    getHeader = payload + "?signature="+sig+" HTTP/1.1";
    Serial.println(getHeader);
    client.println(getHeader);
    Serial.println("Host: "+String(domain));
    client.println("Host: "+String(domain));
    client.println();
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

  /*Serial.println("connecting...");
  if (client.connect()) {
    Serial.println("connected");
  } else {
    Serial.println("connection failed");
  }*/
  //Sha256.init();
  //Sha256.print("123456789");
  //hash = Sha256.result();
  //printHash(hash);
  //Sha256.initHmac(hmacKey1,6);
  //Sha256.print("secret message!");
  //printHash(Sha256.resultHmac());
  if (client.connect()) {
    Serial.println("Connected");
  } else {
    Serial.println("There was a connection error.");
  }   
}
int a=0;
void loop() {
 
  if (a == 0){
    sendPut("temp","41");
    a++;
  }

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


