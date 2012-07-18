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
     $('#kegerator_details').append("<li><a href='#'>" + kegerator.name + "</a></li>");
     $('#kegerator_details').append("<li><a href='#'>" + kegerator.description + "</a></li>");
     $('#kegerator_details').append("<li><a href='#'>current beer temperature: <span id='kegerator_temp'>--</span></a></li>");

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
  socket.emit('attach', kegeratorId);
  socket.on('attached', function () { socketDebug('attached', kegeratorId); });
};


var handleTempEvent = function(data) {
  socketDebug('temp', data);
  temperature = data['data'];
  $('#kegerator_temp').empty();
  $('#kegerator_temp').html(temperature);
  $("#kegerator_temp").animate({color: "#000000", backgroundColor: "#FF0000"}, 700);
  $("#kegerator_temp").animate({color: "#000000", backgroundColor: "#FFFFFF"}, 700);
};

var handleScanEvent = function(data) {
  socketDebug('scan', data);

  rfid = data['data'];
  $.getJSON("/users/" + rfid, function(data) {
    var user = data;
    if (_.isArray(data)) {
      user = data[0];
    }

    console.log(user);

    /*
      <div class="card">
              <img class="profile" src="http://www.gravatar.com/avatar/a6bb9f750f1a3f52b7bddc5a3f843852?s=128">
              <div class="bc-right">
                <h1>Your Mom</h1>
                <p class="location">Seattle, WA</p>
                <p class="title" >Solid dude</p>
              </div>
            </div>


    email: "garrett.patterson@vivaki.com"
    first_name: "Garrett"
      gravatar: "http://www.gravatar.com/avatar/576befa3d0acd03ae83895890c17f848?s=256"
      last_name: "Patterson"
      nickname: ""
      rfid: "440055F873"
      twitter_handle: "@thegarrettp"
*/
   // $('#hero').empty();

    /* $('#hero').append("<h1>Hello, " + user.first_name + "!</h1>");
    $('#hero').append("<p>Pour yourself a tasty beer!</p>");
    $('#hero').append("<img style='float: right;' src='http://www.gravatar.com/avatar/a6bb9f750f1a3f52b7bddc5a3f843852?s=256' />"); */

    $('#gravatar').attr('src', user.gravatar);
    $('#user_info').empty();
    $('#user_info').append("<h1>Hello, " + user.first_name + "!</h1>");
    $('#user_info').append("<p>Pour yourself a tasty beer!</p>");
    //$('#user_info').append("<p class='location'>Seattle, WA</p>");
    //$('#user_info').append("<p class='title' >Solid dude</p>");
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
 socket.on('scan', handleScanEvent);
 socket.on('temp', handleTempEvent);

});   // document ready

$('.dropdown-menu').on('click', 'li', function(event){
  var selectedId = $(event.srcElement).html();
  console.log('New kegerator selected: ' + selectedId);
  switchKegerator(selectedId);
});

