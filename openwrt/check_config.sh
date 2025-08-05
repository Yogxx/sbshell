#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

CONFIG_FILE="/etc/sing-box/config.json"

# 检查配置文件是否存在
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${CYAN}Check the configuration file ${CONFIG_FILE} ...${NC}"
    # 验证配置文件
    if sing-box check -c "$CONFIG_FILE"; then
        echo -e "${CYAN}Configuration file verification passed!${NC}"
    else
        echo -e "${RED}Configuration file validation failed!${NC}"
        exit 1
    fi
else
    echo -e "${RED}Configuration file ${CONFIG_FILE} does not exist!${NC}"
    exit 1
fi
