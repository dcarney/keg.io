#ifndef __HTTP_CLIENT_H__
#define __HTTP_CLIENT_H__

#include <Arduino.h>
#include "WiFlyClient.h"

static const int HTTP_ERROR_API =-2;
static const int HTTP_ERROR_TIMED_OUT =-3;
static const int HTTP_ERROR_INVALID_RESPONSE =-4;

class HttpClient {
public:
  HttpClient(WiFlyClient& aClient);

  typedef enum {
    eIdle,
    eRequestStarted,
    eRequestSent,
    eReadingStatusCode,
    eStatusCodeRead,
    eReadingContentLength,
    eSkipToEndOfHeader,
    eLineStartingCRFound,
    eReadingBody
  } tHttpState;

  // Number of ms that we wait each time there isn't any data
  // available to be read (during status code and header processing)
  static const int kHttpWaitForDataDelay = 100;

  // Number of milliseconds that we'll wait in total without receieving any
  // data before returning HTTP_ERROR_TIMED_OUT (during status code and header
  // processing)
  static const int kHttpResponseTimeout = 10*1000;

  // Number of milliseconds to wait without receiving any data before we give up
  static const int kNetworkTimeout = 10*1000;

  // Number of ms to wait if no data is available before trying again
  static const int kNetworkDelay = 100;

  void setState(tHttpState state);
  int getResponseStatusCode();
  void readRemainingResponse();

protected:
  void resetState();

  // The WiFly client obj
  WiFlyClient * _client;

  // Current state of the finite-state-machine
  tHttpState iState;

  int iStatusCode;
  int iContentLength;
  int iBodyLengthConsumed;
  int iContentLengthPtr;
};

#endif