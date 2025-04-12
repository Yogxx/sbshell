#!/bin/bash

# Defining Colors
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "Detecting the latest version of sing-box..."
# Update package information
sudo apt-get update -qq > /dev/null 2>&1

# Check sing-box version
if command -v sing-box &> /dev/null; then
    current_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
    echo -e "${CYAN}The currently installed sing-box version is:${NC} $current_version"
    
    # Get the latest stable and test version information
    stable_version=$(apt-cache policy sing-box | grep Candidate | awk '{print $2}')
    beta_version=$(apt-cache policy sing-box-beta | grep Candidate | awk '{print $2}')
    
    echo -e "${CYAN}Latest stable version：${NC} $stable_version"
    echo -e "${CYAN}Latest beta version：${NC} $beta_version"
    
    # Provides the option to switch versions
    while true; do
        read -rp "Whether to switch versions (1: stable version, 2: beta version) (current version: $current_version, press Enter to cancel the operation): " switch_choice
        case $switch_choice in
            1)
                echo "Selected to switch to stable version"
                sudo apt-get install sing-box -y
                break
                ;;
            2)
                echo "Selected Switch to beta"
                sudo apt-get install sing-box-beta -y
                break
                ;;
            '')
                echo "不进行版本切换"
                break
                ;;
            *)
                echo -e "${RED}无效的选择，请输入 1 或 2。${NC}"
                ;;
        esac
    done
else
    echo -e "${RED}sing-box 未安装${NC}"
fi
