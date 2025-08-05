#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

echo -e "${GREEN}Set auto-start at boot...${NC}"
echo "Please select an action (1: Enable auto-start, 2: Disable auto-start)"
read -rp "(1/2): " autostart_choice

apply_firewall() {
    MODE=$(grep -oP '(?<=^MODE=).*' /etc/sing-box/mode.conf)
    if [ "$MODE" = "TProxy" ]; then
        echo "Applying firewall rules in TProxy mode..."
        bash /etc/sing-box/scripts/configure_tproxy.sh
    elif [ "$MODE" = "TUN" ]; then
        echo "Applying firewall rules in TUN mode..."
        bash /etc/sing-box/scripts/configure_tun.sh
    else
        echo "Invalid mode, skips applying firewall rules."
        exit 1
    fi
}

case $autostart_choice in
    1)
        # 检查自启动是否已经开启
        if [ -f /etc/rc.d/S99sing-box ]; then
            echo -e "${GREEN}Automatic startup is enabled and no operation is required.${NC}"
            exit 0  # 返回主菜单
        fi

        echo -e "${GREEN}Enable autostart...${NC}"

        # 启用并启动服务
        /etc/init.d/sing-box enable
        /etc/init.d/sing-box start
        cmd_status=$?

        if [ "$cmd_status" -eq 0 ]; then
            echo -e "${GREEN}Autostart has been successfully enabled.${NC}"
        else
            echo -e "${RED}Failed to enable autostart.${NC}"
        fi
        ;;
    2)
        # 检查自启动是否已经禁用
        if [ ! -f /etc/rc.d/S99sing-box ]; then
            echo -e "${GREEN}Auto-start is disabled, no action is required.${NC}"
            exit 0  # 返回主菜单
        fi

        echo -e "${RED}Disable autostart...${NC}"
        
        # 禁用并停止服务
        /etc/init.d/sing-box disable
        cmd_status=$?

        if [ "$cmd_status" -eq 0 ]; then
            echo -e "${GREEN}Autostart successfully disabled.${NC}"
        else
            echo -e "${RED}Disabling autostart failed.${NC}"
        fi
        ;;
    *)
        echo -e "${RED}Invalid selection${NC}"
        ;;
esac

# 调用应用防火墙规则的函数
if [ "$1" = "apply_firewall" ]; then
    apply_firewall
fi
