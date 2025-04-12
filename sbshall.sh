#!/bin/bash
# Defines the download URL for the main script
DEBIAN_MAIN_SCRIPT_URL="https://ghfast.top/https://raw.githubusercontent.com/Yogxx/sbshell/refs/heads/master/debian/menu.sh"
OPENWRT_MAIN_SCRIPT_URL="https://ghfast.top/https://raw.githubusercontent.com/Yogxx/sbshell/refs/heads/master/openwrt/menu.sh"

# Script download directory
SCRIPT_DIR="/etc/sing-box/scripts"

# Defining Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check whether the system supports
if [[ "$(uname -s)" != "Linux" ]]; then
    echo -e "${RED}The current system does not support running this script.${NC}"
    exit 1
fi

# Check the release and download the corresponding master script
if grep -qi 'debian\|ubuntu\|armbian' /etc/os-release; then
    echo -e "${GREEN}The system is Debian/Ubuntu/Armbian, which supports running this script.${NC}"
    MAIN_SCRIPT_URL="$DEBIAN_MAIN_SCRIPT_URL"
    DEPENDENCIES=("wget" "nftables")

    # Check if sudo is installed
    if ! command -v sudo &> /dev/null; then
        echo -e "${RED}sudo is not installed.${NC}"
        read -rp "Do you want to install sudo? (y/n): " install_sudo
        if [[ "$install_sudo" =~ ^[Yy]$ ]]; then
            apt-get update
            apt-get install -y sudo
            if ! command -v sudo &> /dev/null; then
                echo -e "${RED}Installation of sudo failed, please install sudo manually and rerun this script.${NC}"
                exit 1
            fi
            echo -e "${GREEN}sudo was installed successfully.${NC}"
        else
            echo -e "${RED}Since sudo is not installed, the script cannot proceed.${NC}"
            exit 1
        fi
    fi

    # Check and install missing dependencies
    for DEP in "${DEPENDENCIES[@]}"; do
        if [ "$DEP" == "nftables" ]; then
            CHECK_CMD="nft --version"
        else
            CHECK_CMD="wget --version"
        fi

        if ! $CHECK_CMD &> /dev/null; then
            echo -e "${RED}$DEP Not installed.${NC}"
            read -rp "Do you want to install $DEP? (y/n): " install_dep
            if [[ "$install_dep" =~ ^[Yy]$ ]]; then
                sudo apt-get update
                sudo apt-get install -y "$DEP"
                if ! $CHECK_CMD &> /dev/null; then
                    echo -e "${RED}Installation of $DEP failed, please install $DEP manually and rerun this script.${NC}"
                    exit 1
                fi
                echo -e "${GREEN}$DEP Installation was successful.${NC}"
            else
                echo -e "${RED}The script cannot continue because $DEP is not installed.${NC}"
                exit 1
            fi
        fi
    done
elif grep -qi 'openwrt' /etc/os-release; then
    echo -e "${GREEN}The system is OpenWRT, which supports running this script.${NC}"
    MAIN_SCRIPT_URL="$OPENWRT_MAIN_SCRIPT_URL"
    DEPENDENCIES=("nftables")

    # Check and install missing dependencies
    for DEP in "${DEPENDENCIES[@]}"; do
        if [ "$DEP" == "nftables" ]; then
            CHECK_CMD="nft --version"
        fi

        if ! $CHECK_CMD &> /dev/null; then
            echo -e "${RED}$DEP Not installed.${NC}"
            read -rp "Do you want to install $DEP? (y/n): " install_dep
            if [[ "$install_dep" =~ ^[Yy]$ ]]; then
                opkg update
                opkg install "$DEP"
                if ! $CHECK_CMD &> /dev/null; then
                    echo -e "${RED}Installation of $DEP failed, please install $DEP manually and rerun this script.${NC}"
                    exit 1
                fi
                echo -e "${GREEN}$DEP Installation was successful.${NC}"
            else
                echo -e "${RED}The script cannot continue because $DEP is not installed.${NC}"
                exit 1
            fi
        fi
    done
else
    echo -e "${RED}The current system is not Debian/Ubuntu/Armbian/OpenWRT and does not support running this script.${NC}"
    exit 1
fi

# Make sure the script directory exists and set permissions
if grep -qi 'openwrt' /etc/os-release; then
    mkdir -p "$SCRIPT_DIR"
else
    sudo mkdir -p "$SCRIPT_DIR"
    sudo chown "$(whoami)":"$(whoami)" "$SCRIPT_DIR"
fi

# Download and execute the main script
if grep -qi 'openwrt' /etc/os-release; then
    curl -s -o "$SCRIPT_DIR/menu.sh" "$MAIN_SCRIPT_URL"
else
    wget -q -O "$SCRIPT_DIR/menu.sh" "$MAIN_SCRIPT_URL"
fi

echo -e "${GREEN}The script is downloading, please wait patiently...${NC}"
echo -e "${YELLOW}Note: Try to use a proxy environment when installing and updating singbox, and remember to turn off the proxy when running singbox!${NC}"

if ! [ -f "$SCRIPT_DIR/menu.sh" ]; then
    echo -e "${RED}Failed to download the main script, please check the network connection.${NC}"
    exit 1
fi

chmod +x "$SCRIPT_DIR/menu.sh"
bash "$SCRIPT_DIR/menu.sh"
