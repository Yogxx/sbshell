#!/bin/bash

# Defining Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Script download directory
SCRIPT_DIR="/etc/sing-box/scripts"

# Stop the sing-box service
stop_singbox() {
    echo -e "${CYAN}Stopping sing-box service...${NC}"
    /etc/init.d/sing-box stop
    result=$?
    if [ $result -ne 0 ]; then
        echo -e "${CYAN}Failed to stop sing-box service, return code: $result${NC}"
    else
        echo -e "${GREEN}sing-box stopped successfully.${NC}"
    fi

    # Prompt the user to confirm whether to clear firewall rules
    read -rp "Do you want to clear firewall rules?(y/n): " confirm_cleanup
    if [[ "$confirm_cleanup" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Execute cleanup firewall rules...${NC}"
        bash "$SCRIPT_DIR/clean_nft.sh"
        echo -e "${GREEN}Firewall rules cleared${NC}"
    else
        echo -e "${CYAN}Cleanup of firewall rules has been cancelled.${NC}"
    fi
}

# Prompt the user to confirm whether to stop
read -rp "Stop sing-box?(y/n): " confirm_stop
if [[ "$confirm_stop" =~ ^[Yy]$ ]]; then
    stop_singbox
else
    echo -e "${CYAN}Stop sing-box has been cancelled.${NC}"
    exit 0
fi
