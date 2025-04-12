#!/bin/bash

# Defining Colors
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# View Firewall Rules
function view_firewall_rules() {
    echo -e "${YELLOW}View Firewall Rules...${NC}"
    sudo nft list ruleset
    read -rp "Press Enter to return to the secondary menu..."
}

# Show Log
function view_logs() {
    echo -e "${YELLOW}Show Log...${NC}"
    sudo journalctl -u sing-box --output cat -e
    read -rp "Press Enter to return to the secondary menu..."
}

# Real-time log
function live_logs() {
    echo -e "${YELLOW}Real-time log...${NC}"
    sudo journalctl -u sing-box -f --output=cat
    read -rp "Press Enter to return to the secondary menu..."
}

# Check the configuration file
function check_config() {
    echo -e "${YELLOW}Check the configuration file...${NC}"
    bash /etc/sing-box/scripts/check_config.sh
    read -rp "Press Enter to return to the secondary menu..."
}

# Secondary menu options
function show_submenu() {
    echo -e "${CYAN}=========== Secondary menu options ===========${NC}"
    echo -e "${MAGENTA}1. View Firewall Rules${NC}"
    echo -e "${MAGENTA}2. Show Log${NC}"
    echo -e "${MAGENTA}3. Real-time log${NC}"
    echo -e "${MAGENTA}4. Check the configuration file${NC}"
    echo -e "${MAGENTA}0. Return to main menu${NC}"
    echo -e "${CYAN}===================================${NC}"
}

# Handling User Input
function handle_submenu_choice() {
    while true; do
        read -rp "Please select an operation: " choice
        case $choice in
            1) view_firewall_rules ;;
            2) view_logs ;;
            3) live_logs ;;
            4) check_config ;;
            0) return 0 ;;
            *) echo -e "${RED}Invalid selection${NC}" ;;
        esac
        show_submenu
    done
    return 0  # Make sure the function returns 0 when it finishes
}

# Display and handle secondary menus
menu_active=true
while $menu_active; do
    show_submenu
    handle_submenu_choice
    choice_returned=$?  # Capturing function return values
    if [[ $choice_returned -eq 0 ]]; then
        menu_active=false
    fi
done
