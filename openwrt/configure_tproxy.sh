#!/bin/sh

# Configuration parameters
TPROXY_PORT=7895  # Same as defined in sing-box
ROUTING_MARK=666  # Same as defined in sing-box
PROXY_FWMARK=1
PROXY_ROUTE_TABLE=100
INTERFACE=$(ip route show default | awk '/default/ {print $5; exit}')

# Reserved IP address set
ReservedIP4='{ 127.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 169.254.0.0/16, 172.16.0.0/12, 192.0.0.0/24, 192.0.2.0/24, 198.51.100.0/24, 192.88.99.0/24, 192.168.0.0/16, 203.0.113.0/24, 224.0.0.0/4, 240.0.0.0/4, 255.255.255.255/32 }'
CustomBypassIP='{ 192.168.0.0/16, 10.0.0.0/8 }'  # Custom bypass IP address set

# Read the current mode
MODE=$(grep -E '^MODE=' /etc/sing-box/mode.conf | sed 's/^MODE=//')

# Check whether the specified routing table exists
check_route_exists() {
    ip route show table "$1" >/dev/null 2>&1
    return $?
}

# Create the routing table if it does not exist
create_route_table_if_not_exists() {
    if ! check_route_exists "$PROXY_ROUTE_TABLE"; then
        echo "The routing table does not exist and is being created..."
        ip route add local default dev "$INTERFACE" table "$PROXY_ROUTE_TABLE" || { echo "Failed to create routing table"; exit 1; }
    fi
}

# Wait for the FIB table to load.
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

# Clean up existing sing-box firewall rules
clearSingboxRules() {
    nft list table inet sing-box >/dev/null 2>&1 && nft delete table inet sing-box
    ip rule del fwmark $PROXY_FWMARK lookup $PROXY_ROUTE_TABLE 2>/dev/null
    ip route del local default dev "${INTERFACE}" table $PROXY_ROUTE_TABLE 2>/dev/null
    echo "Clean up sing-box related firewall rules"
}

# Apply firewall rules only in TProxy mode
if [ "$MODE" = "TProxy" ]; then
    echo "Apply firewall rules in TProxy mode..."

    # Create and ensure the routing table exists
    create_route_table_if_not_exists

    # Wait for the FIB table to load.
    if ! wait_for_fib_table; then
        echo "FIB table preparation failed, exiting script."
        exit 1
    fi

    # Cleaning up existing rules
    clearSingboxRules

    # Setting up IP rules and routing
    ip rule add fwmark $PROXY_FWMARK table $PROXY_ROUTE_TABLE
    ip route add local default dev "$INTERFACE" table $PROXY_ROUTE_TABLE
    sysctl -w net.ipv4.ip_forward=1 > /dev/null

    # Make sure the directory exists
    mkdir -p /etc/sing-box/nft

    # Manually create inet table
    nft add table inet sing-box

    # Setting nftables rules in TProxy mode
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

        # DNS requests are redirected to the local TProxy port
        meta l4proto { tcp, udp } th dport 53 tproxy to :$TPROXY_PORT accept

        # Custom bypass address
        ip daddr $CustomBypassIP accept

        # Access to the local TProxy port is denied
        fib daddr type local meta l4proto { tcp, udp } th dport $TPROXY_PORT reject with icmpx type host-unreachable

        # Local Address Bypass
        fib daddr type local accept

        # Reserved Address Bypass
        ip daddr @RESERVED_IPSET accept

        #Allow all traffic passing through DNAT
        ct status dnat accept comment "Allow forwarded traffic"

        # Redirect remaining traffic to TProxy port and set flags
        meta l4proto { tcp, udp } tproxy to :$TPROXY_PORT meta mark set $PROXY_FWMARK
    }

    chain output_tproxy {
        type route hook output priority mangle; policy accept;

        # Allow local loopback interface traffic
        meta oifname "lo" accept

        # Traffic from local sing-box bypasses
        meta mark $ROUTING_MARK accept

        # DNS request marking
        meta l4proto { tcp, udp } th dport 53 meta mark set $PROXY_FWMARK

        # Bypassing NBNS traffic
        udp dport { netbios-ns, netbios-dgm, netbios-ssn } accept

        # Custom bypass address
        ip daddr $CustomBypassIP accept

        # Local Address Bypass
        fib daddr type local accept

        # Reserved Address Bypass
        ip daddr @RESERVED_IPSET accept

        # Mark and redirect remaining traffic
        meta l4proto { tcp, udp } meta mark set $PROXY_FWMARK
    }
}
EOF

    # Apply firewall rules and IP routing
    echo "Applying nftables rules..."  # Add debug information
    nft -f /etc/sing-box/nft/nftables.conf

    # Check for errors
    if [ $? -ne 0 ]; then
        echo "Error applying nftables rules. Please check the configuration."
        exit 1
    fi

    # Persistent firewall rules
    nft list ruleset > /etc/nftables.conf

    echo "Firewall rules for TProxy mode are applied."
else
    echo "The current mode is TUN mode and no firewall rules need to be applied." >/dev/null 2>&1
fi
