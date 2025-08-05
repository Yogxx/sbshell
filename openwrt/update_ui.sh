#!/bin/bash

UI_DIR="/etc/sing-box/ui"
BACKUP_DIR="/tmp/sing-box/ui_backup"
TEMP_DIR="/tmp/sing-box-ui"

ZASHBOARD_URL="https://gh-proxy.com/https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
METACUBEXD_URL="https://gh-proxy.com/https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
YACD_URL="https://gh-proxy.com/https://github.com/MetaCubeX/Yacd-meta/archive/refs/heads/gh-pages.zip"

# 定义颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色


# 创建备份目录
mkdir -p "$BACKUP_DIR"
mkdir -p "$TEMP_DIR"

# 检查依赖并安装
check_and_install_dependencies() {
    if ! command -v unzip &> /dev/null; then
        echo -e "${RED}unzip is not installed, installing...${NC}"
        opkg update > /dev/null 2>&1
        opkg install unzip > /dev/null 2>&1
    fi
}

get_download_url() {
    CONFIG_FILE="/etc/sing-box/config.json"
    DEFAULT_URL="https://gh-proxy.com/https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
    
    if [ -f "$CONFIG_FILE" ]; then
        URL=$(grep -o '"external_ui_download_url": "[^"]*' "$CONFIG_FILE" | sed 's/"external_ui_download_url": "//')
        echo "${URL:-$DEFAULT_URL}"
    else
        echo "$DEFAULT_URL"
    fi
}

backup_and_remove_ui() {
    if [ -d "$UI_DIR" ]; then
        echo -e "${CYAN}Back up the current ui folder...${NC}"
        mv "$UI_DIR" "$BACKUP_DIR/$(date +%Y%m%d%H%M%S)_ui"
        echo -e "${GREEN}Backed up to $BACKUP_DIR${NC}"
    fi
}

download_and_process_ui() {
    local url="$1"
    local temp_file="$TEMP_DIR/ui.zip"
    
    # 清理临时目录
    rm -rf "${TEMP_DIR:?}"/*
    
    echo -e "${CYAN}Downloading panel...${NC}"
    curl -L "$url" -o "$temp_file" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}Download failed, restoring backup...${NC}"
        [ -d "$BACKUP_DIR" ] && mv "$BACKUP_DIR/"* "$UI_DIR" 2>/dev/null
        return 1
    fi

    # 解压文件
    echo -e "${CYAN}Unzipping...${NC}"
    if unzip "$temp_file" -d "$TEMP_DIR" > /dev/null 2>&1; then
        # 确保目标目录存在
        mkdir -p "$UI_DIR"
        rm -rf "${UI_DIR:?}"/*
        mv "$TEMP_DIR"/*/* "$UI_DIR"
        echo -e "${GREEN}Panel installation completed${NC}"
        return 0
    else
        echo -e "${RED}Unzip failed, restoring backup...${NC}"
        [ -d "$BACKUP_DIR" ] && mv "$BACKUP_DIR/"* "$UI_DIR" 2>/dev/null
        return 1
    fi
}

install_default_ui() {
    echo -e "${CYAN}Installing default ui panel...${NC}"
    DOWNLOAD_URL=$(get_download_url)
    backup_and_remove_ui
    download_and_process_ui "$DOWNLOAD_URL"
}

install_selected_ui() {
    local url="$1"
    backup_and_remove_ui
    download_and_process_ui "$url"
}

check_ui() {
    if [ -d "$UI_DIR" ] && [ "$(ls -A "$UI_DIR")" ]; then
        echo -e "${GREEN}UI panel installed${NC}"
    else
        echo -e "${RED}The ui panel is not installed or is empty${NC}"
    fi
}

setup_auto_update_ui() {
    local schedule_choice
    while true; do
        echo -e "${CYAN}Please select the frequency of automatic updates:${NC}"
        echo "1. Every Monday"
        echo "2. 1st of every month"
        read -rp "Please enter your options (1/2, default is 1): " schedule_choice
        schedule_choice=${schedule_choice:-1}

        if [[ "$schedule_choice" =~ ^[12]$ ]]; then
            break
        else
            echo -e "${RED}Invalid input, please enter 1 or 2.${NC}"
        fi
    done

    if crontab -l 2>/dev/null | grep -q '/etc/sing-box/update-ui.sh'; then
        echo -e "${RED}An existing automatic update task has been detected.${NC}"
        read -rp "Do you want to reset the automatic update task? (y/n): " confirm_reset
        if [[ "$confirm_reset" =~ ^[Yy]$ ]]; then
            crontab -l 2>/dev/null | grep -v '/etc/sing-box/update-ui.sh' | crontab -
            echo "The old auto-update task has been deleted."
        else
            echo -e "${CYAN}Keep the existing automatic update task. Return to the menu.${NC}"
            return
        fi
    fi

    # 创建自动更新脚本
    cat > /etc/sing-box/update-ui.sh <<EOF
#!/bin/bash

CONFIG_FILE="/etc/sing-box/config.json"
DEFAULT_URL="https://gh-proxy.com/https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
URL=\$(grep -o '"external_ui_download_url": "[^"]*' "\$CONFIG_FILE" | sed 's/"external_ui_download_url": "//')
URL="\${URL:-\$DEFAULT_URL}"

TEMP_DIR="/tmp/sing-box-ui"
UI_DIR="/etc/sing-box/ui"
BACKUP_DIR="/tmp/sing-box/ui_backup"

# 创建备份目录
mkdir -p "\$BACKUP_DIR"
mkdir -p "\$TEMP_DIR"

# 备份当前ui文件夹
if [ -d "\$UI_DIR" ]; then
    mv "\$UI_DIR" "\$BACKUP_DIR/\$(date +%Y%m%d%H%M%S)_ui"
fi

# 下载并解压新ui
curl -L "\$URL" -o "\$TEMP_DIR/ui.zip"
if unzip "\$TEMP_DIR/ui.zip" -d "\$TEMP_DIR" > /dev/null 2>&1; then
    mkdir -p "\$UI_DIR"
    rm -rf "\${UI_DIR:?}"/*
    mv "\$TEMP_DIR"/*/* "\$UI_DIR"
else
    echo "Unzip failed, restoring backup..."
    [ -d "\$BACKUP_DIR" ] && mv "\$BACKUP_DIR/"* "\$UI_DIR" 2>/dev/null
fi

EOF

    chmod a+x /etc/sing-box/update-ui.sh

    if [ "$schedule_choice" -eq 1 ]; then
        (crontab -l 2>/dev/null; echo "0 0 * * 1 /etc/sing-box/update-ui.sh") | crontab -
        echo -e "${GREEN}The scheduled update task has been set and will be executed every Monday${NC}"
    else
        (crontab -l 2>/dev/null; echo "0 0 1 * * /etc/sing-box/update-ui.sh") | crontab -
        echo -e "${GREEN}The scheduled update task has been set and will be executed once a month on the 1st${NC}"
    fi

    systemctl restart cron
}

update_ui() {
    check_and_install_dependencies  # 检查并安装依赖
    while true; do
        echo -e "${CYAN}Please select a function:${NC}"
        echo "1. Default UI (based on configuration file)"
        echo "2. Install/update optional UI"
        echo "3. Check if ui panel exists"
        echo "4. Set up a scheduled automatic update panel"
        read -r -p "Please enter an option (1/2/3/4) or press Enter to exit: " choice

        if [ -z "$choice" ]; then
            echo "Exit the program."
            exit 0
        fi

        case "$choice" in
            1)
                install_default_ui
                exit 0  # 更新结束后退出菜单
                ;;
            2)
                echo -e "${CYAN}Please select Panel Mount:${NC}"
                echo "1. Zashboard"
                echo "2. metacubexd panel"
                echo "3. yacd panel"
                read -r -p "Please enter options(1/2/3): " ui_choice

                case "$ui_choice" in
                    1)
                        install_selected_ui "$ZASHBOARD_URL"
                        ;;
                    2)
                        install_selected_ui "$METACUBEXD_URL"
                        ;;
                    3)
                        install_selected_ui "$YACD_URL"
                        ;;
                    *)
                        echo -e "${RED}Invalid option, return to the previous menu.${NC}"
                        ;;
                esac
                exit 0  # 更新结束后退出菜单
                ;;
            3)
                check_ui
                ;;
            4)
                setup_auto_update_ui
                ;;
            *)
                echo -e "${RED}Invalid option, return to main menu${NC}"
                ;;
        esac
    done
}

update_ui
