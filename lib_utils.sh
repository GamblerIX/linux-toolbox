#!/bin/bash
# -*- coding: utf-8 -*-

# Linux Toolbox - Utility Library

# Note: Color variables (RED, GREEN, etc.) are sourced from the global config.sh

# --- Core System Checks ---
function check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${YELLOW}检测到非root用户，正尝试提权至root...${NC}"
        exec sudo -i "$0" "$@"
    fi
}

function detect_os() {
    OS_TYPE=""
    OS_VERSION=""
    OS_CODENAME=""

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        
        OS_TYPE=${ID}
        OS_VERSION=${VERSION_ID}
        
        if [ -n "${VERSION_CODENAME}" ]; then
            OS_CODENAME=${VERSION_CODENAME}
        elif command -v lsb_release &>/dev/null; then
            OS_CODENAME=$(lsb_release -sc)
        fi

    elif [ -f /etc/redhat-release ]; then
        if grep -q "CentOS release 7" /etc/redhat-release; then
            OS_TYPE="centos"
            OS_VERSION="7"
        fi
    fi

    # --- Final Validation ---
    case "${OS_TYPE}" in
        ubuntu|debian|centos)
            if [ -z "$OS_TYPE" ] || [ -z "$OS_VERSION" ]; then
                 echo -e "${RED}错误：无法确定操作系统或版本。脚本无法继续。${NC}"
                 exit 1
            fi
            if [[ "$OS_TYPE" == "debian" || "$OS_TYPE" == "ubuntu" ]] && [ -z "$OS_CODENAME" ]; then
                 echo -e "${RED}错误：无法确定 ${OS_TYPE} 的系统代号 (Codename)。脚本无法继续。${NC}"
                 echo -e "${YELLOW}这在最小化安装的系统上很常见。请尝试安装 'lsb-release' 包后重试。${NC}"
                 exit 1
            fi
            ;;
        *)
            if [ -n "$PRETTY_NAME" ]; then
                 echo -e "${YELLOW}检测到的系统是: ${PRETTY_NAME}${NC}"
            fi
            echo -e "${RED}错误：此脚本目前仅支持 Ubuntu, Debian, CentOS 系统。${NC}"
            exit 1
            ;;
    esac
}


# --- Configuration Management ---
function init_config() {
    # Determine 'installed' status by checking if the main executable exists at the standard path.
    # This is a more reliable method and avoids sourcing the problematic config.cfg file,
    # which was overwriting the runtime-detected OS variables.
    if [ -f "/usr/local/bin/tool" ]; then
        INSTALLED=true
    fi
    # No other action is needed. Directories are created by the installer.
}

function update_config() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "$CONFIG_FILE"; then
        sed -i "s/^${key}=.*/${key}='${value}'/" "$CONFIG_FILE"
    else
        echo "${key}='${value}'" >> "$CONFIG_FILE"
    fi
}

# --- User Interface Elements ---
function show_header() {
    clear
    echo -e "${PURPLE}"
    echo '██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗'
    echo '██║     ██║████╗  ██║██║   ██║╚██╗██╔╝'
    echo '██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝ '
    echo '██║     ██║██║╚██╗██║██║   ██║ ██╔██╗ '
    echo '███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗'
    echo '╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝'
    echo -e "${NC}"
    echo -e "${CYAN}╔═══════════════╗${NC}"
    echo -e "${GREEN}  Linux工具箱 ${NC}"
    echo -e "${CYAN}╚═══════════════╝${NC}"
    
    if [ "$INSTALLED" = "true" ]; then
        echo -e "${BLUE}  运行模式: 已安装 (命令: tool)${NC}"
    else
        echo -e "${BLUE}  运行模式: 临时运行${NC}"
    fi
    echo -e "${PURPLE}  检测到系统: ${OS_TYPE} ${OS_VERSION} (${OS_CODENAME})${NC}"
}


function press_any_key() {
    echo
    read -p "按回车键返回..." < /dev/tty
}

function select_user_interactive() {
    local prompt_message="$1"
    mapfile -t users < <(awk -F: '($1 == "root") || ($3 >= 1000 && $7 ~ /^\/bin\/(bash|sh|zsh|dash)$/)' /etc/passwd | cut -d: -f1 | sort)
    
    if [ ${#users[@]} -eq 0 ]; then
        echo -e "${RED}未找到可操作的用户。${NC}" >&2
        return 1
    fi

    echo -e "${YELLOW}${prompt_message}${NC}"
    local i
    for i in "${!users[@]}"; do
        echo -e "${GREEN}$((i+1)). ${users[$i]}${NC}"
    done
    echo -e "${GREEN}0. 取消${NC}"

    read -p "请输入选项: " choice < /dev/tty
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -gt "${#users[@]}" ]; then
        echo -e "${RED}无效选项${NC}" >&2 ; sleep 1
        return 1
    fi
    
    if [ "$choice" -eq 0 ]; then
        return 1
    fi
    
    echo "${users[$((choice-1))]}"
    return 0
}

# --- Toolbox Management ---
function toolbox_management_menu() {
    show_header
    echo -e "${YELLOW}====== 工具箱管理 ======${NC}"
    echo -e "${GREEN}1. 安装/更新 工具箱${NC}"
    echo -e "${GREEN}2. 卸载工具箱${NC}"
    echo -e "${GREEN}0. 返回主菜单${NC}"
    echo -e "${CYAN}==============================================${NC}"
    
    read -p "请输入选项 [0-2]: " choice < /dev/tty
    case $choice in
        1) install_toolbox ;;
        2) uninstall_toolbox ;;
        0) main_menu ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1; toolbox_management_menu ;;
    esac
}

function install_toolbox() {
    echo -e "${YELLOW}正在从 GitHub 下载最新安装脚本并执行...${NC}"
    local install_script_url="https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main/install.sh"
    
    local install_output
    if command -v curl &>/dev/null; then
        install_output=$(bash <(curl -sL "${install_script_url}"))
    elif command -v wget &>/dev/null; then
        install_output=$(bash <(wget -qO- "${install_script_url}"))
    else
        echo -e "${RED}错误: curl 或 wget 未安装，无法下载安装脚本。${NC}"
        press_any_key
        toolbox_management_menu
        return
    fi

    echo "$install_output"

    if [[ "$install_output" == *"安装/更新 成功"* ]]; then
        echo -e "${GREEN}更新成功！正在重启工具箱...${NC}"
        sleep 2
        exec tool
    else
        echo -e "${RED}更新似乎失败了，请检查上面的输出。${NC}"
        press_any_key
        toolbox_management_menu
    fi
}

function uninstall_toolbox() {
    echo -e "${YELLOW}正在卸载工具箱...${NC}"
    if [ ! -f "$TOOL_EXECUTABLE" ]; then
        echo -e "${RED}工具箱未安装，无需卸载。${NC}"
    else
        rm -f "$TOOL_EXECUTABLE"
        rm -rf "$TOOLBOX_INSTALL_DIR"
        rm -rf "$TOOLBOX_LIB_DIR"
        hash -r
        echo -e "${GREEN}工具箱已成功卸载。${NC}"
        echo -e "${YELLOW}为了确保所有更改生效，建议您关闭并重新打开终端。${NC}"
    fi
    read -p "按回车键退出..." < /dev/tty
    exit 0
}
