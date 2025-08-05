#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 手动输入的配置文件
MANUAL_FILE="/etc/sing-box/manual.conf"
DEFAULTS_FILE="/etc/sing-box/defaults.conf"

# 获取当前模式
MODE=$(grep '^MODE=' /etc/sing-box/mode.conf | sed 's/^MODE=//')

# 提示用户是否更换订阅的函数
prompt_user_input() {
    while true; do
        read -rp "Please enter the backend address (default value will be used if left blank): " BACKEND_URL
        if [ -z "$BACKEND_URL" ]; then
            BACKEND_URL=$(grep BACKEND_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
            if [ -z "$BACKEND_URL" ]; then
                echo -e "${RED}No default value set, please set in the menu!${NC}"
                continue
            fi
            echo -e "${CYAN}Use the default backend address: $BACKEND_URL${NC}"
        fi
        break
    done

    while true; do
        read -rp "Please enter the subscription address (default value will be used if left blank): " SUBSCRIPTION_URL
        if [ -z "$SUBSCRIPTION_URL" ]; then
            SUBSCRIPTION_URL=$(grep SUBSCRIPTION_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
            if [ -z "$SUBSCRIPTION_URL" ]; then
                echo -e "${RED}No default value set, please set in the menu!${NC}"
                continue
            fi
            echo -e "${CYAN}Use the default subscription address: $SUBSCRIPTION_URL${NC}"
        fi
        break
    done

    while true; do
        read -rp "Please enter the configuration file address (leave it blank to use the default value): " TEMPLATE_URL
        if [ -z "$TEMPLATE_URL" ]; then
            if [ "$MODE" = "TProxy" ]; then
                TEMPLATE_URL=$(grep TPROXY_TEMPLATE_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
                if [ -z "$TEMPLATE_URL" ]; then
                    echo -e "${RED}No default value set, please set it in the menu!${NC}"
                    continue
                fi
                echo -e "${CYAN}Use the default TProxy configuration file address: $TEMPLATE_URL${NC}"
            elif [ "$MODE" = "TUN" ]; then
                TEMPLATE_URL=$(grep TUN_TEMPLATE_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
                if [ -z "$TEMPLATE_URL" ]; then
                    echo -e "${RED}No default value set, please set in the menu!${NC}"
                    continue
                fi
                echo -e "${CYAN}Use the default TUN configuration file address: $TEMPLATE_URL${NC}"
            else
                echo -e "${RED}Unknown mode: $MODE${NC}"
                exit 1
            fi
        fi
        break
    done
}

read -rp "Do you want to change your subscription address? (y/n): " change_subscription
if [[ "$change_subscription" =~ ^[Yy]$ ]]; then
    # 执行手动输入相关内容
    while true; do
        prompt_user_input

        echo -e "${CYAN}The configuration information you enter is as follows:${NC}"
        echo "Backend address: $BACKEND_URL"
        echo "Subscription address: $SUBSCRIPTION_URL"
        echo "Configuration file address: $TEMPLATE_URL"

        read -rp "Confirm the configuration information you entered? (y/n): " confirm_choice
        if [[ "$confirm_choice" =~ ^[Yy]$ ]]; then
            # 更新手动输入的配置文件
            cat > "$MANUAL_FILE" <<EOF
BACKEND_URL=$BACKEND_URL
SUBSCRIPTION_URL=$SUBSCRIPTION_URL
TEMPLATE_URL=$TEMPLATE_URL
EOF

            echo "Manually entered configuration updated"
            break
        else
            echo -e "${RED}Please re-enter the configuration information.${NC}"
        fi
    done
else
    if [ ! -f "$MANUAL_FILE" ]; then
        echo -e "${RED}The subscription address is empty, please set it!${NC}"
        exit 1
    fi

    # 使用现有配置，并输出调试信息
    BACKEND_URL=$(grep BACKEND_URL "$MANUAL_FILE" 2>/dev/null | cut -d'=' -f2-)
    SUBSCRIPTION_URL=$(grep SUBSCRIPTION_URL "$MANUAL_FILE" 2>/dev/null | cut -d'=' -f2-)
    TEMPLATE_URL=$(grep TEMPLATE_URL "$MANUAL_FILE" 2>/dev/null | cut -d'=' -f2-)

    if [ -z "$BACKEND_URL" ] || [ -z "$SUBSCRIPTION_URL" ] || [ -z "$TEMPLATE_URL" ]; then
        echo -e "${RED}The subscription address is empty, please set it!${NC}"
        exit 1
    fi

    echo -e "${CYAN}The current configuration is as follows:${NC}"
    echo "Backend address: $BACKEND_URL"
    echo "Subscription Address: $SUBSCRIPTION_URL"
    echo "Configuration file address: $TEMPLATE_URL"
fi

# 构建完整的配置文件URL
FULL_URL="${BACKEND_URL}/config/${SUBSCRIPTION_URL}&file=${TEMPLATE_URL}"
echo "Generate full subscription link: $FULL_URL"

# 备份现有配置文件
[ -f "/etc/sing-box/config.json" ] && cp /etc/sing-box/config.json /etc/sing-box/config.json.backup

if curl -L --connect-timeout 10 --max-time 30 "$FULL_URL" -o /etc/sing-box/config.json; then
    echo -e "${GREEN}Configuration file updated successfully!${NC}"
    if ! sing-box check -c /etc/sing-box/config.json; then
        echo -e "${RED}Configuration file verification failed, restoring backup...${NC}"
        [ -f "/etc/sing-box/config.json.backup" ] && cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
    fi
else
    echo -e "${RED}Configuration file download failed, restoring backup...${NC}"
    [ -f "/etc/sing-box/config.json.backup" ] && cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
fi

# 重启sing-box并检查启动状态
/etc/init.d/sing-box start

if /etc/init.d/sing-box status | grep -q "running"; then
    echo -e "${GREEN}sing-box started successfully${NC}"
else
    echo -e "${RED}sing-box failed to start${NC}"
fi
