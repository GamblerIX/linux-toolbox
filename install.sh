
#!/bin/bash

set -Eeuo pipefail
IFS=$'\n\t'

# 错误处理函数
function error_handler() {
    local line_no=$1
    printf "${RED_TEMP:-\e[1;91m}错误: 安装脚本在第 %s 行执行失败${NC_TEMP:-\e[0m}\n" "$line_no" >&2
    exit 1
}

trap 'error_handler ${LINENO}' ERR

REPO_USER="GamblerIX"
REPO_NAME="linux-toolbox"
BRANCH="main"

TOOL_EXECUTABLE="/usr/local/bin/tool"
LIB_DIR="/usr/local/lib/linux-toolbox"
CONFIG_DIR="/etc/linux-toolbox"
CONFIG_FILE="$CONFIG_DIR/config.cfg"

FILES_TO_INSTALL=(
    "tool.sh" "config.sh" "lib_utils.sh" "lib_system.sh" "lib_ui.sh"
    "lib_network.sh" "lib_firewall.sh" "lib_installer.sh" "lib_superbench.sh" "lib_install.sh"
)

RED_TEMP=$'\e[1;91m'
GREEN_TEMP=$'\e[1;92m'
YELLOW_TEMP=$'\e[1;93m'
CYAN_TEMP=$'\e[1;96m'
NC_TEMP=$'\e[0m'

function check_root_installer() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED_TEMP}错误: 此安装脚本需要 root 权限运行。${NC_TEMP}"
        echo -e "${YELLOW_TEMP}请尝试: curl ... | sudo bash${NC_TEMP}"
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
        printf "${RED_TEMP}错误: curl 和 wget 都未安装${NC_TEMP}\n" >&2
        return 255
    fi
}

function download_file() {
    local remote_path="${1:-}"
    local local_path="${2:-}"
    local timeout="${3:-3}"
    
    if [[ -z "$remote_path" ]] || [[ -z "$local_path" ]]; then
        printf "${RED_TEMP}错误: 下载参数不能为空${NC_TEMP}\n" >&2
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
    
    printf "${CYAN_TEMP}  -> 使用 %s 源下载: %s${NC_TEMP}\n" "$source_name" "$(basename "$local_path")"
    
    if command -v curl >/dev/null 2>&1; then
        if curl -sL --connect-timeout 10 --max-time 60 "$selected_url" -o "$local_path"; then
            printf "  -> 使用 curl 从 %s 源下载成功\n" "$source_name"
        else
            printf "${RED_TEMP}  -> 使用 curl 从 %s 源下载失败${NC_TEMP}\n" "$source_name" >&2
            if [ "$source_name" = "GitHub" ]; then
                printf "  -> 重试 Gitee 源...\n"
                if curl -sL --connect-timeout 10 --max-time 60 "$gitee_url" -o "$local_path"; then
                    printf "${YELLOW_TEMP}  -> 已切换到 Gitee 源完成下载${NC_TEMP}\n"
                else
                    printf "${RED_TEMP}curl 下载失败: %s${NC_TEMP}\n" "$remote_path" >&2
                    return 1
                fi
            else
                printf "${RED_TEMP}curl 下载失败: %s${NC_TEMP}\n" "$remote_path" >&2
                return 1
            fi
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget --timeout=10 --tries=3 -qO "$local_path" "$selected_url"; then
            printf "  -> 使用 wget 从 %s 源下载成功\n" "$source_name"
        else
            printf "${RED_TEMP}  -> 使用 wget 从 %s 源下载失败${NC_TEMP}\n" "$source_name" >&2
            if [ "$source_name" = "GitHub" ]; then
                printf "  -> 重试 Gitee 源...\n"
                if wget --timeout=10 --tries=3 -qO "$local_path" "$gitee_url"; then
                    printf "${YELLOW_TEMP}  -> 已切换到 Gitee 源完成下载${NC_TEMP}\n"
                else
                    printf "${RED_TEMP}wget 下载失败: %s${NC_TEMP}\n" "$remote_path" >&2
                    return 1
                fi
            else
                printf "${RED_TEMP}wget 下载失败: %s${NC_TEMP}\n" "$remote_path" >&2
                return 1
            fi
        fi
    else
        printf "${RED_TEMP}致命错误: curl 和 wget 都未安装${NC_TEMP}\n" >&2
        return 1
    fi
    
    if [[ ! -s "$local_path" ]]; then
        printf "${RED_TEMP}下载文件为空或失败: %s${NC_TEMP}\n" "$remote_path" >&2
        rm -f "$local_path" 2>/dev/null || true
        return 1
    fi
    
    return 0
}

echo -e "${GREEN_TEMP}===== 开始安装/更新 Linux 工具箱 =====${NC_TEMP}"
check_root_installer

echo -e "${CYAN_TEMP}--> 步骤 1: 创建目录...${NC_TEMP}"
mkdir -p "${LIB_DIR}"; mkdir -p "${CONFIG_DIR}"
echo -e "${GREEN_TEMP}目录准备就绪。${NC_TEMP}"

echo -e "\n${CYAN_TEMP}--> 步骤 2: 下载脚本文件...${NC_TEMP}"
for file in "${FILES_TO_INSTALL[@]}"; do
    if [[ "$file" == "tool.sh" ]]; then
        download_file "$file" "$TOOL_EXECUTABLE"
    else
        download_file "$file" "${LIB_DIR}/${file}"
    fi
done

source "${LIB_DIR}/config.sh"

echo -e "\n${CYAN}--> 步骤 3: 设置文件权限...${NC}"
chmod +x "$TOOL_EXECUTABLE"
chmod 644 ${LIB_DIR}/*
echo -e "${GREEN}权限设置完毕。${NC}"

echo -e "\n${CYAN}--> 步骤 4: 初始化配置...${NC}"
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << EOF

TOOLBOX_INSTALL_DIR="/etc/linux-toolbox"
CONFIG_FILE="\$TOOLBOX_INSTALL_DIR/config.cfg"
TOOLBOX_LIB_DIR="/usr/local/lib/linux-toolbox"
TOOL_EXECUTABLE="/usr/local/bin/tool"

INSTALLED=true
OS_TYPE=""
OS_CODENAME=""
OS_VERSION=""
EOF
else
    if grep -q "^INSTALLED=" "$CONFIG_FILE"; then
        sed -i "s/^INSTALLED=.*/INSTALLED=true/" "$CONFIG_FILE"
    else
        echo "INSTALLED=true" >> "$CONFIG_FILE"
    fi
fi
echo -e "${GREEN}配置初始化完成。${NC}"

echo -e "\n${GREEN}===========================================${NC}"
echo -e "${GREEN}    Linux 工具箱安装/更新 成功！  ${NC}"
echo -e "${GREEN}===========================================${NC}"
echo -e "${YELLOW}现在你可以通过输入以下命令来运行它:${NC}"
echo -e "${CYAN}\n    tool\n${NC}"
exit 0
