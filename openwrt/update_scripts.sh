#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 脚本下载目录
SCRIPT_DIR="/etc/sing-box/scripts"
TEMP_DIR="/tmp/sing-box"

# 脚本的URL基础路径
BASE_URL="https://gh-proxy.com/https://raw.githubusercontent.com/Yogxx/sbshell/refs/heads/main/openwrt"

# 初始下载菜单脚本的URL
MENU_SCRIPT_URL="$BASE_URL/menu.sh"

# 提示用户正在检测版本
echo -e "${CYAN}Detecting version, please wait patiently...${NC}"

# 确保脚本目录和临时目录存在并设置权限
mkdir -p "$SCRIPT_DIR"
mkdir -p "$TEMP_DIR"
chown "$(id -u)":"$(id -g)" "$SCRIPT_DIR"
chown "$(id -u)":"$(id -g)" "$TEMP_DIR"

# 下载远程脚本到临时目录
wget -q -O "$TEMP_DIR/menu.sh" "$MENU_SCRIPT_URL"

# 检查下载是否成功
if ! [ -f "$TEMP_DIR/menu.sh" ]; then
    echo -e "${RED}Failed to download remote script, please check the network connection.${NC}"
    exit 1
fi

# 获取本地和远程脚本版本
LOCAL_VERSION=$(grep '^# Version:' "$SCRIPT_DIR/menu.sh" | awk '{print $3}')
REMOTE_VERSION=$(grep '^# Version:' "$TEMP_DIR/menu.sh" | awk '{print $3}')

# 检查远程版本是否为空
if [ -z "$REMOTE_VERSION" ]; then
    echo -e "${RED}Failed to obtain the remote version. Please check the network connection.${NC}"
    read -rp "Do you want to try again? (y/n): " retry_choice
    if [[ "$retry_choice" =~ ^[Yy]$ ]]; then
        wget -q -O "$TEMP_DIR/menu.sh" "$MENU_SCRIPT_URL"
        REMOTE_VERSION=$(grep '^# Version:' "$TEMP_DIR/menu.sh" | awk '{print $3}')
        if [ -z "$REMOTE_VERSION" ]; then
            echo -e "${RED}Failed to retrieve the remote version. Please check the network connection and try again. Return to the menu.${NC}"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    else
        echo -e "${RED}Please check your network connection and try again. Return to menu.${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
fi

# 输出检测到的版本
echo -e "${CYAN}Detected versions: local version $LOCAL_VERSION, remote version $REMOTE_VERSION${NC}"

# 比较版本号
if [ "$LOCAL_VERSION" == "$REMOTE_VERSION" ]; then
    echo -e "${GREEN}The script version is the latest and does not need to be upgraded.${NC}"
    read -rp "Do you want to force update? (y/n): " force_update
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

# 脚本列表
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

# 下载并设置单个脚本，带重试逻辑
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

    echo -e "${RED}Download of $SCRIPT failed, please check your network connection.${NC}"
    return 1
}

# 并行下载脚本
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

# 常规更新
function regular_update() {
    echo -e "${CYAN}Cleaning cache, please wait patiently...${NC}"
    rm -f "$SCRIPT_DIR"/*.sh
    echo -e "${CYAN}Regular update in progress, please be patient...${NC}"
    parallel_download_scripts
    echo -e "${CYAN}General script update completed.${NC}"
}

# 重置更新
function reset_update() {
    echo -e "${RED}Stopping sing-box and resetting everything, please wait...${NC}"
    bash "$SCRIPT_DIR/clean_nft.sh"
    rm -rf /etc/sing-box
    echo -e "${CYAN}The sing-box folder has been deleted.${NC}"
    echo -e "${CYAN}Re-pulling the script, please wait patiently...${NC}"
    bash <(curl -s "$MENU_SCRIPT_URL")
}

# 提示用户并确认选择
echo -e "${CYAN}Please select the update method:${NC}"
echo -e "${GREEN}1. General Updates${NC}"
echo -e "${GREEN}2. Reset Update${NC}"
read -rp "Please select an action: " update_choice

case $update_choice in
    1)
        echo -e "${RED}Regular updates only update the script content, and the new script will be executed when the menu content is executed again.${NC}"
        read -rp "Continue with regular updates? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            regular_update
        else
            echo -e "${CYAN}Regular updates have been canceled.${NC}"
        fi
        ;;
    2)
        echo -e "${RED}This will stop the sing-box and reset everything, and initialize the boot settings.${NC}"
        read -rp "Continue with the reset update? (y/n): " confirm
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

# 清理临时目录
rm -rf "$TEMP_DIR"
