#!/bin/bash

# Defining Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script download directory
SCRIPT_DIR="/etc/sing-box/scripts"
TEMP_DIR="/tmp/sing-box"

# The script's URL base path
BASE_URL="https://gh-proxy.com/https://raw.githubusercontent.com/Yogxx/sbshell/refs/heads/master/openwrt"

# URL for the initial download menu script
MENU_SCRIPT_URL="$BASE_URL/menu.sh"

# Prompt the user to detect the version
echo -e "${CYAN}The version is being detected, please wait patiently...${NC}"

# Make sure the script directory and temporary directory exist and set permissions
mkdir -p "$SCRIPT_DIR"
mkdir -p "$TEMP_DIR"
chown "$(id -u)":"$(id -g)" "$SCRIPT_DIR"
chown "$(id -u)":"$(id -g)" "$TEMP_DIR"

# Download remote script to a temporary directory
wget -q -O "$TEMP_DIR/menu.sh" "$MENU_SCRIPT_URL"

# Check if the download was successful
if ! [ -f "$TEMP_DIR/menu.sh" ]; then
    echo -e "${RED}Failed to download remote script, please check network connection.${NC}"
    exit 1
fi

# Get local and remote script versions
LOCAL_VERSION=$(grep '^# Version:' "$SCRIPT_DIR/menu.sh" | awk '{print $3}')
REMOTE_VERSION=$(grep '^# Version:' "$TEMP_DIR/menu.sh" | awk '{print $3}')

# Check if the remote version is empty
if [ -z "$REMOTE_VERSION" ]; then
    echo -e "${RED}Failed to obtain the remote version. Please check the network connection.${NC}"
    read -rp "Do you want to retry?(y/n): " retry_choice
    if [[ "$retry_choice" =~ ^[Yy]$ ]]; then
        wget -q -O "$TEMP_DIR/menu.sh" "$MENU_SCRIPT_URL"
        REMOTE_VERSION=$(grep '^# Version:' "$TEMP_DIR/menu.sh" | awk '{print $3}')
        if [ -z "$REMOTE_VERSION" ]; then
            echo -e "${RED}Failed to obtain the remote version. Please check the network connection and try again. Return to the menu.${NC}"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    else
        echo -e "${RED}Please check your network connection and try again. Return to menu.${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
fi

# Output detected version
echo -e "${CYAN}Detected versions: local version $LOCAL_VERSION, remote version $REMOTE_VERSION${NC}"

# 比较版本号
if [ "$LOCAL_VERSION" == "$REMOTE_VERSION" ]; then
    echo -e "${GREEN}The script version is the latest and does not need to be upgraded.${NC}"
    read -rp "Is update mandatory?(y/n): " force_update
    if [[ "$force_update" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Forcing update...${NC}"
    else
        echo -e "${CYAN}Return to menu.${NC}"
        rm -rf "$TEMP_DIR"
        exit 0
    fi
else
    echo -e "${RED}A new version has been detected, ready to upgrade.${NC}"
fi

# Script List
SCRIPTS=(
    "check_environment.sh"
    "install_singbox.sh"
    "manual_input.sh"
    "manual_update.sh"
    "auto_update.sh"
    "configure_tproxy.sh"
    "configure_tun.sh"
    "start_singbox.sh"
    "stop_singbox.sh"
    "clean_nft.sh"
    "set_defaults.sh"
    "commands.sh"
    "switch_mode.sh"
    "manage_autostart.sh"
    "check_config.sh"
    "update_scripts.sh"
    "update_ui.sh"
    "menu.sh"
)

# Download and set up a single script with retry logic
download_script() {
    local SCRIPT="$1"
    local RETRIES=3
    local RETRY_DELAY=5

    for ((i=1; i<=RETRIES; i++)); do
        if wget -q -O "$SCRIPT_DIR/$SCRIPT" "$BASE_URL/$SCRIPT"; then
            chmod +x "$SCRIPT_DIR/$SCRIPT"
            return 0
        else
            sleep "$RETRY_DELAY"
        fi
    done

    echo -e "${RED}Failed to download $SCRIPT, please check your network connection.${NC}"
    return 1
}

# Parallel download scripts
parallel_download_scripts() {
    local pids=()
    for SCRIPT in "${SCRIPTS[@]}"; do
        download_script "$SCRIPT" &
        pids+=("$!")
    done

    for pid in "${pids[@]}"; do
        wait "$pid"
    done
}

# General Updates
function regular_update() {
    echo -e "${CYAN}The cache is being cleared, please wait patiently...${NC}"
    rm -f "$SCRIPT_DIR"/*.sh
    echo -e "${CYAN}Regular update in progress, please be patient...${NC}"
    parallel_download_scripts
    echo -e "${CYAN}General script update completed.${NC}"
}

# Reset Update
function reset_update() {
    echo -e "${RED}About to stop sing-box and reset everything, please wait...${NC}"
    bash "$SCRIPT_DIR/clean_nft.sh"
    rm -rf /etc/sing-box
    echo -e "${CYAN}The sing-box folder has been deleted.${NC}"
    echo -e "${CYAN}The script is being re-pulled, please wait patiently...${NC}"
    bash <(curl -s "$MENU_SCRIPT_URL")
}

# Prompt the user to confirm the selection
echo -e "${CYAN}Please select the update method：${NC}"
echo -e "${GREEN}1. General Updates${NC}"
echo -e "${GREEN}2. Reset Update${NC}"
read -rp "Please select an operation: " update_choice

case $update_choice in
    1)
        echo -e "${RED}Regular updates only update the script content, and the new script will be executed when the menu content is executed again.${NC}"
        read -rp "Continue with regular updates?(y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            regular_update
        else
            echo -e "${CYAN}Regular updates have been cancelled.${NC}"
        fi
        ;;
    2)
        echo -e "${RED}This will stop the sing-box and reset everything, and initialize the boot settings.${NC}"
        read -rp "Continue with reset update?(y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            reset_update
        else
            echo -e "${CYAN}Reset update canceled.${NC}"
        fi
        ;;
    *)
        echo -e "${RED}Invalid selection.${NC}"
        ;;
esac

# Clean up the temporary directory
rm -rf "$TEMP_DIR"
