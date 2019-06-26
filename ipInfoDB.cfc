component {

	function init(
		required string apiKey
	,	string apiUrl= "http://api.ipinfodb.com"
	,	numeric throttle= 1000
	,	numeric httpTimeOut= 60
	,	boolean debug= ( request.debug ?: false )
	) {
		this.apiUrl= arguments.apiUrl;
		this.apiKey= arguments.apiKey;
		this.throttle= arguments.throttle;
		this.httpTimeOut= arguments.httpTimeOut;
		this.debug= arguments.debug;
		this.lastRequest= server.ipinfo_lastRequest ?: 0;
		return this;
	}

	function debugLog( required input ) {
		if ( structKeyExists( request, "log" ) && isCustomFunction( request.log ) ) {
			if ( isSimpleValue( arguments.input ) ) {
				request.log( "ipInfoDB: " & arguments.input );
			} else {
				request.log( "ipInfoDB: (complex type)" );
				request.log( arguments.input );
			}
		} else if( this.debug ) {
			cftrace( text=( isSimpleValue( arguments.input ) ? arguments.input : "" ), var=arguments.input, category="ipInfoDB", type="information" );
		}
		return;
	}

	string function getRemoteIp(){
		if( len( cgi.http_x_cluster_client_ip)  ) {
			return trim( listFirst( cgi.http_x_cluster_client_ip ) );
		}
		if( len( cgi.http_x_forwarded_for ) ) {
			return trim( listFirst( cgi.http_x_forwarded_for ) );
		}
		return cgi.remote_addr;
	}

	struct function ipCity( string ip= this.getRemoteIp() ) {
		var args= {
			"key"= this.apiKey
		,	"method"= "/v3/ip-city/?format=json"
		,	"ip"= arguments.ip
		};
		var out= this.apiRequest( argumentCollection= args );
		if ( out.success ) {
			// process 
			try {
				structAppend( out, deserializeJSON( out.response ) );
			} catch (any cfcatch) {
				out.error &= " JSON Error: " & (cfcatch.message?:"No catch message") & " " & (cfcatch.detail?:"No catch detail") & "; ";
			}
		}
		return out;
	}

	struct function ipCountry( string ip= this.getRemoteIp() ) {
		var args= {
			"key"= this.apiKey
		,	"method"= "/v3/ip-country/?format=json"
		,	"ip"= arguments.ip
		};
		var out= this.apiRequest( argumentCollection= args );
		if ( out.success ) {
			// process 
			try {
				structAppend( out, deserializeJSON( out.response ) );
			} catch (any cfcatch) {
				out.error &= " JSON Error: " & (cfcatch.message?:"No catch message") & " " & (cfcatch.detail?:"No catch detail") & "; ";
			}
		}
		return out;
	}

	struct function apiRequest() {
		var http= 0;
		var item= "";
		var out= {
			url= this.apiUrl & arguments.method
		,	success= false
		,	error= ""
		,	status= ""
		,	response= ""
		,	delay= 0
		};
		var sAppend= find( "?", out.url ) ? "&" : "?";
		structDelete( arguments, "method" );
		for ( item in arguments ) {
			out.url &= sAppend & lCase( item ) & "=" & replace( urlEncodedFormat( lCase( arguments[ item ] ) ), "%20", "+", "all" );
			sAppend= "&";
		}
		if ( this.throttle > 0 && this.lastRequest > 0 ) {
			out.delay= this.throttle - ( getTickCount() - this.lastRequest );
			if ( out.delay > 0 ) {
				this.debugLog( "Pausing for #out.delay#/ms" );
				sleep( out.delay );
			}
		}
		this.debugLog( out.url );
		cfhttp( charset="utf-8", throwOnError=false, url=out.url, timeOut=this.httpTimeOut, result="http", method="GET" );
		if ( this.throttle > 0 ) {
			this.lastRequest= getTickCount();
			server.ipinfo_lastRequest= this.lastRequest;
		}
		out.response= toString( http.fileContent );
		// this.debugLog( out.response );
		out.statusCode= http.responseHeader.Status_Code ?: 500;
		if ( left( out.statusCode, 1 ) == 4 || left( out.statusCode, 1 ) == 5 ) {
			out.error= "status code error: #out.statusCode#";
		} else if ( out.response == "Connection Timeout" || out.response == "Connection Failure" ) {
			out.error= out.response;
		} else if ( left( out.statusCode, 1 ) == 2 ) {
			out.success= true;
		}
		if ( len( out.error ) ) {
			out.success= false;
		}
		if( !out.success ) {
			this.debugLog( out );
		}
		return out;
	}

}