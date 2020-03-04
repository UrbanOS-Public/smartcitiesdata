var auth0Client = new auth0.WebAuth({
  clientID: window.config.client_id,
  domain: window.config.auth_domain,
  redirectUri: window.config.redirect_uri,
  responseType: 'code',
  scope: 'offline_access',
  audience: 'discovery_api'
});
