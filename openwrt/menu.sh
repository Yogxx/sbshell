#!/bin/bash

#################################################
# 描述: OpenWRT 官方sing-box 全自动脚本
# 版本: 2.1.0
#################################################

# 定义颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 脚本下载目录和初始化标志文件
SCRIPT_DIR="/etc/sing-box/scripts"
INITIALIZED_FILE="$SCRIPT_DIR/.initialized"

mkdir -p "$SCRIPT_DIR"
if ! grep -qi 'openwrt' /etc/os-release; then
    chown "$(whoami)":"$(whoami)" "$SCRIPT_DIR"
fi

# The script's URL base path
BASE_URL="https://raw.githubusercontent.com/Yogxx/sbshell/refs/heads/main/openwrt"
                               
# 脚本列表
SCRIPTS=(
    "check_environment.sh"     # 检查系统环境
    "install_singbox.sh"       # 安装 Sing-box
    "manual_input.sh"          # 手动输入配置
    "manual_update.sh"         # 手动更新配置
    "auto_update.sh"           # 自动更新配置
    "configure_tproxy.sh"      # 配置 TProxy 模式
    "configure_tun.sh"         # 配置 TUN 模式
    "start_singbox.sh"         # 手动启动 Sing-box
    "stop_singbox.sh"          # 手动停止 Sing-box
    "clean_nft.sh"             # 清理 nftables 规则
    "set_defaults.sh"          # 设置默认配置
    "commands.sh"              # 常用命令
    "switch_mode.sh"           # 切换代理模式
    "manage_autostart.sh"      # 设置自启动
    "check_config.sh"          # 检查配置文件
    "update_scripts.sh"        # 更新脚本
    "update_ui.sh"             # 控制面板安装/更新/检查
    "menu.sh"                  # 主菜单
)

# 下载并设置单个脚本，带重试和日志记录逻辑
download_script() {
    local SCRIPT="$1"
    local RETRIES=5  # 增加重试次数
    local RETRY_DELAY=5

    for ((i=1; i<=RETRIES; i++)); do
        if curl -s -o "$SCRIPT_DIR/$SCRIPT" "$BASE_URL/$SCRIPT"; then
            chmod +x "$SCRIPT_DIR/$SCRIPT"
            return 0
        else
            echo -e "${YELLOW} Failed to download $SCRIPT, retrying $i/${RETRIES}...${NC}"
            sleep "$RETRY_DELAY"
        fi
    done

    echo -e "${RED}Failed to download $SCRIPT, please check the network connection.${NC}"
    return 1
}

# 并行下载脚本
parallel_download_scripts() {
    local pids=()
    for SCRIPT in "${SCRIPTS[@]}"; do
        download_script "$SCRIPT" &
        pids+=("$!")
    done

    for pid in "${pids[@]}"; do
        wait "$pid"
    done
}

check_and_download_scripts() {
    local missing_scripts=()
    for SCRIPT in "${SCRIPTS[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$SCRIPT" ]; then
            missing_scripts+=("$SCRIPT")
        fi
    done

    if [ ${#missing_scripts[@]} -ne 0 ]; then
        echo -e "${CYAN}The script is downloading, please wait patiently...${NC}"
        for SCRIPT in "${missing_scripts[@]}"; do
            download_script "$SCRIPT" || {
                echo -e "${RED} Failed to download $SCRIPT, do you want to retry? (y/n): ${NC}"
                read -r retry_choice
                if [[ "$retry_choice" =~ ^[Yy]$ ]]; then
                    download_script "$SCRIPT"
                else
                    echo -e "${RED}Skipping $SCRIPT download.${NC}"
                fi
            }
        done
    fi
}

# 初始化操作
initialize() {
    # 检查是否存在旧脚本
    if ls "$SCRIPT_DIR"/*.sh 1> /dev/null 2>&1; then
        find "$SCRIPT_DIR" -type f -name "*.sh" ! -name "menu.sh" -exec rm -f {} \;
        rm -f "$INITIALIZED_FILE"
    fi

    # 重新下载脚本
    parallel_download_scripts
    # 进行首次运行的其他初始化操作
    auto_setup
    touch "$INITIALIZED_FILE"
}

# 自动引导设置
auto_setup() {
    if [ -f /etc/init.d/sing-box ]; then
        /etc/init.d/sing-box stop
    fi
    mkdir -p /etc/sing-box/
    [ -f /etc/sing-box/mode.conf ] || touch /etc/sing-box/mode.conf
    chmod 777 /etc/sing-box/mode.conf
    bash "$SCRIPT_DIR/check_environment.sh"
    command -v sing-box &> /dev/null || bash "$SCRIPT_DIR/install_singbox.sh" || bash "$SCRIPT_DIR/check_update.sh"
    bash "$SCRIPT_DIR/switch_mode.sh"
    bash "$SCRIPT_DIR/manual_input.sh"
    bash "$SCRIPT_DIR/start_singbox.sh"  
}

# 检查是否需要初始化
if [ ! -f "$INITIALIZED_FILE" ]; then
    echo -e "${CYAN}Press Enter to enter the initialization boot settings, enter skip to skip the boot${NC}"
    read -r init_choice
    if [[ "$init_choice" =~ ^[Ss]kip$ ]]; then
        echo -e "${CYAN}Skip the initialization boot and go directly to the menu...${NC}"
    else
        initialize
    fi
fi

# 添加别名
[ -f ~/.bashrc ] || touch ~/.bashrc
if ! grep -q "alias sb=" ~/.bashrc || true; then
    echo "alias sb='bash $SCRIPT_DIR/menu.sh menu'" >> ~/.bashrc
fi

# 创建快捷脚本
if [ ! -f /usr/bin/sb ]; then
    echo -e '#!/bin/bash\nbash /etc/sing-box/scripts/menu.sh menu' | tee /usr/bin/sb >/dev/null
    chmod +x /usr/bin/sb
fi

show_menu() {
    echo -e "${CYAN}=========== SBSHELL MANAGEMENT MENU ===========${NC}"
    echo -e "${GREEN}1. SWITCH TPROXY/TUN MODE${NC}"
    echo -e "${GREEN}2. MANUALLY UPDATE THE CONFIGURATION FILE${NC}"
    echo -e "${GREEN}3. AUTOMATICALLY UPDATE CONFIGURATION FILES${NC}"
    echo -e "${GREEN}4. START SING-BOX${NC}"
    echo -e "${GREEN}5. STOP SING-BOX${NC}"
    echo -e "${GREEN}6. DEFAULT PARAMETER SETTINGS${NC}"
    echo -e "${GREEN}7. SET UP AUTO-START${NC}"
    echo -e "${GREEN}8. COMMON COMMANDS${NC}"
    echo -e "${GREEN}9. UPDATE SCRIPT${NC}"
    echo -e "${GREEN}10. UPDATE UI${NC}"
    echo -e "${GREEN}0. QUIT${NC}"
    echo -e "${CYAN}=======================================${NC}"
}

handle_choice() {
    read -rp "Please select an operation: " choice
    case $choice in
        1)
            bash "$SCRIPT_DIR/switch_mode.sh"
            bash "$SCRIPT_DIR/manual_input.sh"
            bash "$SCRIPT_DIR/start_singbox.sh"
            ;;
        2)
            bash "$SCRIPT_DIR/manual_update.sh"
            ;;
        3)
            bash "$SCRIPT_DIR/auto_update.sh"
            ;;
        4)
            bash "$SCRIPT_DIR/start_singbox.sh"
            ;;
        5)
            bash "$SCRIPT_DIR/stop_singbox.sh"
            ;;
        6)
            bash "$SCRIPT_DIR/set_defaults.sh"
            ;;
        7)
            bash "$SCRIPT_DIR/manage_autostart.sh"
            ;;
        8)
            bash "$SCRIPT_DIR/commands.sh"
            ;;
        9)
            bash "$SCRIPT_DIR/update_scripts.sh"
            ;;
        10)
            bash "$SCRIPT_DIR/update_ui.sh"
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid selection${NC}"
            ;;
    esac
}

# 主循环
while true; do
    show_menu
    handle_choice
done
