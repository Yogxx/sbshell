#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

if command -v sing-box &> /dev/null; then
    echo -e "${CYAN}sing-box is already installed, skip the installation steps${NC}"
else
    echo "Updating package lists and installing sing-box, please wait..."
    opkg update >/dev/null 2>&1
    opkg install kmod-nft-tproxy >/dev/null 2>&1
    opkg install sing-box >/dev/null 2>&1

    if command -v sing-box &> /dev/null; then
        echo -e "${CYAN}sing-box installed successfully${NC}"
    else
        echo -e "${RED}sing-box installation failed, please check the log or network configuration${NC}"
        exit 1
    fi
fi

# 添加启动和停止命令到现有服务脚本
if [ -f /etc/init.d/sing-box ]; then
    sed -i '/start_service()/,/}/d' /etc/init.d/sing-box
    sed -i '/stop_service()/,/}/d' /etc/init.d/sing-box
fi

cat << 'EOF' >> /etc/init.d/sing-box

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/sing-box run -c /etc/sing-box/config.json
    procd_set_param respawn
    procd_set_param stderr 1
    procd_set_param stdout 1
    procd_close_instance
    
    # 等待服务完全启动
    sleep 3
    
    # 读取模式并应用防火墙规则
    MODE=$(grep -oE '^MODE=.*' /etc/sing-box/mode.conf | cut -d'=' -f2)
    if [ "$MODE" = "TProxy" ]; then
        /etc/sing-box/scripts/configure_tproxy.sh
    elif [ "$MODE" = "TUN" ]; then
        /etc/sing-box/scripts/configure_tun.sh
    fi
}

stop_service() {
    procd_kill "$NAME" 2>/dev/null
}
EOF

chmod +x /etc/init.d/sing-box

/etc/init.d/sing-box enable
/etc/init.d/sing-box start

echo -e "${CYAN}sing-box service is enabled and started${NC}"
