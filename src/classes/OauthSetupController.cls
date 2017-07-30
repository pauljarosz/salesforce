public class OauthSetupController {
	public String environment {get; set;}
	public String Name {get; set /*{	 	Server = new Salesforce_Oauth__c(Name = this.Name); }*/; }
	public Salesforce_Oauth__c Server {get; set;}
	public String CallbackUrl { get { return URL.getSalesforceBaseUrl().toExternalForm() + Page.OauthSetup.getUrl(); } }
	SalesforceOauthClient m_OauthClient;
	
	public OauthSetupController()
	{
		m_OauthClient = new SalesforceOauthClient();
		
		Map<String, String> mapParameters = ApexPages.currentPage().getParameters();
		system.debug(mapParameters);
		
		// returning from an authorize
		if (mapParameters.containsKey('code') && mapParameters.containsKey('state')) {
			Name = mapParameters.get('state');
			system.debug(Name);
			
			//SalesforceOauthClient.getToken(SalesforceOauthClient.getServer(Name), CallbackUrl, mapParameters.get('code'));
		}

		List<Salesforce_Oauth__c> lstServers = Salesforce_Oauth__c.getAll().values();

		system.debug(Name);
		
		if (lstServers.size() <= 0) {
			Server = new Salesforce_Oauth__c();
		} else {
			if (String.isBlank(Name)) {
				Name = lstServers[0].Name;
			}
			
			changeServer();
		}
	}
	
	public void newAction()
	{
		Server = new Salesforce_Oauth__c();
	}
	
	public void saveAction()
	{
		m_OauthClient.generateCodeVerifier();
		upsert Server;
		system.debug('CV ' + Server.Code_Verifier__c);
	}
	
	public void deleteAction()
	{
		upsert Server;
	}

	public void changeServer()
	{
		changeServer(this.Name);
	}	
	
	public void changeServer(String sName)
	{
		system.debug('cs Name: ' + sName);
		Server = Salesforce_Oauth__c.getInstance(sName);
		this.Name = Server.Name;
		m_OauthClient.setServer(Server);
		system.debug('cs '+Server);
	}

	public PageReference getTokenAction()
	{
		system.debug('her');
		Map<String, String> mapParameters = ApexPages.currentPage().getParameters();
		system.debug(mapParameters);
		
		// returning from an authorize
		if (mapParameters.containsKey('code') && mapParameters.containsKey('state')) {
			Name = mapParameters.get('state');
			
			m_OauthClient.getToken(CallbackUrl, Name = mapParameters.get('code'));
		
	PageReference pageRef = new PageReference('/apex/oauthsetup');
	pageRef.setRedirect(true);
	return pageRef;
		}
		
		return null;
	}
	
	public List<SelectOption> getServers()
	{
		List<SelectOption> options = new List<SelectOption>();

		List<Salesforce_Oauth__c> lstServers = Salesforce_Oauth__c.getAll().values();
		
		for(Salesforce_Oauth__c server : lstServers) {  
			options.add(new SelectOption(server.Name, Server.Name));
		}
		
		return options;
	}
	
	public List<SelectOption> getEnvironments()
	{
		List<SelectOption> options = new List<SelectOption>();

		options.add(new SelectOption(SalesforceOauthClient.ENV_PROD_DEV, SalesforceOauthClient.ENV_PROD_DEV));
		options.add(new SelectOption(SalesforceOauthClient.ENV_SANDBOX, SalesforceOauthClient.ENV_SANDBOX));
		
		return options;
	}
	
	public PageReference getAuthRedirection()
	{
		String sUrl = m_OauthClient.getAuthorizeLink(CallbackUrl);

		PageReference page = new PageReference(sUrl);
		page.setRedirect(true);
		
		return page;
	}
}