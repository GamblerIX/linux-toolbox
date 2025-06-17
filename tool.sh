#!/bin/bash
# -*- coding: utf-8 -*-

# Linux Toolbox - Main Script

# --- Global Variables ---
TOOLBOX_LIB_DIR="/usr/local/lib/linux-toolbox"

# --- Source Library Files ---
source "${TOOLBOX_LIB_DIR}/config.sh"
source "${TOOLBOX_LIB_DIR}/lib_utils.sh"
source "${TOOLBOX_LIB_DIR}/lib_system.sh"
source "${TOOLBOX_LIB_DIR}/lib_network.sh"
source "${TOOLBOX_LIB_DIR}/lib_firewall.sh"
source "${TOOLBOX_LIB_DIR}/lib_installer.sh"

# --- Main Logic ---
check_root
detect_os
init_config

# --- Main Menu Function ---
function main_menu() {
    ((COUNTER++))
    update_config "COUNTER" "$COUNTER"

    show_header
    echo -e "${GREEN}1. 系统管理工具${NC}"
    echo -e "${GREEN}2. 网络与安全工具${NC}"
    echo -e "${GREEN}3. 一键换源加速${NC}"
    echo -e "${GREEN}4. 一键安装程序${NC}"
    echo -e "${GREEN}5. 工具箱管理${NC}"
    echo -e "${GREEN}0. 退出${NC}"
    echo -e "${CYAN}==============================================${NC}"
    echo -e "${BLUE}  已运行 ${COUNTER} 次${NC}"
    
    read -p "请输入选项 [0-5]: " choice < /dev/tty
    
    case $choice in
        1) manage_tools_menu ;;
        2) network_tools_menu ;;
        3) change_source_menu ;;
        4) installer_menu ;;
        5) toolbox_management_menu ;;
        0)
            if [ "$INSTALLED" = "false" ]; then
                echo -e "\n${YELLOW}一键运行命令: ${CYAN}curl -Ls https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main/install.sh | bash${NC}\n"
            fi
            echo -e "${PURPLE}感谢使用，再见！${NC}"
            exit 0
            ;;
        *) 
            echo -e "${RED}无效选项，请重试。${NC}"; 
            sleep 1; 
            main_menu 
            ;;
    esac
}

# --- Script Entry Point ---
main_menu