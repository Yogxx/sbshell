#!/bin/bash

# Configuration parameters
PROXY_FWMARK=1
PROXY_ROUTE_TABLE=100
INTERFACE=$(ip route show default | awk '/default/ {print $5}')

# Read the current mode
MODE=$(grep -E '^MODE=' /etc/sing-box/mode.conf | sed 's/^MODE=//')

# Clean up firewall rules for TProxy mode
clearTProxyRules() {
    nft list table inet sing-box >/dev/null 2>&1 && nft delete table inet sing-box
    ip rule del fwmark $PROXY_FWMARK lookup $PROXY_ROUTE_TABLE 2>/dev/null
    ip route del local default dev "$INTERFACE" table $PROXY_ROUTE_TABLE 2>/dev/null
    echo "Clean up firewall rules for TProxy mode"
}

if [ "$MODE" = "TUN" ]; then
    echo "Apply firewall rules in TUN mode..."

    # Clean up firewall rules for TProxy mode
    clearTProxyRules

    # Make sure the directory exists
    mkdir -p /etc/sing-box/tun

    # Set the specific configuration of TUN mode
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

    # Application firewall rules
    nft -f /etc/sing-box/tun/nftables.conf

    # Persistent firewall rules
    nft list ruleset > /etc/nftables.conf

    echo "The TUN mode firewall rules are applied."
else
    echo "The current mode is not TUN mode, skipping firewall rule configuration." >/dev/null 2>&1
fi
