#!/bin/bash

CONFIG_FILE=$(find . -name connector.config.js)

cat > $CONFIG_FILE <<EOL
window.config = {
};
EOL
