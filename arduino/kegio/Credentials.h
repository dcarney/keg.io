#ifndef __CREDENTIALS_H__
#define __CREDENTIALS_H__


    #define WIFI_SSID "YOUR_SSID"
    #define WIFI_PASSPHRASE "YOUR_PASSPHRASE"
    #define KEGIO_DOMAIN "192.168.8.203"

    // Used by keg.io to send responses back the arduino
    char kegioPrefix[] = "KEGIO:";
    #define KEGIO_PREFIX_LENGTH 6
    char kegioSuffix[] = ":::";
    #define KEGIO_SUFFIX_LENGTH 3

    char clientId[] = "1111";
    uint8_t clientSecret[]={
      // s3cr3t
      0x73,0x33,0x63,0x72,0x33,0x74
    };
    int clientSecretLength = 6;

    // How often should the arduino check the temperature and report to keg.io?
    #define TEMPERATURE_SEND_INTERVAL_MS 30000

    // Set to 1 to enable verbose debugging on the serial port
    //
    // !!!NOTE!!! THIS HAS THE ABILITY TO BREAK THE SKETCH!!
    //
    // Due to the memory contstraints of the arduino microcontroller,
    // including too many string constants (and the like) can cause bizzare
    // runtime behavior.  Use of the MemoryFree lib is recommended.
    #define KEGIO_VERBOSE_DEBUGGING 0

#endif
