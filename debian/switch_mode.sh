#!/bin/bash

# Defining Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if sing-box is installed
if ! command -v sing-box &> /dev/null; then
    echo "Please install sing-box before executing."
    sudo bash /etc/sing-box/scripts/install_singbox.sh
    exit 1
fi

# Stop sing-box service
function stop_singbox() {
    sudo systemctl stop sing-box
    if ! systemctl is-active --quiet sing-box; then
        echo "sing-box has stopped" >/dev/null
    else
        exit 1
    fi
}

# Logic for switching modes
echo "Switching mode starts...Please enter the operation according to the prompts."

while true; do
    # Selection Mode
    read -rp "Please select the mode (1: TProxy mode, 2: TUN mode): " mode_choice

    case $mode_choice in
        1)
            stop_singbox
            echo "MODE=TProxy" | sudo tee /etc/sing-box/mode.conf > /dev/null
            echo -e "${GREEN}The current selected mode is: TProxy mode${NC}"
            break
            ;;
        2)
            stop_singbox
            echo "MODE=TUN" | sudo tee /etc/sing-box/mode.conf > /dev/null
            echo -e "${GREEN}The current selected mode is: TUN mode${NC}"
            break
            ;;
        *)
            echo -e "${RED}Invalid selection, please try again.${NC}"
            ;;
    esac
done
