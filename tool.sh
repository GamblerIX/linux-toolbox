#!/bin/bash

set -Eeuo pipefail
IFS=$'\n\t'

LTBX_LIB_DIR="/usr/local/lib/linux-toolbox"
LTBX_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${LTBX_SCRIPT_DIR}/config.sh" ]]; then
    LTBX_LIB_DIR="${LTBX_SCRIPT_DIR}"
elif [[ -n "${LTBX_LIB_DIR_OVERRIDE:-}" ]]; then
    LTBX_LIB_DIR="${LTBX_LIB_DIR_OVERRIDE}"
fi

source "${LTBX_LIB_DIR}/config.sh"
source "${LTBX_LIB_DIR}/lib_system.sh"
source "${LTBX_LIB_DIR}/lib_ui.sh"
source "${LTBX_LIB_DIR}/lib_utils.sh"

function ltbx_load_lib() {
    local lib_name="$1"
    local lib_path="${LTBX_LIB_DIR}/lib_${lib_name}.sh"

    if [[ -f "$lib_path" ]] && [[ -z "${LTBX_LOADED_LIBS[$lib_name]:-}" ]]; then
        source "$lib_path"
        LTBX_LOADED_LIBS[$lib_name]=1
        ltbx_log "DEBUG" "已加载库: $lib_name"
    fi
}

declare -A LTBX_LOADED_LIBS

function ltbx_show_help() {
    printf "Linux 工具箱v%s\n\n" "${LTBX_VERSION}"
    printf "用法: %s [选项] [瀛愬懡浠\n\n" "$(basename "$0")"
    printf "选项:\n"
    printf "  --help, -h          显示姝ゅ府鍔╀俊鎭痋n"
    printf "  --version, -v       显示版本信息\n"
    printf "  --doctor            检查系统环境\n"
    printf "  --non-interactive   非交互模式\n"
    printf "  --debug             鍚敤璋冭瘯妯″紡\n\n"
    printf "子命令\n"
    printf "  system              系统管理工具\n"
    printf "  network             网络与安全工具\n"
    printf "  install             一键安装程序\n"
    printf "  manage              工具箱管理\n\n"
}

function ltbx_show_version() {
    printf "Linux 工具箱v%s\n" "${LTBX_VERSION}"
}

function ltbx_doctor() {
    ltbx_log "INFO" "正在检查系统环境.."

    printf "系统信息:\n"
    printf "  操作系统: %s %s (%s)\n" "${LTBX_OS_TYPE}" "${LTBX_OS_VERSION}" "${LTBX_OS_CODENAME}"
    printf "  用户权限: %s\n" "$(id -u)"
    printf "  TTY状态: %s\n" "已禁用检测"

    printf "\n依赖检查\n"
    for cmd in curl wget sudo systemctl; do
        if command -v "$cmd" &>/dev/null; then
            printf "  ✗ %s\n" "$cmd"
        else
            printf "  ✗ %s (未找到)\n" "$cmd"
        fi
    done

    printf "\n网络连接:\n"
    if curl -s --connect-timeout 5 https://www.baidu.com >/dev/null 2>&1; then
        printf "  ✗ 网络连接正常\n"
    else
        printf "  ✗ 网络连接异常\n"
    fi
}

LTBX_SUBCOMMAND=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            ltbx_show_help
            exit 0
            ;;
        --version|-v)
            ltbx_show_version
            exit 0
            ;;
        --doctor)
            ltbx_check_root
            ltbx_detect_os
            ltbx_init_config
            ltbx_doctor
            exit 0
            ;;
        --non-interactive)
LTBX_NON_INTERACTIVE="true"
            shift
            ;;
        --debug)
LTBX_DEBUG="true"
            shift
            ;;
        system|network|install|manage)
LTBX_SUBCOMMAND="$1"
            shift
            ;;
        *)
            ltbx_log "ERROR" "鏈煡参数: $1"
            ltbx_show_help
            exit 1
            ;;
    esac
done

ltbx_check_root
ltbx_detect_os
ltbx_init_config

if [[ "${LTBX_AUTO_UPDATE_CHECK}" == "true" ]] && [[ "${LTBX_NON_INTERACTIVE}" != "true" ]]; then
    ltbx_load_lib "install"
    ltbx_auto_update_check
fi

function ltbx_read_input() {
    local prompt="$1"
    local default="${2:-}"
    local input

    if [[ "${LTBX_NON_INTERACTIVE}" == "true" ]]; then
        if [[ -n "$default" ]]; then
            printf "%s" "$default"
            return 0
        else
            ltbx_log "ERROR" "非交互模式下需要默认值"
            return 1
        fi
    fi

    read -r -p "$prompt" input
    printf "%s" "$input"
}

function ltbx_main_menu() {
    while true; do
        ltbx_show_header
        printf "%s1. 系统管理工具%s\n" "${GREEN}" "${NC}"
        printf "%s2. 网络与安全工具s\n" "${GREEN}" "${NC}"
        printf "%s3. 一键崲婧愬姞閫?s\n" "${GREEN}" "${NC}"
        printf "%s4. 一键安装程序?s\n" "${GREEN}" "${NC}"
        printf "%s5. 工具箱管理?s\n" "${GREEN}" "${NC}"
        printf "%s0. 退出s\n" "${RED}" "${NC}"
        printf "%s==============================================%s\n" "${CYAN}" "${NC}"

        local choice
        if ! choice=$(ltbx_read_input "请输入选项 [0-5]: " "0"); then
            return 1
        fi

        case $choice in
            1)
                ltbx_load_lib "system"
                ltbx_manage_tools_menu
                ;;
            2)
                ltbx_load_lib "network"
                ltbx_load_lib "firewall"
                ltbx_network_tools_menu
                ;;
            3)
                ltbx_load_lib "system"
                ltbx_change_source_menu
                ;;
            4)
                ltbx_load_lib "installer"
                ltbx_installer_menu
                ;;
            5)
                ltbx_load_lib "install"
                ltbx_toolbox_management_menu
                ;;
            0)
                if [[ "${LTBX_INSTALLED}" == "false" ]]; then
                    printf "\n%s一键运行命令: %scurl -Ls https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main/install.sh | bash%s\n\n" "${YELLOW}" "${CYAN}" "${NC}"
                fi
                printf "%s感谢使用，再见！%s\n" "${PURPLE}" "${NC}"
                exit 0
                ;;
            *)
                ltbx_log "WARN" "无效选项锛岃重试"
                sleep 1
                ;;
        esac
    done
}

function ltbx_handle_subcommand() {
    case "${LTBX_SUBCOMMAND}" in
        "system")
            ltbx_load_lib "system"
            ltbx_manage_tools_menu
            ;;
        "network")
            ltbx_load_lib "network"
            ltbx_load_lib "firewall"
            ltbx_network_tools_menu
            ;;
        "install")
            ltbx_load_lib "installer"
            ltbx_installer_menu
            ;;
        "manage")
            ltbx_load_lib "install"
            ltbx_toolbox_management_menu
            ;;
        *)
            ltbx_main_menu
            ;;
    esac
}

if [[ -n "${LTBX_SUBCOMMAND}" ]]; then
    ltbx_handle_subcommand
else
    ltbx_main_menu
fi
