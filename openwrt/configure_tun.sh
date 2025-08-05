#!/bin/bash

# 配置参数
PROXY_FWMARK=1
PROXY_ROUTE_TABLE=100
INTERFACE=$(ip route show default | awk '/default/ {print $5}')

# 读取当前模式
MODE=$(grep -E '^MODE=' /etc/sing-box/mode.conf | sed 's/^MODE=//')

# 清理 TProxy 模式的防火墙规则
clearTProxyRules() {
    nft list table inet sing-box >/dev/null 2>&1 && nft delete table inet sing-box
    ip rule del fwmark $PROXY_FWMARK lookup $PROXY_ROUTE_TABLE 2>/dev/null
    ip route del local default dev "$INTERFACE" table $PROXY_ROUTE_TABLE 2>/dev/null
    echo "Clean up firewall rules for TProxy mode"
}

if [ "$MODE" = "TUN" ]; then
    echo "Applying firewall rules in TUN mode..."

    # 清理 TProxy 模式的防火墙规则
    clearTProxyRules

    # 确保目录存在
    mkdir -p /etc/sing-box/tun

    # 设置 TUN 模式的具体配置
    cat > /etc/sing-box/tun/nftables.conf <<EOF
table inet sing-box {
    chain input {
        type filter hook input priority 0; policy accept;
    }
    chain forward {
        type filter hook forward priority 0; policy accept;
    }
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF

    # 应用防火墙规则
    nft -f /etc/sing-box/tun/nftables.conf

    # 持久化防火墙规则
    nft list ruleset > /etc/nftables.conf

    echo "TUN mode firewall rules are applied."
else
    echo "The current mode is not TUN mode, skipping firewall rule configuration." >/dev/null 2>&1
fi
