#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

function view_firewall_rules() {
    echo -e "${YELLOW}View firewall rules...${NC}"
    nft list ruleset
    read -rp "Press Enter to return to the secondary menu..."
}

function check_config() {
    echo -e "${YELLOW}Checking configuration files...${NC}"
    bash /etc/sing-box/scripts/check_config.sh
    read -rp "Press Enter to return to the secondary menu..."
}

function view_logs() {
    echo -e "${YELLOW}Log is being generated, please wait...${NC}"
    echo -e "${RED}Press Ctrl + C to end log output${NC}"
    logread -f | grep sing-box
    read -rp "Press Enter to return to the secondary menu..."
}

function show_submenu() {
    echo -e "${CYAN}=========== Secondary menu options ===========${NC}"
    echo -e "${MAGENTA}1. View firewall rules${NC}"
    echo -e "${MAGENTA}2. Check the configuration file${NC}"
    echo -e "${MAGENTA}3. View real-time logs${NC}"
    echo -e "${MAGENTA}0. Return to main menu${NC}"
    echo -e "${CYAN}===================================${NC}"
}

function handle_submenu_choice() {
    while true; do
        read -rp "Please select an action: " choice
        case $choice in
            1) view_firewall_rules ;;
            2) check_config ;;
            3) view_logs ;;
            0) return 0 ;;
            *) echo -e "${RED}Invalid selection${NC}" ;;
        esac
        show_submenu
    done
    return 0  # 确保函数结束时返回 0
}

# 显示并处理二级菜单
menu_active=true
while $menu_active; do
    show_submenu
    handle_submenu_choice
    choice_returned=$?  # 捕获函数返回值
    if [[ $choice_returned -eq 0 ]]; then
        menu_active=false
    fi
done
