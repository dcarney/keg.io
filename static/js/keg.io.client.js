

var kegio = {
	
	
	accessKey: '1111',

  gauges:[ 
  {
      target:'flow_chart',
      type:'gauge',
      label:'Flow',
      data:0,
      options:{ 
                redFrom:70,
                redTo:80,
                yellowFrom:60,
                yellowTo:70,
                yellowColor: '#FF6E00',
        width:135,
        height:135,
                min: 0,
                max: 80
              }   
  
    },{
      target:'temp_chart',
      type:'gauge',
      label:'Temp °F',
      data:function(callback){
        kegio.getCurrentTemp(callback);
      },
      update:function(){
        kegio.getCurrentTemp(callback,this.target);
      },
      options:{
                min:30,
                max:70,
                greenFrom:30,
                greenTo:48,
                greenColor:'#1FD8D8',
                yellowFrom:48,
                yellowTo:60,
                yellowColor: '#FF6E00',
                redFrom:60,
                redTo:70,
                redColor: 'red',
                width:135,
                height:135
              }


    },{
      target:'beer_chart',
      type:'gauge',
      label:'Beer',
      data:0,
      options:{
        redFrom:0,
        redTo:10,
        yellowFrom:10,
        yellowTo:30,
        yellowColor: '#FF6E00',
        greenFrom:80,
        greenTo:100,
        width:135,
        height:135
      }
    }
      ]
  ,

needleBump : function(){
  flowchart = charts['flow_chart'];
  if(flowchart.data.getValue(0, 1)!=0){
    var bump = Math.random()>.5?1:-1;
    var nv = flowchart.data.getValue(0, 1) + bump;
    flowchart.data.setValue(0,1,nv);
    flowchart.draw(flowchart.data,flowchart.options);
  }
},
     
     
googleDatafy: function(g_data,json){
  
  var values = json.value;
  g_data.addRows(values.length);
  for(var i = 0; i < values.length; i++){
    var tv = values[i];
    for(var z = 0; z < tv.length; z ++){
      g_data.setValue(i,z,tv[z]);
    }
  
  }
  return g_data;
  
},

  getSocketPort: function(callback){
  		return this.sendRequest('/config/socketPort',callback);
  		
  	}	,
  	
  getLastDrinkers: function(callback,n){
  		if(n==null){
  			n=1;
  		}
  		this.sendRequest('/kegerators/'+this.accessKey+'/users?recent='+n,callback);
  		
	},

  getLastDrinker: function(callback){

      this.sendRequest('/kegerators/' + this.accessKey + '/lastdrinker',callback);
  },

	getCurrentTemp: function(callback,target){
		  this.getTemperatures(function(data){
        callback(data[0].temperature,target);
      },1);
   },

   getTemperatures : function (callback, n){
      this.sendRequest('/kegerators/'+this.accessKey+'/temperatures?recent='+n,callback);
   },
	
	getKegs: function(callback, n){
			if(n==null){
				n = 1;	
			}
			this.sendRequest('/kegerators/' + this.accessKey + '/kegs?recent=' + n,callback);
			
		},

    getPours : function(callback, n){
      n = n==null?1:n;
      this.sendRequest('/kegerators/' + this.accessKey + '/pours?recent='+n,callback);
    },

    getUsers : function(callback){
      this.sendRequest('/users',callback);
    },

    getUserInfo : function(rfid,callback){
        this.sendRequest('/users/'+rfid,function(users){
          callback(users[0]);
        });
    },

    getUserCoasters : function(rfid,callback){
        this.sendRequest('/coasters/'+rfid,callback);
    },

    getCoasters:function(callback){
        this.sendRequest('/coasters');
    },


	
	
  handleError: function(data) {
       if (typeof data.data == 'undefined'){
            var data = jQuery.parseJSON(data.responseText);
       }
       if (typeof data.code == 'undefined'){
               data.code = 'N/A';
       }
       new Notification('<strong>' + data.status.toUpperCase() + '</strong> ' + data.data + ' - Error Code: ' + data.code, 'error');
   },

 
   inDeveloperMode: function() {
       return $('#devmode').is(':checked');
   },
 
   // display nicely formatted API request details before sending it to API server
    formatAndConfirmRequest: function(method, url, data, callback) {
       if ( this.inDeveloperMode() ) {
           var request = $('<div></div>');
 
           var urlArray = url.split('?');
           var path = urlArray[0];
           var queryString = urlArray.length > 1 ? urlArray[1] : '';
           var dataString = data;
 
           var curlCommand = 'curl -i -H "Accept: application/json" -k' +
                               ' "' + window.location.protocol + '//' +
                               window.location.host +
                               path +
                               (queryString && queryString.length > 0 ? '?' + queryString + '"': '"') +
                               ' -X ' + method +
                               (dataString && dataString.length > 0 ? ' -d "' + dataString + '"' : '') +
                               ' --user ' + user_name;
 
                        $(request).append('The GUI is about to make a Brainstem API request on your behalf. ' +
                                                                'The exact same request can be made on the command line using the ' +
                                                                '<a href="http://curl.haxx.se/" target="_blank">cURL</a> command below.<br /><br />' +
                                                                'Click the command text to highlight it, Ctrl/Command+C, then paste it on the command line to see it in action.<br /><br />' +
                                                                'You will be prompted for your password so that it will not be shown in plain text.<br /><br />');
           $(request).append('<pre><code>' + curlCommand + '</pre></code><br /><br />');
           $(request).append('Continuing sending request to server?');
           $(request).dialog({ buttons: { "Ok": function() { $(this).dialog("close"); callback(true); },
                                          "Cancel": function() { $(this).dialog("close"); callback(false); }
                                        },
                               modal: true,
                               title: 'Request Details',
                               width: 700
                            });
 
           // select the full text of the curl command by single-clicking
           $('code').click(function() {
                $(this).selectText();
           });
       } else {
           callback(true);
       }
   },
   

 
sendRequest: function(url, callback, error, method, data) {
       //method is optional param, as default behavior is just "GET me that stuff, yo"
       if (typeof method == 'undefined' || method == null) method = 'GET';
       //so is error, but give it a default catch-all for sure
       if (typeof error == 'undefined' || error == null) error = this.handleError;
 
       this.formatAndConfirmRequest(method, url, data, function(status) {
           if (status == false) {
               error( { status: 'ab /config/socketPortorted', data: 'User cancelled request.', code: 'N/A' } );
               return;
           } else {
 
               $.ajax({
                   type: method,
                   url: url,
                   data: data,
                   dataType: 'json',
                   beforeSend: function(xhr) {
                      // xhr.setRequestHeader("Authorization", "Basic " + token);
                   },
                   success: callback,
                   error: error
               });
           }
       });
   }


}