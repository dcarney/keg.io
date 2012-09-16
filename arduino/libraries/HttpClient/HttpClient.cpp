#include "HttpClient.h"

/*
Example HTTP response from keg.io:


HTTP/1.1 200 OK
Connection: keep-alive
Transfer-Encoding: chunked

1a
KEGIO:scan:5100ffed286b:::
0

*/

void HttpClient::resetState() {
    iState = eIdle;
    iStatusCode = 0;
    iContentLength = 0;
    iBodyLengthConsumed = 0;
    iContentLengthPtr = 0;
}

HttpClient::HttpClient(WiFlyClient& client) : _client(&client) {
  resetState();
}

void HttpClient::setState(tHttpState state) {
    iState = state;
}

int HttpClient::getResponseStatusCode() {
    if (iState < eRequestSent)
    {
        return HTTP_ERROR_API;
    }
    // The first line will be of the form:
    //   HTTP/<version> <status_code> <reason> CRLF
    //
    // Example:
    // HTTP/1.1 200 OK
    char c = '\0';
    do
    {
        // Make sure the status code is reset, and likewise the state.  This
        // lets us easily cope with 1xx informational responses by just
        // ignoring them really, and reading the next line for a proper response
        iStatusCode = 0;
        iState = eRequestSent;

        unsigned long timeoutStart = millis();
        // Psuedo-regexp we're expecting before the status-code
        const char* statusPrefix = "HTTP/*.* ";
        const char* statusPtr = statusPrefix;
        // Whilst we haven't timed out & haven't reached the end of the headers
        while ((c != '\n') && ((millis() - timeoutStart) < kHttpResponseTimeout ))
        {
            if (_client->available())
            {
                c = _client->read();
                Serial.print(c);
                switch(iState)
                {
                  case eRequestSent:
                    // We haven't reached the status code yet
                    if ( (*statusPtr == '*') || (*statusPtr == c) )
                    {
                        // This character matches, just move along
                        statusPtr++;
                        if (*statusPtr == '\0')
                        {
                            // We've reached the end of the prefix
                            iState = eReadingStatusCode;
                        }
                    }
                    else
                    {
                        return HTTP_ERROR_INVALID_RESPONSE;
                    }
                    break;
                case eReadingStatusCode:
                    if (isdigit(c))
                    {
                        // This assumes we won't get more than 3 digits
                        iStatusCode = iStatusCode*10 + (c - '0');
                    }
                    else
                    {
                        // We've reached the end of the status code
                        // We could sanity check it here or double-check for ' '
                        // rather than anything else, but let's be lenient
                        iState = eStatusCodeRead;
                    }
                    break;
                case eStatusCodeRead:
                    // We're just waiting for the end of the line now
                    break;
                };
                // We read something, reset the timeout counter
                timeoutStart = millis();
            }
            else
            {
                // We haven't got any data, so let's pause to allow some to
                // arrive
                delay(kHttpWaitForDataDelay);
            }
        }
        if ((c == '\n') && (iStatusCode < 200)) {
            // We've reached the end of an informational status line
            c = '\0'; // Clear c so we'll go back into the data reading loop
        }
    }
    // If we've read a status code successfully but it's informational (1xx)
    // loop back to the start
    while ((iState == eStatusCodeRead) && (iStatusCode < 200));

    if ( (c == '\n') && (iState == eStatusCodeRead) )
    {
        // We've read the status-line successfully
        return iStatusCode;
    }
    else if (c != '\n')
    {
        // We must've timed out before we reached the end of the line
        return HTTP_ERROR_TIMED_OUT;
    }
    else
    {
        // This wasn't a properly formed status line, or at least not one we
        // could understand
        return HTTP_ERROR_INVALID_RESPONSE;
    }
}

void HttpClient::readRemainingResponse() {
  // Now we've got to the body, so we can print it out
  unsigned long timeoutStart = millis();
  char c;
  while (_client->available() && ((millis() - timeoutStart) < HttpClient::kNetworkTimeout)) {
    if (_client->available()) {
      c = _client->read();
      // Print out this character
      Serial.print(c);

      // We read something, reset the timeout counter
      timeoutStart = millis();
    } else {
      // We haven't got any data, so let's pause to allow some to arrive
      delay(HttpClient::kNetworkDelay);
    }
  }
}