 var socketDebug = function(msg, data) {
  console.log("socket event: '" + msg + "' data: " + (data === null ? "" : JSON.stringify(data)));
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

     // Populate some DOM elements w/ info
     $('#kegerator_details').empty();
     $('#kegerator_details').append("<li class='nav-header'>Kegerator</li>");
     $('#kegerator_details').append('<span class="badge badge-important connected">connected</span>');
     $('#kegerator_details').append('<span class="badge badge-important pour">pour</span>');
     $('#kegerator_details').append("<li><a href='#'>" + kegerator.name + "</a></li>");
     $('#kegerator_details').append("<li><a href='#'>" + kegerator.description + "</a></li>");
     $('#kegerator_details').append("<li><a href='#'>current beer temperature: <span class='badge' id='kegerator_temp'>-- &deg;F</span></a></li>");

     // Get data about most recent keg on this kegerator
     $.getJSON("/kegerators/" + kegeratorId + "/kegs?limit=1", function(data) {
      keg = data;
      if (_.isArray(data)) {
        keg = data[0];
      }

      // populate some DOM elements w/ current keg info
      // TODO: Make image_path part of the repsonse, liek we do with gravatar images
      $('#keg_details').empty();
      $('#keg_details').append("<li class='nav-header'>Keg</li>");
      $('#keg_details').append("<li class='nav-header'>" + keg.beer + ' ' + keg.beer_style + "</li>");
      $('#keg_details').append("<li class='nav-header'>" + keg.brewery + "</li>");
      $('#keg_details').append("<li class='nav-header'>tapped: " + moment(keg.tapped_date).from(moment()) + "</li>");
      $('#keg_details').append("<li><img src='http://images.keg.io/" + keg.image_path + "'></img></li>");

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
  if(temperature < 40) {
    $('#kegerator_temp').addClass("badge-success");
  } else if(temperature < 50) {
    $('#kegerator_temp').addClass("badge-warning");
  } else {
    $('#kegerator_temp').addClass("badge-important");
	}
};

var handleDenyEvent=function(data){
  $("#kegerator_details .badge.pour").removeClass("badge-important").addClass("badge-important");
  window.setTimeout(function(){
    $("#kegerator_details .badge.pour").toggleClass("on");
  }, 1500);
};

var handlePourEvent = function(data){
		$("#kegerator_details .badge.pour").removeClass("badge-important badge-success badge-warning").addClass("badge-important");
};

var handleScanEvent = function(data) {
  socketDebug('scan', data);

  rfid = data['data'];
  $.getJSON("/users/" + rfid, function(data) {
    var user = data;
    if (_.isArray(data)) {
      user = data[0];
    }
	$("#kegerator_details .badge.pour").removeClass("badge-important").addClass("badge-success on");

    if (user) {
      _.each(user.coasters, function(coaster_id) {
        $.getJSON("/coasters/" + coaster_id, function(data) {
          var image_path = data.image_path;
          var description = data.description;
        });
      });
    }
    console.log(user);

    var newprev = $('<div class="span4"></div>').append($('#hero #user_info').html());
    var name = $(newprev).find("h2 .firstname").text() + " " + $(newprev).find("h2 .lastname").text();
    $(newprev).find("h2").text(name);
    $(newprev).find(".user_coasters").remove();
    $(".previous").prepend(newprev.addClass('mini-card'));
    $(".previous div.span4").last().remove();

    $('#gravatar').attr('src', user.gravatar);
    $('#user_info').empty();
    $('#user_info').append('<h2>Hello, <span class="firstname"> '+ user.first_name + '</span><span class="lastname">'+user.last_name+'</span>!</h2>');
    $('#user_info').append("<p class='tagline'>Pour yourself a tasty beer!</p>");
    $('#user_info').append("<p class='location'>Seattle, WA</p>");
    $('#user_info').append('<a class="btn rfid" href="#/users/'+user.rfid+'">View Profile</a>');
    //$('#user_info').append("<p class='title' >Solid dude</p>");
    // $('#user_coasters').empty();

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

$(document).ready(function(){

  $('img.coaster').each(function(index, el) {
    $(el).on('hover', function() {
      var self = this;
      $(self).tooltip();
    });
  });

  // Look for a keg.io cookie, with an all-numeric kegerator ID in it.
  var cookieVal = cookieRead('kegio');
  if ((cookieVal !== null) && (cookieVal.match(/^\d+$/))) {
    switchKegerator(cookieVal);
  }

  // Get the list of available kegerators, populate the dropdown with them
  $.getJSON("/kegerators", function(kegerators) {
    console.log(kegerators);
    console.log(_.pluck(kegerators, 'kegerator_id'));

    var ids = _.pluck(kegerators, 'kegerator_id');
    console.log(ids);
    //var tmpl = $('#kegerator_template');
    //console.log(tmpl);
    //var drinker = $(Mustache.render("<li><a href='#'>{{id}}</a></li>",ids));
    //console.log(drinker);

    _.each(ids, function(id) {
      $('.dropdown-menu').append("<li><a href='#'>" + id + "</a></li>");
    });
  }); // getJSON

 socket = io.connect('http://localhost:8081');
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

$('.dropdown-menu').on('click', 'li', function(event){
  var selectedId = $(event.srcElement).html();
  console.log('New kegerator selected: ' + selectedId);
  switchKegerator(selectedId);
});

