// keg.io v2 Arduino Code
// Written By: Carl Krauss
//

// Serial
long serialBaud = 2400;

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
String applicationPath = ap + String(clientId);
String httpParameters = "id="+ String(clientId);
char domain[] = "dev.keg.io";
WiFlyClient client(domain, 80);

// RFID reader
#include <SoftwareSerial.h>
#define rxPin 8
#define txPin 9
int rfidPin = 2;
// RFID reader SOUT pin connected to Serial RX pin at 2400bps to pin8
SoftwareSerial RFID(rxPin,txPin);
int val = 0;
char code[10];

// Regexp library to validate RFID card ID
#include <Regexp.h>

void setup() {
  Serial.begin(serialBaud);
  Serial.println("Booting...");

  // setup solenoid
/*
  pinMode(solenoid, OUTPUT);
  digitalWrite(solenoid, LOW);
  solenoidStatus = SOLENOID_CLOSED;
*/

  // setup temp sensor
  // IC Default 9 bit. If you have troubles consider upping it 12.
  // Ups the delay giving the IC more time to process the temperature measurement
  //tempSensor.begin();

  // setup flow sensor
/*
  pinMode(hallsensor, INPUT); //initializes digital pin 2 as an input
  attachInterrupt(interrupt, rpm, RISING); //and the interrupt is attached
*/

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
    //sendGet("hello", "");

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
  Serial.println("Boot complete.");
}

void loop() {
  while (true) {
/*
    // read temp value and convert to String
    char charTemp[6];
    String strTemp = String(dtostrf(getTemp(),5,2,charTemp));
    // send temp in put request
    sendPut("temp", strTemp);
*/

    // if data is available from card scanner
    if (RFID.available() > 0) {
      readTag();
      unsigned long start = millis();
      while (RFID.available() <= 1) {
        delay(10);
        if (RFID.available() > 0 && RFID.peek() == 13) {
          RFID.read();  // dump stop byte
        }
        if ((millis() - start) > 1000) {
          Serial.println("tag scan timeout");
          break;
        }
      }
      if (RFID.available() > 0) {
        if (isValidTag()) {
          digitalWrite(rfidPin, HIGH);  //deactivate RFID reader
          Serial.print("**Tag is: ");
          String strCode = String(code).substring(0,10);
          Serial.println(strCode);

          sendGet("scan", strCode);

          // wait 3 seconds for response then timeout
          unsigned long scanTime = millis();
          while ((millis() - scanTime) < 3000) {

            // if HTTP response available?
            while (client.available()) {
              char c = client.read();
              Serial.print(c);
            }
            // TODO: replace false with real logic
            if ( false ) {
              // TODO: set LED to solid green
              // open solenoid
              digitalWrite(solenoid, HIGH);
              solenoidStatus = SOLENOID_OPENED;
            }
          }
        }
      }

      RFID.flush();
      clearTag();
      delay(2000);
      digitalWrite(rfidPin, LOW);  //reactivate RFID reader
    } // end if (RFID.available())

    // if solenoid is open, send flow data
    // or if it has been open for 3 seconds with zero flow, send flow end
    // TODO: replace false with real logic
    if ( false ) { // TODO: replace false with "solenoid"
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
    // TODO: Fix this...
/*
    if (!client.connected()) {
      Serial.println("Wifi connection lost");
      client.stop();
      // TODO: set LED to flashing red
      while (true) {
        // hang on dead wifi connection
      }
    }
*/

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

void readTag() {
  if((val = RFID.read()) == 10) {   // check for header
    int bytesread = 0;
    while(bytesread<10) {              // read 10 digit code
      if( RFID.available() > 0) {
        val = RFID.read();
        if((val == 10)||(val == 13)) { // if header or stop bytes before the 10 digit reading
          break;                       // stop reading
        }
        code[bytesread] = byte(val);         // add the digit
        bytesread++;                   // ready to read next digit
      }
    }
  }
}

bool isValidTag() {
  int value;
  int bytesread = 0;
  while (RFID.available() > 0) {
    if((value = RFID.read()) == 10) {   // check for header
      int bytesread = 0;
      while(bytesread<10) {              // read 10 digit code
        if( RFID.available() > 0) {
          value = RFID.read();
          if((value == 10)||(value == 13)) { // if header or stop bytes before the 10 digit reading
            Serial.println("tag validate break");
            break;                       // stop reading
          }
          if (code[bytesread] != byte(value)) {
            Serial.println("isTagValid: Tag does not match");
            return false;
          }
          bytesread++;                   // ready to read next digit
        }
      }
      //Serial.println("isTagValid: Valid Tag");
      return true;
    }
    Serial.println("isTagValid: no header");
    return false;
  }
  Serial.println("isTagValid: no match");
  return false;
}

void clearTag() {
  for(int i=0; i<10; i++) {
    code[i] = 0;
  }
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


