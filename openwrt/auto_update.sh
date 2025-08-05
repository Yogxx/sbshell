#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 手动输入的配置文件
MANUAL_FILE="/etc/sing-box/manual.conf"

# 创建定时更新脚本
cat > /etc/sing-box/update-singbox.sh <<EOF
#!/bin/bash

# 读取手动输入的配置参数
BACKEND_URL=\$(grep BACKEND_URL $MANUAL_FILE | cut -d'=' -f2-)
SUBSCRIPTION_URL=\$(grep SUBSCRIPTION_URL $MANUAL_FILE | cut -d'=' -f2-)
TEMPLATE_URL=\$(grep TEMPLATE_URL $MANUAL_FILE | cut -d'=' -f2-)

# 构建完整的配置文件URL
FULL_URL="\${BACKEND_URL}/config/\${SUBSCRIPTION_URL}&file=\${TEMPLATE_URL}"

# 备份现有配置文件
[ -f "/etc/sing-box/config.json" ] && cp /etc/sing-box/config.json /etc/sing-box/config.json.backup

# 下载并验证新配置文件
if curl -L --connect-timeout 10 --max-time 30 "\$FULL_URL" -o /etc/sing-box/config.json; then
    if ! sing-box check -c /etc/sing-box/config.json; then
        echo "New configuration file verification failed, restoring backup..."
        [ -f "/etc/sing-box/config.json.backup" ] && cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
    fi
else
    echo "Failed to download configuration file, restoring backup..."
    [ -f "/etc/sing-box/config.json.backup" ] && cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
fi

# 重启 sing-box 服务
/etc/init.d/sing-box restart
EOF

chmod a+x /etc/sing-box/update-singbox.sh

while true; do
    echo -e "${CYAN}Please select an action:${NC}"
    echo "1. Set the automatic update interval"
    echo "2. Cancel automatic renewal"
    read -rp "Please enter option (1 or 2, default is 1): " menu_choice
    menu_choice=${menu_choice:-1}

    if [[ "$menu_choice" == "1" ]]; then
        while true; do
            read -rp "Please enter the update interval in hours (1-23 hours, default is 12 hours): " interval_choice
            interval_choice=${interval_choice:-12}

            if [[ "$interval_choice" =~ ^[1-9]$|^1[0-9]$|^2[0-3]$ ]]; then
                break
            else
                echo -e "${RED}Invalid input, please enter an hour between 1 and 23.${NC}"
            fi
        done

        
        if crontab -l 2>/dev/null | grep -q '/etc/sing-box/update-singbox.sh'; then
            echo -e "${RED}An existing automatic update task has been detected.${NC}"
            read -rp "Do you want to reset the automatic update task? (y/n): " confirm_reset
            if [[ "$confirm_reset" =~ ^[Yy]$ ]]; then
                crontab -l 2>/dev/null | grep -v '/etc/sing-box/update-singbox.sh' | crontab -
                echo "The old auto-update task has been deleted."
            else
                echo -e "${CYAN}Keep the existing automatic update task. Return to the menu.${NC}"
                exit 0
            fi
        fi

        
        (crontab -l 2>/dev/null; echo "0 */$interval_choice * * * /etc/sing-box/update-singbox.sh") | crontab -
        /etc/init.d/cron restart

        echo "Scheduled update task has been set to execute every $interval_choice hours"
        break

    elif [[ "$menu_choice" == "2" ]]; then
        # 取消自动更新任务
        if crontab -l 2>/dev/null | grep -q '/etc/sing-box/update-singbox.sh'; then
            crontab -l 2>/dev/null | grep -v '/etc/sing-box/update-singbox.sh' | crontab -
            /etc.init.d/cron restart
            echo -e "${CYAN}The automatic update task has been canceled.${NC}"
        else
            echo -e "${CYAN}No automatic update tasks found.${NC}"
        fi
        break

    else
        echo -e "${RED}Invalid input, please enter 1 or 2.${NC}"
    fi
done
