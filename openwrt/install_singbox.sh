#!/bin/bash

# Defining Colors
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if sing-box is installed
if command -v sing-box &> /dev/null; then
    echo -e "${CYAN}sing-box is already installed, skip the installation step${NC}"
else
    # Update package lists and install necessary dependencies and sing-box
    echo "Updating package list and installing sing-box, please wait..."
    opkg update >/dev/null 2>&1
    opkg install kmod-nft-tproxy >/dev/null 2>&1
    opkg install sing-box >/dev/null 2>&1

    if command -v sing-box &> /dev/null; then
        echo -e "${CYAN}sing-box installation successful${NC}"
    else
        echo -e "${RED}sing-box installation failed, please check the log or network configuration${NC}"
        exit 1
    fi
fi

# Adding start and stop commands to an existing service script
if [ -f /etc/init.d/sing-box ]; then
    sed -i '/start_service()/,/}/d' /etc/init.d/sing-box
    sed -i '/stop_service()/,/}/d' /etc/init.d/sing-box
fi

cat << 'EOF' >> /etc/init.d/sing-box

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/sing-box run -c /etc/sing-box/config.json
    procd_set_param respawn
    procd_set_param stderr 1
    procd_set_param stdout 1
    procd_close_instance
    
    # Wait for the service to fully start
    sleep 3
    
    # Read the schema and apply firewall rules
    MODE=$(grep -oE '^MODE=.*' /etc/sing-box/mode.conf | cut -d'=' -f2)
    if [ "$MODE" = "TProxy" ]; then
        /etc/sing-box/scripts/configure_tproxy.sh
    elif [ "$MODE" = "TUN" ]; then
        /etc/sing-box/scripts/configure_tun.sh
    fi
}

stop_service() {
    procd_kill "$NAME" 2>/dev/null
}
EOF

# Make sure the service script has executable permissions
chmod +x /etc/init.d/sing-box

# Enable and start the sing-box service
/etc/init.d/sing-box enable
/etc/init.d/sing-box start

echo -e "${CYAN}sing-box service is enabled and started${NC}"
