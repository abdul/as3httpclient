package code.google.as3httpclient
{
	import flash.net.URLRequestMethod;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.net.URLVariables;
	import flash.net.URLRequestHeader;
	
	/**
	 * This class is used by the SocketURLLoader class. The URLRequest class could not be extended,
	 * which is the reason that this class exists. It will extract more information from the url
	 * then the normal URLRequest.
	 * 
	 * @see SocketURLLoader
	 * @see http://livedocs.adobe.com/flex/2/langref/flash/net/URLRequest.html flash.net.URLRequest
	 */
	public class SocketHTTPRequest
	{
		/**
		 * Will create an instance of SocketHTTPRequest from the given URLRequest.
		 * 
		 * @param request The request used to create the SocketHTTPRequest instance.
		 */
		static public function createInstanceFromURLRequest(request:URLRequest):SocketHTTPRequest
		{
			var instance:SocketHTTPRequest = new SocketHTTPRequest();
			instance.url = request.url;
			instance.data = request.data;
			if (request.contentType)
			{
				instance.contentType = request.contentType;
			}
			instance.method = request.method;
			instance.requestHeaders = request.requestHeaders;
			
			return instance;
		}
		
		/**
		 * The contentType of the request, the default value is ContentType.APPLICATION_X_WWW_FORM_URLENCODED
		 * 
		 * @see ContentType
		 */
		public var contentType:String;
		
		/**
		 * The request headers to be included in the request. Note that the Content-Length header 
		 * is automatically set is the content has length. The Content-Type header is also 
		 * included by default.
		 */
		public var requestHeaders:Array;
		
		/**
		 * The given data will be handled differently depending on a few variables.<br />
		 * <br />
		 * If method is set to POST and contentType is set to ContentType.APPLICATION_X_WWW_FORM_URLENCODED:
		 * If data is ByteArray it will be written as is to the request, else the toString() method will 
		 * be called and the result will be written to the request.<br />
		 * <br />
		 * If method is set to POST and contentType is set to ContentType.MULTIPART_FORM_DATA:<br />
		 * If data is URLVariables it will create a part for each entry. This part will look 
		 * like this:<br />
		 * <br />
		 * "--{separator}"<br />
		 * Content-Disposition: form-data; name="{urlVariableName}"<br />
		 * {content}<br />
		 * <br />
		 * {separator} will be replaced by the separator.<br />
		 * {urlVariableName} will be replaced by the name of the the URLVariables entry.<br />
		 * {content} will be replaced by the data. If data is ByteArray it will be written directly, 
		 * 			 else the toString() method will be called and the result will be written.<br />
		 * @see http://livedocs.adobe.com/flex/2/langref/flash/utils/ByteArray.html flash.utils.ByteArray
		 * @see http://livedocs.adobe.com/flex/2/langref/flash/net/URLVariables.html flash.net.URLVariables
		 * 
		 * @throws ArgumentError Is thrown when method is POST,ContentType.MULTIPART_FORM_DATA and the data
		 * 						 is NOT of type URLVariables.
		 */
		public var data:Object;
		
		/*
			Getters / setters
		*/
		private var _url:String;
		private var _method:String;
		
		/*
			Getters
		*/
		private var _port:int;
		private var _baseURL:String;
		private var _extendedURL:String;

		private var _userAgent:String = "as3httpclient";
		
		/**
		 * Creates a new SocketHTTPRequest.<br />
		 * Defeaults the method to SocketURLRequestMethod.GET and contentType to 
		 * ContentType.APPLICATION_X_WWW_FORM_URLENCODED.<br />
		 * <br />
		 * Note that the SocketHTTPRequest currently only supports urls that start 
		 * with http://.<br />
		 * @param url If given it will be passed to the url setter.
		 */
		public function SocketHTTPRequest(url:String = null)
		{
			requestHeaders = new Array();
			contentType = ContentType.APPLICATION_X_WWW_FORM_URLENCODED;
			method = SocketURLRequestMethod.GET;
			if (url)
			{
				url = url;
			}
		}
		
		private function parseURL():void
		{
			var url:String = _url;

			/*
				In the code below the url is parsed. This should be replaced by a 
				regular expression to reduce the amount of code.
			
				We currently only support requests that start with http://
			*/
			if (url.substr(0, 7) == "http://")
			{
				/*
					ignore authentication entry, use request headers to apply authentication
					In a future version we might decide to automatically convert these entries
					into an authentication header
				*/
				var authenticationEnd:int = url.indexOf("@");
				
				var hasAuthentication:Boolean;
				if (authenticationEnd > -1)
				{
					hasAuthentication = true;
				} else
				{
					authenticationEnd = 7;
				}
				
				/*
					Find the start of the port
				*/
				var portStart:int = url.indexOf(":", authenticationEnd);
				var hasPort:Boolean;
				var portEnd:int;
				
				if (portStart > -1)
				{
					/*
						port found, extract it
					*/
					hasPort = true;
					portEnd = url.indexOf("/", portStart);
					if (portEnd == -1)
					{
						portEnd = url.length;
					}
					_port = parseInt(url.substring(portStart + 1, portEnd));
				}
				
				/*
					The next if statement will extract the base url and set the extendedURLStart
					variable
				*/
				var extendedURLStart:int;
				if (hasAuthentication && hasPort)
				{
					_baseURL = url.substring(authenticationEnd + 1, portStart);
					extendedURLStart = portEnd;
				} else if (hasAuthentication)
				{
					extendedURLStart = url.indexOf("/", authenticationEnd);
					if (extendedURLStart == -1)
					{
						extendedURLStart = url.length;
					}
					
					_baseURL = url.substring(authenticationEnd + 1, extendedURLStart);
				} else if (hasPort)
				{
					_baseURL = url.substring(7, portStart);
					extendedURLStart = portEnd;
				} else
				{
					extendedURLStart = url.indexOf("/", 7);
					if (extendedURLStart == -1)
					{
						extendedURLStart = url.length;
					}
					
					_baseURL = url.substring(7, extendedURLStart);				
				}
				
				/* 
					if the extendedURLStart is smaller then the total url, get it from the url
				*/
				if (extendedURLStart > -1 && extendedURLStart < url.length)
				{
					_extendedURL = url.substr(extendedURLStart);
				}
			} else
			{
				throw new Error("SocketHTTPRequest: could not parse url, the url did not start with 'http://', this feature is not implemented yet");
			}
		}
		
		/**
		 * This method will construct the request and return it as a ByteArray. This 
		 * ByteArray can be used directly to make the request on the socket.
		 * 
		 * @see http://livedocs.adobe.com/flex/2/langref/flash/utils/ByteArray.html flash.utils.ByteArray
		 */
		public function constructRequest():ByteArray
		{
			/*
				If the method is POST, call both constructHeader and __constrcutData methods.
			*/
			
			var methodIsPost_bool:Boolean = (method == SocketURLRequestMethod.POST) || (method == SocketURLRequestMethod.PUT);
			
			var requestBA:ByteArray;
			if (methodIsPost_bool)
			{
				/*
					Create a boundary variable which might be needed for the MultiPart
					content type.
				*/
				var boundary:String = "------------Ij5Ef1Ef1Ij5Ij5cH2ei4gL6KM7KM7";
				
				var dataBA:ByteArray = constructData(boundary);
				var contentLength:Number = dataBA.length;
				if (contentType == ContentType.MULTIPART_FORM_DATA)
				{
					contentLength -= 4;
				}
				requestBA = constructHeader(contentLength, boundary);
				//add data
				requestBA.writeBytes(dataBA, 0, dataBA.length);
			} else
			{
				requestBA = constructHeader(0, null);
			}
			
			return requestBA;
		}
		
		/**
		 * This method constructs the header of the request.
		 * 
		 * @param contentLength The length of the content.
		 * @param boundary The boundary which is only used if contentType is ContentType.MULTIPART_FORM_DATA
		 */
		protected function constructHeader(contentLength:Number, boundary:String):ByteArray
		{
			var header:String = "";
			
			/*
				Add data to the extended URL if its given and the method is GET
			*/
			var extendedUrl:String = extendedURL ? extendedURL : "/";
			
			if ((method == SocketURLRequestMethod.GET || method == SocketURLRequestMethod.HEAD || method == SocketURLRequestMethod.DELETE) && data)
			{
				if (extendedUrl.indexOf("?") == -1)
				{
					extendedUrl += "?";
				}
				
				extendedUrl += data.toString();
			}
			
			/*
				Create the first line of the header
			*/
			header += method + " " + extendedUrl + " HTTP/1.1" + HTTP_SEPARATOR;

			/*
				Add user-agent header
			*/
			header += "User-Agent: " + _userAgent + HTTP_SEPARATOR;

			/*
				If a content length is given, add the request header for it
			*/
			if (contentLength)
			{
				header += "Content-Length: " + contentLength + HTTP_SEPARATOR;
			}
			
			/*
				Add the content type
			*/
			if (contentType)
			{
				header += "Content-Type: " + contentType;
			}
			
			/*
				If the content type is of multipart, add a boundary
			*/
			if (contentType == ContentType.MULTIPART_FORM_DATA)
			{
				header += "; boundary=" + boundary;
			}
			header += HTTP_SEPARATOR;

			/*
				Add additional request headers
			*/
			if(requestHeaders)
			{
				var requestHeader:URLRequestHeader;
				for each (requestHeader in requestHeaders)
				{
					header += requestHeader.name + ": " + requestHeader.value + HTTP_SEPARATOR;
				}
			}
			
			/*
				Add the host of the request
			*/
			var serverURL:String = baseURL;
			if (port)
			{
				serverURL += ":" + port;
			}			
			header += "Host: " + serverURL + HTTP_SEPARATOR;
			
			/*
				End the header
			*/
			header += HTTP_SEPARATOR;
			
			var headerBA:ByteArray = new ByteArray();
			headerBA.writeUTFBytes(header);
			
			return headerBA;
		}
		
		/**
		 * This method constructs the data that is send with the request. More information on 
		 * how data is handled can be found at the data property.
		 * 
		 * @see #data
		 */
		protected function constructData(boundary:String):ByteArray
		{
			var dataBA:ByteArray = new ByteArray();
			
			if (data)
			{
				
				switch (contentType)
				{
					default:
					case ContentType.APPLICATION_X_WWW_FORM_URLENCODED:
						
						if (data is ByteArray)
						{
							dataBA.writeBytes(data as ByteArray, 0, (data as ByteArray).length);
						} else
						{
							dataBA.writeUTFBytes(data.toString());
						}
						
						break;
					case ContentType.MULTIPART_FORM_DATA:
					
						if (data is URLVariables)
						{
							
							var i:String;
							var value:Object;
							
							for (i in data)
							{
								value = data[i];
								dataBA.writeUTFBytes("--" + boundary + HTTP_SEPARATOR);
								dataBA.writeUTFBytes("Content-Disposition: form-data; name=\"" + i + "\"" + HTTP_SEPARATOR);
								dataBA.writeUTFBytes(HTTP_SEPARATOR);
								if (value is ByteArray)
								{
									dataBA.writeBytes(value as ByteArray, 0, (value as ByteArray).length);
								} else
								{
									dataBA.writeUTFBytes(value.toString());
								}
								dataBA.writeUTFBytes(HTTP_SEPARATOR);
							}							
							dataBA.writeUTFBytes("--" + boundary + "--" + HTTP_SEPARATOR);
						} else
						{
							throw new ArgumentError("SocketHTTPRequest: cannot create data stream when content type is set to MULTIPART_FORM_DATA and data is not of type URLVariables");
						}
					
						break;
					
				}
			}
			
			return dataBA;			
		}
		
		/**
		 * The url of the request. Note that currently only url's which start with http://
		 * can be parsed.
		 */
		public function get url():String
		{
			return _url;
		}
		
		public function set url(url:String):void
		{
			_url = url;
			parseURL();
		}
		
		/**
		 * The method of the request. The default method is GET, valid values are 
		 * SocketURLRequestMethod.DELETE, SocketURLRequestMethod.GET, SocketURLRequestMethod.HEAD, SocketURLRequestMethod.OPTIONS,
		 * URLRequestMethod.POST and SocketURLRequestMethod.TRACE
		 * 
		 * @see #code.google.as3httpclient.SocketURLRequestMethod
		 * 
		 * @throws ArgumentError is the given method is not valid.
		 */
		public function get method():String
		{
			return _method;
		}
		
		public function set method(value:String):void
		{
			if (value == SocketURLRequestMethod.GET || value == SocketURLRequestMethod.POST
				|| value == SocketURLRequestMethod.PUT || SocketURLRequestMethod.DELETE || SocketURLRequestMethod.HEAD
				|| value == SocketURLRequestMethod.OPTIONS || value == SocketURLRequestMethod.TRACE)			
			{
				_method = value;
			} else
			{
				throw new ArgumentError("SocketHTTPRequest: invalid method given, use values stored in the SocketURLRequestMethod class");
			}
		}
		
		/**
		 * Gives the port from the URL
		 */
		public function get port():int
		{
			return _port;
		}	
		
		/**
		 * Gives the baseURL from the url, this could be seen as the server name.<br />
		 * <br />
		 * <code>http://www.mywebsite.com:8080/test/?id=100</code> will result in <code>www.mywebsite.com</code>
		 * as base url.
		 */
		public function get baseURL():String
		{
			return _baseURL;
		}
		
		/**
		 * Gives the extendedURL from the url, this is all extra information besides the
		 * server and port<br />
		 * <br />
		 * <code>http://www.mywebsite.com:8080/test/?id=100</code> will result in <code>/test/?id=100</code>
		 * as extended url.
		 */
		public function get extendedURL():String
		{
			return _extendedURL;
		}
	}
}
