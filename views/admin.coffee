doctype 5
html lang: "en", ->
  head ->
    meta charset: "utf-8"
    title "#{@title ? 'keg.io'}"
    meta name: "viewport", content: "width=device-width, initial-scale=1.0"
    meta(name: 'description', content: @description) if @description?
    link(rel: 'canonical', href: @canonical) if @canonical?

    link href: "../css/bootstrap.css", rel: "stylesheet"
    style type: "text/css", """
            body {
              padding-top: 60px;
              padding-bottom: 40px;
            }

            .sidebar-nav {
              padding: 9px 0;
            }

            #hero .lastname, #hero .location, #hero .rfid {
              display: none;
            }

            .mini-card .tagline, .mini-card .user_coasters{
              display: none;
            }

            .mini-card .bc-right{
              width: auto;
              height: auto;
              float: right;
            }
      """
    link href: "../css/bootstrap-responsive.css", rel: "stylesheet"
    link href: "../css/style.css", rel: "stylesheet"
    comment "Le HTML5 shim, for IE6-8 support of HTML5 elements"
    ie "lt IE 9", ->
      script src: "http://html5shim.googlecode.com/svn/trunk/html5.js"
    link href: "http://fonts.googleapis.com/css?family=Cabin+Sketch:bold", rel: "stylesheet", type: "text/css"
    comment "Le fav and touch icons"
    link rel: "shortcut icon", href: "favicon.ico"
    link rel: "apple-touch-icon-precomposed", sizes: "144x144", href: "../ico/apple-touch-icon-144-precomposed.png"
    link rel: "apple-touch-icon-precomposed", sizes: "114x114", href: "../ico/apple-touch-icon-114-precomposed.png"
    link rel: "apple-touch-icon-precomposed", sizes: "72x72", href: "../ico/apple-touch-icon-72-precomposed.png"
    link rel: "apple-touch-icon-precomposed", href: "../ico/apple-touch-icon-57-precomposed.png"


    script src: 'http://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js'
    script src: '../js/bootstrap.js'
    script src: '../js/bootbox.min.js'
    script src: '../js/underscore-min.js'
    script src: '../js/moment.min.js'
    script src: '../js/jquery.color.js'
    script src: '../js/jquery.quicksand.js'
    script src: '../js/jquery.dataTables.min.js'
    script src: '/socket.io/socket.io.js'
    script src: '../js/keg.io.js'

  body ->
    div class: 'navbar navbar-fixed-top', ->
      div class: 'navbar-inner', ->
        div class: 'container-fluid', ->
          a class: 'btn btn-navbar', "data-toggle": "collapse", "data-target": ".nav-collapse", ->
            span class: 'icon-bar'
            span class: 'icon-bar'
            span class: 'icon-bar'
          a class: 'home_link brand', href: "#", "keg.io"
          div class: 'nav-collapse', ->
            ul class: 'nav', ->
              li class: 'home_link active', ->
                a href: "#", 'home'
              li class: 'dropdown', ->
                a class: 'dropdown-toggle', "data-toggle": "dropdown", href: "#", ->
                  text " kegerators "
                  span class: 'caret'
                ul class: 'dropdown-menu', ->
              li ->
                a href: "http://keg.io", target: "_blank", "about"
              li ->
                a href: "https://github.com/dcarney/keg.io", target: "_blank", "github"
              li ->
                a href: '/signup', 'signup!'
          comment "/.nav-collapse"
    div class:'container-fluid',->
      div class:'row',->
        div class:'span3 well',->
          ul class:'nav nav-list',->
            li ->
              a href:'/admin/kegs', 'kegs'
            li ->
              a href:'/admin/users', 'users'  
        
        
        div class:'span9 well',->
          text 'this is admin'
          table id:'user_table',->
            thead ->
              tr ->
                th
            tbody ->
              tr ->
                td
          
    coffeescript ->
      $(document).ready ->
         $.get '/users', (users) ->
           $('#user_table').dataTable ->
             aaData:users
             aoColumns:[
               mData:'rfid'
               sTitle:"RFID"
             ,
               mData:'first_name'
               sTitle:"name"
             ,
               mData:"last_name"
             ,
               mData:"email"
             ,
               mData:"twitter_handle"
             ,
              mData: "tokens.untappd"
              mRender: (d) ->
                (if d or d isnt "" then true else false)
             ]
           #$.each users, (i, user)->
             
             #$('#user_table').append('<tr><td>'+ user.first_name + '</td></tr>')
           
      
