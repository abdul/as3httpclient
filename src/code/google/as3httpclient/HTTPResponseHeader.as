package code.google.as3httpclient
{
	import flash.net.URLRequestHeader;
	
	/**
	 * This class is used by the SocketURLLoader to parse the HTTP response header
	 * 
	 * @see SocketURLLoader
	 */
	public class HTTPResponseHeader
	{
		private var _protocol:String;
		private var _status:int;
		private var _message:String;
		private var _contentLength:Number;
		
		private var _headers:Array;
		private var _headerObject:Object;
		
		/**
		 * @param completeHeader This is the complete HTTP response header.
		 */
		public function HTTPResponseHeader(completeHeader:String)
		{
			_headers = new Array();
			_headerObject = new Object();
			
			parseHeader(completeHeader);
		};
		
		private function parseHeader(completeHeader:String):void
		{
			var headers:Array = completeHeader.split(HTTP_SEPARATOR);
			
			var info:String = headers.shift() as String;
			var infoArray:Array = info.split(" ");
			
			_protocol = infoArray[0];
			_status = parseInt(infoArray[1]);
			if (infoArray.length > 2)
			{
				_message = infoArray[2];
			};
			
			var headerText:String;
			var name:String;
			var value:String;
			var header:URLRequestHeader
			var headerContent:Array;
			
			for each (headerText in headers)
			{
				headerContent = headerText.split(": ");
				name = headerContent[0];
				value = headerContent[1];
				header = new URLRequestHeader(name, value);
				_headers.push(header);
				_headerObject[name] = value;
			};
		};
		
		/**
		 * Contains the protocol of the response
		 */
		public function get protocol():String
		{
			return _protocol;
		};
		
		/**
		 * Contains the status of the response
		 */
		public function get status():int
		{
			return _status;
		};
		
		/**
		 * Contains an array of URLRequestHeaders.
		 * 
		 * @see http://livedocs.adobe.com/flex/2/langref/flash/net/URLRequestHeader.html flash.net.URLRequestHeader
		 */
		public function get headers():Array
		{
			return _headers;
		};
		
		/**
		 * This object contains all headers as a hash / lookup table. They are 
		 * inserted with the header name as key and header value as value.<br />
		 * <br />
		 * Note that if a header with the same name is found more then once it will 
		 * overwrite the previously set one.
		 */
		public function get headerObject():Object
		{
			return _headerObject;
		};
		
		/**
		 * The message which is send along with the status code.
		 */
		public function get message():String
		{
			return _message;
		};
	};
};
