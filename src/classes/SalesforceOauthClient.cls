public class SalesforceOauthClient {
	final public static string ENV_PROD_DEV = 'Production/Developer';
	final public static string ENV_SANDBOX = 'Sandbox';
	final public static string PROD_ENDPOINT = 'https://login.salesforce.com';
	final public static string SANDBOX_ENDPOINT = 'https://test.salesforce.com';
	
	public Salesforce_Oauth__c m_Server;
	
	public class OauthException extends Exception {}
	
	public SalesforceOauthClient()
	{
		m_Server = null;
	}
	
	static public Salesforce_Oauth__c getServer(String sName)
	{
		return Salesforce_Oauth__c.getInstance(sName);
	}
	
	public void setServer(Salesforce_Oauth__c server)
	{
		m_Server = server;
	}

	public boolean load(String sName)
	{
		m_Server = Salesforce_Oauth__c.getInstance(sName);
		
		if (m_Server == null) {
			return false;
		}
		
		return true;
	}
	
	static public string getLoginEndpoint(Salesforce_Oauth__c server)
	{
		if (server.Environment__c.equalsIgnoreCase(ENV_PROD_DEV)) {
			return PROD_ENDPOINT;
		} else if (server.Environment__c.equalsIgnoreCase(ENV_SANDBOX)) {
			return SANDBOX_ENDPOINT;
		}
		
		throw new OauthException('Invalid Environment');
	}
	
	public string getAuthorizeLink(String sRedirectUrl)
	{
		if (m_Server == null) {
			return null;
		}
		
		return getLoginEndpoint(m_Server) + '/services/oauth2/authorize?response_type=code' +
			'&client_id=' + EncodingUtil.urlEncode(m_Server.Consumer_Key__c, 'UTF-8') +
			'&client_secret=' + EncodingUtil.urlEncode(m_Server.Consumer_Secret__c, 'UTF-8') +
			'&state=' + EncodingUtil.urlEncode(m_Server.name, 'UTF-8') +
			'&redirect_uri=' + EncodingUtil.urlEncode(sRedirectUrl, 'UTF-8') +
			'&code_challenge=' + base64UrlEncode(Crypto.generateDigest('SHA-256', Blob.valueOf(m_Server.Code_Verifier__c)))
			;
	}
	
    public void getToken(String sRedirectUrl, String sCode)
    {    	
    	String sUrl = getLoginEndpoint(m_Server) + '/services/oauth2/token?grant_type=authorization_code' +
			'&client_id=' + EncodingUtil.urlEncode(m_Server.Consumer_Key__c, 'UTF-8') +
			'&client_secret=' + EncodingUtil.urlEncode('826459854415633146', 'UTF-8') +
			'&code=' + EncodingUtil.urlEncode(sCode, 'UTF-8') +
			'&redirect_uri=' + EncodingUtil.urlEncode(sRedirectUrl, 'UTF-8') +
			'&code_verifier=' + m_Server.Code_Verifier__c		
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
		
		if (mapJson.containsKey('access_token')) {
			m_Server.Access_Token__c = (String) mapJson.get('access_token');
		}

		if (mapJson.containsKey('refresh_token')) {
			m_Server.Access_Token__c = (String) mapJson.get('refresh_token');
		}
		
		if (mapJson.containsKey('instance_url')) {
			m_Server.Instance_Url__c = (String) mapJson.get('instance_url');
		}
		
		upsert m_Server;
    }
    
    public void generateCodeVerifier()
    {
    	List<String> lstHexDigits = new List<String>{'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};
    	
    	String sRandom = '';
    	for (Integer i = 0; i < 128; i++) {
    		sRandom += lstHexDigits[Math.abs(Math.mod(Crypto.getRandomInteger(), 16))];
    		sRandom += lstHexDigits[Math.abs(Math.mod(Crypto.getRandomInteger(), 16))];
    	}
    	
		m_Server.Code_Verifier__c = base64UrlEncode(EncodingUtil.convertFromHex(sRandom));
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
}