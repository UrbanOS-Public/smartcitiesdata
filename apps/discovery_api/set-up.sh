#!/bin/bash

CONFIG_FILE=$(find . -name connector.config.js)

cat > $CONFIG_FILE <<EOL
window.config = {
  client_id: '${AUTH_CLIENT_ID}',
  auth_domain: '${AUTH_DOMAIN}',
  auth_url: 'https://${AUTH_DOMAIN}',
  redirect_uri: '${AUTH_REDIRECT_BASE_URL}/tableau/connector.html'
};
EOL
