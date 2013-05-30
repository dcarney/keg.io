// keg.io!!!
#include "kegio.h"


// serial lib for use with RFID pins
#include <SoftwareSerial.h>

// Wifly and HTTP stuff
#include <SPI.h>
#include <SC16IS750.h>
#include <WiFly.h>
#include <HttpClient.h>

// hashing
#include <sha256.h>

// More keg.io stuff!! Remember, order is important with #includes
#include "credentials.h"

// OneWire temp. sensor lib
#include <OneWire.h>

// For debugging
//#include <MemoryFree.h>

#define SERIAL_BAUD 9600
#define RFID_BAUD 9600

// ASCII char codes
#define START 2
#define CR 13
#define LF 10
#define END 3

// HTTP request consts
char PATH[20] = "/api/kegerator/";

// The Arduino we're using has interrupt 0 ob digital pin 2 and interrupt 1
// on digital pin 3.  Insure that the pin assignment matches the interrupt
#define FLOW_SENSOR_INTERRUPT 1

// Arduino pins
#define TEMPERATURE_SENSOR_PIN 4
#define FLOW_SENSOR_PIN 3
#define SOFT_SERIAL_RX_PIN 2
//#define SOFT_SERIAL_TX_PIN 4
#define BEEP_PIN 6
#define SOLENOID_PIN 5
#define RFID_RESET_PIN 7
#define RED_PIN 8
#define BLUE_PIN 9
#define GREEN_PIN 10
#define OVERRIDE_PIN A0

// Status LED colors
#define BLUE 0
#define RED 1
#define PURPLE 2
#define GREEN 3
#define OFF 4
int led = 13; // Pin 13 has an LED connected on most Arduino boards.

#define BEEP_HZ_LO 440
#define BEEP_HZ_MID 550
#define BEEP_HZ_HI 660

// measures the rising edges of the flow sensor's interrupt signal
volatile int numFlowInterrupts;

// vars for reading tag/temp/flow values
char tagBuffer[13];
char temperatureBuffer[4];
char flowBuffer[4];

int inByte = 0;

// Temp sensor stuff
// Temp sensor (DS18S20) signal pin on digital 2
// Analog TMP36 on analog pin 0
#define TEMP_SENSOR_ERROR -1000 // Used by the OneWire sensor
unsigned long lastTemperatureMs = 0;

unsigned long solenoidOpenMs = 0;
float totalFlow = 0.0;
unsigned long lastFlowMillis = 0;
unsigned long lastHttpOkMs = 0;
unsigned long lastHttpAttemptMs = 0;

// For the onewire temp sensor:
OneWire ds(TEMPERATURE_SENSOR_PIN);

// Time between allowed scans - prevents double and triple scans from
// being read each time a card is near.  By starting lastRfidMs at the duration,
// we allow the first scan to happen immediately
#define RFID_DURATION_MS 2000
unsigned long lastRfidMs = RFID_DURATION_MS;

// Create a software serial port, to keep the real RX and TX pins free
SoftwareSerial rfidSerial(SOFT_SERIAL_RX_PIN, 0);

// Create WiFly client and our own HTTP client
WiFlyClient client(KEGIO_DOMAIN, KEGIO_PORT);
HttpClient http = HttpClient(client);

// the setup routine runs once when you press reset:
void setup() {

  // build the full path to the kegerator, using the credentials.h info
  strlcat(PATH, clientId, sizeof(PATH));

  pinMode(led, OUTPUT);
  pinMode(FLOW_SENSOR_PIN, INPUT);
  attachInterrupt(FLOW_SENSOR_INTERRUPT, onFlowSensorInterrupt, RISING);
  pinMode(RED_PIN, OUTPUT);
  pinMode(BLUE_PIN, OUTPUT);
  pinMode(GREEN_PIN, OUTPUT);
  pinMode(RFID_RESET_PIN, OUTPUT);
  pinMode(BEEP_PIN, OUTPUT);
  pinMode(SOLENOID_PIN, OUTPUT);
  pinMode(OVERRIDE_PIN,INPUT);

  digitalWrite(RED_PIN, LOW);
  digitalWrite(GREEN_PIN, LOW);
  digitalWrite(BLUE_PIN, LOW);
  digitalWrite(OVERRIDE_PIN, LOW);
  
  Serial.begin(SERIAL_BAUD);
  rfidSerial.begin(SERIAL_BAUD);

  Serial.println("booting..");
  Serial.println(PATH);

  lastTemperatureMs = millis();

  // Show red while booting
  ledStatus(OFF, 1000);
  ledStatus(BLUE);

  // Set up RFID
  #if KEGIO_VERBOSE_DEBUGGING
  Serial.println("init RFID..");
  #endif
  digitalWrite(RFID_RESET_PIN, HIGH);

  // wifly!
  SC16IS750.begin();
  WiFly.setUart(&SC16IS750);
  #if KEGIO_VERBOSE_DEBUGGING
  Serial.println("init wifly..");
  #endif
  WiFly.begin();

  #if KEGIO_VERBOSE_DEBUGGING
  Serial.println("join wifi network..");
  #endif

  if (!WiFly.join(WIFI_SSID, WIFI_PASSPHRASE)) {
    #if KEGIO_VERBOSE_DEBUGGING
    Serial.println("association failed");
    #endif
    client.stop();
    tone(BEEP_PIN, BEEP_HZ_MID, 250); // 550hz for 250ms
    delay(250);
    tone(BEEP_PIN, BEEP_HZ_LO, 250); // 440hz for 250ms
    while (1) {
      ledStatus(RED, 500);
      ledStatus(OFF, 500);
      // Hang on failure.
    }
  }
  else {
    #if KEGIO_VERBOSE_DEBUGGING
    Serial.println("wifi connected");
    Serial.println("client request..");
    #endif

    if (client.connect()) {
      // hello out there...
      sendHttp("GET", "/hello");
      tone(BEEP_PIN, BEEP_HZ_MID, 250);
      delay(250);
      tone(BEEP_PIN, BEEP_HZ_HI, 250);
    }
  }

  lastHttpOkMs = millis();
}

// The signed HTTP requests that we actually care about
#define INVALID_MSG -1
#define SCAN_MSG 0
#define TEMP_MSG 1
#define FLOW_MSG 2
int lastHttpReqAction = INVALID_MSG;
int isOverride = LOW;

// the loop routine runs over and over again forever:
void loop() {
  isOverride = digitalRead(OVERRIDE_PIN);
  // If there are a few bytes waiting on the WiFly shield...
  // If there's less than 4, chances are we don't want to parse just yet
  // HTTP/1.1 200 OK
   if (client.available()) {

    // Wait 100ms.  We want to give the rest of the msg a chance to arrive in
    // the buffer.  If we read too quickly, we won't find/parse the entire msg
    // delay(100);
    // ACTUALLY, if we wait, too long, the 64 byte (?) buffer will fill up
    int responseCode = http.getResponseStatusCode();
    http.readRemainingResponse();

    // Track the last time we successfully contacted the server via HTTP
    if (responseCode == 200) {
      lastHttpOkMs = millis();
      ledStatus(GREEN);
    }

    if (((lastHttpReqAction == SCAN_MSG) && (responseCode == 200))) {
      solenoidOpenMs = millis();
      lastFlowMillis = solenoidOpenMs;
      totalFlow = 0.0;
      digitalWrite(SOLENOID_PIN, HIGH);
    }
  }
  
  if ((isOverride == HIGH) && solenoidOpenMs == 0) {
    tone(BEEP_PIN, BEEP_HZ_HI, 250);
    delay(250);
    tone(BEEP_PIN, BEEP_HZ_LO, 750);
    solenoidOpenMs = millis();
    lastFlowMillis = solenoidOpenMs;
    totalFlow = 0.0;
    //sendSignedHttp("GET", SCAN_MSG, "000000");
    digitalWrite(SOLENOID_PIN, HIGH);
  }
  
  if(digitalRead(OVERRIDE_PIN)==HIGH){
   //Serial.println("OVR ON"); 
  }

  // If it's time to close the solenoid (and it was open)
  if ((solenoidOpenMs > 0) &&
      (millis() - solenoidOpenMs) > SOLENOID_OPEN_DURATION_MS && isOverride == LOW) {
    digitalWrite(SOLENOID_PIN, LOW);
    solenoidOpenMs = 0;
    lastFlowMillis = 0;
    totalFlow = totalFlow * FLOW_METER_COEFFICIENT; // correction
    // multiply by 100 so we don't lose too much precision when truncating to an int
    totalFlow = totalFlow * 100.0;
    sendSignedHttp("PUT", FLOW_MSG, itoa((int)totalFlow, flowBuffer, 10));
    totalFlow = 0.0;
  } else if (solenoidOpenMs > 0) {
    // solenoid is open.  sample the flow rate for 1 second
    numFlowInterrupts = 0;

    //interrupts();   // Enable interrupts
    delay (1000);   // Wait 1 second
    //noInterrupts(); // Disable interrupts

    // flow rate in L/hr
    float flowRate = ((float) numFlowInterrupts * 60) / 7.5;

    // 1 L = 33.814022702 fl oz
    // 1 L/hr  = 0.00000939278408 US fluid ounces per millisecond
    // 1 L/min = 0.000563567045 US fluid ounces per millisecond
    flowRate = flowRate * 0.00000939278408;

    Serial.print(flowRate, DEC);
    Serial.print(" oz/sec at ");
    totalFlow = totalFlow + (flowRate * (millis() - lastFlowMillis));
    lastFlowMillis = millis();
    Serial.println(lastFlowMillis);
    Serial.print("total flow:");
    Serial.println(totalFlow, DEC);
  }

  // memory debugging
  // Serial.print("mem:");
  // Serial.println( freeMemory() );

  // If it's time to send a temperature update...
  if ((millis() - lastTemperatureMs) > TEMPERATURE_SEND_INTERVAL_MS && solenoidOpenMs == 0) {
    float temperature = (getTemp()*1.8)+32;
    if ((temperature >= 0.0) && (temperature <= 120.0)) {
      // Anything outside this range is garbage, plus we're only allocating
      // enough room for 3 chars (e.g. 3 digit integer temp)
      sendSignedHttp("PUT", TEMP_MSG, itoa((int)temperature, temperatureBuffer, 10));
      clearBuffer(temperatureBuffer);
      delay(150);  // it works for the resetRfidReader() case....
    }

    lastTemperatureMs = millis();
  }

  if ((millis() - lastHttpOkMs) > WIFLY_RESET_INTERVAL_MS) {
    if (millis() - lastHttpAttemptMs > WIFLY_RESET_ATTEMPT_INTERVAL_MS) {
      lastHttpAttemptMs = millis();
      // attempt a reconnect
      ledStatus(PURPLE);
      Serial.println("reconnecting");
      client.flush();
      client.stop();
      if (client.connect()) {
        Serial.println("reconnected");
      }
    }
  }

  // if there's a byte waiting to be read on the RFID serial port...
  if (isOverride == LOW && ((millis() - lastRfidMs) > RFID_DURATION_MS) && (rfidSerial.available() > 1)) {
    readTag3();
    if (checkTag(tagBuffer)) {
       // 440hz for 250ms
      Serial.println(tagBuffer);
      sendSignedHttp("GET", SCAN_MSG, tagBuffer);
    } else {
      Serial.println("Invalid tag");
    }
    clearBuffer2(tagBuffer, 12);
    resetRfidReader();
    lastRfidMs = millis();
  } else if (rfidSerial.available() > 0) {
    // There's data waiting on the RFID serial, but it's not time to read it yet
    while(rfidSerial.available()) {
      rfidSerial.read();
    }
    resetRfidReader();
  }

} // loop

// interrupt handler
void onFlowSensorInterrupt() {
  numFlowInterrupts++;
}

// Set the status LED to the specified color, and leave it that way
void ledStatus(int color) {
  switch (color) {
    case RED:
      digitalWrite(RED_PIN, HIGH);
      digitalWrite(BLUE_PIN, LOW);
      digitalWrite(GREEN_PIN, LOW);
      break;
    case BLUE:
      digitalWrite(RED_PIN, LOW);
      digitalWrite(BLUE_PIN, HIGH);
      digitalWrite(GREEN_PIN, LOW);
      break;
    case PURPLE:
      digitalWrite(RED_PIN, HIGH);
      digitalWrite(BLUE_PIN, HIGH);
      digitalWrite(GREEN_PIN, LOW);
      break;
    case GREEN:
      digitalWrite(RED_PIN, LOW);
      digitalWrite(BLUE_PIN, LOW);
      digitalWrite(GREEN_PIN, HIGH);
      break;
    case OFF:
      digitalWrite(RED_PIN, LOW);
      digitalWrite(BLUE_PIN, LOW);
      digitalWrite(GREEN_PIN, LOW);
      break;
    default:
      // invalid color!
      break;
  }
}

// Set the status LED to the specified color, then delay for 'duration' ms
// before returning
void ledStatus(int color, int durationInMs) {
  ledStatus(color);
  delay(durationInMs);
}

// reads an RFID tag into the contents of tagBuffer
// A valid tag message should contain a header char, 10 digits, then an optional header char
// <START><12 hex bytes><LF><CR><END>
//
// returns true if a valid tag msg was recieved, false otherwise
bool readTag() {
  if ((inByte = rfidSerial.read()) == START) {
    //Serial.println("Yeah, fill that 12-char buffer.....");
    int bytesRead = 0;
    while (bytesRead < sizeof(tagBuffer) - 1) {   // read 12 hex bytes
      if (rfidSerial.available() > 0) {
        inByte = rfidSerial.read();
        if ((inByte == CR)   || (inByte == LF)  ||
            (inByte == START) || (inByte == END)) { //|| (!byteIsHex(inByte))) {
          // We haven't read an entire tag yet...
          //Serial.println("ppop");
          return false;
        }
        tagBuffer[bytesRead] = byte(inByte);
        bytesRead++;
      }
    }
    // null-terminate the 'string' with the last remaining byte
    tagBuffer[bytesRead] = '\0';
    return true;
  }
  Serial.println("yyyy");
  return false;
}

void readTag3() {
  int index = 0;
  boolean reading = false;
  while(rfidSerial.available()){

    int readByte = rfidSerial.read(); //read next available byte

    if(readByte == 2) reading = true; //begining of tag
    if(readByte == 3) reading = false; //end of tag

    if(reading && readByte != 2 && readByte != 10 && readByte != 13){
      //store the tag
      tagBuffer[index] = readByte;
      index++;
    }
  }
}

boolean readHttpResponse(char* destBuffer, int destBufferLen) {
  int prefixBytesSeen = 0;
  int index = 0;
  int readingSection = 0;   // 0 = nothing, 1 = prefix, 2 = body, 3 = suffix
  //#if KEGIO_VERBOSE_DEBUGGING
  Serial.println("Read HTTP res..");
  //#endif
  while (client.available() && index < destBufferLen) {
    char readByte = client.read();
    Serial.print(readByte);

    if ((readingSection == 0) && (readByte == kegioPrefix[0])) {
      readingSection = 1; // beginning of prefix
      prefixBytesSeen++;
      continue;
    }

    if (readingSection == 1) {
      if (readByte == kegioPrefix[prefixBytesSeen]) {
        prefixBytesSeen++; // all good so far
      }
      else {
        // Invalid prefix sequence.  reset.
        readingSection = 0;
        prefixBytesSeen = 0;
      }

      if (prefixBytesSeen == KEGIO_PREFIX_LENGTH) {
         // Prefix complete, now start reading the data
        Serial.println("prefix done");
        readingSection = 2;
      }
      continue;
    }

    if (readingSection == 2) {
      destBuffer[index] = readByte;
      index++;
    }
  } // while
/*
  // Check that the shit in teh destBuffer is a valid message.
  int suffixBytesSeen = 0;
  Serial.println("examin msg..");
  Serial.print(destBuffer);
  for(int i=0; i < destBufferLen - 1; i++) {
    if (destBuffer[i] == kegioSuffix[suffixBytesSeen]) {
      suffixBytesSeen++;

      if (suffixBytesSeen == KEGIO_SUFFIX_LENGTH) {
        // Suffix complete!
        // Somehow, printing this line causes the next HTTP sig to be invalid (truncated).
        // Yes, really.
        //#if KEGIO_VERBOSE_DEBUGGING
        Serial.println("msg complete");

        // TODO: should we enfore a lower case here?
        //destBuffer will be something like: temp:79::: or scan:5100ffed286b:::

        //char* actionStr = getHttpActionStr(lastHttpReqAction);
        //if (strncmp(destBuffer, actionStr, strlen(actionStr)) == 0) {
        //  Serial.println("msg valid");
       // }

        Serial.println(destBuffer);
        //#endif
        clearBuffer2(destBuffer, 63);
        Serial.println(destBuffer);
        return true;
      }
    }
  }

  //Serial.print(destBuffer);
  clearBuffer2(destBuffer, 64);
  Serial.print(destBuffer);
  */
  return false;
}

void readWiflyBytes(char * destBuffer, int numBytesToRead, int offset) {
  while (numBytesToRead != 0 && client.available()) {
    destBuffer[offset] = client.read();
    offset++;
    numBytesToRead--;
  }
}

void readSerialBytes(char * destBuffer, int numBytesToRead, int offset) {
  while (numBytesToRead != 0) {
    destBuffer[offset] = Serial.read();
    offset++;
    numBytesToRead--;
  }
}

boolean checkTag(char tag[]){
///////////////////////////////////
//Check the read tag against known tags
///////////////////////////////////
  if(strlen(tag) == 0) { return false; }
  Serial.println(tag);
  //if (compareTag("5100FFED286B", tag) || compareTag("44004C5FC295", tag)) { return true; }
  return (strlen(tag) == 12);
  //return false;
}

boolean compareTag(char one[], char two[]){
///////////////////////////////////
// compare two value to see if same,
// strcmp not working 100% so we do this
///////////////////////////////////

  if(strlen(one) == 0) { return false; }//empty

  for(int i = 0; i < 12; i++) {
    if(one[i] != two[i]) return false;
  }

  return true; //no mismatches
}

// zeroes out the char[] used to store the scanned card ID
void clearBuffer(char buffer[]) {
  //for(int i=0; i<sizeof(buffer); i++) { buffer[i] = 0; }
  memset(&buffer, 0, sizeof(buffer));
}

void clearBuffer2(char buffer[], int bufferLen) {
  for(int i = 0; i < bufferLen; i++) { buffer[i] = 0; }
}

void clearBuffer3(char buffer[], int bufferLen) {
  memset(&buffer, 0, bufferLen);
}

// Reset the RFID reader to read again
void resetRfidReader(){
  digitalWrite(RFID_RESET_PIN, LOW);
  digitalWrite(RFID_RESET_PIN, HIGH);
  delay(150);
}

// Sends a plain-jane, unsigned HTTP request
// Example:
// GET /search?q=arduino HTTP/1.0
void sendHttp(char* httpMethod, char* path) {
  #if KEGIO_VERBOSE_DEBUGGING
  Serial.print("Send HTTP req...");
  Serial.println(httpMethod);
  #endif

  // lower case these values
  //lower(action);
  //lower(actionValue);

  char httpStr[128];  // If this isn't big enough, the request will obviously fail
  strlcpy(httpStr, httpMethod, sizeof(httpStr));
  strlcat(httpStr, " ", sizeof(httpStr));
  strlcat(httpStr, path, sizeof(httpStr));

  // now write to wifly client and output to Serial
  #if KEGIO_VERBOSE_DEBUGGING
  //Serial.print(httpStr);
  //Serial.println(" HTTP/1.1");
  //Serial.print("Host: ");
  //Serial.println(KEGIO_DOMAIN);
  //Serial.println("Connection: keep-alive");
  //Serial.println();
  #endif

  client.print(httpStr);
  client.println(" HTTP/1.1");
  client.print("Host: ");
  client.println(KEGIO_DOMAIN);
  client.println("Connection: keep-alive");
  client.println();

  http.setState(HttpClient::eRequestSent);
  clearBuffer(httpStr);
}

char* getHttpActionStr(int action) {
  // This MUST be lowercase, for the sig to be correct
  char* actionStr = "";
  switch (action) {
    case TEMP_MSG:
      actionStr = "temp";
      break;
    case SCAN_MSG:
      actionStr = "scan";
      break;
    case FLOW_MSG:
      actionStr = "flow";
      break;
    default:
      break;
  }

  return actionStr;
}

// Send HTTP request with HmacSha256 signature
void sendSignedHttp(char* httpMethod, int action, char* actionValue) {

  #if KEGIO_VERBOSE_DEBUGGING
  Serial.print("send signed HTTP req..");
  #endif

  char* actionStr = getHttpActionStr(action);

  // lower case these values
  //lower(action);
  lower(actionValue);

  char httpStr[128];  // If this isn't big enough, the signature will be invalid
  strlcpy(httpStr, httpMethod, sizeof(httpStr));
  strlcat(httpStr, " ", sizeof(httpStr));
  strlcat(httpStr, KEGIO_DOMAIN, sizeof(httpStr));
  strlcat(httpStr, PATH, sizeof(httpStr));
  strlcat(httpStr, "/", sizeof(httpStr));
  strlcat(httpStr, actionStr, sizeof(httpStr));
  strlcat(httpStr, "/", sizeof(httpStr));
  strlcat(httpStr, actionValue, sizeof(httpStr));

  Serial.println(httpStr);

  char sig[65]; // 64 bytes plus null string termination byte
  for(int i =0; i<65; i++) {sig[i] = 0;}
  calcHash(clientSecret, clientSecretLength, httpStr, sig);
  Serial.println(sig);

  strlcpy(httpStr, httpMethod, sizeof(httpStr));
  strlcat(httpStr, " ", sizeof(httpStr));
  strlcat(httpStr, PATH, sizeof(httpStr));
  strlcat(httpStr, "/", sizeof(httpStr));
  strlcat(httpStr, actionStr, sizeof(httpStr));
  strlcat(httpStr, "/", sizeof(httpStr));
  strlcat(httpStr, actionValue, sizeof(httpStr));

  #if KEGIO_VERBOSE_DEBUGGING
  Serial.print(httpStr);
  Serial.print("?signature=");
  Serial.print(sig);
  Serial.println(" HTTP/1.1");
  Serial.print("Host: ");
  Serial.println(KEGIO_DOMAIN);
  Serial.println("Connection: keep-alive");
  Serial.println();
  #endif

  // now write to wifly client
  client.print(httpStr);
  client.print("?signature=");
  client.print(sig);
  client.println(" HTTP/1.1");
  client.print("Host: ");
  client.println(KEGIO_DOMAIN);
  client.println("Connection: keep-alive");
  client.println();

  // track the last request made, so we know whether the response is legit
  lastHttpReqAction = action;
  http.setState(HttpClient::eRequestSent);

  clearBuffer(httpStr);
  clearBuffer(sig);
}

// converts a string to its lowercase equivalent
void lower(char str[]) {
  for (int i = 0; i < strlen(str); i++) {
    str[i] = tolower(str[i]);
  }
}

// Calculate and put a HmacSha256 hash in sig[] parameter
void calcHash(uint8_t secret[], int secretLength, char str[], char sig[]) {
  // TODO: Do we really need to do this init every time?
  Sha256.initHmac(secret, secretLength);
  Sha256.print(str);
  getHash2(Sha256.resultHmac(), sig);
}

void getHash2(uint8_t* hash, char sig[]) {
  int i;
  for (i=0; i<32; i++) {
    byteToChars(hash[i], &sig[i*2]);
  }
}

// TODO: This multi-purpose fn from kegbot could be used to replace the getHash
// mystery fn (that uses the String lib)
// Converts a single hex byte to 2 ascii chars that represent the byte
// Same as getHash method above, but without the String lib
void byteToChars(uint8_t byte, char* out) {
  for (int i=0; i<2; i++) {
    uint8_t val = (byte >> (4*i)) & 0xf;
    if (val < 10) {
      out[1-i] = (char) ('0' + val);
    } else if (val < 16) {
      out[1-i] = (char) ('a' + (val - 10));
    }
  }
}


//For the OneWire temp. sensor:
float getTemp(){
  //returns the temperature from one DS18S20 in DEG Celsius
  byte data[12];
  byte addr[8];

  if ( !ds.search(addr)) {
      //no more sensors on chain, reset search
      ds.reset_search();
      return TEMP_SENSOR_ERROR;
  }

// this next if statement has caused issues
// if temp readings + scan causes garbled scans and the board to reboot
// try removing it
//  if ( OneWire::crc8( addr, 7) != addr[7]) {
 //     Serial.println("Temp sensor CRC is not valid!");
//      return TEMP_SENSOR_ERROR;
//  }

  if ( addr[0] != 0x10 && addr[0] != 0x28) {
      Serial.print("Temp sensor device is not recognized");
      return TEMP_SENSOR_ERROR;
  }

  ds.reset();
  ds.select(addr);
  ds.write(0x44,1); // start conversion, with parasite power on at the end

  byte present = ds.reset();
  ds.select(addr);
  ds.write(0xBE); // Read Scratchpad

  for (int i = 0; i < 9; i++) { // we need 9 bytes
    data[i] = ds.read();
  }

  ds.reset_search();

  byte MSB = data[1];
  byte LSB = data[0];

  float tempRead = ((MSB << 8) | LSB); //using two's compliment
  float TemperatureSum = tempRead / 16;

  return TemperatureSum;
}

