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
            
                        #untappd-modal .modal-body{
              max-height: 600px;
            }
            
            #untappd-modal {
              width: 600px;
              text-align: center;
              /*margin: -320px 0 0 -280px;*/
            }
            
            #untappd-modal .modal-body .label {
              font-size: 1.2em;
              
            }
            
            #untappd-modal iframe{
              border: 0;
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
          div class:"well success", style:"display:none;", ->
            h1 'Sucessfully Authorized Untappd'
      div id:'user_form', class:'modal hide', role:'dialog',->
        div class:'modal-header',->
          button type:'button',class:'close','data-dismiss':'modal', 'aria-hidden':'true',->'x'
          h3 ->'Edit User'
        div class:'modal-body',->
          form class: 'form-horizontal', ->
            fieldset ->
   
              div class: "control-group", ->
                label class: "control-label", 'RFID'
                div class: "controls", ->
                  input id: 'rfid', type:"text", placeholder:"RFID tag #", class: "input-xlarge"
                  p class: "help-block", 'This was given to you along with your RFID tag'
    
              div class: "control-group", ->
                label class: "control-label", for:"input01", 'First Name'
                div class: "controls", ->
                  input id:'first_name', type:"text", placeholder:"first name", class: "input-xlarge"
                  p class: "help-block"
    
              div class: "control-group", ->
                label class: "control-label", for: "input01", 'Last Name'
                div class: "controls", ->
                  input id:'last_name',  type:"text", placeholder:"last name", class: "input-xlarge"
                  p class: "help-block"
    
              div class: "control-group", ->
                label class: "control-label", for:"input01", 'Email'
                div class: "controls", ->
                  input id:'email', type:"text", placeholder:"email", class: "input-xlarge"
                  p class: "help-block", ->
                    span ->'This is only used to display your keg.io'
                    a href:'http://en.gravatar.com/', -> ' gravatar'
    
              div class: "control-group", ->
                label class: "control-label", 'Twitter Username'
                div class: "controls", ->
                  div class: "input-prepend", ->
                    span class: "add-on", '@'
                    input id:'twitter', class: "span2", placeholder: "twitter username",  type:"text"
                    #p class: "help-block", ->
                     # a href:'https://twitter.com/keg_io', -> 'keg.io will mention you '
                     # span -> 'in relevant tweets!'
    
            #   div class: "control-group untappd", ->
             #     label class: "control-label", ->
            #        text 'Untappd'
            #        img src:'http://untappd.com/favicon.ico'
            #      div class:"controls",->
                    #label -> 'Link my account to Untappd (you will be prompted to authorize keg.io after sucessful registration)'
            #        div class:'switch switch-small', 'data-on':'warning', 'data-off':' ', ->
           #           input id:'authUntappd', type:'checkbox', value:'on'
                    #button id:'linkUntappd', type: 'button', disabled:'disabled',class:'btn disabled', -> 
                    #  img src:"http://untappd.com/favicon.ico"
                     # text 'Link Untappd'
                   # p class:"help-block",->
                   #   a href:"http://untappd.com/", target:"_blank", -> "Untappd social drinking app, "
                    #  text "keg.io will check you into brews at this keg"
        div class:'modal-footer', ->
          button class:'btn', 'data-dismiss':'modal', 'aria-hidden':'true', -> 'Cancel'
          button id:'update_user_btn', class:'btn btn-success', -> 'Update User'
               # div class: "control-group", ->
                #     label class: 'control-label'
                #     div class: 'controls', ->
                 #      button id:'signup', type: 'button', class:'btn btn-success', 'Sign up!'
                       
    coffeescript ->
      $(document).ready ->
           $('#update_user_btn').click updateUser
         #$.get '/users', (users) ->
           $('#user_table').dataTable
             #aaData:users
             bProcessing:true
             sAjaxSource:'/users'
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
                  if data.value is true
                    $.get '/users/' +   oData.rfid + '/authurl/untappd', (res) ->
                      authorizeUntappd (
                        untappd_enabled:true
                        untappd_auth_url:res.authurl
                        )
                  else
                    #send untappd clear token
              mRender: (d) ->
                #(if d or d isnt "" then true else false)
                '<div class="switch switch-mini" data-on="warning" data-off=""><input value="untappd" type="checkbox" '+ (if d and d isnt "" then 'checked="checked"' else '') + ' ></div>'
                   
             ,
              mRender:()->
                '<button class="btn"><i class="icon-edit"></i></button>'
              fnCreatedCell:(td,d,oData) ->
                $(td).find('button').click () ->
                  modalEdit oData
             ]
             fnDrawCallback:()->
               #$('#user_table div.switch').bootstrapSwitch();
               
           #$.each users, (i, user)->
             
             #$('#user_table').append('<tr><td>'+ user.first_name + '</td></tr>')
        
        
  
        modalEdit = (user) ->
          for k of user
            $('#'+ k).val(user[k]);
          $('#twitter').val(user.twitter_handle.replace('@',''));

          $('#user_form').modal('show')
        
        window.modalChecker =null
        
        updateUser = ()->
          user =
            email: $('#email').val()
            rfid: $('#rfid').val()
            first_name: $('#first_name').val()
            last_name: $('#last_name').val()
            twitter_handle: '@' + $('#twitter').val()
            link_untappd:$('#authUntappd').attr('checked')
            
          $.ajax
            type: 'PUT'
            url: '/users/'+user.rfid
            data: JSON.stringify user
            contentType: 'application/json'
            dataType: "json"
            error: (jqxhr) ->
              console.log "ERROR: #{jqxhr.status}"
              alert 'Hmmm...that didn\'t work.  Did you enter the correct RFID tag?'
            success: (response) ->
              $('#user_form').modal('hide')
              


        logoutUntappd = ()->
          img = new Image 1,1
          img.src = 'http://untappd.com/logout?'+Math.random()
          document.body.appendChild img
        
        authorizeUntappd = (user) ->
          #make sure we're logged out since this is an all-user admin
          logoutUntappd
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
           $('#untappd-modal').modal('show').find('iframe').show().attr('src',authurl)
           $('#untappd-modal .modal-body .success').hide();
           window.modalChecker = window.setInterval( ()->
             if document.getElementById("untappd-frame").contentDocument
               window.clearInterval(window.modalChecker)
               $('#untappd-frame').hide()
               #this logs out user that just linked accounts
               logoutUntappd
               #need to not destroy the content as we'll want to re-use
               $('#untappd-modal .modal-body .success').show();
               $('#untappd-modal .modal-body iframe').hide();
               #$('#untappd-modal .modal-body').remove('div.well').append('<div class="well" id="untappd_success"><h1>Sucessfully Authorized Untappd</h1></div>')
               window.setTimeout ()->
                 $('#untappd-modal').modal('hide')
                 $('#linkUntappd').attr('disabled','disabled').addClass('disabled')
               ,3000
             
           , 1000)
      
