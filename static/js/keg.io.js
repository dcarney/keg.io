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
         $('#kegerator_details').empty();
         $('#kegerator_details').append("<li class='nav-header'>" + kegerator.name + "</li>");
         $('#kegerator_details').append("<li class='nav-header'>" + kegerator.description + "</li>");
    });
};

$(document).ready(function(){

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
    });
});

$('.dropdown-menu').on('click', 'li', function(event){
    var selectedId = $(event.srcElement).html();
    console.log('New kegerator selected: ' + selectedId);
    switchKegerator(selectedId);
});