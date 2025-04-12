#!/bin/bash

# Defining Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Set up auto-startup...${NC}"
echo "Please select an action (1: Enable auto-start, 2: Disable auto-start)"
read -rp "(1/2): " autostart_choice

apply_firewall() {
    MODE=$(grep -oP '(?<=^MODE=).*' /etc/sing-box/mode.conf)
    if [ "$MODE" = "TProxy" ]; then
        echo "Apply firewall rules in TProxy mode..."
        bash /etc/sing-box/scripts/configure_tproxy.sh
    elif [ "$MODE" = "TUN" ]; then
        echo "Apply firewall rules in TUN mode..."
        bash /etc/sing-box/scripts/configure_tun.sh
    else
        echo "Invalid mode, skips applying firewall rules."
        exit 1
    fi
}

case $autostart_choice in
    1)
        # Check whether auto-start is enabled
        if [ -f /etc/rc.d/S99sing-box ]; then
            echo -e "${GREEN}Automatic startup is already enabled, no operation is required.${NC}"
            exit 0  # Return to main menu
        fi

        echo -e "${GREEN}Enable Autostart...${NC}"

        # Enable and start the service
        /etc/init.d/sing-box enable
        /etc/init.d/sing-box start
        cmd_status=$?

        if [ "$cmd_status" -eq 0 ]; then
            echo -e "${GREEN}Autostart has been successfully enabled.${NC}"
        else
            echo -e "${RED}Failed to enable autostart.${NC}"
        fi
        ;;
    2)
        # Check if autostart is disabled
        if [ ! -f /etc/rc.d/S99sing-box ]; then
            echo -e "${GREEN}Auto-start has been disabled, no action is required.${NC}"
            exit 0  # Return to main menu
        fi

        echo -e "${RED}Disable auto-start...${NC}"
        
        # Disable and stop the service
        /etc/init.d/sing-box disable
        cmd_status=$?

        if [ "$cmd_status" -eq 0 ]; then
            echo -e "${GREEN}Autostart has been successfully disabled.${NC}"
        else
            echo -e "${RED}Disabling autostart failed.${NC}"
        fi
        ;;
    *)
        echo -e "${RED}Invalid selection${NC}"
        ;;
esac

# Call the function that applies the firewall rules
if [ "$1" = "apply_firewall" ]; then
    apply_firewall
fi