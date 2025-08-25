#!/bin/bash

set -Eeuo pipefail
IFS=$'\n\t'

# 错误处理函数
function error_handler() {
    local line_no=$1
    printf "${RED}错误: 脚本在第 %s 行执行失败${NC}\n" "$line_no" >&2
    exit 1
}

trap 'error_handler ${LINENO}' ERR

REPO_USER="GamblerIX"
REPO_NAME="linux-toolbox"
BRANCH="main"

TOOL_EXECUTABLE="/usr/local/bin/tool"
LIB_DIR="/usr/local/lib/linux-toolbox"

MISSING_FILES=(
    "lib_ui.sh" "lib_install.sh"
)

RED=$'\e[1;91m'
GREEN=$'\e[1;92m'
YELLOW=$'\e[1;93m'
CYAN=$'\e[1;96m'
NC=$'\e[0m'

function check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误: 此脚本需要 root 权限运行。${NC}"
        echo -e "${YELLOW}请使用: sudo bash reinstall.sh${NC}"
        exit 1
    fi
}

function ltbx_convert_github_to_gitee() {
    local url="$1"
    echo "$url" | sed 's/github\.com/gitee.com/g; s/githubusercontent\.com/gitee.com/g'
}

function ltbx_test_url_response_time() {
    local url="$1"
    local timeout="${2:-3}"
    
    local start_time end_time response_time
    start_time=$(date +%s)
    
    if command -v curl &>/dev/null; then
        if curl -s --connect-timeout "$timeout" --max-time "$timeout" -I "$url" >/dev/null 2>&1; then
            end_time=$(date +%s)
            response_time=$((end_time - start_time))
            return "$response_time"
        else
            return 255
        fi
    elif command -v wget &>/dev/null; then
        if wget --timeout="$timeout" --tries=1 -q --spider "$url" >/dev/null 2>&1; then
            end_time=$(date +%s)
            response_time=$((end_time - start_time))
            return "$response_time"
        else
            return 255
        fi
    else
        printf "${RED}错误: curl 和 wget 都未安装${NC}\n" >&2
        return 255
    fi
}

function download_file() {
    local remote_path="${1:-}"
    local local_path="${2:-}"
    local timeout="${3:-3}"
    
    if [[ -z "$remote_path" ]] || [[ -z "$local_path" ]]; then
        printf "${RED}错误: 下载参数不能为空${NC}\n" >&2
        return 1
    fi
    
    local base_url="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${BRANCH}"
    local github_url="${base_url}/${remote_path}"
    local gitee_url
    gitee_url=$(ltbx_convert_github_to_gitee "$github_url")
    
    printf "  -> 正在下载 %s...\n" "$remote_path"
    printf "  -> 测试 GitHub 源响应时间...\n"
    
    local github_response_time
    ltbx_test_url_response_time "$github_url" "$timeout"
    github_response_time=$?
    
    local selected_url="$github_url"
    local source_name="GitHub"
    
    if [ "$github_response_time" -eq 255 ] || [ "$github_response_time" -gt "$timeout" ]; then
        printf "  -> GitHub 源超时或失败，切换到 Gitee 源\n"
        selected_url="$gitee_url"
        source_name="Gitee"
    else
        printf "  -> GitHub 源响应时间 ${github_response_time}s，使用 GitHub 源\n"
    fi
    
    printf "${CYAN}  -> 使用 %s 源下载: %s${NC}\n" "$source_name" "$(basename "$local_path")"
    
    if command -v curl >/dev/null 2>&1; then
        if curl -sL --connect-timeout 10 --max-time 60 "$selected_url" -o "$local_path"; then
            printf "  -> 使用 curl 从 %s 源下载成功\n" "$source_name"
        else
            printf "${RED}  -> 使用 curl 从 %s 源下载失败${NC}\n" "$source_name" >&2
            if [ "$source_name" = "GitHub" ]; then
                printf "  -> 重试 Gitee 源...\n"
                if curl -sL --connect-timeout 10 --max-time 60 "$gitee_url" -o "$local_path"; then
                    printf "${YELLOW}  -> 已切换到 Gitee 源完成下载${NC}\n"
                else
                    printf "${RED}curl 下载失败: %s${NC}\n" "$remote_path" >&2
                    return 1
                fi
            else
                printf "${RED}curl 下载失败: %s${NC}\n" "$remote_path" >&2
                return 1
            fi
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget --timeout=10 --tries=3 -qO "$local_path" "$selected_url"; then
            printf "  -> 使用 wget 从 %s 源下载成功\n" "$source_name"
        else
            printf "${RED}  -> 使用 wget 从 %s 源下载失败${NC}\n" "$source_name" >&2
            if [ "$source_name" = "GitHub" ]; then
                printf "  -> 重试 Gitee 源...\n"
                if wget --timeout=10 --tries=3 -qO "$local_path" "$gitee_url"; then
                    printf "${YELLOW}  -> 已切换到 Gitee 源完成下载${NC}\n"
                else
                    printf "${RED}wget 下载失败: %s${NC}\n" "$remote_path" >&2
                    return 1
                fi
            else
                printf "${RED}wget 下载失败: %s${NC}\n" "$remote_path" >&2
                return 1
            fi
        fi
    else
        printf "${RED}致命错误: curl 和 wget 都未安装${NC}\n" >&2
        return 1
    fi
    
    if [[ ! -s "$local_path" ]]; then
        printf "${RED}下载文件为空或失败: %s${NC}\n" "$remote_path" >&2
        rm -f "$local_path" 2>/dev/null || true
        return 1
    fi
    
    return 0
}

echo -e "${GREEN}===== 修复 Linux 工具箱缺失文件 =====${NC}"
check_root

echo -e "${CYAN}--> 检查缺失的库文件...${NC}"
for file in "${MISSING_FILES[@]}"; do
    if [ ! -f "${LIB_DIR}/${file}" ]; then
        echo -e "${YELLOW}发现缺失文件: ${file}${NC}"
        download_file "${file}" "${LIB_DIR}/${file}"
        chmod 644 "${LIB_DIR}/${file}"
        echo -e "${GREEN}已修复: ${file}${NC}"
    else
        echo -e "${GREEN}文件存在: ${file}${NC}"
    fi
done

echo -e "\n${GREEN}===========================================${NC}"
echo -e "${GREEN}    缺失文件修复完成！${NC}"
echo -e "${GREEN}===========================================${NC}"
echo -e "${YELLOW}现在可以正常使用 tool 命令了${NC}"
echo -e "${CYAN}\n    tool\n${NC}"
exit 0