public class SalesforceOauthClient {
	final public static string ENV_PROD_DEV = 'Production/Developer';
	final public static string ENV_SANDBOX = 'Sandbox';
	final public static string PROD_ENDPOINT = 'https://login.salesforce.com';
	final public static string SANDBOX_ENDPOINT = 'https://test.salesforce.com';
	
	public class OauthException extends Exception {}
	
	static public Salesforce_Oauth__c getServer(String sName)
	{
		return Salesforce_Oauth__c.getInstance(sName);
	}
	
	static public string getEndpoint(Salesforce_Oauth__c server)
	{
		if (server.Environment__c.equalsIgnoreCase(ENV_PROD_DEV)) {
			return PROD_ENDPOINT;
		} else if (server.Environment__c.equalsIgnoreCase(ENV_SANDBOX)) {
			return SANDBOX_ENDPOINT;
		}
		
		throw new OauthException('Invalid Environment');
	}
	
	static public string getAuthorizeLink(Salesforce_Oauth__c server, String sRedirectUrl)
	{
		return getEndpoint(server) + '/services/oauth2/authorize?response_type=code' +
			'&client_id=' + EncodingUtil.urlEncode(server.Consumer_Key__c, 'UTF-8') +
			'&client_secret=' + EncodingUtil.urlEncode('826459854415633146', 'UTF-8') +
			'&state=' + EncodingUtil.urlEncode(server.name, 'UTF-8') +
			'&redirect_uri=' + EncodingUtil.urlEncode(sRedirectUrl, 'UTF-8')		
			;
	}
	
    static public void getToken(Salesforce_Oauth__c server, String sRedirectUrl, String sCode)
    {
    	String sUrl = getEndpoint(server) + '/services/oauth2/token?grant_type=authorization_code' +
			'&client_id=' + EncodingUtil.urlEncode(server.Consumer_Key__c, 'UTF-8') +
			'&client_secret=' + EncodingUtil.urlEncode('826459854415633146', 'UTF-8') +
			'&code=' + EncodingUtil.urlEncode(sCode, 'UTF-8') +
			'&redirect_uri=' + EncodingUtil.urlEncode(sRedirectUrl, 'UTF-8')		
			;        HttpRequest request = new HttpRequest();

		system.debug(sUrl);
        request.setEndpoint(sUrl);
        request.setMethod('GET');
        request.setTimeout(60000);

		HttpResponse response = new Http().send(request);
		System.debug(response.getBody());
		Map<String, Object> mapJson = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
		system.debug(mapJson);
		if (mapJson.containsKey('error')) {
			throw new OauthException((String) mapJson.get('error_description'));
		}
		
		if (mapJson.containsKey('access_token')) {
			server.Access_Token__c = (String) mapJson.get('access_token');
		}

		if (mapJson.containsKey('refresh_token')) {
			server.Access_Token__c = (String) mapJson.get('refresh_token');
		}
		
		if (mapJson.containsKey('instance_url')) {
			server.Instance_Url__c = (String) mapJson.get('instance_url');
		}
		
		system.debug(server);

		upsert server;
    }
}