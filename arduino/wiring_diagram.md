ARDUINO WIRING REFERENCE
=======================================

      D0 (RX) ---------------> RFID 9 (data)
      D1 (TX)
      D2      ---------------> temp signal (middle)
      D3
      D4
      D5
      D6
      D7      --> 180 ohm ---> RGB LED red
      D8      --> 100 ohm ---> RGB LED blu
      D9
      D10
      D11
      D12
      D13     ---------------> RFID 2 (reset)
      AREF
      A0

      GND     ---------------> temp gnd
              |--------------> RFID 7
              |--------------> RFID 1
              |--------------> RGB LED gnd

      +5V     --> 4.7k ohm --> temp signal (middle)
              |--------------> temp power
              |--------------> RFID 11