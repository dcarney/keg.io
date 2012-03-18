/*
 * Simulates a kegerator client, for development without the physical hardware.
 *
 * Usage: node test-kegerator-client.js [access_key] [secret_key]
 *
 * Options:
 *   [access_key] : the 'public key' for the desired kegerator (defaults to '1111')
 *   [secret_key] : the 'secret key' for the desired kegerator (defaults to 's3cr3t')
 *
 *   remember to quote any access/secret keys that contain special characters:
 *
 *   Ex. node test-kegerator-client.js 2222 'p@$$w3rd'
 *
 */

// this allows us to require coffeescript files as if they were .js files
require('coffee-script');

var HOST = 'localhost';
var KEGERATOR_ID = (process.argv.length > 2) ? process.argv[2] : '1111';
var PORT = '8081';
//password with which to sign requests. should *never* be transferred over the wire.
var SECRET = (process.argv.length > 3) ? process.argv[3] : 's3cr3t';

console.log(KEGERATOR_ID);
console.log(SECRET);

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
			var randomFlow = (Math.floor(Math.random() * 61)) + 30; // between 30-90

			// send API request
			kegioAPI.flow(randomFlow).put(function(err, result) {
				if (!err) {
					console.log('flow sent: ' + randomFlow + ', server responded with: ' + result);
				} else {
					console.log('ERROR: error sending flow request: ' + result );
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
				console.log('ERROR: error sending flow end request: ' + result );
			}
		});
	}
};

// Produces a fake "pour" event on a given interval, used in development mode
FakeKegerator.prototype.fakePour = function()
{
	var frequencyInMs = 10000;	// repeat every 10 seconds
	var self = this;
	this.fakeFlow(7);   // flow for 7 seconds

	// Select a random user, using values that we "know" are in the DB,
	// (based on the fact that they're hardcoded into the DB rebuild script)
	var randomUser = Math.floor(Math.random() * 6); // between 0-5
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
		case 5:
			userRFID = "DENYTAG546";  //deny user
		break;
	}

	setTimeout(function() {
		console.log('fake pour!!!!!!');

		// send API request
		kegioAPI.scan(userRFID).get(function(err, result) {
			if (!err) {
				console.log('scan user: ' + userRFID + ', server responded with: ' + result);
			} else {
				console.log('ERROR: error sending scan request for user: ' + userRFID + ' ' + result);
			}
		});

		setTimeout(self.fakePour(), frequencyInMs);
		}, frequencyInMs);
};

// Produces a fake "temp" event on a given interval, used in development mode
FakeKegerator.prototype.fakeTemp = function()
{
	var frequencyInMs = 30000;    // repeat every 30 seconds
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
