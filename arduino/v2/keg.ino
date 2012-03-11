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
#include <SoftwareSerial.h>

// Globl Variable Definitions
String ap = "/api/kegerator/";
String applicationPath = ap+clientId;
String httpParameters = "id="+ String(clientId);
char domain[] = "dev.keg.io";

WiFlyClient client(domain, 80);

// Global variables for RFID reader
int rxPin = 12;
int txPin = 10;
SoftwareSerial RFID(rxPin,txPin);


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
    client.println("Connection: close");
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

void setup() {
  //Setup variables
  Serial.begin(115200);
  SC16IS750.begin();
  WiFly.setUart(&SC16IS750);
  WiFly.begin();

  if (!WiFly.join(ssid, passphrase)) {
    Serial.println("Association failed.");
    client.stop();
    // TODO: set LED to flash red continuously
    while (1) {
      // Hang on failure.
    }
  }

  if (client.connect()) {
    // TODO: make test request to keg.io
    // sendGet("ping", "1");

    // if test request was successful
    if ( true/* test keg.io request returned with 200 */ ) { // TODO: replace false with real logic
      Serial.println("Connected");
      // TODO: set LED to solid red
      // now start listening to RFID reader since we know we have an active internet connection
      RFID.begin(2400);
    } else {
      Serial.println("Connected to wifi, but unable to contact server.");
      client.stop();
      // TODO: set LED to flash red continuously
    }

  } else {
    Serial.println("Unable to connect to wifi.");
    client.stop();
    // TODO: set LED to flash red continuously
  }
}

void loop() {
  while (true) {
    // if there is a temp value
    if (false) { // TODO: replace false with real logic
      // TODO: read temp value
      // send temp in put request
      sendPut("temp", "43");
    }

    // if data is available from card scanner
    if (RFID.available()) {
      // then read rfid
      // TODO: this needs to be turned in to a loop that constructs the char[]
      char rfid[ ] = "44004C3A1A";//RFID.read();

      // if rfid is invalid length, ignore rfid
      // note that 11 is the valid length because the char[] needs to be terminated with a null byte
      if (sizeof(rfid) != 11) {
        Serial.println("bad rfid");
        // TODO: make LED turn off for 1 sec then back to red
        // restart main while loop
        continue;
      }

      // create a regexp object
      MatchState ms;
      // create buffer to work in
      char buf [22];  // large enough to hold expected string, or malloc it
      ms.Target (rfid);  // string to test with regexp

      // test char[] against "(%x+)" regexp starting at index 0 in char[]
      char result = ms.Match("(%x+)", 0);

      // if char[] is valid hex characters
      if (result == REGEXP_MATCHED) {

        // get the first string of hex characters that matched
        String validRfid = String(ms.GetCapture(buf, 0));
        sendGet("scan", validRfid);  // send get scan request

        // wait 3 seconds for response then timeout
        unsigned long scanTime = millis();
        unsigned long now = millis();
        while ((now - scanTime) < 3000) {
          // clear any other extraneous incoming RFID data
          RFID.flush();

          // if HTTP response available?
          String response = "";
          while (client.available()) {
            response += client.read();
          }
          // TODO: replace false with real logic
          if ( false/*response is not empty && status code is 200 && response hash is good*/ ) {
            // TODO: set LED to solid green
            // TODO: open solenoid
          }
        }
      } else if (result == REGEXP_NOMATCH) {
        Serial.println("Bad RFID");
        // TODO: make LED turn off for 1 sec then back to red
      } else {
        Serial.print("Regex error parsing RFID: ");
        Serial.println(result, DEC);
        // TODO: make LED turn off for 1 sec then back to red
      }
    } // end if (RFID.available())

    // if solenoid is open, send flow data
    // or if it has been open for 3 seconds with zero flow, send flow end
    // TODO: replace false with real logic
    if ( false/* solenoid is open? */ ) { // TODO: replace false with real logic
      // TODO: read flow value
      if ( false/* flow value is zero for > 3 seconds */ ) { // TODO: replace false with real logic
        // TODO: close solenoid
        // tell server pour is done
        sendGet("flow", "end");
        // TODO: set LED to solid red
      } else if ( false/* flow value > 0 */ ) { // TODO: replace false with real logic
        // TODO: send flow value every second
      }
    }

    // if wifi connection is lost
    if (!client.connected()) {
      Serial.println("Wifi connection lost");
      client.stop();
      // TODO: set LED to flashing red
      while (true) {
        // hang on dead wifi connection
      }
    }

  } // end while(true)
} // end void loop()






/******************
   NOTES AND SHIT
*******************/
/*
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
*/


