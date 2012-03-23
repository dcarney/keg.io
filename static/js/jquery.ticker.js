jQuery(document).ready(function(){
    // Instantiate jTicker
	jQuery("#ticker").ticker({
 		cursorList:  " ",
 		rate:        10,
 		delay:       4000
	}).trigger("play").trigger("stop");

    // Trigger events
    jQuery(".stop").click(function(){
        jQuery("#ticker").trigger("stop");
        return false;
    });

    jQuery(".play").click(function(){
        jQuery("#ticker").trigger("play");
        return false;
    });

    jQuery(".speedup").click(function(){
        jQuery("#ticker")
        .trigger({
            type: "control",
            item: 0,
            rate: 10,
            delay: 4000
        })
        return false;
    });

    jQuery(".slowdown").click(function(){
        jQuery("#ticker")
        .trigger({
            type: "control",
            item: 0,
            rate: 90,
            delay: 8000
        })
        return false;
    });

    jQuery(".next").live("click", function(){
        jQuery("#ticker")
        .trigger({type: "play"})
        .trigger({type: "stop"});
        return false;
    });

    jQuery(".style").click(function(){
        jQuery("#ticker")
        .trigger({
            type: "control",
            cursor: jQuery("#ticker").data("ticker").cursor.css({width: "4em", background: "#efefef", position: "relative", top: "1em", left: "-1em"})
        })
        return false;
    });

  });