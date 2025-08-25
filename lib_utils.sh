#!/bin/bash

set -Eeuo pipefail
IFS=$'\n\t'

# 加载配置文件以获取日志函数
if [ -f "$(dirname "${BASH_SOURCE[0]}")/config.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
fi

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

function ltbx_convert_github_to_gitee() {
    local url="$1"
    echo "$url" | sed 's/github\.com/gitee.com/g; s/githubusercontent\.com/gitee.com/g'
}

function ltbx_test_url_response_time_ms() {
    local url="$1"
    local timeout="${2:-3}"
    
    local start_time end_time response_time_ms
    
    if command -v curl &>/dev/null; then
        start_time=$(date +%s%3N)
        if curl -s --connect-timeout "$timeout" --max-time "$timeout" -I "$url" >/dev/null 2>&1; then
            end_time=$(date +%s%3N)
            response_time_ms=$((end_time - start_time))
            echo "$response_time_ms"
            return 0
        else
            echo "99999"
            return 1
        fi
    elif command -v wget &>/dev/null; then
        start_time=$(date +%s%3N)
        if wget --timeout="$timeout" --tries=1 -q --spider "$url" >/dev/null 2>&1; then
            end_time=$(date +%s%3N)
            response_time_ms=$((end_time - start_time))
            echo "$response_time_ms"
            return 0
        else
            echo "99999"
            return 1
        fi
    else
        ltbx_log "ERROR" "Neither curl nor wget is available for URL testing"
        echo "99999"
        return 1
    fi
}

function ltbx_test_url_response_time() {
    local url="$1"
    local timeout="${2:-3}"
    
    local response_time_ms
    response_time_ms=$(ltbx_test_url_response_time_ms "$url" "$timeout")
    local response_time_s=$((response_time_ms / 1000))
    
    if [ "$response_time_ms" = "99999" ]; then
        return 255
    else
        return "$response_time_s"
    fi
}

function ltbx_select_best_source() {
    local url="$1"
    local timeout="${2:-3}"
    
    if [[ -z "$url" ]]; then
        ltbx_log "ERROR" "URL is required for source selection"
        return 1
    fi
    
    local github_url="$url"
    local gitee_url
    gitee_url=$(ltbx_convert_github_to_gitee "$url")
    
    local github_delay gitee_delay
    
    ltbx_log "INFO" "Testing GitHub source response time (ms precision)..."
    github_delay=$(ltbx_test_url_response_time_ms "$github_url" "$timeout")
    
    ltbx_log "INFO" "Testing Gitee source response time (ms precision)..."
    gitee_delay=$(ltbx_test_url_response_time_ms "$gitee_url" "$timeout")
    
    printf "${CYAN}源延迟测试结果:${NC}\n"
    if [ "$github_delay" = "99999" ]; then
        printf "  GitHub: ${RED}超时/失败${NC}\n"
    else
        printf "  GitHub: ${GREEN}%d ms${NC}\n" "$github_delay"
    fi
    
    if [ "$gitee_delay" = "99999" ]; then
        printf "  Gitee: ${RED}超时/失败${NC}\n"
    else
        printf "  Gitee: ${GREEN}%d ms${NC}\n" "$gitee_delay"
    fi
    
    if [ "$github_delay" = "99999" ] && [ "$gitee_delay" = "99999" ]; then
        ltbx_log "ERROR" "Both sources are unavailable"
        return 1
    elif [ "$github_delay" = "99999" ]; then
        printf "${YELLOW}选择 Gitee 源 (GitHub 不可用)${NC}\n"
        echo "$gitee_url"
        return 0
    elif [ "$gitee_delay" = "99999" ]; then
        printf "${YELLOW}选择 GitHub 源 (Gitee 不可用)${NC}\n"
        echo "$github_url"
        return 0
    elif [ "$github_delay" -le "$gitee_delay" ]; then
        printf "${GREEN}选择 GitHub 源 (延迟更低: %d ms vs %d ms)${NC}\n" "$github_delay" "$gitee_delay"
        echo "$github_url"
        return 0
    else
        printf "${GREEN}选择 Gitee 源 (延迟更低: %d ms vs %d ms)${NC}\n" "$gitee_delay" "$github_delay"
        echo "$gitee_url"
        return 0
    fi
}

function ltbx_download_with_auto_source() {
    local url="$1"
    local output_file="$2"
    local timeout="${3:-3}"
    
    if [[ -z "$url" ]] || [[ -z "$output_file" ]]; then
        ltbx_log "ERROR" "URL and output file are required"
        return 1
    fi
    
    local selected_url
    selected_url=$(ltbx_select_best_source "$url" "$timeout")
    
    if [ $? -ne 0 ] || [[ -z "$selected_url" ]]; then
        ltbx_log "ERROR" "Failed to select optimal source"
        return 1
    fi
    
    local source_name
    if [[ "$selected_url" == *"gitee.com"* ]]; then
        source_name="Gitee"
    else
        source_name="GitHub"
    fi
    
    printf "${CYAN}使用最优源下载: %s (来源: %s)${NC}\n" "$(basename "$output_file")" "$source_name"
    
    if command -v curl &>/dev/null; then
        if curl -sL --connect-timeout 10 --max-time 60 "$selected_url" -o "$output_file"; then
            ltbx_log "INFO" "Download successful using curl from $source_name"
        else
            ltbx_log "ERROR" "Download failed using curl from $source_name"
            return 1
        fi
    elif command -v wget &>/dev/null; then
        if wget --timeout=10 --tries=3 -qO "$output_file" "$selected_url"; then
            ltbx_log "INFO" "Download successful using wget from $source_name"
        else
            ltbx_log "ERROR" "Download failed using wget from $source_name"
            return 1
        fi
    else
        ltbx_log "ERROR" "Neither curl nor wget is available"
        return 1
    fi
    
    if [[ ! -s "$output_file" ]]; then
        ltbx_log "ERROR" "Downloaded file is empty or does not exist"
        rm -f "$output_file" 2>/dev/null || true
        return 1
    fi
    
    return 0
}
