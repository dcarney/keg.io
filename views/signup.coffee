
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

            legend {
              margin-left: 40px;
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
    script src: '../js/underscore-min.js'
    script src: '../js/moment.min.js'
    script src: '../js/jquery.color.js'
    script src: '../js/jquery.quicksand.js'
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
          comment "/.nav-collapse"
    div ->
      coffeescript ->
        onSignup = () ->
          user =
            email: $('#email').val()
            rfid: $('#rfid').val()
            firstName: $('#first_name').val()
            lastName: $('#last_name').val()
            twitter: $('#twitter').val()

          $.ajax
            type: 'POST'
            url: '/users'
            data: JSON.stringify user
            contentType: 'application/json'
            dataType: "json"
            error: (jqxhr) ->
              console.log "ERROR: #{jqxhr.status}"
            success: (response) ->
              alert 'asdf'
              $('#email').val('')
              $('#rfid').val('')
              $('#first_name').val('')
              $('#last_name').val('')
              $('#twitter').val('')

          return false

        $(document).ready ->
          $('#signup').click onSignup
          return false

      form class: 'form-horizontal', ->
        fieldset ->
          div id: 'legend', ->
            legend 'Signup for keg.io!'

          div class: "control-group", ->
            label class: "control-label"
            div class: "controls", ->
              input id: 'rfid', type:"text", placeholder:"RFID tag #", class: "input-xlarge"
              p class: "help-block", 'This was given to you along with your RFID tag'

          div class: "control-group", ->
            label class: "control-label", for:"input01"
            div class: "controls", ->
              input id:'first_name', type:"text", placeholder:"first name", class: "input-xlarge"
              p class: "help-block"

          div class: "control-group", ->
            label class: "control-label", for: "input01"
            div class: "controls", ->
              input id:'last_name',  type:"text", placeholder:"last name", class: "input-xlarge"
              p class: "help-block"

          div class: "control-group", ->
            label class: "control-label", for:"input01"
            div class: "controls", ->
              input id:'email', type:"text", placeholder:"email", class: "input-xlarge"
              p class: "help-block", ->
                span ->'This is only used to display your keg.io'
                a href:'http://en.gravatar.com/', -> ' gravatar'

          div class: "control-group", ->
            label class: "control-label"
            div class: "controls", ->
              div class: "input-prepend", ->
                span class: "add-on", '@'
                input id:'twitter', class: "span2", placeholder: "twitter username",  type:"text"
                p class: "help-block", ->
                  a href:'https://twitter.com/keg_io', -> 'keg.io will mention you '
                  span -> 'in relevant tweets!'

          div class: "control-group", ->
            label class: 'control-label'
            div class: 'controls', ->
              button id:'signup', type: 'button', class:'btn btn-success', 'Sign up!'
