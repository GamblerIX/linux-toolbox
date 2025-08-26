#!/bin/bash

set -Eeuo pipefail
IFS=$'\n\t'

trap 'ltbx_error_handler "${BASH_SOURCE[0]}" "${LINENO}" "${FUNCNAME[0]:-main}" "$?"' ERR

TOOLBOX_INSTALL_DIR="/etc/linux-toolbox"
CONFIG_FILE="$TOOLBOX_INSTALL_DIR/config.cfg"
TOOLBOX_LIB_DIR="/usr/local/lib/linux-toolbox"
TOOL_EXECUTABLE="/usr/local/bin/tool"

function ltbx_init_colors() {
    if [[ -n "${NO_COLOR:-}" ]] || [[ "${TERM:-}" == "dumb" ]]; then
RED=""
GREEN=""
YELLOW=""
BLUE=""
PURPLE=""
CYAN=""
NC=""
    else
RED=$'\e[1;91m'
GREEN=$'\e[1;92m'
YELLOW=$'\e[1;93m'
BLUE=$'\e[1;94m'
PURPLE=$'\e[1;95m'
CYAN=$'\e[1;96m'
NC=$'\e[0m'
    fi

SKYBLUE="${CYAN}"
PLAIN="${NC}"
}

ltbx_init_colors

LTBX_VERSION="2.0.0"
LTBX_BUILD_DATE="$(date '+%Y-%m-%d')"
LTBX_GITHUB_REPO="GamblerIX/linux-toolbox"
LTBX_UPDATE_CHECK_INTERVAL=86400

function ltbx_error_handler() {
    local source_file=$1
    local line_no=$2
    local func_name=$3
    local exit_code=$4

    printf "${RED}错误: 脚本执行失败${NC}\n" >&2
    printf "${YELLOW}文件: %s${NC}\n" "$source_file" >&2
    printf "${YELLOW}行号: %s${NC}\n" "$line_no" >&2
    printf "${YELLOW}函数: %s${NC}\n" "$func_name" >&2
    printf "${YELLOW}退出码: %s${NC}\n" "$exit_code" >&2

    if [[ -n "${LTBX_LOG_FILE:-}" ]] && [[ -w "$(dirname "${LTBX_LOG_FILE}")" ]]; then
        printf "[%s] ERROR: exit_code=%s line=%s command='%s' stack='%s'\n" \
            "$(date '+%Y-%m-%d %H:%M:%S')" "$exit_code" "$line_no" "$last_command" "$func_stack" >> "$LTBX_LOG_FILE"
    fi
}

function ltbx_log() {
    local level=$1
    shift
    local message="$*"

    case "$level" in
        "ERROR") printf "${RED}[错误]${NC} %s\n" "$message" >&2 ;;
        "WARN")  printf "${YELLOW}[警告]${NC} %s\n" "$message" >&2 ;;
        "INFO")  printf "${GREEN}[信息]${NC} %s\n" "$message" ;;
        "DEBUG") [[ "${LTBX_DEBUG:-}" == "true" ]] && printf "${CYAN}[调试]${NC} %s\n" "$message" ;;
    esac

    if [[ -n "${LTBX_LOG_FILE:-}" ]] && [[ -w "$(dirname "${LTBX_LOG_FILE}")" ]]; then
        printf "[%s] %s: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message" >> "$LTBX_LOG_FILE"
    fi
}

LTBX_INSTALLED=false
LTBX_OS_TYPE=""
LTBX_OS_CODENAME=""
LTBX_OS_VERSION=""
LTBX_LOG_FILE="/var/log/linux-toolbox/tool.log"
LTBX_DEBUG="${LTBX_DEBUG:-false}"
LTBX_NON_INTERACTIVE="${LTBX_NON_INTERACTIVE:-false}"

LTBX_TOOL_EXECUTABLE="${TOOL_EXECUTABLE}"
LTBX_TOOLBOX_INSTALL_DIR="${TOOLBOX_INSTALL_DIR}"
LTBX_TOOLBOX_LIB_DIR="${TOOLBOX_LIB_DIR}"
LTBX_CONFIG_DIR="${TOOLBOX_INSTALL_DIR}"
LTBX_CONFIG_FILE="${CONFIG_FILE}"
LTBX_BACKUP_DIR="${HOME}/.linux-toolbox-backup"

LTBX_AUTO_UPDATE_CHECK="${LTBX_AUTO_UPDATE_CHECK:-true}"
LTBX_UPDATE_PROMPT="${LTBX_UPDATE_PROMPT:-true}"
