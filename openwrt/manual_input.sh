#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 手动输入的配置文件
MANUAL_FILE="/etc/sing-box/manual.conf"
DEFAULTS_FILE="/etc/sing-box/defaults.conf"

# 获取当前模式
MODE=$(grep -E '^MODE=' /etc/sing-box/mode.conf | sed 's/^MODE=//')

prompt_user_input() {
    read -rp "Please enter the backend address (press Enter to use the default value or leave it blank): " BACKEND_URL
    if [ -z "$BACKEND_URL" ]; then
        BACKEND_URL=$(grep BACKEND_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
        echo -e "${CYAN}Use the default backend address: $BACKEND_URL${NC}"
    fi

    read -rp "Please enter the subscription address (press Enter to use the default value or leave it blank): " SUBSCRIPTION_URL
    if [ -z "$SUBSCRIPTION_URL" ]; then
        SUBSCRIPTION_URL=$(grep SUBSCRIPTION_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
        echo -e "${CYAN}Use the default subscription address: $SUBSCRIPTION_URL${NC}"
    fi

    read -rp "Please enter the configuration file address (press Enter to use the default value or leave it blank): " TEMPLATE_URL
    if [ -z "$TEMPLATE_URL" ]; then
        if [ "$MODE" = "TProxy" ]; then
            TEMPLATE_URL=$(grep TPROXY_TEMPLATE_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
            echo -e "${CYAN}Use the default TProxy configuration file address: $TEMPLATE_URL${NC}"
        elif [ "$MODE" = "TUN" ]; then
            TEMPLATE_URL=$(grep TUN_TEMPLATE_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
            echo -e "${CYAN}Use the default TUN configuration file address: $TEMPLATE_URL${NC}"
        else
            echo -e "${RED}Unknown mode: $MODE${NC}"
            exit 1
        fi
    fi
}

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

        # 构建完整的配置文件URL
        if [ -n "$BACKEND_URL" ] && [ -n "$SUBSCRIPTION_URL" ]; then
            FULL_URL="${BACKEND_URL}/config/${SUBSCRIPTION_URL}&file=${TEMPLATE_URL}"
        else
            FULL_URL="${TEMPLATE_URL}"
        fi
        echo "Generate full subscription link: $FULL_URL"

        while true; do
            # 下载并验证配置文件
            if curl -L --connect-timeout 10 --max-time 30 "$FULL_URL" -o /etc/sing-box/config.json; then
                echo "The configuration file has been downloaded and verified successfully!"
                if ! sing-box check -c /etc/sing-box/config.json; then
                    echo "Configuration file validation failed"
                    exit 1
                fi
                break
            else
                echo "Configuration file download failed"
                read -rp "Download failed, do you want to try again? (y/n): " retry_choice
                if [[ "$retry_choice" =~ ^[Nn]$ ]]; then
                    exit 1
                fi
            fi
        done

        break
    else
        echo -e "${RED}Please re-enter the configuration information.${NC}"
    fi
done
