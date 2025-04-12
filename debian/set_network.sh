#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无颜色

# 捕获 Ctrl+C 信号并处理
trap 'echo -e "\n${RED}The operation has been canceled, returning to the Network Settings menu.${NC}"; exit 1' SIGINT

# 获取当前系统的 IP 地址、网关和 DNS
CURRENT_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}')
CURRENT_GATEWAY=$(ip route show default | awk '{print $3}')
CURRENT_DNS=$(grep 'nameserver' /etc/resolv.conf | awk '{print $2}')

echo -e "${YELLOW}Current IP address: $CURRENT_IP${NC}"
echo -e "${YELLOW}Current gateway address: $CURRENT_GATEWAY${NC}"
echo -e "${YELLOW}Current DNS Servers: $CURRENT_DNS${NC}"

# 获取网卡名称
INTERFACE=$(ip -br link show | awk '{print $1}' | grep -v "lo" | head -n 1)
[ -z "$INTERFACE" ] && { echo -e "${RED}The network interface was not found and the program exited.${NC}"; exit 1; }

echo -e "${YELLOW}The detected network interface is: $INTERFACE${NC}"

while true; do
    # 提示用户输入静态 IP 地址、网关和 DNS
    read -rp "Please enter a static IP address: " IP_ADDRESS
    read -rp "Please enter the gateway address: " GATEWAY
    read -rp "Please enter the DNS server address (separate multiple addresses with spaces): " DNS_SERVERS

    echo -e "${YELLOW}The configuration information you entered is as follows:${NC}"
    echo -e "IP address: $IP_ADDRESS"
    echo -e "Gateway Address: $GATEWAY"
    echo -e "DNS Server: $DNS_SERVERS"

    read -rp "Do you confirm the above configuration information? (y/n): " confirm_choice
    if [[ "$confirm_choice" =~ ^[Yy]$ ]]; then
        # 配置文件路径
        INTERFACES_FILE="/etc/network/interfaces"
        RESOLV_CONF_FILE="/etc/resolv.conf"

        # 更新网络配置
        cat > $INTERFACES_FILE <<EOL
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
allow-hotplug $INTERFACE
iface $INTERFACE inet static
    address $IP_ADDRESS
    netmask 255.255.255.0
    gateway $GATEWAY
EOL

        # 更新 resolv.conf 文件
        echo > $RESOLV_CONF_FILE
        for dns in $DNS_SERVERS; do
            echo "nameserver $dns" >> $RESOLV_CONF_FILE
        done

        # 重启网络服务
        sudo systemctl restart networking

        # 输出配置结果
        echo -e "${GREEN}Static IP address and DNS configuration complete!${NC}"
        break
    else
        echo -e "${RED}Please re-enter the configuration information.${NC}"
    fi
done
