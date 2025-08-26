#!/bin/bash

set -Eeuo pipefail
IFS=$'\n\t'

trap 'ltbx_error_handler "${BASH_SOURCE[0]}" "${LINENO}" "${FUNCNAME[0]:-main}" "$?"' ERR

function ltbx_installer_menu() {
    if [[ "${LTBX_NON_INTERACTIVE:-false}" == "true" ]]; then
        ltbx_log "WARN" "Non-interactive mode detected, skipping installer menu"
        return 1
    fi

    local choice
    ltbx_show_header
    printf "${YELLOW}====== 一键安装程序?======${NC}\n"
    printf "${CYAN}--- 堆″非㈡澘 (BT Panel) ---${NC}\n"
    printf "${GREEN}1. 安装国内堆″ LTS 稳定版?{NC}\n"
    printf "${GREEN}2. 安装国内堆″娆℃新姝ｅ紡版?{NC}\n"
    printf "${GREEN}3. 安装国内堆″用版版跳忕可${NC}\n"
    printf "${GREEN}4. 安装国介际堆″ aapanel 用版本可${NC}\n"
    printf "${CYAN}--- 1Panel ---${NC}\n"
    printf "${GREEN}5. 安装国到内 1Panel 绀惧尯版?{NC}\n"
    printf "${GREEN}6. 安装国介际 1Panel 绀惧尯版?{NC}\n"
    printf "${CYAN}--- 具朵粬工具 ---${NC}\n"
    printf "${GREEN}7. 安装 sing-box-yg 脚本${NC}\n"
    printf "${GREEN}0. 返回主菜单?{NC}\n"
    printf "${CYAN}==============================================${NC}\n"
    printf "${YELLOW}提示: 所用安安装呴能将出出本工具箱变互执行完樻柟脚本。?{NC}\n"

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

    printf "${GREEN}即将退出工具并跳跳始执执行外部安安装脚脚用?..${NC}\n"
    printf "${YELLOW}脚本在板潃: ${script_url}${NC}\n"
    sleep 3; clear

    local temp_script="installer_temp.sh"
    ltbx_log "INFO" "Downloading installer script from: ${script_url}"

    if [[ "$script_url" == *"github.com"* ]] || [[ "$script_url" == *"githubusercontent.com"* ]]; then
        if ! ltbx_download_with_auto_source "${script_url}" "${temp_script}"; then
            ltbx_log "ERROR" "Failed to download script with auto source selection"
            printf "${RED}错误: 下载安装脚本失败。?{NC}\n"
            ltbx_press_any_key
            return 1
        fi
    else
        if command -v curl &>/dev/null; then
            if ! curl -sSL "${script_url}" -o "${temp_script}" 2>/dev/null; then
                ltbx_log "ERROR" "Failed to download script using curl"
                printf "${RED}错误: 下载安装脚本失败。?{NC}\n"
                ltbx_press_any_key
                return 1
            fi
        elif command -v wget &>/dev/null; then
            if ! wget -qO "${temp_script}" "${script_url}" 2>/dev/null; then
                ltbx_log "ERROR" "Failed to download script using wget"
                printf "${RED}错误: 下载安装脚本失败。?{NC}\n"
                ltbx_press_any_key
                return 1
            fi
        else
            ltbx_log "ERROR" "Neither curl nor wget is available"
            printf "${RED}错误: curl 或?wget 用安装呫?{NC}\n"
            ltbx_press_any_key
            return 1
        fi
    fi

    if [[ ! -s "${temp_script}" ]]; then
        ltbx_log "ERROR" "Downloaded script is empty or does not exist"
        printf "${RED}错误: 下载安装脚本失败。?{NC}\n"
        rm -f "${temp_script}" 2>/dev/null || true
        ltbx_press_any_key
        return 1
    fi

    ltbx_log "INFO" "Executing installer script with args: ${script_args}"
    exec bash "${temp_script}" ${script_args}
}
