
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

function download_file() {
    local remote_path="${1:-}"
    local local_path="${2:-}"
    
    if [[ -z "$remote_path" ]] || [[ -z "$local_path" ]]; then
        printf "${RED_TEMP}错误: 下载参数不能为空${NC_TEMP}\n" >&2
        return 1
    fi
    
    local base_url="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${BRANCH}"
    printf "  -> 正在下载 %s...\n" "$remote_path"
    
    if command -v curl >/dev/null 2>&1; then
        if ! curl -sL "${base_url}/${remote_path}" -o "${local_path}"; then
            printf "${RED_TEMP}curl 下载失败: %s${NC_TEMP}\n" "$remote_path" >&2
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -qO "${local_path}" "${base_url}/${remote_path}"; then
            printf "${RED_TEMP}wget 下载失败: %s${NC_TEMP}\n" "$remote_path" >&2
            return 1
        fi
    else
        printf "${RED_TEMP}致命错误: curl 和 wget 都未安装${NC_TEMP}\n" >&2
        return 1
    fi
    
    if [[ ! -s "$local_path" ]]; then
        printf "${RED_TEMP}下载文件为空或失败: %s${NC_TEMP}\n" "$remote_path" >&2
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
