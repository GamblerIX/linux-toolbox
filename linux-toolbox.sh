#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib_utils.sh"
source "$SCRIPT_DIR/lib_system.sh"
source "$SCRIPT_DIR/lib_network.sh"
source "$SCRIPT_DIR/lib_firewall.sh"
source "$SCRIPT_DIR/lib_software.sh"
source "$SCRIPT_DIR/lib_toolbox.sh"

VERSION=$(cat "$SCRIPT_DIR/version" 2>/dev/null || echo "1.0.0")

show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Linux 系统工具箱                         ║"
    echo "║                                                              ║"
    echo "║                    版本: $VERSION                              ║"
    echo "║                                                              ║"
    echo "║              专为 Debian 系统运维设计                       ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

show_system_info() {
    echo -e "${CYAN}系统信息:${NC}"
    echo "操作系统: $(get_os_info)"
    echo "内核版本: $(uname -r)"
    echo "运行时间: $(uptime -p 2>/dev/null || uptime | awk '{print $3,$4}' | sed 's/,//')"
    echo "负载均衡: $(uptime | awk -F'load average:' '{print $2}')"
    echo "内存使用: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
    echo "磁盘使用: $(df -h / | awk 'NR==2{print $5}')"
    echo
}

main_menu() {
    while true; do
        show_banner
        show_system_info
        
        show_menu "主菜单" \
            "系统管理" \
            "网络工具" \
            "防火墙管理" \
            "软件管理" \
            "工具箱管理" \
            "系统信息" \
            "快速操作" \
            "帮助信息"
        
        local choice=$(read_choice 8)
        
        case $choice in
            0) 
                log_info "感谢使用 Linux 工具箱！"
                exit 0
                ;;
            1) system_management ;;
            2) network_management ;;
            3) firewall_management ;;
            4) software_management ;;
            5) toolbox_management ;;
            6) show_detailed_system_info ;;
            7) quick_operations ;;
            8) show_help ;;
        esac
    done
}

network_management() {
    while true; do
        show_menu "网络工具" \
            "网络速度测试" \
            "SSH 管理" \
            "BBR 加速" \
            "端口管理" \
            "网络诊断" \
            "IP 信息查询"
        
        local choice=$(read_choice 6)
        
        case $choice in
            0) return ;;
            1) network_speed_test ;;
            2) ssh_management ;;
            3) bbr_management ;;
            4) port_management ;;
            5) network_diagnosis ;;
            6) ip_info_query ;;
        esac
    done
}

show_detailed_system_info() {
    print_title "详细系统信息"
    
    echo -e "${CYAN}基本信息:${NC}"
    echo "主机名: $(hostname)"
    echo "用户名: $(whoami)"
    echo "当前目录: $(pwd)"
    echo "Shell: $SHELL"
    echo
    
    echo -e "${CYAN}硬件信息:${NC}"
    echo "CPU型号: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^ *//')"
    echo "CPU核心: $(nproc)"
    echo "总内存: $(free -h | awk 'NR==2{print $2}')"
    echo "可用内存: $(free -h | awk 'NR==2{print $7}')"
    echo
    
    echo -e "${CYAN}磁盘信息:${NC}"
    df -h | grep -E '^/dev/'
    echo
    
    echo -e "${CYAN}网络信息:${NC}"
    ip addr show | grep -E 'inet.*scope global' | awk '{print $2}' | head -5
    echo
    
    echo -e "${CYAN}进程信息:${NC}"
    echo "总进程数: $(ps aux | wc -l)"
    echo "运行进程: $(ps aux | awk '$8 ~ /^R/ {count++} END {print count+0}')"
    echo "睡眠进程: $(ps aux | awk '$8 ~ /^S/ {count++} END {print count+0}')"
    echo
    
    echo -e "${CYAN}最近登录:${NC}"
    last -n 5
    
    press_enter
}

quick_operations() {
    while true; do
        show_menu "快速操作" \
            "系统更新" \
            "清理系统" \
            "重启服务" \
            "查看日志" \
            "性能监控" \
            "安全检查" \
            "备份重要文件" \
            "一键优化"
        
        local choice=$(read_choice 8)
        
        case $choice in
            0) return ;;
            1) quick_system_update ;;
            2) quick_system_cleanup ;;
            3) quick_service_restart ;;
            4) quick_log_view ;;
            5) quick_performance_monitor ;;
            6) quick_security_check ;;
            7) quick_backup ;;
            8) quick_optimization ;;
        esac
    done
}

quick_system_update() {
    print_title "快速系统更新"
    
    local pm=$(get_package_manager)
    
    log_info "更新软件包列表..."
    case $pm in
        "apt")
            apt-get update
            log_info "升级系统包..."
            apt-get upgrade -y
            log_info "清理无用包..."
            apt-get autoremove -y
            apt-get autoclean
            ;;
        "yum")
            yum update -y
            yum autoremove -y
            ;;
        "dnf")
            dnf update -y
            dnf autoremove -y
            ;;
    esac
    
    log_success "系统更新完成"
    press_enter
}

quick_system_cleanup() {
    print_title "快速系统清理"
    
    log_info "清理临时文件..."
    rm -rf /tmp/*
    rm -rf /var/tmp/*
    
    log_info "清理日志文件..."
    journalctl --vacuum-time=7d 2>/dev/null
    
    log_info "清理包缓存..."
    local pm=$(get_package_manager)
    case $pm in
        "apt")
            apt-get clean
            apt-get autoremove -y
            ;;
        "yum")
            yum clean all
            ;;
        "dnf")
            dnf clean all
            ;;
    esac
    
    log_info "清理用户缓存..."
    if [[ -d "$HOME/.cache" ]]; then
        find "$HOME/.cache" -type f -atime +7 -delete 2>/dev/null
    fi
    
    log_success "系统清理完成"
    
    echo -e "${CYAN}清理后磁盘使用情况:${NC}"
    df -h /
    
    press_enter
}

quick_service_restart() {
    print_title "重启服务"
    
    echo "请选择要重启的服务:"
    echo "1. SSH"
    echo "2. Nginx"
    echo "3. Apache"
    echo "4. MySQL/MariaDB"
    echo "5. Redis"
    echo "6. Docker"
    echo "7. 网络服务"
    echo "0. 返回"
    
    local choice=$(read_choice 7)
    
    case $choice in
        0) return ;;
        1) systemctl restart sshd || systemctl restart ssh ;;
        2) systemctl restart nginx ;;
        3) systemctl restart apache2 || systemctl restart httpd ;;
        4) systemctl restart mysql || systemctl restart mariadb ;;
        5) systemctl restart redis ;;
        6) systemctl restart docker ;;
        7) systemctl restart networking || systemctl restart NetworkManager ;;
    esac
    
    if [[ $choice -ne 0 ]]; then
        log_success "服务重启完成"
    fi
    
    press_enter
}

quick_log_view() {
    print_title "查看系统日志"
    
    echo "请选择要查看的日志:"
    echo "1. 系统日志 (最近50行)"
    echo "2. 认证日志"
    echo "3. 内核日志"
    echo "4. SSH日志"
    echo "5. Nginx日志"
    echo "6. 自定义日志文件"
    echo "0. 返回"
    
    local choice=$(read_choice 6)
    
    case $choice in
        0) return ;;
        1) 
            echo -e "${CYAN}系统日志:${NC}"
            journalctl -n 50 --no-pager
            ;;
        2)
            echo -e "${CYAN}认证日志:${NC}"
            tail -50 /var/log/auth.log 2>/dev/null || tail -50 /var/log/secure 2>/dev/null
            ;;
        3)
            echo -e "${CYAN}内核日志:${NC}"
            dmesg | tail -50
            ;;
        4)
            echo -e "${CYAN}SSH日志:${NC}"
            grep sshd /var/log/auth.log 2>/dev/null | tail -20 || grep sshd /var/log/secure 2>/dev/null | tail -20
            ;;
        5)
            echo -e "${CYAN}Nginx访问日志:${NC}"
            tail -20 /var/log/nginx/access.log 2>/dev/null || echo "Nginx日志文件不存在"
            echo -e "${CYAN}Nginx错误日志:${NC}"
            tail -20 /var/log/nginx/error.log 2>/dev/null || echo "Nginx错误日志文件不存在"
            ;;
        6)
            read -p "请输入日志文件路径: " log_file
            if [[ -f "$log_file" ]]; then
                tail -50 "$log_file"
            else
                log_error "文件不存在: $log_file"
            fi
            ;;
    esac
    
    press_enter
}

quick_performance_monitor() {
    print_title "性能监控"
    
    echo -e "${CYAN}CPU使用率:${NC}"
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//'
    
    echo -e "${CYAN}内存使用情况:${NC}"
    free -h
    
    echo -e "${CYAN}磁盘I/O:${NC}"
    iostat 1 1 2>/dev/null || echo "iostat 未安装"
    
    echo -e "${CYAN}网络连接:${NC}"
    netstat -tuln | head -10
    
    echo -e "${CYAN}进程TOP10:${NC}"
    ps aux --sort=-%cpu | head -11
    
    press_enter
}

quick_security_check() {
    print_title "安全检查"
    
    log_info "检查失败登录尝试..."
    grep "Failed password" /var/log/auth.log 2>/dev/null | tail -10 || grep "Failed password" /var/log/secure 2>/dev/null | tail -10
    
    log_info "检查sudo使用记录..."
    grep "sudo" /var/log/auth.log 2>/dev/null | tail -10 || grep "sudo" /var/log/secure 2>/dev/null | tail -10
    
    log_info "检查开放端口..."
    netstat -tuln | grep LISTEN
    
    log_info "检查运行服务..."
    systemctl list-units --type=service --state=running | head -10
    
    log_info "检查最近登录..."
    last -n 10
    
    press_enter
}

quick_backup() {
    print_title "备份重要文件"
    
    local backup_dir="/backup/$(date +%Y%m%d-%H%M%S)"
    
    if confirm_action "是否创建系统配置备份到 $backup_dir？" "y"; then
        mkdir -p "$backup_dir"
        
        log_info "备份系统配置文件..."
        cp -r /etc "$backup_dir/" 2>/dev/null
        
        log_info "备份用户配置..."
        cp -r "$HOME/.bashrc" "$HOME/.profile" "$backup_dir/" 2>/dev/null
        
        log_info "备份crontab..."
        crontab -l > "$backup_dir/crontab.bak" 2>/dev/null
        
        log_info "创建系统信息快照..."
        {
            echo "备份时间: $(date)"
            echo "系统信息: $(uname -a)"
            echo "安装包列表:"
            dpkg -l 2>/dev/null || rpm -qa 2>/dev/null
        } > "$backup_dir/system_info.txt"
        
        log_success "备份完成: $backup_dir"
    fi
    
    press_enter
}

quick_optimization() {
    print_title "一键优化"
    
    log_warn "此操作将执行多项系统优化，请确认继续"
    
    if ! confirm_action "确定要执行一键优化吗？"; then
        return
    fi
    
    log_info "1. 更新系统..."
    quick_system_update
    
    log_info "2. 清理系统..."
    quick_system_cleanup
    
    log_info "3. 优化内核参数..."
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
    echo 'net.core.rmem_max=16777216' >> /etc/sysctl.conf
    echo 'net.core.wmem_max=16777216' >> /etc/sysctl.conf
    sysctl -p
    
    log_info "4. 优化SSH配置..."
    sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 60/' /etc/ssh/sshd_config
    sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 3/' /etc/ssh/sshd_config
    
    log_info "5. 设置时区..."
    timedatectl set-timezone Asia/Shanghai 2>/dev/null
    
    log_success "一键优化完成！"
    log_info "建议重启系统以使所有优化生效"
    
    press_enter
}

show_help() {
    print_title "帮助信息"
    
    echo -e "${CYAN}Linux 工具箱使用说明:${NC}"
    echo
    echo "1. 系统管理 - 用户管理、软件源配置、系统清理等"
    echo "2. 网络工具 - 网速测试、SSH管理、BBR加速等"
    echo "3. 防火墙管理 - UFW/iptables/firewalld 管理"
    echo "4. 软件管理 - Docker、Nginx、MySQL等软件安装"
    echo "5. 工具箱管理 - 更新、配置、备份工具箱"
    echo "6. 系统信息 - 查看详细的系统信息"
    echo "7. 快速操作 - 常用的快捷操作"
    echo
    echo -e "${CYAN}快捷键:${NC}"
    echo "Ctrl+C - 退出当前操作"
    echo "0 - 返回上级菜单"
    echo
    echo -e "${CYAN}注意事项:${NC}"
    echo "• 请以root权限运行此工具"
    echo "• 重要操作前会提示确认"
    echo "• 建议在执行前备份重要数据"
    echo "• 如遇问题请查看日志文件"
    echo
    echo -e "${CYAN}版本信息:${NC}"
    echo "当前版本: $VERSION"
    echo "脚本路径: $SCRIPT_DIR"
    echo
    
    press_enter
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo $0"
        exit 1
    fi
}

check_dependencies() {
    local missing_deps=()
    
    local required_commands=("curl" "wget" "systemctl")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warn "缺少依赖: ${missing_deps[*]}"
        if confirm_action "是否自动安装缺少的依赖？" "y"; then
            local pm=$(get_package_manager)
            case $pm in
                "apt")
                    apt-get update
                    apt-get install -y "${missing_deps[@]}"
                    ;;
                "yum")
                    yum install -y "${missing_deps[@]}"
                    ;;
                "dnf")
                    dnf install -y "${missing_deps[@]}"
                    ;;
            esac
        fi
    fi
}

init_toolbox() {
    check_root
    check_dependencies
    check_toolbox_update
    
    trap 'echo -e "\n${YELLOW}操作已取消${NC}"; exit 0' INT
    
    if [[ ! -f "$SCRIPT_DIR/lib_utils.sh" ]]; then
        log_error "找不到必要的库文件，请检查安装"
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_toolbox
    main_menu
fi