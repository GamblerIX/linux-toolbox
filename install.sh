#!/bin/bash
# -*- coding: utf-8 -*-

# Linux Toolbox - Installation Script

# --- Configuration ---
REPO_USER="GamblerIX"
REPO_NAME="linux-toolbox"
BRANCH="main"

TOOL_EXECUTABLE="/usr/local/bin/tool"
LIB_DIR="/usr/local/lib/linux-toolbox"
CONFIG_DIR="/etc/linux-toolbox"
CONFIG_FILE="$CONFIG_DIR/config.cfg"

# ADDED lib_superbench.sh to the list
FILES_TO_INSTALL=(
    "tool.sh" "config.sh" "lib_utils.sh" "lib_system.sh"
    "lib_network.sh" "lib_firewall.sh" "lib_installer.sh" "lib_superbench.sh"
)

# --- Helper Functions ---
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; NC='\033[0m'

function check_root_installer() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误: 此安装脚本需要 root 权限运行。${NC}"
        echo -e "${YELLOW}请尝试: curl ... | sudo bash${NC}"
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

# --- Main Installation Logic ---
echo -e "${GREEN}===== 开始安装/更新 Linux 工具箱 =====${NC}"
check_root_installer

echo -e "${CYAN}--> 步骤 1: 创建目录...${NC}"
mkdir -p "${LIB_DIR}"; mkdir -p "${CONFIG_DIR}"
echo -e "${GREEN}目录准备就绪。${NC}"

echo -e "\n${CYAN}--> 步骤 2: 下载脚本文件...${NC}"
for file in "${FILES_TO_INSTALL[@]}"; do
    if [[ "$file" == "tool.sh" ]]; then
        download_file "$file" "$TOOL_EXECUTABLE"
    else
        download_file "$file" "${LIB_DIR}/${file}"
    fi
done

echo -e "\n${CYAN}--> 步骤 3: 设置文件权限...${NC}"
chmod +x "$TOOL_EXECUTABLE"
chmod 644 ${LIB_DIR}/*
echo -e "${GREEN}权限设置完毕。${NC}"

echo -e "\n${CYAN}--> 步骤 4: 初始化配置...${NC}"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "INSTALLED=true" > "$CONFIG_FILE"
else
    if grep -q "^INSTALLED=" "$CONFIG_FILE"; then
        sed -i "s/^INSTALLED=.*/INSTALLED=true/" "$CONFIG_FILE"
    else
        echo "INSTALLED=true" >> "$CONFIG_FILE"
    fi
fi
echo -e "${GREEN}配置初始化完成。${NC}"

echo -e "\n${GREEN}===========================================${NC}"
echo -e "${GREEN}    Linux 工具箱 安装/更新 成功！   ${NC}"
echo -e "${GREEN}===========================================${NC}"
echo -e "${YELLOW}现在你可以通过输入以下命令来运行它:${NC}"
echo -e "${CYAN}\n    tool\n${NC}"
exit 0
