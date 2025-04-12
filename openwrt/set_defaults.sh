#!/bin/bash

DEFAULTS_FILE="/etc/sing-box/defaults.conf"

# Prompt the user to enter a parameter, and use the default value if it is empty
read -rp "Please enter the backend address: " BACKEND_URL
BACKEND_URL=${BACKEND_URL:-$(grep BACKEND_URL $DEFAULTS_FILE | cut -d '=' -f2)}

read -rp "Please enter the subscription address: " SUBSCRIPTION_URL
SUBSCRIPTION_URL=${SUBSCRIPTION_URL:-$(grep SUBSCRIPTION_URL $DEFAULTS_FILE | cut -d '=' -f2)}

read -rp "Please enter the TProxy configuration file address: " TPROXY_TEMPLATE_URL
TPROXY_TEMPLATE_URL=${TPROXY_TEMPLATE_URL:-$(grep TPROXY_TEMPLATE_URL $DEFAULTS_FILE | cut -d '=' -f2)}

read -rp "Please enter the TUN configuration file address: " TUN_TEMPLATE_URL
TUN_TEMPLATE_URL=${TUN_TEMPLATE_URL:-$(grep TUN_TEMPLATE_URL $DEFAULTS_FILE | cut -d '=' -f2)}

# Update the default configuration file
cat > $DEFAULTS_FILE <<EOF
BACKEND_URL=$BACKEND_URL
SUBSCRIPTION_URL=$SUBSCRIPTION_URL
TPROXY_TEMPLATE_URL=$TPROXY_TEMPLATE_URL
TUN_TEMPLATE_URL=$TUN_TEMPLATE_URL
EOF

echo "Default configuration updated"
