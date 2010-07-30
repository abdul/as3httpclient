package code.google.as3httpclient
{
	import flash.utils.ByteArray;
	import flash.net.URLVariables;
	import flash.net.URLRequestMethod;
	
	/**
	 * This type of request allows you to upload a file using the SocketURLLoader.
	 * 
	 * @see SocketURLLoader
	 */
	public class SocketHTTPFileRequest extends SocketHTTPRequest
	{
		/**
		 * The name of the file you are uploading
		 */
		public var fileName:String;
		
		/**
		 * The name of the form field that should contain the data
		 */
		public var dataField:String;
		
		/**
		 * The actual file data.
		 */
		public var fileContent:ByteArray;
		
		/**
		 * Defaults the method to URLRequestMethod.POST and the contentType to
		 * ContentType.MULTIPART_FORM_DATA
		 * 
		 * @see ContentType
		 */
		public function SocketHTTPFileRequest(url:String = null)
		{
			super(url);
			method = URLRequestMethod.POST;
			dataField = "Filedata";
			contentType = ContentType.MULTIPART_FORM_DATA;
		};
		
		/**
		 * Will construct the data containing the file information.
		 * 
		 * @see SocketHTTPRequest#data
		 * 
		 * @throws Error if one of the following fields is empty: fileName, dataField, fileContent
		 * @throws ArgumentError is the data is not of type URLVariables
		 * @throws Error if the content type and method are not ContentType.MULTIPART_FORM_DATA and
		 * 				 URLRequestMethod.POST
		 */ 
		override protected function constructData(boundary:String):ByteArray
		{
			if (!fileName || !dataField || !fileContent)
			{
				throw new Error("SocketHTTPFileRequest: can not construct data if any of the following properties is null: fileName, dataField or fileContent");
			};
			
			var dataBA:ByteArray = new ByteArray();
			if (contentType == ContentType.MULTIPART_FORM_DATA && method == URLRequestMethod.POST)
			{
				//first process the given data
				if (data)
				{
					if (data is URLVariables)
					{
						var forbiddenFields:Object = new Object();
						forbiddenFields["Filename"] = true;
						forbiddenFields["Upload"] = true;
						forbiddenFields[dataField] = true;
						
						var i:String;
						var value:Object;
						
						for (i in data)
						{
							//make sure that the forbidden fields are excluded
							if (!forbiddenFields.hasOwnProperty(i))
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
								};
								dataBA.writeUTFBytes(HTTP_SEPARATOR);
							};
						};
					} else
					{
						throw new ArgumentError("SocketHTTPFileRequest: cannot create data stream when content type is set to MULTIPART_FORM_DATA and data is not of type URLVariables");
					};				
				};
				dataBA.writeUTFBytes("--" + boundary + HTTP_SEPARATOR);
				dataBA.writeUTFBytes("Content-Disposition: form-data; name=\"Filename\"" + HTTP_SEPARATOR);
				dataBA.writeUTFBytes(HTTP_SEPARATOR);
				dataBA.writeUTFBytes(fileName);
				dataBA.writeUTFBytes(HTTP_SEPARATOR);
				
				dataBA.writeUTFBytes("--" + boundary + HTTP_SEPARATOR);
				dataBA.writeUTFBytes("Content-Disposition: form-data; name=\"" + dataField + "\"; filename=\"" + fileName + "\"" + HTTP_SEPARATOR);
				dataBA.writeUTFBytes("Content-Type: application/octet-stream" + HTTP_SEPARATOR);
				dataBA.writeUTFBytes(HTTP_SEPARATOR);
				dataBA.writeBytes(fileContent, 0, fileContent.length);
				dataBA.writeUTFBytes(HTTP_SEPARATOR);
				
				dataBA.writeUTFBytes("--" + boundary + HTTP_SEPARATOR);
				dataBA.writeUTFBytes("Content-Disposition: form-data; name=\"Upload\"" + HTTP_SEPARATOR);
				dataBA.writeUTFBytes(HTTP_SEPARATOR);
				dataBA.writeUTFBytes("Submit Query");
				dataBA.writeUTFBytes(HTTP_SEPARATOR);
				
				dataBA.writeUTFBytes("--" + boundary + "--" + HTTP_SEPARATOR);
			} else
			{
				throw new Error("SocketHTTPFileRequest: cannot construct data if contentType is not set to ContentType.MULTIPART_FORM_DATA or method is not set to URLRequestMethod.POST");
			};
			
			return dataBA;
		};
	};
};
