#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 检查 sing-box 是否已安装
if ! command -v sing-box &> /dev/null; then
    echo "Please install sing-box before executing this command."
    bash /etc/sing-box/scripts/install_singbox.sh
    exit 1
fi

# 确定文件存在
mkdir -p /etc/sing-box/
[ -f /etc/sing-box/mode.conf ] || touch /etc/sing-box/mode.conf
chmod 777 /etc/sing-box/mode.conf

echo "Switching mode starts...Please enter the operation according to the prompts."


while true; do
    # 选择模式
    read -rp "Please select the mode (1: TProxy mode, 2: TUN mode): " mode_choice

    /etc/init.d/sing-box stop

    case $mode_choice in
        1)
            echo "MODE=TProxy" | tee /etc/sing-box/mode.conf > /dev/null
            echo -e "${GREEN}The current selected mode is: TProxy mode${NC}"
            break
            ;;
        2)
            echo "MODE=TUN" | tee /etc/sing-box/mode.conf > /dev/null
            echo -e "${GREEN}The current selected mode is: TUN mode${NC}"
            break
            ;;
        *)
            echo -e "${RED}Invalid selection, please re-enter.${NC}"
            ;;
    esac
done
