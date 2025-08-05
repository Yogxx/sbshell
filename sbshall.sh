#!/bin/bash
# 定义主脚本的下载URL
DEBIAN_MAIN_SCRIPT_URL="https://ghfast.top/https://raw.githubusercontent.com/Yogxx/sbshell/refs/heads/main/debian/menu.sh"
OPENWRT_MAIN_SCRIPT_URL="https://gh-proxy.com/https://raw.githubusercontent.com/Yogxx/sbshell/refs/heads/main/openwrt/menu.sh"
 
# 脚本下载目录
SCRIPT_DIR="/etc/sing-box/scripts"

# 定义颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 检查系统是否支持
if [[ "$(uname -s)" != "Linux" ]]; then
    echo -e "${RED}The current system does not support running this script.${NC}"
    exit 1
fi

# 检查发行版并下载相应的主脚本
if grep -qi 'debian\|ubuntu\|armbian' /etc/os-release; then
    echo -e "${GREEN}The system supports running this script, which is Debian/Ubuntu/Armbian.${NC}"
    MAIN_SCRIPT_URL="$DEBIAN_MAIN_SCRIPT_URL"
    DEPENDENCIES=("wget" "nftables")

    # 检查 sudo 是否安装
    if ! command -v sudo &> /dev/null; then
        echo -e "${RED}sudo is not installed.${NC}"
        read -rp "Do you want to install sudo? (y/n): " install_sudo
        if [[ "$install_sudo" =~ ^[Yy]$ ]]; then
            apt-get update
            apt-get install -y sudo
            if ! command -v sudo &> /dev/null; then
                echo -e "${RED}Installation of sudo failed, please install sudo manually and rerun this script.${NC}"
                exit 1
            fi
            echo -e "${GREEN}sudo was installed successfully.${NC}"
        else
            echo -e "${RED}The script cannot continue because sudo is not installed.${NC}"
            exit 1
        fi
    fi

    # 检查并安装缺失的依赖项
    for DEP in "${DEPENDENCIES[@]}"; do
        if [ "$DEP" == "nftables" ]; then
            CHECK_CMD="nft --version"
        else
            CHECK_CMD="wget --version"
        fi

        if ! $CHECK_CMD &> /dev/null; then
            echo -e "${RED}$DEP Not installed.${NC}"
            read -rp "Is it installed? $DEP?(y/n): " install_dep
            if [[ "$install_dep" =~ ^[Yy]$ ]]; then
                sudo apt-get update
                sudo apt-get install -y "$DEP"
                if ! $CHECK_CMD &> /dev/null; then
                    echo -e "${RED}Install $DEP fail，Please install manually $DEP and rerun the script.${NC}"
                    exit 1
                fi
                echo -e "${GREEN}$DEP The installation was successful.${NC}"
            else
                echo -e "${RED}The script cannot continue because $DEP is not installed.${NC}"
                exit 1
            fi
        fi
    done
elif grep -qi 'openwrt' /etc/os-release; then
    echo -e "${GREEN}The system is OpenWRT, which supports running this script.${NC}"
    MAIN_SCRIPT_URL="$OPENWRT_MAIN_SCRIPT_URL"
    DEPENDENCIES=("nftables")

    # 检查并安装缺失的依赖项
    for DEP in "${DEPENDENCIES[@]}"; do
        if [ "$DEP" == "nftables" ]; then
            CHECK_CMD="nft --version"
        fi

        if ! $CHECK_CMD &> /dev/null; then
            echo -e "${RED}$DEP Not installed.${NC}"
            read -rp "Is it installed? $DEP?(y/n): " install_dep
            if [[ "$install_dep" =~ ^[Yy]$ ]]; then
                opkg update
                opkg install "$DEP"
                if ! $CHECK_CMD &> /dev/null; then
                    echo -e "${RED}Installation of $DEP failed, please install $DEP manually and rerun this script.${NC}"
                    exit 1
                fi
                echo -e "${GREEN}$DEP The installation was successful.${NC}"
            else
                echo -e "${RED}The script cannot continue because $DEP is not installed.${NC}"
                exit 1
            fi
        fi
    done
else
    echo -e "${RED}The current system is not Debian/Ubuntu/Armbian/OpenWRT and does not support running this script.${NC}"
    exit 1
fi

# 确保脚本目录存在并设置权限
if grep -qi 'openwrt' /etc/os-release; then
    mkdir -p "$SCRIPT_DIR"
else
    sudo mkdir -p "$SCRIPT_DIR"
    sudo chown "$(whoami)":"$(whoami)" "$SCRIPT_DIR"
fi

# 下载并执行主脚本
if grep -qi 'openwrt' /etc/os-release; then
    curl -s -o "$SCRIPT_DIR/menu.sh" "$MAIN_SCRIPT_URL"
else
    wget -q -O "$SCRIPT_DIR/menu.sh" "$MAIN_SCRIPT_URL"
fi

echo -e "${GREEN}The script is downloading, please wait patiently...${NC}"
echo -e "${YELLOW}Note: When installing and updating Singbox, try to use a proxy environment. Remember to turn off the proxy when running Singbox!${NC}"

if ! [ -f "$SCRIPT_DIR/menu.sh" ]; then
    echo -e "${RED}Failed to download the main script, please check your network connection.${NC}"
    exit 1
fi

chmod +x "$SCRIPT_DIR/menu.sh"
bash "$SCRIPT_DIR/menu.sh"
