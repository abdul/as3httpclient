package code.google.as3httpclient
{
	import flash.events.EventDispatcher;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.net.URLRequest;
	import flash.net.URLLoaderDataFormat;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.HTTPStatusEvent;
	import flash.net.URLVariables;
	import flash.errors.IOError;
	import code.google.as3httpclient.HTTP_SEPARATOR;

	/**
	 * Dispatched when the socket is closed.
	 */
	[Event(name="close", type="flash.events.Event")]
	
	/**
	 * Dispatched when the data has completed loading
	 */
	[Event(name="complete", type="flash.events.Event")]
	
	/**
	 * Dispatched when the socket is connected.
	 */
	[Event(name="open", type="flash.events.Event")]
	
	/**
	 * Dispatched when a socket throws an ioError
	 */
	[Event(name="ioError", type="flash.events.IOErrorEvent")]
	
	/**
	 * Dispatched when the socket throws a security error
	 */
	[Event(name="securityError", type="flash.events.SecurityErrorEvent")]
	
	/**
	 * Note that the progress event gives strange results for chunked data
	 * If the data received from the server is send chunked it will send progress 
	 * events for each separate chunk. That meanse that bytesLoaded and bytesTotal
	 * will count for the chunk that is currently being processed.
	 */
	[Event(name="progress", type="flash.events.ProgressEvent")]
	
	/**
	 * Dispatched if the header is received from the server
	 */
	[Event(name="httpStatus", type="flash.events.HTTPStatusEvent")]

	/**
	 * This class can in most cases be used as a replacement for the URLLoader class. <br />
	 * <br />
	 * It allows you to do things that are not possible with the URLLoader class:<br />
	 * <ul>
	 * 		<li>Authenticating without showing an authentication window on each request</li>
	 * 		<li>Adding request headers that are forbidden by the URLLoader class</li>
	 * 		<li>Uploading files to a server that uses http authentication</li>
	 * 		<li>Copying bytes (for example from images downloaded using this loader)</li>
	 * </ul>
	 * <br />
	 * Note that to authenticate you need to include an authentication header. An 
	 * authentication header looks like this:<br />
	 * <br />
	 * "Authorization: Basic" + Base64.encode(username + ":" + password))<br />
	 * <br />
	 * If the data from the server does not contain a Content-Length header and the 
	 * Transfer-Encoding header is not set to chunked, results will be unexpected.
	 */
	public class SocketURLLoader extends EventDispatcher
	{
		static private const defaultPort:int = 80;
		
		private var socket:Socket;
		private var socketHTTPRequest:SocketHTTPRequest;
		
		private var socketData:ByteArray;
		private var headerFound:Boolean;
		private var contentLength:Number;
		private var contentStart:Number;
		private var contentIsChunked:Boolean;
		
		private var _data:*;
		private var _respondeHeaders:Array;
		private var _bytesLoaded:uint;
		private var _bytesTotal:uint;

		/**
		 * The format of the data that is retrieved from the request.
		 * 
		 * @see http://livedocs.adobe.com/flex/2/langref/flash/net/URLLoaderDataFormat.html flash.net.URLLoaderDataFormat
		 */
		public var dataFormat:String;
		
		/**
		 * The reqeust is given to the load method if given. Defaults the dataFormat
		 * property to URLLoaderDataFormat.TEXT.
		 * 
		 * @see #load()
		 */
		public function SocketURLLoader(request:Object = null)
		{
			dataFormat = URLLoaderDataFormat.TEXT;
			
			socket = new Socket();
			socket.addEventListener(Event.CLOSE, socketCloseHandler);
			socket.addEventListener(Event.CONNECT, socketConnectHandler);
			socket.addEventListener(IOErrorEvent.IO_ERROR, socketIOErrorHandler);
			socket.addEventListener(ProgressEvent.SOCKET_DATA, socketDataHandler);
			socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, socketSecurityErrorHandler);
			
			if (request)
			{
				load(request);
			};
		};
		
		/**
		 * If the given request is of type URLRequest, the reqeust is converted to an instance of 
		 * SocketHTTPRequest.<br />
		 * <br />
		 * If the socket is still open it will close the socket.<br />
		 * <br />
		 * If no port could be extraced from the url, port 80 is used.<br />
		 * 
		 * @param request An instance of URLRequest, SocketHTTPRequest or SocketHTTPFileRequest.
		 * 
		 * @throws ArgumentError if the request is not of type URLRequest, SocketHTTPRequest or SocketHTTPFileRequest
		 */
		public function load(request:Object):void
		{
			if (request is URLRequest)
			{
				socketHTTPRequest = SocketHTTPRequest.createInstanceFromURLRequest(request as URLRequest);
			} else if (request is SocketHTTPRequest || request is SocketHTTPFileRequest)
			{
				socketHTTPRequest = request as SocketHTTPRequest;
			} else
			{
				throw new ArgumentError("SocketURLLoader: the method load accepts only requests of the types 'URLRequest', 'SocketHTTPRequest' or 'SocketHTTPFileRequest'");
			};
			
			var port:int = socketHTTPRequest.port ? socketHTTPRequest.port : defaultPort;
			
			close();
			
			socket.connect(socketHTTPRequest.baseURL, port);
		};
		
		/**
		 * If the socket is connected it will be closed.
		 * 
		 * @param dispatchEvent_bool if set to true a close event is dispatched.
		 */
		public function close(triggerEvent:Boolean = false):void
		{
			if (socket.connected)
			{
				socket.close();
				if (triggerEvent)
				{
					socketCloseHandler(null);
				};
			};
		};
		
		/**
		 * @private
		 * 
		 * Resets all variables
		 */
		private function reset():void
		{
			socketData = new ByteArray();
			headerFound = false;
			contentIsChunked = false;
			contentLength = NaN;
			contentStart = NaN;
			_data = null;
		};
		
		/**
		 * @private
		 * 
		 * Sends the actual request
		 */
		private function sendRequest():void
		{
			reset();
			
			var encodedBytes:ByteArray = socketHTTPRequest.constructRequest();
			socket.writeBytes(encodedBytes);

			socket.flush()				
		};
		
		/**
		 * @private
		 * 
		 * tries to find the header in the socketData, if its found the headerFound and contentStart
		 * variable are set. If the header contains a Content-Length entry the contentLength variable is 
		 * also set.
		 * 
		 * Will dispatch an HTTPStatus event.
		 */
		private function gatherHeader():void
		{
			socketData.position = 0;
			var data_str:String = socketData.readUTFBytes(socketData.bytesAvailable);
			var headerEndIndex:int = data_str.indexOf(HTTP_SEPARATOR + HTTP_SEPARATOR);
			if (headerEndIndex > -1)
			{
				headerFound = true;
				
				var header:HTTPResponseHeader = new HTTPResponseHeader(data_str.substr(0, headerEndIndex));
				_respondeHeaders = header.headers;

				var httpStatusEvent:HTTPStatusEvent = new HTTPStatusEvent(HTTPStatusEvent.HTTP_STATUS, false, false, header.status);
				dispatchEvent(httpStatusEvent);
				
				var header_obj:Object = header.headerObject;
				
				contentStart = headerEndIndex + 4;
				
				if (header_obj.hasOwnProperty("Content-Length"))
				{
					contentLength = Number(header_obj["Content-Length"]);
				} else if (header_obj.hasOwnProperty("Transfer-Encoding") && header_obj["Transfer-Encoding"] == "chunked")
				{
					contentIsChunked = true;
				} else
				{
					/*
						no Content-Length was specified and the data is not chunked, 
						we will need to set the position to the actual content start
						and guess the content length during gathering
					*/
					socketData.position = contentStart;
				};
			};
			
		};
		
		/**
		 * @private
		 * 
		 * This method is used is the header contained a Content-Length entry. If the socket has enough 
		 * bytes available the data is parsed into the correct dataFormat, a complete event is 
		 * dispatched and the socket is closed. Else a progress event is dispatched.
		 */
		private function gatherData():void
		{
			if (isNaN(contentLength))
			{
				/*
					The length of the content is unknown. Check if the last bytes is a separator.
				*/
				var position:int = socketData.position;
				var stringData:String = socketData.readUTFBytes(socketData.bytesAvailable);
				
				socketData.position = position;
				
				if (stringData.substr(-2) == HTTP_SEPARATOR)
				{
					contentLength = socketData.bytesAvailable - 2;
				};
			};
			
			if (isNaN(contentLength) || contentLength > socketData.bytesAvailable)
			{
				//waiting for more data
				var progressEvent:ProgressEvent = new ProgressEvent(ProgressEvent.PROGRESS, false, false, socketData.bytesAvailable, contentLength);
				dispatchEvent(progressEvent);
			} else
			{
				switch (dataFormat)
				{
					default:
					case URLLoaderDataFormat.TEXT:
						_data = socketData.readUTFBytes(contentLength);
						break;
					case URLLoaderDataFormat.VARIABLES:
						_data = new URLVariables(socketData.readUTFBytes(contentLength));
						break;
					case URLLoaderDataFormat.BINARY:
						var data:ByteArray = new ByteArray();
						socketData.readBytes(data, 0, contentLength);
						_data = data;
						break;
				};
				
				var completeEvent:Event = new Event(Event.COMPLETE);
				dispatchEvent(completeEvent);
				
				close(true);
			};
		};
		
		/**
		 * @private
		 * 
		 * This method is used if not Content-Length entry was found in the header and the Transfer-Encoding
		 * entry contained 'chunked'. If contentLength has not beed set the length and start of the 
		 * content are determined.
		 * 
		 * If contentLength is 0 all data has arrived, a complete event is dispatched and the socket is 
		 * closed. Else if contentLength is less then the available bytes in the socket, a progress 
		 * event is dispatched.
		 * 
		 * If a chunk has arrived completely its added to the _data property.
		 */
		private function gatherChunkedData():void
		{
			if (isNaN(contentLength))
			{
				if (socketData.bytesAvailable < 3)
				{
					//not enough bytes are available, lets wait
					return;
				};
				
				/*
					Get the size of the chunk
				*/
				var str:String = "";
				while (socketData.readUTFBytes(2) != HTTP_SEPARATOR)
				{
					socketData.position -= 2;
					str += socketData.readUTFBytes(1);
					
					if (socketData.bytesAvailable < 3)
					{
						//not enough bytes are available, lets wait
						return;
					};
				};
				contentStart = socketData.position;
				contentLength = parseInt(str, 16);
			};
			
			if (!contentLength)
			{
				//_data might be empty if the contentLength was 0 from the start
				if (_data)
				{
					//we are done, convert the data
					_data.position = 0;
					switch (dataFormat)
					{
						default:
						case URLLoaderDataFormat.TEXT:
							_data = _data.readUTFBytes(_data.bytesAvailable);
							break;
						case URLLoaderDataFormat.VARIABLES:
							_data = new URLVariables(_data.readUTFBytes(_data.bytesAvailable));
							break;
						case URLLoaderDataFormat.BINARY:
							//do nothing, the data is allready binary
							break;
					};
				};
				
				var completeEvent:Event = new Event(Event.COMPLETE);
				dispatchEvent(completeEvent);
				
				close(true);
				
				return;					
			};
			
			if (contentLength > socketData.bytesAvailable)
			{
				//lets wait for more data
				var progressEvent:ProgressEvent = new ProgressEvent(ProgressEvent.PROGRESS, false, false, socketData.bytesAvailable, contentLength);
				dispatchEvent(progressEvent);
				
			} else
			{
				if (!_data)
				{
					/*
						if the data object is null, create it as a byte array as its 
						easy to append data to it
					*/
					_data = new ByteArray();
				};
				
				/*
					Read the chunk into data
				*/
				var data:ByteArray = _data as ByteArray;
				socketData.readBytes(data, data.length, contentLength);
				
				if (socketData.bytesAvailable > 1 && socketData.readUTFBytes(2) != HTTP_SEPARATOR)
				{
					throw new IOError("SocketURLLoader: could not parse datastream, was expecting CRLF (Carriage return + Line feed).");
				};
				
				contentLength = NaN;
				contentStart = socketData.position;
				
				/*
					Call this method again, there might be another chunk waiting in the socketData
				*/
				gatherChunkedData();
			};			
		};
		
		private function socketCloseHandler(e:Event):void
		{
			var closeEvent:Event = new Event(Event.CLOSE);
			
			dispatchEvent(closeEvent);
		};
		
		/**
		 * @private
		 * 
		 * The socket is connected, dispatch an open event and send the request
		 */
		private function socketConnectHandler(e:Event):void
		{
			var openEvent:Event = new Event(Event.OPEN);
			
			dispatchEvent(openEvent);
			
			sendRequest();
		};
		
		/**
		 * @private
		 * 
		 * If the IOError is not handled throw an Error
		 */
		private function socketIOErrorHandler(e:IOErrorEvent):void
		{
			if (hasEventListener(IOErrorEvent.IO_ERROR))
			{
				dispatchEvent(e);
			} else
			{
				throw new Error("SocketURLLoader: unhandled IOErrorEvent #" + e.text + ": " + e.text);
			};
		};
		
		/**
		 * @private
		 * 
		 * If the header was not found, try to find it by calling the gatherHeader method,
		 * else, try to gather the data.
		 */
		private function socketDataHandler(e:ProgressEvent):void
		{
			socket.readBytes(socketData, socketData.length, socket.bytesAvailable);
			
			if (!headerFound)
			{
				gatherHeader();
			};

			if (headerFound)
			{
				socketData.position = contentStart;
				
				if (contentIsChunked)
				{
					gatherChunkedData();
				} else
				{
					gatherData();
				};
			};
		};
		
		/**
		 * @private
		 * 
		 * If the IOError is not handled throw an Error
		 */
		private function socketSecurityErrorHandler(e:SecurityErrorEvent):void
		{
			if (hasEventListener(SecurityErrorEvent.SECURITY_ERROR))
			{
				dispatchEvent(e);
			} else
			{
				throw new Error("SocketURLLoader: unhandled SecurityError #" + e.text + ": " + e.text);
			};
		};
		
		/**
		 * Will contain the data as soon as the complete event has been dispatched
		 */
		public function get data():*
		{
			return _data;
		};
		
		/**
		 * Will contain the response headers as soon as the complete event has been dispatched.
		 * This array will contain instances of URLRequestHeader.
		 * 
		 * @see http://livedocs.adobe.com/flex/2/langref/flash/net/URLRequestHeader.html flash.net.URLRequestHeader
		 */
		public function get responseHeaders():Array
		{
			return _respondeHeaders;
		};
	};
};
