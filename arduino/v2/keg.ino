// keg.io v2 Arduino Code
// Written By: Carl Krauss
//

// Serial
long serialBaud = 115200L;

// Solenoid
int solenoid = 2; //Solenoid Pin
#define SOLENOID_OPENED 1
#define SOLENOID_CLOSED 0
int solenoidStatus;

// Temp sensor
#include <OneWire.h>
#include <DallasTemperature.h>
// Data wire is plugged into pin 2 on the Arduino
#define ONE_WIRE_BUS 9
float temp = 0;
// Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
OneWire oneWire(ONE_WIRE_BUS);
// Pass our oneWire reference to Dallas Temperature.
DallasTemperature tempSensor(&oneWire);
long PreviousTempMillis = 0;
long TempInterval = 5000; //how often to send temp

// Flow sensor
volatile int NbTopsFan;
int Calc;
int hallsensor = 3;
int interrupt = 1;

// Wifly and HTTP stuff
#include <SPI.h>
#include <SC16IS750.h>
#include <WiFly.h>
#include "Credentials.h"
#include <sha256.h>
String ap = "/api/kegerator/";
String applicationPath = ap+clientId;
String httpParameters = "id="+ String(clientId);
char domain[] = "dev.keg.io";
WiFlyClient client(domain, 80);

// RFID reader
#include <SoftwareSerial.h>
int rxPin = 12;
int txPin = 10;
int rfidPin = 11;
SoftwareSerial RFID(rxPin,txPin);

// Regexp library to validate RFID card ID
#include <Regexp.h>

void setup() {
  Serial.begin(serialBaud);

  // setup solenoid
  pinMode(solenoid, OUTPUT);
  digitalWrite(solenoid, LOW);
  solenoidStatus = SOLENOID_CLOSED;

  // setup temp sensor
  // IC Default 9 bit. If you have troubles consider upping it 12.
  // Ups the delay giving the IC more time to process the temperature measurement
  tempSensor.begin();

  // setup flow sensor
  pinMode(hallsensor, INPUT); //initializes digital pin 2 as an input
  attachInterrupt(interrupt, rpm, RISING); //and the interrupt is attached

  //wifly!
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
      // now setup and start listening to RFID reader since we know we have
      // an active internet connection and can verify RFID cards
      pinMode(rfidPin,OUTPUT);
      digitalWrite(rfidPin, LOW);
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
    // read temp value and convert to String
    char charTemp[6];
    String strTemp = String(dtostrf(getTemp(),5,2,charTemp));
    // send temp in put request
    sendPut("temp", strTemp);

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
            // open solenoid
            digitalWrite(solenoid, HIGH);
            solenoidStatus = SOLENOID_OPENED;
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
    if ( solenoidStatus ) { // TODO: replace false with real logic
      // TODO: read flow value
      if ( false/* flow value is zero for > 3 seconds */ ) { // TODO: replace false with real logic
        // close solenoid
        digitalWrite(solenoid, LOW);
        solenoidStatus = SOLENOID_CLOSED;
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

/*******************************
 *
 * HELPER FUNCTIONS
 *
 *******************************/

// Read the current temperature, convert to F, and return it as a Float
// Temp library from http://milesburton.com/Main_Page?title=Dallas_Temperature_Control_Library
// OneWire library from http://www.pjrc.com/teensy/td_libs_OneWire.html
float getTemp() {
  Serial.print("Requesting temperatures...");
  tempSensor.requestTemperatures(); // Send the command to get temperatures

  Serial.print("Temperature for Device 1 is: ");
  // Why "byIndex"? You can have more than one IC on the same bus. 0 refers to the first IC on the wire
  temp = tempSensor.getTempCByIndex(0);
  temp = temp*1.8+32; // comment this line out to get celsius
  Serial.println(temp);

  return temp;
}

// Print hash out to Serial as hex values
// This is for debugging only.
void printHash(uint8_t* hash) {
  int i;
  for (i=0; i<32; i++) {
    Serial.print("0123456789abcdef"[hash[i]>>4]);
    Serial.print("0123456789abcdef"[hash[i]&0xf]);
  }
  Serial.println();
}

// Return hash as String of hex values
String getHash(uint8_t* hash){
  String stringOne;
  int i;
  for (i=0; i<32; i++) {
    stringOne+=("0123456789abcdef"[hash[i]>>4]);
    stringOne+=("0123456789abcdef"[hash[i]&0xf]);
  }
  return stringOne;
}

// Send HTTP PUT request with HmacSha256 signature
void sendPut(String action, String actionValue){
  sendHttp("PUT", action, actionValue);
}

// Send HTTP GET request with HmacSha256 signature
void sendGet(String action, String cardId){
  sendHttp("GET", action, cardId);
}

void sendHttp(String httpMethod, String action, String actionValue) {
  Serial.println("Connected: Sending " + httpMethod + " Request");
  action.toLowerCase();
  actionValue.toLowerCase();
  String valueToHash = httpMethod + " " + domain + applicationPath + "/" + action + "/" + actionValue;
  String sig = calcHash(clientSecret, clientSecretLength, valueToHash);
  String requestPath = httpMethod + " " + applicationPath + "/" + action + "/" + actionValue;

  // now write to wifly client and output to Serial
  client.println(requestPath + "?signature=" + sig + " HTTP/1.1");
  Serial.println(requestPath + "?signature=" + sig + " HTTP/1.1");
  client.println("Host: " + String(domain));
  Serial.println("Host: " + String(domain));
  client.println("Connection: close");
  Serial.println("Connection: close");
  client.println();
}

// Calculate and return a HmacSha256 hash as a String
String calcHash(uint8_t secret[], int secretLength, String str) {
  Sha256.initHmac(secret, secretLength);
  Sha256.print(str);
  return getHash(Sha256.resultHmac());
}

//This is the function that the interupt calls
//This function measures the rising and falling edge of the hall effect sensors signal
void rpm (){
  NbTopsFan++;
}




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


