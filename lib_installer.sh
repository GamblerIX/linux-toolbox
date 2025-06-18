#!/bin/bash
# -*- coding: utf-8 -*-

# Linux Toolbox - One-Click Installer Library

# --- High-Intensity Bright & Bold Color Definitions ---
RED=$'\e[1;91m'
GREEN=$'\e[1;92m'
YELLOW=$'\e[1;93m'
CYAN=$'\e[1;96m'
NC=$'\e[0m'

function installer_menu() {
    show_header
    echo -e "${YELLOW}====== 一键安装程序 ======${NC}"
    echo -e "${CYAN}--- 堡塔面板 (BT Panel) ---${NC}"
    echo -e "${GREEN}1. 安装国内堡塔 LTS 稳定版${NC}"
    echo -e "${GREEN}2. 安装国内堡塔次新正式版${NC}"
    echo -e "${GREEN}3. 安装国内堡塔最新正式版${NC}"
    echo -e "${GREEN}4. 安装国际堡塔 aapanel 最新版${NC}"
    echo -e "${CYAN}--- 1Panel ---${NC}"
    echo -e "${GREEN}5. 安装国内 1Panel 社区版${NC}"
    echo -e "${GREEN}6. 安装国际 1Panel 社区版${NC}"
    echo -e "${CYAN}--- 其他工具 ---${NC}"
    echo -e "${GREEN}7. 安装 sing-box-yg 脚本${NC}"
    echo -e "${GREEN}0. 返回主菜单${NC}"
    echo -e "${CYAN}==============================================${NC}"
    echo -e "${YELLOW}提示: 所有安装都将退出本工具箱以执行官方脚本。${NC}"
    
    read -p "请输入选项 [0-7]: " choice < /dev/tty
    case $choice in
        1) _run_installer "https://download.bt.cn/install/install_lts.sh" "ed8484bec" ;;
        2) _run_installer "https://download.bt.cn/install/install_nearest.sh" "ed8484bec" ;;
        3) _run_installer "https://download.bt.cn/install/install_panel.sh" "ed8484bec" ;;
        4) _run_installer "https://www.aapanel.com/script/install_7.0_en.sh" "aapanel" ;;
        5) _run_installer "https://resource.fit2cloud.com/1panel/package/quick_start.sh" ;;
        6) _run_installer "https://resource.1panel.pro/quick_start.sh" ;;
        7) _run_installer "https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh" ;;
        0) main_menu ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1; installer_menu ;;
    esac
}

function _run_installer() {
    local script_url="$1"
    local script_args="$2"
    
    echo -e "${GREEN}即将退出工具箱并开始执行外部安装脚本...${NC}"
    echo -e "${YELLOW}脚本地址: ${script_url}${NC}"
    sleep 3; clear

    local temp_script="installer_temp.sh"
    if command -v curl &>/dev/null; then
        curl -sSL "${script_url}" -o "${temp_script}"
    elif command -v wget &>/dev/null; then
        wget -qO "${temp_script}" "${script_url}"
    else
        echo -e "${RED}错误: curl 或 wget 未安装。${NC}"; press_any_key; installer_menu; return
    fi
    
    if [ ! -s "${temp_script}" ]; then
        echo -e "${RED}错误: 下载安装脚本失败。${NC}"; rm -f "${temp_script}"; press_any_key; installer_menu; return
    fi
    
    exec bash "${temp_script}" ${script_args}
}
