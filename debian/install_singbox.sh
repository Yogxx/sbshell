#!/bin/bash

# Defining Colors
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if sing-box is installed
if command -v sing-box &> /dev/null; then
    echo -e "${CYAN}sing-box is already installed, skip the installation step${NC}"
else
    # Add official GPG key and repository
    sudo mkdir -p /etc/apt/keyrings
    sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
    sudo chmod a+r /etc/apt/keyrings/sagernet.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | sudo tee /etc/apt/sources.list.d/sagernet.list > /dev/null

    # Always update package lists
    echo "Updating package list, please wait..."
    sudo apt-get update -qq > /dev/null 2>&1

    # Choose to install the stable version or the beta version
    while true; do
        read -rp "Please select the version to install (1: stable version, 2: beta version): " version_choice
        case $version_choice in
            1)
                echo "Install the stable version..."
                sudo apt-get install sing-box -yq > /dev/null 2>&1
                echo "Installation Completed"
                break
                ;;
            2)
                echo "Install the beta version..."
                sudo apt-get install sing-box-beta -yq > /dev/null 2>&1
                echo "Installation Completed"
                break
                ;;
            *)
                echo -e "${RED}Invalid selection, please enter 1 or 2.${NC}"
                ;;
        esac
    done

    if command -v sing-box &> /dev/null; then
        sing_box_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
        echo -e "${CYAN}sing-box was successfully installed, version：${NC} $sing_box_version"
    else
        echo -e "${RED}sing-box installation failed, please check the log or network configuration${NC}"
    fi
fi
