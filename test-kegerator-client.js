
/*****************************
	Communication protocol spec between keg.io server and kegerator client
	All communication is one-way.  Requests are initiated by kegerator client.

	URL Format: http://keg.io/api/kegerator/KEGERATOR_ID/ACTION/VALUE?signature=REQUEST_SIGNATURE
		- KEGERATOR_ID: 4-digit kegerator ID
		- ACTION: one of "scan", "flow", or "temp"
		- VALUE:
			- an rfid when ACTION=scan
			- an integer or the special keyword "end" when ACTION=flow
			- an integer when ACTION=temp
		- REQUEST_SIGNATURE: the HMAC-SHA-256 signature of the request (in hex)

	Example:
	http://keg.io/api/kegerator/1111/scan/afcdef09d43?signature=79732c5ca659b29acd04967431d2843b6b958de308d974cc2f45cb09aaa7b08a

	Signing the request:
		- The signature is computed by HMAC-SHA-256 signing the HTTP verb followed by the full request URL
		- The signature is a hex value
		- For example the signature for "GET http://keg.io/api/kegerator/1111/scan/afcdef09d43" with secret 's3cr3t' is '79732c5ca659b29acd04967431d2843b6b958de308d974cc2f45cb09aaa7b08a'
		- This library is used by the server to verify signatures https://github.com/crcastle/nodejs-string-signer

	Request Details:

	Verify a card ID:
	GET http://keg.io/api/kegerator/1111/scan/afcdef09d43
		- *rfid* indicates an rfid scan, where *rfid* is the value that was scanned
		- all subsequent received flow requests are associated with this rfid until the special "flow/end" request is received

	Send the current flow rate:
	PUT http://keg.io/api/kegerator/1111/flow/89
		- 89 indicates the current flow rate in liters/min
		- this and all subsequent flow requests are associated with the last rfid until the special "flow/end" request is received

	Tell the server that the flow for this card ID done(special case of the above):
	PUT http://keg.io/api/kegerator/1111/flow/end
		- indicates that pouring is complete e.g. solenoid closed
		- any flow requests after this but before a "scan" request should be ignored

	Send the current temperature:
	PUT http://keg.io/api/kegerator/1111/temp/39
		- *temp* indicates the current keg temp, where *temp* is in F

	Response code details:
	- 200: Request was received and processed successfully
	- 400: Bad request syntax
	- 401: Unauthorized.  Invalid signature.
	- 404: Unknown resource requested.  Either the kegerator ID was incorrect or an invalid ACTION was specified.
 *****************************/

// this allows us to require coffeescript files as if they were .js files
require('coffee-script');

var HOST = 'localhost';
var KEGERATOR_ID = '1111';
var PORT = '8081';
var SECRET = 's3cr3t'; //password with which to sign requests. should *never* be transferred over the wire.

var fermata = require('fermata'), // used to make easy REST HTTP requests
	signedRequest = require('string-signer'), // used to sign each HTTP request
	payload = require('./lib/payload');

// create and register a kegio fermata plugin that takes care of the request signing
fermata.registerPlugin('kegio', function(transport, host, port, kegeratorId, secret) {
	port = (port == '80' ? '' : ':' + port);
	this.base = 'http://'+ host + port + '/api/kegerator/' + kegeratorId;
    transport = transport.using('statusCheck').using('autoConvert', "text/plain");

  return function (req, callback) { // req = {base, method, path, query, headers, data}
    var requestToSign = payload.getPayload(req.method,
                                            host + port,
                                             '/api/kegerator/' + kegeratorId + (req.path ? req.path.join("/") : ''),
                                            req.data);
    var sig = signedRequest.getSignature(requestToSign, secret);
    req.query = { signature: sig };
    req.headers['Content-Type'] = "application/x-www-form-urlencoded";
    transport(req, callback);
	};
});

// define API endpoint using above-defined kegio fermata plugin
var kegioAPI = fermata.kegio(HOST, PORT, KEGERATOR_ID, SECRET);

// create FakeKegerator object
FakeKegerator = function() {};

FakeKegerator.prototype.init = function(socket) {
	this.socket = socket;
	this.fakePour();
	this.fakeTemp();
	return;
};

// Produces a fake "flow" event on a given interval, used in development mode
FakeKegerator.prototype.fakeFlow = function(flowsLeft)
{
	var frequencyInMs = 1000;       // repeat every second
	var self = this;

	if (flowsLeft > 0)
	{
		setTimeout(function() {
			var randomFlow = (Math.floor(Math.random() * 51)) + 30; // between 30-80

			// send API request
			kegioAPI.flow(randomFlow).put(function(err, result) {
				if (!err) {
					console.log('flow sent: ' + randomFlow + ', server responded with: ' + result);
				} else {
					console.log('ERROR: error sending flow request: ' + result.data );
				}
			});

			setTimeout(self.fakeFlow(flowsLeft - 1), frequencyInMs);
			}, frequencyInMs);
	}
	else
	{
		// (In Fred Armisen from Portandia voice): "This flow is **OVER**!!!"
		// send API request
		kegioAPI.flow.end.put(function(err, result) {
			if (!err) {
				console.log('flow ended, server responded with: ' + result);
			} else {
				console.log('ERROR: error sending flow end request: ' + result.data );
			}
		});
	}
};

// Produces a fake "pour" event on a given interval, used in development mode
FakeKegerator.prototype.fakePour = function()
{
	var frequencyInMs = 10000;	// repeat every 10 seconds
	var self = this;
	this.fakeFlow(5);   // flow for 5 seconds

	// Select a random user, using values that we "know" are in the DB,
	// (based on the fact that they're hardcoded into the DB rebuild script)
	var randomUser = Math.floor(Math.random() * 5); // between 0-4
	var userRFID = "";
	switch(randomUser)
	{
		case 0:
			userRFID = "44004C234A";	// Dylan
		break;
		case 1:
			userRFID = "44004C3A1A";	// Chris
		break;
		case 2:
			userRFID = "4400561A0A";	// Carl
		break;
		case 3:
			userRFID = "440055F873";  // Garrett
		break;
		case 4:
			userRFID = "DENYTAG544";  //deny user
		break;
	}

	setTimeout(function() {
		console.log('fake pour!!!!!!');

		// send API request
		kegioAPI.scan(userRFID).get(function(err, result) {
			if (!err) {
				console.log('scan user: ' + userRFID + ', server responded with: ' + result);
			} else {
				console.log('ERROR: error sending scan request for user: ' + userRFID + ' ' + result.data);
			}
		});

		setTimeout(self.fakePour(), frequencyInMs);
		}, frequencyInMs);
};

// Produces a fake "temp" event on a given interval, used in development mode
FakeKegerator.prototype.fakeTemp = function()
{
	var frequencyInMs = 3000;    // repeat every 3 seconds
	var self = this;
	setTimeout(function() {
		var randomTemp = 40;                              	   // start at 40
		var randomTemp = randomTemp + (Math.floor(Math.random() * 10) - 5); // between -5 and 5
		// yields a temp between 35 and 45

		// send API request
		kegioAPI.temp(randomTemp).put(function(err, result) {
			if (!err) {
				console.log('temp send: ' + randomTemp + ', server responded with: ' + result);
			} else {
				console.log('ERROR: error sending temp request: ' + randomTemp);
			}
		});

		setTimeout(self.fakeTemp(), frequencyInMs);
		}, frequencyInMs);
};

fakeKegerator = new FakeKegerator();
fakeKegerator.init();