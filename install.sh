#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TOOLBOX_DIR="/opt/linux-toolbox"
BIN_DIR="/usr/local/bin"
GITHUB_REPO="https://github.com/GamblerIX/linux-toolbox"
GITEE_REPO="https://gitee.com/GamblerIX/linux-toolbox"
GITHUB_RAW="https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main"
GITEE_RAW="https://gitee.com/GamblerIX/linux-toolbox/raw/main"
TEMP_DIR="/tmp/linux-toolbox-install"
USE_SOURCE="auto"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════╗"
    echo " Linux 工具箱 安装程序
    echo " By GamblerIX
    echo "╚════════════════════╝"
    echo -e "${NC}"
    echo
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo bash install.sh"
        exit 1
    fi
}

check_system() {
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        log_error "需要 curl 或 wget 来下载文件"
        log_info "正在安装 curl..."
        
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y curl
        elif command -v yum &> /dev/null; then
            yum install -y curl
        elif command -v dnf &> /dev/null; then
            dnf install -y curl
        else
            log_error "无法自动安装 curl，请手动安装后重试"
            exit 1
        fi
    fi
    
    if ! command -v git &> /dev/null; then
        log_warn "Git 未安装，将使用 curl/wget 下载"
    fi
}

test_source_speed() {
    local url=$1
    local timeout=5
    
    if command -v curl &> /dev/null; then
        local time=$(curl -o /dev/null -s -w "%{time_total}" --connect-timeout $timeout "$url" 2>/dev/null || echo "999")
        echo "$time"
    elif command -v wget &> /dev/null; then
        local start=$(date +%s.%N)
        wget -q --timeout=$timeout --tries=1 -O /dev/null "$url" >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            local end=$(date +%s.%N)
            echo "$(echo "$end - $start" | bc 2>/dev/null || echo "999")"
        else
            echo "999"
        fi
    else
        echo "999"
    fi
}

select_best_source() {
    if [[ "$USE_SOURCE" == "github" ]]; then
        echo "github"
        return
    elif [[ "$USE_SOURCE" == "gitee" ]]; then
        echo "gitee"
        return
    fi
    
    log_info "检测最佳下载源..."
    
    local github_speed=$(test_source_speed "$GITHUB_RAW/VERSION")
    local gitee_speed=$(test_source_speed "$GITEE_RAW/VERSION")
    
    log_info "GitHub延迟: ${github_speed}s, Gitee延迟: ${gitee_speed}s"
    
    if (( $(echo "$github_speed < $gitee_speed" | bc -l 2>/dev/null || echo "0") )); then
        log_info "选择GitHub源 (延迟更低)"
        echo "github"
    else
        log_info "选择Gitee源 (延迟更低)"
        echo "gitee"
    fi
}

get_latest_version() {
    local source=$(select_best_source)
    local version_url
    
    if [[ "$source" == "github" ]]; then
        version_url="$GITHUB_RAW/VERSION"
    else
        version_url="$GITEE_RAW/VERSION"
    fi
    
    local version
    if command -v curl &> /dev/null; then
        version=$(curl -s "$version_url" 2>/dev/null)
    elif command -v wget &> /dev/null; then
        version=$(wget -qO- "$version_url" 2>/dev/null)
    fi
    
    if [[ -z "$version" ]]; then
        version="1.0.0"
    fi
    
    echo "$version"
}

get_current_version() {
    if [[ -f "$TOOLBOX_DIR/VERSION" ]]; then
        cat "$TOOLBOX_DIR/VERSION"
    else
        echo "0.0.0"
    fi
}

compare_versions() {
    local version1=$1
    local version2=$2
    
    if [[ "$version1" == "$version2" ]]; then
        return 0
    fi
    
    local IFS=.
    local i ver1=($version1) ver2=($version2)
    
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 2
        fi
    done
    return 0
}

download_toolbox() {
    log_info "创建临时目录..."
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    local source=$(select_best_source)
    local repo_url
    
    if [[ "$source" == "github" ]]; then
        repo_url="$GITHUB_REPO"
    else
        repo_url="$GITEE_REPO"
    fi
    
    if command -v git &> /dev/null; then
        log_info "使用 Git 克隆仓库 ($source)..."
        git clone "$repo_url" . || {
            log_warn "Git 克隆失败，尝试使用 curl 下载"
            download_with_curl "$source"
        }
    else
        download_with_curl "$source"
    fi
}

download_with_curl() {
    local source=${1:-$(select_best_source)}
    local base_url
    
    if [[ "$source" == "github" ]]; then
        base_url="$GITHUB_RAW"
    else
        base_url="$GITEE_RAW"
    fi
    
    log_info "使用 curl 下载工具箱文件 ($source)..."
    
    local files=(
        "VERSION"
        "lib_utils.sh"
        "lib_system.sh"
        "lib_network.sh"
        "lib_firewall.sh"
        "lib_software.sh"
        "lib_toolbox.sh"
        "tool.sh"
        "README.md"
    )
    
    for file in "${files[@]}"; do
        local url="$base_url/$file"
        log_info "下载 $file..."
        
        if command -v curl &> /dev/null; then
            curl -fsSL "$url" -o "$file" || {
                log_error "下载 $file 失败"
                return 1
            }
        elif command -v wget &> /dev/null; then
            wget -q "$url" -O "$file" || {
                log_error "下载 $file 失败"
                return 1
            }
        fi
    done
}

install_toolbox() {
    log_info "安装工具箱到 $TOOLBOX_DIR..."
    
    if [[ -d "$TOOLBOX_DIR" ]]; then
        log_info "备份现有安装..."
        mv "$TOOLBOX_DIR" "${TOOLBOX_DIR}.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    
    mkdir -p "$TOOLBOX_DIR"
    cp -r "$TEMP_DIR"/* "$TOOLBOX_DIR/"
    
    chmod +x "$TOOLBOX_DIR"/*.sh
    
    log_info "创建系统链接..."
    ln -sf "$TOOLBOX_DIR/tool.sh" "$BIN_DIR/tool"
    
    log_info "设置权限..."
    chown -R root:root "$TOOLBOX_DIR"
    chmod 755 "$TOOLBOX_DIR"
    chmod 644 "$TOOLBOX_DIR"/lib_*.sh
    chmod 755 "$TOOLBOX_DIR/tool.sh"
}

create_desktop_entry() {
    if [[ -d "/usr/share/applications" ]]; then
        log_info "创建桌面快捷方式..."
        cat > /usr/share/applications/linux-toolbox.desktop << EOF
[Desktop Entry]
Name=Linux Toolbox
Comment=Linux系统管理工具箱
Exec=gnome-terminal -- tool
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=System;Administration;
Keywords=linux;system;admin;toolbox;
EOF
        chmod 644 /usr/share/applications/linux-toolbox.desktop
    fi
}

setup_auto_update() {
    log_info "设置自动更新检查..."
    
    cat > /etc/cron.weekly/linux-toolbox-update << 'EOF'
#!/bin/bash

TOOLBOX_DIR="/opt/linux-toolbox"
LOG_FILE="/var/log/linux-toolbox-update.log"

if [[ -f "$TOOLBOX_DIR/install.sh" ]]; then
    echo "$(date): 检查工具箱更新" >> "$LOG_FILE"
    bash "$TOOLBOX_DIR/install.sh" --check-update >> "$LOG_FILE" 2>&1
fi
EOF
    
    chmod +x /etc/cron.weekly/linux-toolbox-update
}

cleanup() {
    log_info "清理临时文件..."
    rm -rf "$TEMP_DIR"
}

show_completion_info() {
    log_success "Linux 工具箱安装完成！"
    echo
    echo -e "${CYAN}使用方法:${NC}"
    echo "  tool             # 启动工具箱"
    echo
    echo -e "${CYAN}安装位置:${NC}"
    echo "  程序目录: $TOOLBOX_DIR"
    echo "  可执行文件: $BIN_DIR/tool"
    echo
    echo -e "${CYAN}功能模块:${NC}"
    echo "  • 系统管理 - 用户管理、软件源配置等"
    echo "  • 网络工具 - 网速测试、SSH管理等"
    echo "  • 防火墙管理 - UFW/iptables管理"
    echo "  • 软件管理 - Docker、Nginx等软件安装"
    echo "  • 工具箱管理 - 更新、配置管理"
    echo
    echo -e "${GREEN}现在可以运行 'tool' 开始使用！${NC}"
    echo
}

show_update_info() {
    local current_version=$1
    local latest_version=$2
    
    log_success "工具箱更新完成！"
    echo
    echo -e "${CYAN}版本信息:${NC}"
    echo "  旧版本: $current_version"
    echo "  新版本: $latest_version"
    echo
    echo -e "${GREEN}更新已完成，可以继续使用工具箱！${NC}"
    echo
}

uninstall_toolbox() {
    log_warn "准备卸载 Linux 工具箱..."
    
    read -p "确定要卸载吗？这将删除所有工具箱文件 [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "取消卸载"
        exit 0
    fi
    
    log_info "停止相关服务..."
    pkill -f tool 2>/dev/null || true
    
    log_info "删除文件..."
    rm -rf "$TOOLBOX_DIR"
    rm -f "$BIN_DIR/tool"
    rm -f "/usr/share/applications/linux-toolbox.desktop"
    rm -f "/etc/cron.weekly/linux-toolbox-update"
    
    log_success "Linux 工具箱已完全卸载"
}

check_update_only() {
    local current_version=$(get_current_version)
    local latest_version=$(get_latest_version)
    
    echo "当前版本: $current_version"
    echo "最新版本: $latest_version"
    
    compare_versions "$latest_version" "$current_version"
    case $? in
        1)
            echo "有新版本可用！"
            exit 1
            ;;
        0)
            echo "已是最新版本"
            exit 0
            ;;
        2)
            echo "当前版本较新"
            exit 0
            ;;
    esac
}

show_help() {
    echo "Linux 工具箱安装程序"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  --install        安装工具箱 (默认)"
    echo "  --update         更新工具箱"
    echo "  --uninstall      卸载工具箱"
    echo "  --check-update   仅检查更新"
    echo "  --github         强制使用GitHub源"
    echo "  --gitee          强制使用Gitee源"
    echo "  --help           显示此帮助信息"
    echo
    echo "示例:"
    echo "  bash install.sh                # 安装工具箱 (自动选择最佳源)"
    echo "  bash install.sh --github       # 强制使用GitHub源安装"
    echo "  bash install.sh --gitee        # 强制使用Gitee源安装"
    echo "  bash install.sh --update       # 更新工具箱"
    echo "  bash install.sh --uninstall    # 卸载工具箱"
    echo
}

main() {
    local action="install"
    
    # 处理参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --install)
                action="install"
                ;;
            --update)
                action="update"
                ;;
            --uninstall)
                action="uninstall"
                ;;
            --check-update)
                action="check-update"
                ;;
            --github)
                USE_SOURCE="github"
                ;;
            --gitee)
                USE_SOURCE="gitee"
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
    
    if [[ "$action" == "uninstall" ]]; then
        uninstall_toolbox
        exit 0
    fi
    
    if [[ "$action" == "check-update" ]]; then
        check_update_only
        exit 0
    fi
    
    show_banner
    check_root
    check_system
    
    local current_version=$(get_current_version)
    local latest_version=$(get_latest_version)
    
    if [[ "$action" == "update" ]]; then
        if [[ ! -d "$TOOLBOX_DIR" ]]; then
            log_error "工具箱未安装，请先运行安装"
            exit 1
        fi
        
        compare_versions "$latest_version" "$current_version"
        case $? in
            1)
                log_info "发现新版本: $latest_version (当前: $current_version)"
                ;;
            0)
                log_info "已是最新版本: $current_version"
                exit 0
                ;;
            2)
                log_warn "当前版本 ($current_version) 比最新版本 ($latest_version) 更新"
                exit 0
                ;;
        esac
    fi
    
    if [[ "$action" == "install" && -d "$TOOLBOX_DIR" ]]; then
        log_warn "检测到已安装的工具箱"
        compare_versions "$latest_version" "$current_version"
        case $? in
            1)
                log_info "发现新版本，将进行更新"
                action="update"
                ;;
            0)
                log_info "已安装最新版本"
                read -p "是否重新安装？ [y/N]: " confirm
                if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                    log_info "取消安装"
                    exit 0
                fi
                ;;
            2)
                log_warn "当前版本较新，继续安装可能会降级"
                read -p "确定继续吗？ [y/N]: " confirm
                if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                    log_info "取消安装"
                    exit 0
                fi
                ;;
        esac
    fi
    
    log_info "开始${action}工具箱..."
    
    download_toolbox
    install_toolbox
    create_desktop_entry
    
    if [[ "$action" == "install" ]]; then
        setup_auto_update
    fi
    
    cleanup
    
    if [[ "$action" == "update" ]]; then
        show_update_info "$current_version" "$latest_version"
    else
        show_completion_info
    fi
}

trap 'echo -e "\n${YELLOW}安装已取消${NC}"; cleanup; exit 1' INT

main "$@"