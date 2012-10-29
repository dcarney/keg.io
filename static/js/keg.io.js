 var socketDebug = function(msg, data) {
  console.log("socket event: '" + msg + "' data: " + (data === null ? "" : JSON.stringify(data)));
};

// Returns the client to the "home page" and hides any
// attached kegerator display info
var clearKegeratorSelection = function() {
  currentKegeratorId = null;
  // hide the intro copy, display the kegerator card
  $('#hero .card').addClass('hidden');
  $('#hero .intro_copy').removeClass('hidden');
  $('.previous').addClass('hidden');
  $('.row-fluid .span3').hide();
  $('#main').removeClass("span9");
  $('#main').addClass("span12");

  // TODO: should we clear the cookie?? I'm leaning towards no

  // stop listening for events on this kegerator
  detachWebSocket();
};

var switchKegerator = function(kegeratorId) {
  $.getJSON("/kegerators/" + kegeratorId, function(data) {
     console.log(data);
     var kegerator = data;
     if (_.isArray(data)) {
      kegerator = data[0];
     }

     // Save the value in a cookie
     cookieCreate('kegio', kegeratorId, 90);

     // hide the intro copy and previous drinkers, display the kegerator card
     $('#hero .card').removeClass('hidden');
     $('#hero .intro_copy').addClass('hidden');
     $('.previous').removeClass('hidden');
     $('.row-fluid .span3').show();
     $('#main').addClass("span9");
     $('#main').removeClass("span12");
     $('#previousRowOne').empty();
     $('#previousRowTwo').empty();

     // Populate some DOM elements w/ info
     $('#kegerator_details').empty();
     $('#kegerator_details').append("<li class='nav-header'>Kegerator</li>");
     $('#kegerator_details').append("<p>" + kegerator.name + "</p>");
     $('#kegerator_details').append("<p>" + kegerator.description + "</p>");
     $('#kegerator_details').append('<span class="badge badge-important connected">connected</span>&nbsp;');
     $('#kegerator_details').append('<span class="badge badge-important pour">pour</span>&nbsp;');
     $('#kegerator_details').append('<span class="badge" id="kegerator_temp">-- &deg;F</span>&nbsp;');

     // Get data about most recent keg on this kegerator
     $.getJSON("/kegerators/" + kegeratorId + "/kegs?limit=1", function(data) {
      keg = data;
      if (_.isArray(data)) {
        keg = data[0];
      }

      // populate some DOM elements w/ current keg info
      // TODO: Make image_path part of the repsonse, liek we do with gravatar images
      $('#keg_details').empty();
      $('#keg_details').append("<li class='divider'></li>");
      $('#keg_details').append("<li class='nav-header'>Keg</li>");
      $('#keg_details').append("<p>" + keg.beer + ' ' + keg.beer_style + "</li>");
      $('#keg_details').append("<p>" + keg.brewery + "</p>");
      $('#keg_details').append("<p>tapped: " + moment(keg.tapped_date).from(moment()) + "</p>");
      $('#keg_details').append("<li><img src='http://images.keg.io/" + keg.image_path + "'></img></p>");

     });  // getJSON

     // re-connect to the appropriate web socket
     reattachWebSocket(kegeratorId);
  });
};

// Connect to a web socket and listen for events for the given kegerator
var reattachWebSocket = function(kegeratorId) {
  $('#kegerator_details .badge.connected').removeClass("badge-important").addClass("badge-warning on");
  socket.emit('attach', kegeratorId);
  socket.on('attached', function () {
    $('#kegerator_details .badge.connected').removeClass("badge-warning").addClass("badge-success");
    socketDebug('attached', kegeratorId);
  });
};

// Stop listening for events for the given kegerator.  Web socket remains connected.
var detachWebSocket = function() {
  $('#kegerator_details .badge.connected').removeClass("badge-important").addClass("badge-warning on");
  socket.emit('detach', null);
  socket.on('detached', function () {
    socketDebug('detached', null);
  });
};

var handleCoasterEvent = function(data) {
  socketDebug('coaster', data);
  // TODO: Make the new coaster show up in the UI
};

var handleTempEvent = function(data) {
  socketDebug('temp', data);
  temperature = data['data'];
  $('#kegerator_temp').empty();
  $('#kegerator_temp').html(temperature + "&deg;F");
	$('#kegerator_temp').removeClass("badge-important badge-success badge-warning");
  if(temperature < 45) {
    $('#kegerator_temp').addClass("badge-success");
  } else if(temperature < 50) {
    $('#kegerator_temp').addClass("badge-warning");
  } else {
    $('#kegerator_temp').addClass("badge-important");
	}
};

var handleDenyEvent = function(data) {
  socketDebug('deny', data);
  $("#kegerator_details .badge.pour").removeClass("badge-important").addClass("badge-important");
  window.setTimeout(function() {
    $("#kegerator_details .badge.pour").toggleClass("on");
  }, 1500);
};

var handlePourEvent = function(data) {
  socketDebug('pour', data);
  var volumeOunces = data['data'];
  var now = new Date();
  $('#user_info .pour_volume').html("You just poured <span class='badge'>" + volumeOunces + " ounces</span>!");
  $('#user_info .pour_date').text( moment(now).fromNow());
  $('#user_info .pour_date').attr('data',now);
  $("#kegerator_details .badge.pour").removeClass("badge-important badge-success badge-warning").addClass("badge-important");
};

// each obj in pourObjects is a regular pour, with the associated member obj
// as the .user property.
// Ex:
// {
//  "rfid": "44004C234A",
//  "keg_id": 1,
//  "kegerator_id": 1111,
//  "volume_ounces": 5,
//  "rates": [],
//  "date": "2012-07-23T20:17:14-07:00"
//  "user": <SOME_USER_OBJ>
//  }
//
var populatePreviousDrinkersMarkup = function(pourObjects) {
  // Clear the previous drinkers rows
  $(".previous").empty();

  var count = 0;
  _.each(pourObjects, function(pourObject) {
    count++;
    var pour = pourObject;
    var user = pour.user;

    // Create a fresh new div for holding the markup for a previous drinker
    var previousCard = $('<div class="span4 mini-card"></div>');
    previousCard.append("<img id='gravatar' class='profile' src='" + user.gravatar + "'>");
    previousCard.append('<h2 class=name>' + user.first_name + '</h2>');
    previousCard.append("<p class='pour_volume'><span class='badge'>" + pour.volume_ounces + " ounces</span></p>");
    previousCard.append("<p class='pour_date'>" + moment(pour.date).fromNow() + "</p>");

    // Put 3 mini-cards per row
    var domSelector = count <= 3 ? '#previousRowOne' : '#previousRowTwo';
    $(domSelector).prepend(previousCard);
  });
};

// Take a user object and populate various bits of markup with info about them
var populateCurrentDrinkerMarkup = function(user) {
  $("#kegerator_details .badge.pour").removeClass("badge-important").addClass("badge-success");

	$('#user_coasters').empty();
  if (user) {
    _.each(user.coasters, function(coaster_id) {
      $.getJSON("/coasters/" + coaster_id, function(data) {
        if (!_.isEmpty(data)) {
          data= data[0];
          var image_path = data.image_path;
          var description = data.description;
          var coaster = $('<img class="coaster" title="'+description+'" data-placement="bottom" src="'+image_path+'">').appendTo('#user_coasters');
          $(coaster).tooltip();
        }
      });
    });
  }

  $('#gravatar').attr('src', user.gravatar);
  $('#user_info').empty();
  $('#user_info').append('<h2>Hello, <span class="firstname"> '+ user.first_name + '</span>!</h2>');
  $('#user_info').append("<p class='pour_volume'><span class='label label-striped active'>pouring...</span></p>");
  $('#user_info').append('<p class="pour_date">Pour yourself a tasty beer!</p>');
  //$('#user_info').append('<a class="btn rfid" href="#/users/' + user.rfid + '">View Profile</a>');
};

// Helper fn for getting a user obj via the API
// cb = (user)
var getUser = function(rfid, cb) {
   $.getJSON("/users/" + rfid, function(data) {
    var user = null;
    if (_.isArray(data)) {
      user = data[0];
    }
    return cb(user);
  });
};

var handleScanEvent = function(data) {
  socketDebug('scan', data);
  rfid = data['data'];
	//var newprev = $('<div class="span4"></div>').append($('#hero #user_info').html());
	var newprev = $('<div class="span4"></div>').append($('#hero div.card').html().replace(/id\=\"[\w\_\-]+\"/gi,"")); //"
    $(newprev).find("h2").text($(newprev).find("h2 .firstname").text());
    //$(newprev).find(".user_coasters").remove();
    var pour = $(newprev).find(".pour_volume");
    pour.html($(pour).find("span"));
    var prevs = $('.previous div.mini-card').clone();
    $('.previous div.mini-card').remove();

    $('#previousRowOne').append(newprev.addClass('mini-card'));
    $('#previousRowOne').append(prevs.slice(0,2));
    $('#previousRowTwo').append(prevs.slice(2,5));
    $('.mini-card .pour_date').each(function(index){
    $(this).text(moment($(this).attr('data')).fromNow());
  });

  getUser(rfid, function(user) {
    populateCurrentDrinkerMarkup(user);

    $("#hero").animate({backgroundColor: "#FF0000"}, 700);
    $("#hero").animate({backgroundColor: "#FFFFFF"}, 700);
  });
};

var cookieCreate = function createCookie(name,value,days) {
  var expires = "";
  if (days) {
    var date = new Date();
    date.setTime(date.getTime() + (days*24*60*60*1000));
    expires = "; expires=" + date.toGMTString();
  }
  document.cookie = name+"="+value+expires+"; path=/";
};

var cookieRead = function readCookie(name) {
  var nameEQ = name + "=";
  var ca = document.cookie.split(';');
  for(var i=0; i < ca.length; i++) {
    var c = ca[i];
    while (c.charAt(0)==' ') c = c.substring(1,c.length);
    if (c.indexOf(nameEQ) === 0) { return c.substring(nameEQ.length,c.length); }
  }
  return null;
};

var cookieDelete = function eraseCookie(name) {
  createCookie(name,"",-1);
};

// The web socket
var socket = null;

// The attached kegerator (if any)
var currentKegeratorId = null;

$(document).ready(function(){

  // Add tooltips to each coaster img
  $('img.coaster').each(function(index, el) {
    $(el).on('hover', 'img', function(event) {
      var el = $(event.srcElement);
      $el.tooltip();
    });
  });

  // Look for a keg.io cookie, with an all-numeric kegerator ID in it.
  var cookieVal = cookieRead('kegio');
  if ((cookieVal !== null) && (cookieVal.match(/^\d+$/))) {
    currentKegeratorId = cookieVal;
    switchKegerator(currentKegeratorId);
  }

  // Get the list of available kegerators, populate the dropdown with them
  $.getJSON("/kegerators", function(kegerators) {
    _.each(kegerators, function(k) {
      $('.dropdown-menu').append("<li><a id=" + k.kegerator_id + " href='#' onclick='javascript:return false;'>" + k.name + "</a></li>");
    });
  }); // getJSON

  // Populate the 'last drinker' and 'current drinker' cards
  if (currentKegeratorId !== null) {
    // limit of 7 = 1 current drinker, 6 previous
    $.getJSON('/kegerators/' + currentKegeratorId + '/pours?limit=7', function(pours) {
      var lastPour = pours.shift(); // the 'last' pour is the 0th element!
      getUser(lastPour.rfid, function(user) {
        populateCurrentDrinkerMarkup(user);
      });

      var pourObjects = [];
      // remove any undefined objecs
      pours = _.reject(pours, function(pour) { return pour === null; });

      var numPours = pours.length;
      _.each(pours, function(pour) {
        getUser(pour.rfid, function(user) {
          pour['user'] = user;
          pourObjects.push(pour);
          if (pourObjects.length === numPours) {
            // all done, populate the UI
            populatePreviousDrinkersMarkup(pourObjects);
          }
        });
      });

    }); // getJSON
  }

 socket = io.connect('http://kegio.herokuapp.com');
 socket.on('connect', function () {
  socketDebug('connect', null);
  $('.badge.connected').removeClass("badge-important badge-warning").addClass("badge-success on");//.text("connected");
 });
 socket.on('disconnect', function() {
  $('.badge.connected').removeClass("badge-success badge-warning").addClass("badge-important on");//.text("disconnected");
 });
 socket.on('hello', function (data) { socketDebug('hello', data); });
 socket.on('scan', handleScanEvent);
 socket.on('temp', handleTempEvent);
 socket.on('deny', handleDenyEvent);
 socket.on('pour', handlePourEvent);
 socket.on('coaster', handleCoasterEvent);
 // TODO: add code to handle flow event

});   // document ready

// Attach an event handler to each item in the "kegerators" menu
$('.dropdown-menu').on('click', 'li', function(event) {
  var selectedId = $(event.srcElement).attr('id');
  console.log('New kegerator selected: ' + selectedId);
  switchKegerator(selectedId);
});

// Attach an event handler to all the "home" links that clears the
// kegerator selection, and displays the homepage content
$('.home_link').on('click', function(event) {
  clearKegeratorSelection();
});
