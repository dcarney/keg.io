/* Author: Chris Castle & Dylan Carney

*/
var temperatureHistoryChart;
var pourHistoryChart;
var flowData = [];
var flowRateGauge;
var tempGauge;
var beerGauge;
var g_pourHistoryChart;   
var g_pourHistoryAllTimeChart;
// temperature history chart options

var beerGaugeOptions = {
	redFrom:0,
	redTo: 10,
	yellowFrom:10,
	yellowTo:30,
	yellowColor: '#FF6E00',
	greenFrom:80,
	greenTo:100,
	width: 150,
	height: 150,
	data : {}
}


var tempGaugeOptions = {
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
	width:150,
	height:150,
	data:{}
}

var flowRateGaugeOptions = {
	redFrom:70,
	redTo:80,
	yellowFrom:60,
	yellowTo:70,
	yellowColor: '#FF6E00',
	width:150,
	height:150,
	min: 0,
	max: 80,
	data:{}
}


var drawGauges = function(){
	    tempGaugeOptions.data = new google.visualization.DataTable();
        tempGaugeOptions.data.addColumn('string', 'Label');
        tempGaugeOptions.data.addColumn('number', 'Value');
        tempGaugeOptions.data.addRows(1);
        tempGaugeOptions.data.setValue(0, 0, 'Temp °F');
        tempGaugeOptions.data.setValue(0, 1, 0);
        
        flowRateGaugeOptions.data = new google.visualization.DataTable();
        flowRateGaugeOptions.data.addColumn('string', 'Label');
        flowRateGaugeOptions.data.addColumn('number', 'Value');
        flowRateGaugeOptions.data.addRows(1);
        flowRateGaugeOptions.data.setValue(0, 0, 'Flow');
        flowRateGaugeOptions.data.setValue(0, 1, 0);
        
      	tempGauge = new google.visualization.Gauge(document.getElementById('temp_chart'));
        tempGauge.draw(tempGaugeOptions.data , tempGaugeOptions);
        
        flowRateGauge =  new google.visualization.Gauge(document.getElementById('flow_chart'));
        flowRateGauge.draw(flowRateGaugeOptions.data,flowRateGaugeOptions);
        window.setInterval(needleBump,100);
        
	    beerGaugeOptions.data = new google.visualization.DataTable();
        beerGaugeOptions.data.addColumn('string', 'Label');
        beerGaugeOptions.data.addColumn('number', 'Value');
        beerGaugeOptions.data.addRows(1);
        beerGaugeOptions.data.setValue(0, 0, 'Beer %');
        beerGaugeOptions.data.setValue(0, 1, 0);
        beerGauge =  new google.visualization.Gauge(document.getElementById('beer_chart'));
        beerGauge.draw(beerGaugeOptions.data,beerGaugeOptions);
}

var needleBump = function(){
	if(flowRateGaugeOptions.data.getValue(0, 1)!=0){
		var bump = Math.random()>.5?1:-1;
		var nv = flowRateGaugeOptions.data.getValue(0, 1) + bump;
		flowRateGaugeOptions.data.setValue(0,1,nv);
		flowRateGauge.draw(flowRateGaugeOptions.data,flowRateGaugeOptions);
	}
}
     
     
var googleDatafy  = function(g_data,json){
	
	var values = json.value;
	g_data.addRows(values.length);
	for(var i = 0; i < values.length; i++){
		var tv = values[i];
		for(var z = 0; z < tv.length; z ++){
			g_data.setValue(i,z,tv[z]);
		}
	
	}
	return g_data;
	
}


var kegio = {
	
	
	accessKey: '1111',

  getSocketPort: function(callback){
  		return this.sendRequest('/config/socketPort',callback);
  		
  	}	,
  	
  	getLastDrinkers: function(callback,n){
  		if(n==null){
  			n=1;
  		}
  		this.sendRequest('/kegerators/'+this.accessKey+'/users?recent='+n,callback);
  		
	},

	getCurrentTemp: function(callback){
		this.sendRequest('/kegerators/'+this.accessKey+'/temperatures',callback);
		
   },
	
	getKegs: function(callback, n){
			if(n==null){
				n = 1;	
			}
			this.sendRequest('/kegerators/' + this.accessKey + '/kegs?recent=' + n,callback);
			
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

 pageAuth: function(data) {
       display_name = data.data.display_name;
       user_name = data.data.user_name;
       $('#userinfo').toggle();
       $('div.intro').html('Welcome, <span style="color: #eee;">' + data.data.display_name + '</span><br />' + data.data.email + '<br /><a class="profile_link" href="profile.html">Profile</a> | <a href="/doc/toc.html" target="_blank">API Docs</a> | <a id="logout" href="login.html">Logout</a>');
       $('img.avatar').attr('src', 'https://secure.gravatar.com/avatar/' + Crypto.MD5(data.data.email) + '?s=50&d=mm');
       $('img.avatar').attr('alt', 'setup image at www.gravatar.com');
       $('#logout').click(function() {
           token = null;
           environment = null;
       });
       $('.profile_link').live('click', function() {
           var exp = new Date();
           exp.setMinutes(exp.getMinutes() + 1);
           $.cookie('token', token, exp);
       });
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
               // Uncomment this and comment json block to use msgpack
               //if (url.indexOf("?") != -1) {
               // url = url + "&format=msgpack";
               //}else {
               //  url = url + "?format=msgpack";
               //}
               //
               //msgPackCallback = function(data, options, status) {
               //      if(status.ok) {
               //              callback(data);
               //      } else {
               //              error(data);
               //      }
               //}
               //msgpack.download(url, {method: method}, msgPackCallback);
 
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