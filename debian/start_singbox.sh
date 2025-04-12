#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 脚本下载目录
SCRIPT_DIR="/etc/sing-box/scripts"

# 检查当前模式
check_mode() {
    if nft list chain inet sing-box prerouting_tproxy &>/dev/null || nft list chain inet sing-box output_tproxy &>/dev/null; then
        echo "TProxy Mode"
    else
        echo "TUN Mode"
    fi
}

# 应用防火墙规则
apply_firewall() {
    MODE=$(grep -oP '(?<=^MODE=).*' /etc/sing-box/mode.conf)
    if [ "$MODE" = "TProxy" ]; then
        bash "$SCRIPT_DIR/configure_tproxy.sh"
    elif [ "$MODE" = "TUN" ]; then
        bash "$SCRIPT_DIR/configure_tun.sh"
    fi
}

# 启动 sing-box 服务
start_singbox() {
    echo -e "${CYAN}Detect whether it is in a non-proxy environment...${NC}"
    STATUS_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "https://www.google.com")

    if [ "$STATUS_CODE" -eq 200 ]; then
        echo -e "${RED}The current network is in a proxy environment, and a direct connection is required to start sing-box, please set it up!${NC}"
        read -rp "Do you want to execute the network setup script (only supports Debian at the moment)? (y/n/skip): " network_choice
        if [[ "$network_choice" =~ ^[Yy]$ ]]; then
            bash "$SCRIPT_DIR/set_network.sh"
            STATUS_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "https://www.google.com")
            if [ "$STATUS_CODE" -eq 200 ]; then
                echo -e "${RED}After the network configuration is changed, it is still in the proxy environment. Please check the network configuration!${NC}"
                exit 1
            fi
        elif [[ "$network_choice" =~ ^[Ss]kip$ ]]; then
            echo -e "${CYAN}Skip the network check and start sing-box directly.${NC}"
        else
            echo -e "${RED}Please switch to a non-proxy environment and then start sing-box.${NC}"
            exit 1
        fi
    else
        echo -e "${CYAN}The current network environment is not a proxy network, and sing-box can be started.${NC}"
    fi

    sudo systemctl restart sing-box &>/dev/null
    
    apply_firewall

    if systemctl is-active --quiet sing-box; then
        echo -e "${GREEN}sing-box started successfully${NC}"
        mode=$(check_mode)
        echo -e "${MAGENTA}Current startup mode: ${mode}${NC}"
    else
        echo -e "${RED}sing-box failed to start, please check the log${NC}"
    fi
}

# 提示用户确认是否启动
read -rp "Do you want to start sing-box?(y/n): " confirm_start
if [[ "$confirm_start" =~ ^[Yy]$ ]]; then
    start_singbox
else
    echo -e "${CYAN}Launching sing-box has been canceled.${NC}"
    exit 0
fi
