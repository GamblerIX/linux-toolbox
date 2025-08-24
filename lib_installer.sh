#!/bin/bash

set -Eeuo pipefail
IFS=$'\n\t'

trap 'ltbx_error_handler "${BASH_SOURCE[0]}" "${LINENO}" "${BASH_COMMAND}"' ERR

function ltbx_installer_menu() {
    if [[ "${LTBX_NON_INTERACTIVE:-false}" == "true" ]] || ! [[ -t 0 ]]; then
        ltbx_log "WARN" "Non-interactive mode or non-TTY environment detected, skipping installer menu"
        return 0
    fi

    local choice
    ltbx_show_header
    printf "${YELLOW}====== 一键安装程序 ======${NC}\n"
    printf "${CYAN}--- 堡塔面板 (BT Panel) ---${NC}\n"
    printf "${GREEN}1. 安装国内堡塔 LTS 稳定版${NC}\n"
    printf "${GREEN}2. 安装国内堡塔次新正式版${NC}\n"
    printf "${GREEN}3. 安装国内堡塔最新正式版${NC}\n"
    printf "${GREEN}4. 安装国际堡塔 aapanel 最新版${NC}\n"
    printf "${CYAN}--- 1Panel ---${NC}\n"
    printf "${GREEN}5. 安装国内 1Panel 社区版${NC}\n"
    printf "${GREEN}6. 安装国际 1Panel 社区版${NC}\n"
    printf "${CYAN}--- 其他工具 ---${NC}\n"
    printf "${GREEN}7. 安装 sing-box-yg 脚本${NC}\n"
    printf "${GREEN}0. 返回主菜单${NC}\n"
    printf "${CYAN}==============================================${NC}\n"
    printf "${YELLOW}提示: 所有安装都将退出本工具箱以执行官方脚本。${NC}\n"

    read -p "请输入选项 [0-7]: " choice < /dev/tty
    case $choice in
        1) ltbx_run_installer "https://download.bt.cn/install/install_lts.sh" "ed8484bec" ;;
        2) ltbx_run_installer "https://download.bt.cn/install/install_nearest.sh" "ed8484bec" ;;
        3) ltbx_run_installer "https://download.bt.cn/install/install_panel.sh" "ed8484bec" ;;
        4) ltbx_run_installer "https://www.aapanel.com/script/install_7.0_en.sh" "aapanel" ;;
        5) ltbx_run_installer "https://resource.fit2cloud.com/1panel/package/quick_start.sh" ;;
        6) ltbx_run_installer "https://resource.1panel.pro/quick_start.sh" ;;
        7) ltbx_run_installer "https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh" ;;
        0) return 0 ;;
        *) printf "${RED}无效选项${NC}\n"; sleep 1; ltbx_installer_menu ;;
    esac
}

function ltbx_run_installer() {
    local script_url="$1"
    local script_args="${2:-}"

    printf "${GREEN}即将退出工具箱并开始执行外部安装脚本...${NC}\n"
    printf "${YELLOW}脚本地址: ${script_url}${NC}\n"
    sleep 3; clear

    local temp_script="installer_temp.sh"
    ltbx_log "INFO" "Downloading installer script from: ${script_url}"

    if command -v curl &>/dev/null; then
        if ! curl -sSL "${script_url}" -o "${temp_script}" 2>/dev/null; then
            ltbx_log "ERROR" "Failed to download script using curl"
            printf "${RED}错误: 下载安装脚本失败。${NC}\n"
            ltbx_press_any_key
            return 1
        fi
    elif command -v wget &>/dev/null; then
        if ! wget -qO "${temp_script}" "${script_url}" 2>/dev/null; then
            ltbx_log "ERROR" "Failed to download script using wget"
            printf "${RED}错误: 下载安装脚本失败。${NC}\n"
            ltbx_press_any_key
            return 1
        fi
    else
        ltbx_log "ERROR" "Neither curl nor wget is available"
        printf "${RED}错误: curl 或 wget 未安装。${NC}\n"
        ltbx_press_any_key
        return 1
    fi

    if [[ ! -s "${temp_script}" ]]; then
        ltbx_log "ERROR" "Downloaded script is empty or does not exist"
        printf "${RED}错误: 下载安装脚本失败。${NC}\n"
        rm -f "${temp_script}" 2>/dev/null || true
        ltbx_press_any_key
        return 1
    fi

    ltbx_log "INFO" "Executing installer script with args: ${script_args}"
    exec bash "${temp_script}" ${script_args}
}
