#ifndef __KEGIO_H__
#define __KEGIO_H__

  // Used by keg.io to send responses back the arduino
  char kegioPrefix[] = "KEGIO:";
  #define KEGIO_PREFIX_LENGTH 6
  char kegioSuffix[] = ":::";
  #define KEGIO_SUFFIX_LENGTH 3

  // How long can we go without an HTTP 200 before re-initializing the
  // wifly http client? (and thus the TCP connection)
  //
  // Obviously, this value is tied to how often you're sending regular updates
  // to the server (mostly likely with temperatures); see below...
  #define WIFLY_RESET_INTERVAL_MS 21000

  // How often should we attempt a reset of the wifly http client if the
  // above interval is exceeded?  This should be frequent enough to be
  // responsive, but not so frequent that a successful reconnect isn't thwarted
  // by an another reconnection attempt. Between 5s and 10s seems to work well.
  #define WIFLY_RESET_ATTEMPT_INTERVAL_MS 9000

  // How often should the arduino check the temperature and report to keg.io?
  // This interval not only serves to send temperature info to the server, but
  // also as a "status heartbeat"
  #define TEMPERATURE_SEND_INTERVAL_MS 10000

  // How long should the solenoid stay open per scan?  This depends on the flow
  // rate that your particular setup is providing, and personal perference
  #define SOLENOID_OPEN_DURATION_MS 18000

  // correction factor to compensate for various
  // flow meter setups/calibrations
  #define FLOW_METER_COEFFICIENT 4.0

  // Set to 1 to enable verbose debugging on the serial port
  //
  // !!!NOTE!!! THIS HAS THE ABILITY TO BREAK THE SKETCH!!
  //
  // Due to the memory constraints of the arduino microcontroller,
  // including too many string constants (and the like) can cause bizzare
  // runtime behavior.  Use of the MemoryFree lib is recommended.
  #define KEGIO_VERBOSE_DEBUGGING 0

#endif
