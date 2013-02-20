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
    link href: "/css/jquery.dataTables.css", rel:"stylesheet", type:"text/css"
    link href:"/css/DT_bootstrap.css", rel:"stylesheet",type:"text/css"
    link href: "/css/bootstrapSwitch.css", rel:"stylesheet",type:"text/css"
    comment "Le fav and touch icons"
    link rel: "shortcut icon", href: "favicon.ico"
    link rel: "apple-touch-icon-precomposed", sizes: "144x144", href: "../ico/apple-touch-icon-144-precomposed.png"
    link rel: "apple-touch-icon-precomposed", sizes: "114x114", href: "../ico/apple-touch-icon-114-precomposed.png"
    link rel: "apple-touch-icon-precomposed", sizes: "72x72", href: "../ico/apple-touch-icon-72-precomposed.png"
    link rel: "apple-touch-icon-precomposed", href: "../ico/apple-touch-icon-57-precomposed.png"


    script src: 'http://ajax.googleapis.com/ajax/libs/jquery/1.9.0/jquery.min.js'
    script src: '../js/bootstrap.js'
    script src: '../js/bootbox.min.js'
    script src: '/js/bootstrapSwitch.js'
    script src: '../js/underscore-min.js'
    script src: '../js/moment.min.js'
    script src: '../js/jquery.color.js'
    script src: '../js/jquery.quicksand.js'
    script src: '../js/jquery.dataTables.min.js'
    script src: '/js/DT_bootstrap.js'
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
        div class:'span2 well',->
          ul class:'nav nav-list',->
            li ->
              a href:'#kegs', 'kegs'
            li ->
              a href:'#users', 'users'  
        
        
        div class:'span14 well',->
          text 'this is admin'
          table id:'user_table', class:"table table-striped table-bordered",->
            thead ->
              tr ->
                th 'rfid'
                th 'first_name'
                th 'last_name'
                th 'email'
                th 'twitter_handle'
                th 'untappd'
                th ''
            tbody class:'dataTable' , ->
              tr ->
                td ''
                td ''
                td ''
                td ''
                td ''
                td ''
                td ''
                
      div id:'untappd-modal', class:'modal hide fade', role:'dialog',->
        div class:'modal-header',->
          button type:'button',class:'close','data-dismiss':'modal', 'aria-hidden':'true',->'x'
          h3 ->'Authorize Untappd'
        div class:'modal-body',->
          iframe id:'untappd-frame', style:"width:550;height:550;margin:0;padding:0;", width:"550",height:"550" 
    coffeescript ->
      $(document).ready ->
         $.get '/users', (users) ->
           $('#user_table').dataTable
             aaData:users
             sAjaxDataProp:""
             aoColumns:[
               'mData':'rfid'
               #sTitle:"RFID"
             ,
               mData:'first_name'
               #sTitle:"name"
             ,
               mData:"last_name"
             ,
               mData:"email"
             ,
               mData:"twitter_handle"
             ,
              mData: "tokens.untappd"
              sDefaultContent:""
              fnCreatedCell: (td,d, oData) ->
                #$(td).append('
                #$switch = $(td).append('<div class="switch switch-mini" data-on="warning" data-off=""><input value="untappd" type="checkbox" '+ (if d and d isnt "" then 'checked="checked"' else '') + ' ></div>')
                $switch = $(td).find('div.switch').bootstrapSwitch()
                $(td).find('div.switch').on 'switch-change', (e,data) ->
                  #$(this).bootstrapSwitch 'setState', false
                  $.get '/users/' +   oData.rfid + '/authurl/untappd', (res) ->
                    authorizeUntappd (
                      untappd_enabled:true
                      untappd_auth_url:res.authurl
                      )
              mRender: (d) ->
                #(if d or d isnt "" then true else false)
                '<div class="switch switch-mini" data-on="warning" data-off=""><input value="untappd" type="checkbox" '+ (if d and d isnt "" then 'checked="checked"' else '') + ' ></div>'
                   
             ,
              mRender:()->
                '<button class="btn"><i class="icon-edit"></i></button>'
             ]
             fnDrawCallback:()->
               #$('#user_table div.switch').bootstrapSwitch();
               
           #$.each users, (i, user)->
             
             #$('#user_table').append('<tr><td>'+ user.first_name + '</td></tr>')
        window.modalChecker =null
        
        authorizeUntappd = (user) ->
          if user.untappd_enabled is false
            bootbox.confirm 'Thank you for signing up!  Unfortunately Untappd is not enabled at this time'
            $('.control-group.untappd').hide();
            return true
           #$('#authorizeUntappd').modal('show')
           #$('#authorizeUntappd iframe').attr('src','https://untappd.com/oauth/authenticate/?client_id=CCB4D76D28137142C30DABB44E9B3F3ECD2654D8&client_secret=5C8A258F1799389A874C997922F8B7C96086EE79&response_type=token&redirect_url=http://localhost:8081/signup');
           #           http://untappd.com/oauth/authenticate/?client_id="+id+"&response_type=token&redirect_url="+returnRedirectionURL;
           #authurl = 'https://untappd.com/oauth/authenticate/?client_id=CCB4D76D28137142C30DABB44E9B3F3ECD2654D8&client_secret=5C8A258F1799389A874C997922F8B7C96086EE79&response_type=code&redirect_url=http://localhost:8081/users/'+user.rfid+'/untappd&code=COD'
           authurl = user.untappd_auth_url
           #window.open authurl , 'untappd'
           #bootbox.confirm '<h2>Link keg.io to Untappd <img src="http://untappd.com/favicon.ico" /><iframe id="untappdFrame" src="'+authurl+' style="width:550;height:800;margin:0;padding:0;" width="550" height="800" />"', (result)->
             #console.log result
           $('#untappd-modal').modal('show').find('iframe').attr('src',authurl)
           window.modalChecker = window.setInterval( ()->
             if document.getElementById("untappd-frame").contentDocument
               window.clearInterval(window.modalChecker)
               $('#untappd-frame').hide()
               #this logs out user that just linked accounts
               img = new Image 1,1
               img.src = 'http://untappd.com/logout'
               document.body.appendChild img
               #need to not destroy the content as we'll want to re-use
               $('#untappd-modal .modal-body').remove('div.well').append('<div class="well"><h1>Sucessfully Authorized Untappd</h1></div>')
               window.setTimeout ()->
                 $('#untappd-modal').modal('hide')
                 $('#linkUntappd').attr('disabled','disabled').addClass('disabled')
               ,3000
             
           , 1000)
      
