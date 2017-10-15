public class SalesforceOauthClient {
	final public static string ENV_PROD_DEV = 'Production/Developer';
	final public static string ENV_SANDBOX = 'Sandbox';
	final public static string PROD_ENDPOINT = 'https://login.salesforce.com';
	final public static string SANDBOX_ENDPOINT = 'https://test.salesforce.com';
	
	public String LoginEndpoint { get; set; }
	public String Name { get; set; }
	public String Name2 { get; set; }
	public String Environment { get; set; }
	public String ConsumerKey { get; set; }
	public String ConsumerSecret { get; set; }
	public String InstanceUrl { get; set; }
	public String AccessToken { get; set; }
	public String RefreshToken { get; set; }
	public String CodeVerifier { get; set; }
		
	public class OauthException extends Exception {}
	
	public SalesforceOauthClient()
	{
		
	}
	
	public SalesforceOauthClient(String sName)
	{
		load(sName);
	}
	
	static public Salesforce_Oauth__c getServer(String sName)
	{
		return Salesforce_Oauth__c.getInstance(sName);
	}
	
	public void setServer(Salesforce_Oauth__c server)
	{
		//m_Server = server;
	}

	public boolean load(String sName)
	{
		Salesforce_Oauth__c Server = Salesforce_Oauth__c.getInstance(sName);
		
		if (Server == null) {
			return false;
		}
		
		Name = sName;
		Environment = Server.Environment__c;
		
		if (String.isBlank(Environment)) {
			if (Environment.equalsIgnoreCase(ENV_PROD_DEV)) {
				LoginEndpoint = PROD_ENDPOINT;
			} else if (Environment.equalsIgnoreCase(ENV_SANDBOX)) {
				LoginEndpoint = SANDBOX_ENDPOINT;
			}
		}
		
		ConsumerKey = Server.Consumer_Key__c;
		ConsumerSecret = Server.Consumer_Secret__c;
		InstanceUrl = Server.Instance_Url__c;
		AccessToken = Server.Access_Token__c;
		RefreshToken = Server.Refresh_Token__c;
		CodeVerifier = Server.Code_Verifier__c;
		
		return true;
	}
	
	public void save(String sName) {
		Salesforce_Oauth__c Server = Salesforce_Oauth__c.getInstance(sName);
		
		if (Server == null) {
			Server = new Salesforce_Oauth__c();
			Server.Name = sName;
		}
		
		Server.Environment__c = Environment;
		Server.Consumer_Key__c = ConsumerKey;
		Server.Consumer_Secret__c = ConsumerSecret;
		Server.Instance_Url__c = InstanceUrl;
		Server.Access_Token__c = AccessToken;
		Server.Refresh_Token__c = RefreshToken;
		Server.Code_Verifier__c = CodeVerifier;
		
		upsert Server;
	}
	
	public string getAuthorizeLink(String sRedirectUrl)
	{
		return LoginEndpoint + '/services/oauth2/authorize?response_type=code' +
			'&client_id=' + EncodingUtil.urlEncode(ConsumerKey, 'UTF-8') +
			'&client_secret=' + EncodingUtil.urlEncode(ConsumerSecret, 'UTF-8') +
			'&state=' + EncodingUtil.urlEncode(Name, 'UTF-8') +
			'&redirect_uri=' + EncodingUtil.urlEncode(sRedirectUrl, 'UTF-8') +
			'&code_challenge=' + base64UrlEncode(Crypto.generateDigest('SHA-256', Blob.valueOf(CodeVerifier)))
			;
	}
	
	/**
	 * get refresh token, initial access token, and instance url
	 */
	public void getToken(String sRedirectUrl, String sCode)
	{
		String sUrl = LoginEndpoint + '/services/oauth2/token?grant_type=authorization_code' +
			'&client_id=' + EncodingUtil.urlEncode(ConsumerKey, 'UTF-8') +
			'&client_secret=' + EncodingUtil.urlEncode(ConsumerSecret, 'UTF-8') +
			'&code=' + EncodingUtil.urlEncode(sCode, 'UTF-8') +
			'&redirect_uri=' + EncodingUtil.urlEncode(sRedirectUrl, 'UTF-8') +
			'&code_verifier=' + CodeVerifier		
			;
			
		HttpRequest request = new HttpRequest();

		request.setEndpoint(sUrl);
		request.setMethod('GET');
		request.setTimeout(60000);

		HttpResponse response = new Http().send(request);
		
		Map<String, Object> mapJson = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
		
		if (mapJson.containsKey('error')) {
			throw new OauthException((String) mapJson.get('error_description'));
		}
		
		if (!mapJson.containsKey('access_token')) {
			throw new OauthException('Missing Access Token');
		}

		AccessToken = (String) mapJson.get('access_token');

		if (!mapJson.containsKey('refresh_token')) {
			throw new OauthException('Missing Refresh Token');
		}
		
		RefreshToken = (String) mapJson.get('refresh_token');
		
		if (!mapJson.containsKey('instance_url')) {
			throw new OauthException('Missing Instance Url');
		}
		
		InstanceUrl = (String) mapJson.get('instance_url');
		
		//upsert m_Server;
	}
	
	/**
	 * request a new access token
	 */
	public void refreshToken()
	{
		if (String.isBlank(ConsumerKey)) {
			throw new OauthException('Invalid Consumer Key');
		}

		if (String.isBlank(ConsumerSecret)) {
			throw new OauthException('Invalid Consumer Secret');
		}
		
		if (String.isBlank(RefreshToken)) {
			throw new OauthException('Invalid Refresh Token');
		}
		
		String sUrl = LoginEndpoint + '/services/oauth2/token?grant_type=refresh_token' +
			'&client_id=' + EncodingUtil.urlEncode(ConsumerKey, 'UTF-8') +
			'&client_secret=' + EncodingUtil.urlEncode(ConsumerSecret, 'UTF-8') +
			'&refresh_token=' + EncodingUtil.urlEncode(RefreshToken, 'UTF-8')
			;
			
			system.debug(sUrl);
		HttpRequest request = new HttpRequest();

		request.setEndpoint(sUrl);
		request.setMethod('GET');
		request.setTimeout(60000);

		HttpResponse response = new Http().send(request);
		
		Map<String, Object> mapJson = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
		
		if (mapJson.containsKey('error')) {
			throw new OauthException((String) mapJson.get('error_description'));
		}
		
		if (mapJson.containsKey('access_token')) {
			AccessToken = (String) mapJson.get('access_token');
		}

		if (mapJson.containsKey('instance_url')) {
			InstanceUrl = (String) mapJson.get('instance_url');
		}
		
		//upsert m_Server;
	}
	
	public void generateCodeVerifier()
	{
		List<String> lstHexDigits = new List<String>{'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};
		
		String sRandom = '';
		for (Integer i = 0; i < 128; i++) {
			sRandom += lstHexDigits[Math.abs(Math.mod(Crypto.getRandomInteger(), 16))];
			sRandom += lstHexDigits[Math.abs(Math.mod(Crypto.getRandomInteger(), 16))];
		}
		
		CodeVerifier = base64UrlEncode(EncodingUtil.convertFromHex(sRandom));
	}
	
	/**
	 * encode a url according to this docs
	 * https://tools.ietf.org/html/rfc4648#section-5
	 */
	public string base64UrlEncode(Blob b)
	{
		String s = EncodingUtil.base64Encode(b).trim();
		
		while (s.endsWith('=')) {
			s = s.removeEnd('=');
		}
		
		s = s.replace('+', '-');
		s = s.replace('/', '_');
		
		return s;
	}
	
	private Object getSecureJson(String sResource, String sMethod, String sBody)
	{
		if (String.isBlank(InstanceUrl)) {
			throw new OauthException('Invalid Instance Url');
		}
		
		HttpRequest request = new HttpRequest();

		request.setEndpoint(InstanceUrl + '/' + sResource);
		request.setMethod(sMethod);
		request.setTimeout(60000);
		request.setCompressed(true);
		request.setHeader('Authorization', 'Bearer ' + AccessToken);
		
		if (!String.isBlank(sBody)) {
			request.setBody(sBody);
			request.setHeader('Content-Type', 'application/json');
		}

		HttpResponse response = new Http().send(request);
				
		return JSON.deserializeUntyped(response.getBody());
	}
	
	public Object getJson(String sResource, String sMethod, String sBody)
	{
		Object retVal = getSecureJson(sResource, sMethod, sBody);
		
		// check if the token needs to be refreshed
		if (retVal instanceof List<Object>) {
			List<Object> lst = (List<Object>) retVal;
			
			if (lst.size() > 0) {
				Map<String, Object> mapData = (Map<String, Object>) lst[0];
			
				if (mapData.containsKey('errorCode')) {
					String sErrorCode = (String) mapData.get('errorCode');
					String sMessage = (String) mapData.get('message');
					
					if (sErrorCode.equalsIgnoreCase('INVALID_SESSION_ID')) {
						refreshToken();
						retVal = getSecureJson(sResource, sMethod, sBody);
					}
					
					throw new OauthException(sErrorCode + ': ' + sMessage);
				}
			}
		}

		// check if an error occured
		if (retVal instanceof List<Object>) {
			List<Object> lst = (List<Object>) retVal;
			
			if (lst.size() > 0) {
				Map<String, Object> mapData = (Map<String, Object>) lst[0];
			
				if (mapData.containsKey('errorCode')) {
					String sErrorCode = (String) mapData.get('errorCode');
					String sMessage = (String) mapData.get('message');
					
					system.debug(retVal);
					throw new OauthException(sErrorCode + ': ' + sMessage);
				}
			}
		}
		
		return retVal;
	}
}