#!/bin/bash

# Defining Colors
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

CONFIG_FILE="/etc/sing-box/config.json"

# Check if the configuration file exists
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${CYAN}Check the configuration file ${CONFIG_FILE} ...${NC}"
    # Verify the configuration file
    if sing-box check -c "$CONFIG_FILE"; then
        echo -e "${CYAN}Configuration file verification passed!${NC}"
    else
        echo -e "${RED}Configuration file validation failed!${NC}"
        exit 1
    fi
else
    echo -e "${RED}Configuration Files ${CONFIG_FILE} Doesn't exist!${NC}"
    exit 1
fi
