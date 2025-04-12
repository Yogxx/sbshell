#!/bin/bash

UI_DIR="/etc/sing-box/ui"
BACKUP_DIR="/tmp/sing-box/ui_backup"
TEMP_DIR="/tmp/sing-box-ui"

ZASHBOARD_URL="https://ghfast.top/https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
METACUBEXD_URL="https://ghfast.top/https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
YACD_URL="https://ghfast.top/https://github.com/MetaCubeX/Yacd-meta/archive/refs/heads/gh-pages.zip"

# 创建备份目录
mkdir -p "$BACKUP_DIR"
mkdir -p "$TEMP_DIR"

# 检查依赖并安装
check_and_install_dependencies() {
    if ! command -v busybox &> /dev/null; then
        echo -e "\e[31mbusybox Not installed, installing...\e[0m"
        sudo apt-get update
        sudo apt-get install -y busybox
        export PATH=$PATH:/bin/busybox
        sudo chmod +x /bin/busybox
    fi
}

unzip_with_busybox() {
    busybox unzip "$1" -d "$2" > /dev/null 2>&1
}

get_download_url() {
    CONFIG_FILE="/etc/sing-box/config.json"
    DEFAULT_URL="https://ghfast.top/https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
    
    if [ -f "$CONFIG_FILE" ]; then
        URL=$(grep -oP '(?<="external_ui_download_url": ")[^"]*' "$CONFIG_FILE")
        echo "${URL:-$DEFAULT_URL}"
    else
        echo "$DEFAULT_URL"
    fi
}

backup_and_remove_ui() {
    if [ -d "$UI_DIR" ]; then
        echo -e "Back up the current ui folder..."
        mv "$UI_DIR" "$BACKUP_DIR/$(date +%Y%m%d%H%M%S)_ui"
        echo -e "Backed up to $BACKUP_DIR"
    fi
}

download_and_process_ui() {
    local url="$1"
    local temp_file="$TEMP_DIR/ui.zip"
    
    # 清理临时目录
    rm -rf "${TEMP_DIR:?}"/*
    
    echo "Downloading Panel..."
    curl -L "$url" -o "$temp_file"
    if [ $? -ne 0 ]; then
        echo -e "\e[31mDownload failed, restoring backup...\e[0m"
        [ -d "$BACKUP_DIR" ] && mv "$BACKUP_DIR/"* "$UI_DIR" 2>/dev/null
        return 1
    fi

    # 解压文件
    echo "Unzipping..."
    if unzip_with_busybox "$temp_file" "$TEMP_DIR"; then
        # 确保目标目录存在
        mkdir -p "$UI_DIR"
        rm -rf "${UI_DIR:?}"/*
        mv "$TEMP_DIR"/*/* "$UI_DIR"
        echo -e "\e[32mPanel installation completed\e[0m"
        return 0
    else
        echo -e "\e[31mUnzip failed, restoring backup...\e[0m"
        [ -d "$BACKUP_DIR" ] && mv "$BACKUP_DIR/"* "$UI_DIR" 2>/dev/null
        return 1
    fi
}

install_default_ui() {
    echo "Installing default ui panel..."
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
        echo -e "\e[32muiPanel installed\e[0m"
    else
        echo -e "\e[31muiPanel not installed or empty\e[0m"
    fi
}

setup_auto_update_ui() {
    local schedule_choice
    while true; do
        echo "Please select the automatic update frequency："
        echo "1. Every Monday"
        echo "2. 1st of every month"
        read -rp "Please enter the option (1/2, default is 1): " schedule_choice
        schedule_choice=${schedule_choice:-1}

        if [[ "$schedule_choice" =~ ^[12]$ ]]; then
            break
        else
            echo -e "\e[31mInvalid input, please enter 1 or 2.\e[0m"
        fi
    done

    if crontab -l 2>/dev/null | grep -q '/etc/sing-box/update-ui.sh'; then
        echo -e "\e[31mAn existing automatic update task has been detected.\e[0m"
        read -rp "Do you want to reset the automatic update task? (y/n): " confirm_reset
        if [[ "$confirm_reset" =~ ^[Yy]$ ]]; then
            crontab -l 2>/dev/null | grep -v '/etc/sing-box/update-ui.sh' | crontab -
            echo "The old auto-update task has been deleted."
        else
            echo -e "\e[36mKeep the existing automatic update tasks. Return to the menu.\e[0m"
            return
        fi
    fi

    # 创建自动更新脚本
    cat > /etc/sing-box/update-ui.sh <<EOF
#!/bin/bash

CONFIG_FILE="/etc/sing-box/config.json"
DEFAULT_URL="https://ghfast.top/https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
URL=\$(grep -oP '(?<="external_ui_download_url": ")[^"]*' "\$CONFIG_FILE")
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
if busybox unzip "\$TEMP_DIR/ui.zip" -d "\$TEMP_DIR"; then
    mkdir -p "\$UI_DIR"
    rm -rf "\${UI_DIR:?}"/*
    mv "\$TEMP_DIR"/*/* "\$UI_DIR"
else
    echo "解压失败，正在还原备份..."
    [ -d "\$BACKUP_DIR" ] && mv "\$BACKUP_DIR/"* "\$UI_DIR" 2>/dev/null
fi

EOF

    chmod a+x /etc/sing-box/update-ui.sh

    if [ "$schedule_choice" -eq 1 ]; then
        (crontab -l 2>/dev/null; echo "0 0 * * 1 /etc/sing-box/update-ui.sh") | crontab -
        echo -e "\e[32mThe scheduled update task has been set and will be executed every Monday\e[0m"
    else
        (crontab -l 2>/dev/null; echo "0 0 1 * * /etc/sing-box/update-ui.sh") | crontab -
        echo -e "\e[32mThe scheduled update task has been set and will be executed once on the 1st of each month\e[0m"
    fi

    systemctl restart cron
}

update_ui() {
    check_and_install_dependencies  # 检查并安装依赖
    while true; do
        echo "Please select a function："
        echo "1. Default ui (based on configuration file)"
        echo "2. Install/update optional ui"
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
                echo "Please select Panel Mount:"
                echo "1. Zashboard panel"
                echo "2. Metacubexd panel"
                echo "3. Yacd panel"
                read -r -p "Please enter your options (1/2/3): " ui_choice

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
                        echo -e "\e[31mInvalid option, return to the previous menu.\e[0m"
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
                echo -e "\e[31mInvalid option, return to main menu\e[0m"
                ;;
        esac
    done
}

update_ui
