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
     $('#kegerator_details').append("<li class='nav-header'>" + kegerator.name + "</li>");
     $('#kegerator_details').append("<li class='nav-header'>" + kegerator.description + "</li>");
     $('#kegerator_details').append("<li class='nav-header'>current beer temperature: <span id='kegerator_temp'>--</span></li>");

     // re-connect to the appropriate web socket
     reattachWebSocket(kegeratorId);
  });
};

// Connect to a web socket and listen for events for the given kegerator
var reattachWebSocket = function(kegeratorId) {
  socket.emit('attach', kegeratorId);
  socket.on('attached', function () { socketDebug('attached', kegeratorId); });
};


var handleTempEvent = function(data) {
  socketDebug('temp', data);
  $('#kegerator_temp').empty();
  $('#kegerator_temp').html(data['data']);
  $("#kegerator_temp").animate({color: "#FF0000"}, 700);
  $("#kegerator_temp").animate({color: "#000000"}, 700);
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
 socket.on('connect', function () { socketDebug('connect', null); });
 socket.on('hello', function (data) { socketDebug('hello', data); });
 socket.on('scan', function (data) { socketDebug('scan', data); });
 socket.on('temp', handleTempEvent);

});   // document ready

$('.dropdown-menu').on('click', 'li', function(event){
  var selectedId = $(event.srcElement).html();
  console.log('New kegerator selected: ' + selectedId);
  switchKegerator(selectedId);
});

