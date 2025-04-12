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