#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 检查当前模式
check_mode() {
    if nft list chain inet sing-box prerouting_tproxy &>/dev/null || nft list chain inet sing-box output_tproxy &>/dev/null; then
        echo "TProxy Mode"
    else
        echo "TUN mode"
    fi
}

# 启动 sing-box 服务
start_singbox() {
    echo -e "${CYAN}Check if you are in a non-proxy environment...${NC}"
    STATUS_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "https://www.google.com")

    if [ "$STATUS_CODE" -eq 200 ]; then
        echo -e "${RED}The current network is in a proxy environment, and a direct connection is required to start sing-box!${NC}"
    else
        echo -e "${CYAN}The current network environment is not a proxy network, and sing-box can be started.${NC}"
    fi

    # 启动 sing-box 服务
    /etc/init.d/sing-box start

    sleep 2  # 等待 sing-box 启动
    

    if /etc/init.d/sing-box status | grep -q "running"; then
        echo -e "${GREEN}sing-box started successfully${NC}"

        mode=$(check_mode)
        echo -e "${MAGENTA}Current startup mode: ${mode}${NC}"
    else
        echo -e "${RED}sing-box failed to start, please check the log${NC}"
    fi
}

# 提示用户确认是否启动
read -rp "Do you want to start sing-box? (y/n): " confirm_start
if [[ "$confirm_start" =~ ^[Yy]$ ]]; then
    start_singbox
else
    echo -e "${CYAN}Canceled launching sing-box.${NC}"
    exit 0
fi
