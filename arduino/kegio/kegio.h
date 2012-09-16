#ifndef __KEGIO_H__
#define __KEGIO_H__

  // Used by keg.io to send responses back the arduino
  char kegioPrefix[] = "KEGIO:";
  #define KEGIO_PREFIX_LENGTH 6
  char kegioSuffix[] = ":::";
  #define KEGIO_SUFFIX_LENGTH 3

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
