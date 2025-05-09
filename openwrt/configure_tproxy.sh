#!/bin/sh

# 配置参数
TPROXY_PORT=7895  # 与 sing-box 中定义的一致
ROUTING_MARK=666  # 与 sing-box 中定义的一致
PROXY_FWMARK=1
PROXY_ROUTE_TABLE=100
INTERFACE=$(ip route show default | awk '/default/ {print $5; exit}')

# 保留 IP 地址集合
ReservedIP4='{ 127.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 169.254.0.0/16, 172.16.0.0/12, 192.0.0.0/24, 192.0.2.0/24, 198.51.100.0/24, 192.88.99.0/24, 192.168.0.0/16, 203.0.113.0/24, 224.0.0.0/4, 240.0.0.0/4, 255.255.255.255/32 }'
CustomBypassIP='{ 192.168.0.0/16, 10.0.0.0/8 }'  # 自定义绕过的 IP 地址集合

# 读取当前模式
MODE=$(grep -E '^MODE=' /etc/sing-box/mode.conf | sed 's/^MODE=//')

# 检查指定路由表是否存在
check_route_exists() {
    ip route show table "$1" >/dev/null 2>&1
    return $?
}

# 创建路由表，如果不存在的话
create_route_table_if_not_exists() {
    if ! check_route_exists "$PROXY_ROUTE_TABLE"; then
        echo "The routing table does not exist and is being created..."
        ip route add local default dev "$INTERFACE" table "$PROXY_ROUTE_TABLE" || { echo "Failed to create routing table"; exit 1; }
    fi
}

# 等待 FIB 表加载完成
wait_for_fib_table() {
    i=1
    while [ $i -le 10 ]; do
        if ip route show table "$PROXY_ROUTE_TABLE" >/dev/null 2>&1; then
            return 0
        fi
        echo "Waiting for FIB table to load, waiting for $i seconds..."
        i=$((i + 1))
    done
    echo "FIB table loading failed, maximum number of retries exceeded"
    return 1
}

# 清理现有 sing-box 防火墙规则
clearSingboxRules() {
    nft list table inet sing-box >/dev/null 2>&1 && nft delete table inet sing-box
    ip rule del fwmark $PROXY_FWMARK lookup $PROXY_ROUTE_TABLE 2>/dev/null
    ip route del local default dev "${INTERFACE}" table $PROXY_ROUTE_TABLE 2>/dev/null
    echo "Clean up sing-box related firewall rules"
}

# 仅在 TProxy 模式下应用防火墙规则
if [ "$MODE" = "TProxy" ]; then
    echo "Apply firewall rules in TProxy mode..."

    # 创建并确保路由表存在
    create_route_table_if_not_exists

    # 等待 FIB 表加载完成
    if ! wait_for_fib_table; then
        echo "FIB table preparation failed, exiting script."
        exit 1
    fi

    # 清理现有规则
    clearSingboxRules

    # 设置 IP 规则和路由
    ip rule add fwmark $PROXY_FWMARK table $PROXY_ROUTE_TABLE
    ip route add local default dev "$INTERFACE" table $PROXY_ROUTE_TABLE
    sysctl -w net.ipv4.ip_forward=1 > /dev/null

    # 确保目录存在
    mkdir -p /etc/sing-box/nft

    # 手动创建 inet 表
    nft add table inet sing-box

    # 设置 TProxy 模式下的 nftables 规则
    cat > /etc/sing-box/nft/nftables.conf <<EOF
table inet sing-box {
    set RESERVED_IPSET {
        type ipv4_addr
        flags interval
        auto-merge
        elements = $ReservedIP4
    }

    chain prerouting_tproxy {
        type filter hook prerouting priority mangle; policy accept;

        # DNS 请求重定向到本地 TProxy 端口
        meta l4proto { tcp, udp } th dport 53 tproxy to :$TPROXY_PORT accept

        # 自定义绕过地址
        ip daddr $CustomBypassIP accept

        # 拒绝访问本地 TProxy 端口
        fib daddr type local meta l4proto { tcp, udp } th dport $TPROXY_PORT reject with icmpx type host-unreachable

        # 本地地址绕过
        fib daddr type local accept

        # 保留地址绕过
        ip daddr @RESERVED_IPSET accept

        #放行所有经过 DNAT 的流量
        ct status dnat accept comment "Allow forwarded traffic"

        # 重定向剩余流量到 TProxy 端口并设置标记
        meta l4proto { tcp, udp } tproxy to :$TPROXY_PORT meta mark set $PROXY_FWMARK
    }

    chain output_tproxy {
        type route hook output priority mangle; policy accept;

        # 放行本地回环接口流量
        meta oifname "lo" accept

        # 本地 sing-box 发出的流量绕过
        meta mark $ROUTING_MARK accept

        # DNS 请求标记
        meta l4proto { tcp, udp } th dport 53 meta mark set $PROXY_FWMARK

        # 绕过 NBNS 流量
        udp dport { netbios-ns, netbios-dgm, netbios-ssn } accept

        # 自定义绕过地址
        ip daddr $CustomBypassIP accept

        # 本地地址绕过
        fib daddr type local accept

        # 保留地址绕过
        ip daddr @RESERVED_IPSET accept

        # 标记并重定向剩余流量
        meta l4proto { tcp, udp } meta mark set $PROXY_FWMARK
    }
}
EOF

    # 应用防火墙规则和 IP 路由
    echo "Applying nftables rules..."  # 添加调试信息
    nft -f /etc/sing-box/nft/nftables.conf

    # 检查是否有错误
    if [ $? -ne 0 ]; then
        echo "Error applying nftables rules. Please check the configuration."
        exit 1
    fi

    # 持久化防火墙规则
    nft list ruleset > /etc/nftables.conf

    echo "Firewall rules for TProxy mode are applied."
else
    echo "The current mode is TUN mode, no firewall rules need to be applied." >/dev/null 2>&1
fi
