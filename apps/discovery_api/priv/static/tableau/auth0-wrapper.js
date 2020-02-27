var auth0Client = new auth0.WebAuth({
  clientID: 'sfe5fZzFXsv5gIRXz8V3zkR7iaZBMvL0',
  domain: 'smartcolumbusos-demo.auth0.com',
  redirectUri: 'http://localhost:9001/connector.html',
  responseType: 'code',
  scope: 'offline_access',
  audience: 'discovery_api'
});
