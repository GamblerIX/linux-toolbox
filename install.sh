
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
    start_time=$(date +%s%3N 2>/dev/null || date +%s)
    
    if command -v curl &>/dev/null; then
        if curl -s --connect-timeout "$timeout" --max-time "$timeout" -I "$url" >/dev/null 2>&1; then
            end_time=$(date +%s%3N 2>/dev/null || date +%s)
            if [[ "$start_time" =~ [0-9]{13} ]] && [[ "$end_time" =~ [0-9]{13} ]]; then
                response_time=$(((end_time - start_time)))
                echo "$response_time"
            else
                response_time=$((end_time - start_time))
                echo "${response_time}000"
            fi
            return 0
        else
            echo "999999"
            return 1
        fi
    elif command -v wget &>/dev/null; then
        if wget --timeout="$timeout" --tries=1 -q --spider "$url" >/dev/null 2>&1; then
            end_time=$(date +%s%3N 2>/dev/null || date +%s)
            if [[ "$start_time" =~ [0-9]{13} ]] && [[ "$end_time" =~ [0-9]{13} ]]; then
                response_time=$(((end_time - start_time)))
                echo "$response_time"
            else
                response_time=$((end_time - start_time))
                echo "${response_time}000"
            fi
            return 0
        else
            echo "999999"
            return 1
        fi
    else
        printf "${RED_TEMP}错误: curl 和 wget 都未安装${NC_TEMP}\n" >&2
        echo "999999"
        return 1
    fi
}

function ltbx_select_best_source() {
    local github_url="$1"
    local timeout="${2:-3}"
    
    local gitee_url
    gitee_url=$(ltbx_convert_github_to_gitee "$github_url")
    
    printf "  -> 智能源选择: 检测最优下载源...\n"
    
    # 并行测试多个源的延迟
    local github_response_time gitee_response_time
    local github_status gitee_status
    
    # 测试GitHub源
    printf "  -> 测试 GitHub 源延迟...\n"
    github_response_time=$(ltbx_test_url_response_time "$github_url" "$timeout")
    github_status=$?
    
    # 测试Gitee源
    printf "  -> 测试 Gitee 源延迟...\n"
    gitee_response_time=$(ltbx_test_url_response_time "$gitee_url" "$timeout")
    gitee_status=$?
    
    # 智能选择最优源
    local selected_url source_name response_time
    
    if [ "$github_status" -eq 0 ] && [ "$gitee_status" -eq 0 ]; then
        # 两个源都可用，选择延迟更低的
        if [ "$github_response_time" -le "$gitee_response_time" ]; then
            selected_url="$github_url"
            source_name="GitHub"
            response_time="$github_response_time"
        else
            selected_url="$gitee_url"
            source_name="Gitee"
            response_time="$gitee_response_time"
        fi
        printf "  -> \e[1;92m最优源选择: %s (延迟: %sms)\e[0m\n" "$source_name" "$response_time"
    elif [ "$github_status" -eq 0 ]; then
        # 仅GitHub可用
        selected_url="$github_url"
        source_name="GitHub"
        response_time="$github_response_time"
        printf "  -> \e[1;93m使用 GitHub 源 (延迟: %sms)\e[0m\n" "$response_time"
    elif [ "$gitee_status" -eq 0 ]; then
        # 仅Gitee可用
        selected_url="$gitee_url"
        source_name="Gitee"
        response_time="$gitee_response_time"
        printf "  -> \e[1;93m使用 Gitee 源 (延迟: %sms)\e[0m\n" "$response_time"
    else
        # 两个源都不可用
        printf "  -> \e[1;91m错误: 所有源都不可用\e[0m\n" >&2
        return 1
    fi
    
    # 返回选择的URL和源名称
    echo "$selected_url|$source_name"
    return 0
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
    
    printf "  -> 正在下载 %s...\n" "$remote_path"
    
    # 使用智能源选择
    local source_result
    source_result=$(ltbx_select_best_source "$github_url" "$timeout")
    if [ $? -ne 0 ]; then
        printf "\e[1;91m源选择失败\e[0m\n" >&2
        return 1
    fi
    
    local selected_url source_name
    selected_url=$(echo "$source_result" | cut -d'|' -f1)
    source_name=$(echo "$source_result" | cut -d'|' -f2)
    
    printf "\e[1;96m  -> 开始下载: %s\e[0m\n" "$(basename "$local_path")"
        # 使用选定的最优源进行下载
    if command -v curl >/dev/null 2>&1; then
        if curl -sL --connect-timeout 10 --max-time 60 "$selected_url" -o "$local_path"; then
            printf "  -> \e[1;92m✓ 使用 curl 从 %s 源下载成功\e[0m\n" "$source_name"
        else
            printf "\e[1;91m  -> ✗ 使用 curl 从 %s 源下载失败\e[0m\n" "$source_name" >&2
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget --timeout=10 --tries=3 -qO "$local_path" "$selected_url"; then
            printf "  -> \e[1;92m✓ 使用 wget 从 %s 源下载成功\e[0m\n" "$source_name"
        else
            printf "\e[1;91m  -> ✗ 使用 wget 从 %s 源下载失败\e[0m\n" "$source_name" >&2
            return 1
        fi
    else
        printf "\e[1;91m致命错误: curl 和 wget 都未安装\e[0m\n" >&2
        return 1
    fi
    
    if [[ ! -s "$local_path" ]]; then
        printf "\e[1;91m下载文件为空或失败: %s\e[0m\n" "$remote_path" >&2
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
echo -e "${CYAN}\n tool\n${NC}"
exit 0
