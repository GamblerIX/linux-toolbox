#!/bin/bash

set -Eeuo pipefail
IFS=$'\n\t'

trap 'ltbx_error_handler "${BASH_SOURCE[0]}" "${LINENO}" "${FUNCNAME[0]:-main}" "$?"' ERR

function ltbx_get_random_string() {
    local length=${1:-8}
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

function ltbx_is_command_available() {
    command -v "$1" &>/dev/null
}

function ltbx_get_file_size() {
    local file="$1"
    if [ -f "$file" ]; then
        stat -c%s "$file" 2>/dev/null || wc -c < "$file"
    else
        echo "0"
    fi
}

function ltbx_format_bytes() {
    local bytes="$1"
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    local size="$bytes"

    while [ "$size" -gt 1024 ] && [ "$unit" -lt 4 ]; do
size=$((size / 1024))
unit=$((unit + 1))
    done

    printf "%.1f %s" "$size" "${units[$unit]}"
}

function ltbx_get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

function ltbx_create_temp_file() {
    local prefix="${1:-ltbx}"
    local temp_file
    temp_file=$(mktemp "/tmp/${prefix}_$(date +%s).XXXXXX")
    if [ -n "$temp_file" ] && [ -f "$temp_file" ]; then
        echo "$temp_file"
    else
        ltbx_log "创建临时文件失败" "error"
        return 1
    fi
}

function ltbx_cleanup_temp_files() {
    local cleanup_patterns=(
        "ltbx*"
        "superbench_*.log"
        "speedtest_*.log"
        "linux-toolbox*"
    )
    
    for pattern in "${cleanup_patterns[@]}"; do
        find /tmp -name "$pattern" -type f -mtime +1 -delete 2>/dev/null || true
    done
    
    find /tmp -name "ltbx.*" -type f -mtime +0 -size 0 -delete 2>/dev/null || true
}

function ltbx_get_system_info() {
    printf "${CYAN}系统信息:${NC}\n"
    printf "  操作系统: %s %s\n" "${LTBX_OS_TYPE:-unknown}" "${LTBX_OS_VERSION:-unknown}"
    printf "  内核版本: %s\n" "$(uname -r)"
    printf "  架构: %s\n" "$(uname -m)"
    printf "  运行时间: %s\n" "$(uptime -p 2>/dev/null || uptime)"
    printf "  负载: %s\n" "$(uptime | awk -F'load average:' '{print $2}')"
}

function ltbx_check_disk_space() {
    local path="${1:-/}"
    local threshold="${2:-90}"

    local usage
usage=$(df "$path" | awk 'NR==2 {print $5}' | sed 's/%//')

    if [ "$usage" -gt "$threshold" ]; then
        printf "${RED}警告: %s 磁盘使用率 %s%% 超过阈值 %s%%${NC}\n" "$path" "$usage" "$threshold"
        return 1
    else
        printf "${GREEN}%s 磁盘使用率: %s%%${NC}\n" "$path" "$usage"
        return 0
    fi
}

function ltbx_check_memory_usage() {
    local threshold="${1:-90}"

    local total used available usage
    if command -v free &>/dev/null; then
        read -r total used available < <(free | awk 'NR==2{printf "%d %d %d", $2, $3, $7}')
usage=$(( (used * 100) / total ))

        printf "${BLUE}内存使用情况:${NC}\n"
        printf "  总计: %s\n" "$(ltbx_format_bytes $((total * 1024)))"
        printf "  已用: %s (%d%%)\n" "$(ltbx_format_bytes $((used * 1024)))" "$usage"
        printf "  可用: %s\n" "$(ltbx_format_bytes $((available * 1024)))"

        if [ "$usage" -gt "$threshold" ]; then
            printf "${RED}警告: 内存使用率 %d%% 超过阈值 %d%%${NC}\n" "$usage" "$threshold"
            return 1
        fi
    else
        printf "${YELLOW}无法获取内存信息${NC}\n"
        return 1
    fi

    return 0
}
