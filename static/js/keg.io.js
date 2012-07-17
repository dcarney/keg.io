var switchKegerator = function(kegeratorId) {
    $.getJSON("/kegerators/" + selectedId, function(data) {

    });
}

$(document).ready(function(){
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
         //   $('.dropdown-menu').append("<li><a href='#'>" + id + "</a></li>");
        });
    });
});

$('.dropdown-menu').on('click', 'li', function(event){
    var selectedId = $(event.srcElement).html()
    console.log(selectedId);

    $.getJSON("/kegerators/" + selectedId, function(data) {
        console.log(data);
    });
});