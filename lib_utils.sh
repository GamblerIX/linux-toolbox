#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_separator() {
    echo -e "${BLUE}================================================${NC}"
}

print_title() {
    echo
    print_separator
    echo -e "${CYAN}$1${NC}"
    print_separator
    echo
}

confirm_action() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        read -p "$message [Y/n]: " choice
        choice=${choice:-y}
    else
        read -p "$message [y/N]: " choice
        choice=${choice:-n}
    fi
    
    case "$choice" in
        [Yy]* ) return 0;;
        [Nn]* ) return 1;;
        * ) log_error "请输入 y 或 n"; confirm_action "$message" "$default";;
    esac
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo $0"
        exit 1
    fi
}

check_internet() {
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        log_error "网络连接失败，请检查网络设置"
        return 1
    fi
    return 0
}

get_os_info() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [[ -f /etc/lsb-release ]]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
}

get_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

install_package() {
    local package="$1"
    local pm=$(get_package_manager)
    
    case $pm in
        "apt")
            apt-get update &> /dev/null
            apt-get install -y "$package"
            ;;
        "yum")
            yum install -y "$package"
            ;;
        "dnf")
            dnf install -y "$package"
            ;;
        "pacman")
            pacman -S --noconfirm "$package"
            ;;
        *)
            log_error "不支持的包管理器"
            return 1
            ;;
    esac
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_warn "命令 $1 未找到，正在安装..."
        install_package "$1"
        if ! command -v "$1" &> /dev/null; then
            log_error "安装 $1 失败"
            return 1
        fi
        log_success "$1 安装成功"
    fi
    return 0
}

get_system_info() {
    echo -e "${CYAN}系统信息:${NC}"
    echo "操作系统: $(uname -o)"
    echo "内核版本: $(uname -r)"
    echo "架构: $(uname -m)"
    echo "主机名: $(hostname)"
    echo "运行时间: $(uptime -p 2>/dev/null || uptime)"
    echo "当前用户: $(whoami)"
    echo "当前目录: $(pwd)"
}

press_enter() {
    echo
    read -p "按回车键继续..."
}

show_menu() {
    local title="$1"
    shift
    local options=("$@")
    
    print_title "$title"
    
    for i in "${!options[@]}"; do
        echo -e "${WHITE}$((i+1)).${NC} ${options[i]}"
    done
    echo -e "${WHITE}0.${NC} 返回上级菜单"
    echo
}

read_choice() {
    local max_choice="$1"
    local choice
    
    while true; do
        read -p "请选择 [0-$max_choice]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 0 ]] && [[ "$choice" -le "$max_choice" ]]; then
            echo "$choice"
            return
        else
            log_error "无效选择，请输入 0-$max_choice 之间的数字"
        fi
    done
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "已备份文件: $file"
    fi
}

check_service() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        return 0
    else
        return 1
    fi
}

get_free_port() {
    local port
    for port in {8000..9000}; do
        if ! netstat -tuln | grep -q ":$port "; then
            echo "$port"
            return
        fi
    done
    echo "8080"
}

validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [[ $i -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && [[ "$port" -ge 1 ]] && [[ "$port" -le 65535 ]]; then
        return 0
    fi
    return 1
}

get_file_size() {
    local file="$1"
    if [[ -f "$file" ]]; then
        du -h "$file" | cut -f1
    else
        echo "0"
    fi
}

cleanup_temp() {
    local temp_dir="/tmp/linux-toolbox-$$"
    if [[ -d "$temp_dir" ]]; then
        rm -rf "$temp_dir"
    fi
}

trap cleanup_temp EXIT