#!/bin/bash

#################################################
# Description: OpenWRT official sing-box fully automatic script
# Version: 2.1.0
# Author: Youtube: 七尺宇
#################################################

# Defining Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script download directory and initialization flag file
SCRIPT_DIR="/etc/sing-box/scripts"
INITIALIZED_FILE="$SCRIPT_DIR/.initialized"

# Make sure the script directory exists and set permissions
mkdir -p "$SCRIPT_DIR"
if ! grep -qi 'openwrt' /etc/os-release; then
    chown "$(whoami)":"$(whoami)" "$SCRIPT_DIR"
fi

# The script's URL base path
BASE_URL="https://gh-proxy.com/https://raw.githubusercontent.com/Yogxx/sbshell/refs/heads/master/openwrt"

# Script List
SCRIPTS=(
    "check_environment.sh"     # Check the system environment
    "install_singbox.sh"       # Installing Sing-box
    "manual_input.sh"          # Manually enter configuration
    "manual_update.sh"         # Manually update the configuration
    "auto_update.sh"           # Automatic update configuration
    "configure_tproxy.sh"      # Configuring TProxy Mode
    "configure_tun.sh"         # Configuring TUN Mode
    "start_singbox.sh"         # Manually start Sing-box
    "stop_singbox.sh"          # Manually Stop Sing-box
    "clean_nft.sh"             # Clean up nftables rules
    "set_defaults.sh"          # Setting the default configuration
    "commands.sh"              # Common commands
    "switch_mode.sh"           # Switch proxy mode
    "manage_autostart.sh"      # Set up auto-start
    "check_config.sh"          # Check the configuration file
    "update_scripts.sh"        # Update Script
    "update_ui.sh"             # Control Panel Install/Update/Check
    "menu.sh"                  # Main Menu
)

# Download and set up a single script with retry and logging logic
download_script() {
    local SCRIPT="$1"
    local RETRIES=5  # Increase the number of retries
    local RETRY_DELAY=5

    for ((i=1; i<=RETRIES; i++)); do
        if curl -s -o "$SCRIPT_DIR/$SCRIPT" "$BASE_URL/$SCRIPT"; then
            chmod +x "$SCRIPT_DIR/$SCRIPT"
            return 0
        else
            echo -e "${YELLOW}download $SCRIPT Failed, try again $i/${RETRIES}...${NC}"
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

# Check script integrity and download missing scripts
check_and_download_scripts() {
    local missing_scripts=()
    for SCRIPT in "${SCRIPTS[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$SCRIPT" ]; then
            missing_scripts+=("$SCRIPT")
        fi
    done

    if [ ${#missing_scripts[@]} -ne 0 ]; then
        echo -e "${CYAN}The script is downloading, please wait patiently...${NC}"
        for SCRIPT in "${missing_scripts[@]}"; do
            download_script "$SCRIPT" || {
                echo -e "${RED}Download of $SCRIPT failed, try again?(y/n): ${NC}"
                read -r retry_choice
                if [[ "$retry_choice" =~ ^[Yy]$ ]]; then
                    download_script "$SCRIPT"
                else
                    echo -e "${RED}Skip $SCRIPT download.${NC}"
                fi
            }
        done
    fi
}

# Initialization Operation
initialize() {
    # Check if old scripts exist
    if ls "$SCRIPT_DIR"/*.sh 1> /dev/null 2>&1; then
        find "$SCRIPT_DIR" -type f -name "*.sh" ! -name "menu.sh" -exec rm -f {} \;
        rm -f "$INITIALIZED_FILE"
    fi

    # Re-download the script
    parallel_download_scripts
    # Perform other initialization operations for the first run
    auto_setup
    touch "$INITIALIZED_FILE"
}

# Autoboot settings
auto_setup() {
    if [ -f /etc/init.d/sing-box ]; then
        /etc/init.d/sing-box stop
    fi
    mkdir -p /etc/sing-box/
    [ -f /etc/sing-box/mode.conf ] || touch /etc/sing-box/mode.conf
    chmod 777 /etc/sing-box/mode.conf
    bash "$SCRIPT_DIR/check_environment.sh"
    command -v sing-box &> /dev/null || bash "$SCRIPT_DIR/install_singbox.sh" || bash "$SCRIPT_DIR/check_update.sh"
    bash "$SCRIPT_DIR/switch_mode.sh"
    bash "$SCRIPT_DIR/manual_input.sh"
    bash "$SCRIPT_DIR/start_singbox.sh"  
}

# Check if initialization is required
if [ ! -f "$INITIALIZED_FILE" ]; then
    echo -e "${CYAN}Press Enter to enter the initialization boot settings, enter skip to skip the boot${NC}"
    read -r init_choice
    if [[ "$init_choice" =~ ^[Ss]kip$ ]]; then
        echo -e "${CYAN}Skip the initialization boot and go directly to the menu...${NC}"
    else
        initialize
    fi
fi

# Add an alias
[ -f ~/.bashrc ] || touch ~/.bashrc
if ! grep -q "alias sb=" ~/.bashrc || true; then
    echo "alias sb='bash $SCRIPT_DIR/menu.sh menu'" >> ~/.bashrc
fi

# Creating a Quick Script
if [ ! -f /usr/bin/sb ]; then
    echo -e '#!/bin/bash\nbash /etc/sing-box/scripts/menu.sh menu' | tee /usr/bin/sb >/dev/null
    chmod +x /usr/bin/sb
fi

# 菜单显示
show_menu() {
    echo -e "${CYAN}=========== SBSHELL MENU ===========${NC}"
    echo -e "${GREEN}1. SWITCH TPROXY/TUN MODE${NC}"
    echo -e "${GREEN}2. MANUAL UPDATE CONFIGURATION${NC}"
    echo -e "${GREEN}3. AUTO UPDATE CONFIGURATION${NC}"
    echo -e "${GREEN}4. START SING-BOX${NC}"
    echo -e "${GREEN}5. STOP SING-BOX${NC}"
    echo -e "${GREEN}6. DEFAULT PARAMETER SETTINGS${NC}"
    echo -e "${GREEN}7. SET AUTOSTART${NC}"
    echo -e "${GREEN}8. COMMON COMMANDS${NC}"
    echo -e "${GREEN}9. UPDATE SCRIPT${NC}"
    echo -e "${GREEN}10. UPDATE UI${NC}"
    echo -e "${GREEN}0. QUIT${NC}"
    echo -e "${CYAN}=======================================${NC}"
}

# Handling User Selections
handle_choice() {
    read -rp "Please select an operation: " choice
    case $choice in
        1)
            bash "$SCRIPT_DIR/switch_mode.sh"
            bash "$SCRIPT_DIR/manual_input.sh"
            bash "$SCRIPT_DIR/start_singbox.sh"
            ;;
        2)
            bash "$SCRIPT_DIR/manual_update.sh"
            ;;
        3)
            bash "$SCRIPT_DIR/auto_update.sh"
            ;;
        4)
            bash "$SCRIPT_DIR/start_singbox.sh"
            ;;
        5)
            bash "$SCRIPT_DIR/stop_singbox.sh"
            ;;
        6)
            bash "$SCRIPT_DIR/set_defaults.sh"
            ;;
        7)
            bash "$SCRIPT_DIR/manage_autostart.sh"
            ;;
        8)
            bash "$SCRIPT_DIR/commands.sh"
            ;;
        9)
            bash "$SCRIPT_DIR/update_scripts.sh"
            ;;
        10)
            bash "$SCRIPT_DIR/update_ui.sh"
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option ${NC}"
            ;;
    esac
}

# Main Loop
while true; do
    show_menu
    handle_choice
done
