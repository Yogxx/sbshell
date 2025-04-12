#!/bin/bash

# Make sure to run with root privileges
if [ "$(id -u)" != "0" ]; then
    echo "Error: This script requires root privileges"
    exit 1
fi

# Check if sing-box is installed
if command -v sing-box &> /dev/null; then
    current_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
    echo "sing-box is installed, version：$current_version"
else
    echo "sing-box not installed"
fi

# Check and enable IP forwarding
ipv4_forward=$(sysctl net.ipv4.ip_forward | awk '{print $3}')
ipv6_forward=$(sysctl net.ipv6.conf.all.forwarding | awk '{print $3}')

if [ "$ipv4_forward" -eq 1 ] && [ "$ipv6_forward" -eq 1 ]; then
    echo "IP forwarding is enabled"
else
    echo "Enable IP forwarding..."
    sudo sed -i '/net.ipv4.ip_forward/s/^#//;/net.ipv6.conf.all.forwarding/s/^#//' /etc/sysctl.conf
    sudo sysctl -p
    echo "IP forwarding has been successfully enabled"
fi
