#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

echo -e "${GREEN}Set up auto-startup...${NC}"
echo "Please select an action (1: Enable auto-start, 2: Disable auto-start)"
read -rp "(1/2): " autostart_choice

apply_firewall() {
    MODE=$(grep -oP '(?<=^MODE=).*' /etc/sing-box/mode.conf)
    if [ "$MODE" = "TProxy" ]; then
        echo "Apply firewall rules in TProxy mode..."
        bash /etc/sing-box/scripts/configure_tproxy.sh
    elif [ "$MODE" = "TUN" ]; then
        echo "Apply firewall rules in TUN mode..."
        bash /etc/sing-box/scripts/configure_tun.sh
    else
        echo "Invalid mode, skips applying firewall rules."
        exit 1
    fi
}

case $autostart_choice in
    1)
        # 检查自启动是否已经开启
        if systemctl is-enabled sing-box.service >/dev/null 2>&1 && systemctl is-enabled nftables-singbox.service >/dev/null 2>&1; then
            echo -e "${GREEN}Automatic startup is already enabled, no operation is required.${NC}"
            exit 0  # 返回主菜单
        fi

        echo -e "${GREEN}Enable Autostart...${NC}"

        # 删除旧的配置文件以避免重复配置
        sudo rm -f /etc/systemd/system/nftables-singbox.service

        # 创建 nftables-singbox.service 文件
        sudo bash -c 'cat > /etc/systemd/system/nftables-singbox.service <<EOF
[Unit]
Description=Apply nftables rules for Sing-Box
After=network.target

[Service]
ExecStart=/etc/sing-box/scripts/manage_autostart.sh apply_firewall
Type=oneshot
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF'

        # 修改 sing-box.service 文件
        sudo bash -c "sed -i '/After=network.target nss-lookup.target network-online.target/a After=nftables-singbox.service' /usr/lib/systemd/system/sing-box.service"
        sudo bash -c "sed -i '/^Requires=/d' /usr/lib/systemd/system/sing-box.service"
        sudo bash -c "sed -i '/

\[Unit\]

/a Requires=nftables-singbox.service' /usr/lib/systemd/system/sing-box.service"

        # 启用并启动服务
        sudo systemctl daemon-reload
        sudo systemctl enable nftables-singbox.service sing-box.service
        sudo systemctl start nftables-singbox.service sing-box.service
        cmd_status=$?

        if [ "$cmd_status" -eq 0 ]; then
            echo -e "${GREEN}Autostart has been successfully enabled.${NC}"
        else
            echo -e "${RED}Failed to enable autostart.${NC}"
        fi
        ;;
    2)
        # 检查自启动是否已经禁用
        if ! systemctl is-enabled sing-box.service >/dev/null 2>&1 && ! systemctl is-enabled nftables-singbox.service >/dev/null 2>&1; then
            echo -e "${GREEN}Auto-start has been disabled, no action is required.${NC}"
            exit 0  # 返回主菜单
        fi

        echo -e "${RED}Disable auto-start...${NC}"
        
        # 禁用并停止服务
        sudo systemctl disable sing-box.service
        sudo systemctl disable nftables-singbox.service
        sudo systemctl stop sing-box.service
        sudo systemctl stop nftables-singbox.service

        # 删除 nftables-singbox.service 文件
        sudo rm -f /etc/systemd/system/nftables-singbox.service

        # 还原 sing-box.service 文件
        sudo bash -c "sed -i '/After=nftables-singbox.service/d' /usr/lib/systemd/system/sing-box.service"
        sudo bash -c "sed -i '/Requires=nftables-singbox.service/d' /usr/lib/systemd/system/sing-box.service"

        # 重新加载 systemd
        sudo systemctl daemon-reload
        cmd_status=$?

        if [ "$cmd_status" -eq 0 ]; then
            echo -e "${GREEN}Autostart has been successfully disabled.${NC}"
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
