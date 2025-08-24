#!/bin/bash

set -Eeuo pipefail

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

function download_file() {
    local remote_path="$1" local_path="$2"
    local base_url="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${BRANCH}"
    echo -e "  -> 正在下载 ${remote_path}..."
    if command -v curl &>/dev/null; then
        curl -sL "${base_url}/${remote_path}" -o "${local_path}"
    elif command -v wget &>/dev/null; then
        wget -qO "${local_path}" "${base_url}/${remote_path}"
    else
        echo -e "${RED}致命错误: curl 和 wget 都未安装。${NC}"; exit 1
    fi
    if [ ! -s "${local_path}" ]; then
        echo -e "${RED}下载文件失败: ${remote_path}。${NC}"; exit 1
    fi
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