#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/lib_utils.sh"

network_speed_test() {
    while true; do
        show_menu "网络速度测试" \
            "speedtest-cli 测试" \
            "Superbench 综合测试" \
            "简单ping测试" \
            "下载速度测试"
        
        local choice=$(read_choice 4)
        
        case $choice in
            0) return ;;
            1) speedtest_cli_test ;;
            2) superbench_test ;;
            3) ping_test ;;
            4) download_speed_test ;;
        esac
    done
}

speedtest_cli_test() {
    print_title "speedtest-cli 网络测试"
    
    if ! check_command "speedtest-cli"; then
        log_info "正在安装 speedtest-cli..."
        local pm=$(get_package_manager)
        case $pm in
            "apt")
                apt-get update
                apt-get install -y speedtest-cli
                ;;
            "yum")
                yum install -y epel-release
                yum install -y speedtest-cli
                ;;
            "dnf")
                dnf install -y speedtest-cli
                ;;
        esac
    fi
    
    if command -v speedtest-cli &> /dev/null; then
        log_info "开始网络速度测试..."
        speedtest-cli --simple
    else
        log_error "speedtest-cli 安装失败"
    fi
    
    press_enter
}

superbench_test() {
    print_title "Superbench 综合测试"
    
    log_warn "此测试将花费较长时间，包含CPU、内存、网络等多项测试"
    
    if ! confirm_action "确定要运行综合测试吗？"; then
        return
    fi
    
    log_info "下载并运行 Superbench..."
    bash <(curl -Lso- https://git.io/superbench)
    
    press_enter
}

ping_test() {
    print_title "网络连通性测试"
    
    local targets=("8.8.8.8" "114.114.114.114" "1.1.1.1" "baidu.com" "google.com")
    
    for target in "${targets[@]}"; do
        echo -e "${CYAN}测试 $target:${NC}"
        if ping -c 4 "$target" | tail -1; then
            log_success "$target 连通正常"
        else
            log_error "$target 连接失败"
        fi
        echo
    done
    
    press_enter
}

download_speed_test() {
    print_title "下载速度测试"
    
    local test_urls=(
        "http://speedtest.tele2.net/100MB.zip"
        "https://proof.ovh.net/files/100Mb.dat"
        "http://ipv4.download.thinkbroadband.com/100MB.zip"
    )
    
    for url in "${test_urls[@]}"; do
        echo -e "${CYAN}测试下载: $(basename "$url")${NC}"
        if command -v wget &> /dev/null; then
            wget --progress=dot:mega -O /dev/null "$url" 2>&1 | grep -E '\([0-9]+.*\/s\)'
        elif command -v curl &> /dev/null; then
            curl -o /dev/null "$url" -w "平均速度: %{speed_download} bytes/s\n"
        else
            log_error "需要安装 wget 或 curl"
            break
        fi
        echo
    done
    
    press_enter
}

ssh_management() {
    while true; do
        show_menu "SSH 安全管理" \
            "查看SSH登录日志" \
            "查看当前SSH连接" \
            "修改SSH端口" \
            "禁用root登录" \
            "启用密钥认证" \
            "查看失败登录记录"
        
        local choice=$(read_choice 6)
        
        case $choice in
            0) return ;;
            1) view_ssh_logs ;;
            2) view_ssh_connections ;;
            3) change_ssh_port ;;
            4) disable_root_login ;;
            5) enable_key_auth ;;
            6) view_failed_logins ;;
        esac
    done
}

view_ssh_logs() {
    print_title "SSH登录日志"
    
    echo -e "${CYAN}最近的SSH登录记录:${NC}"
    if [[ -f /var/log/auth.log ]]; then
        grep "sshd.*Accepted" /var/log/auth.log | tail -20
    elif [[ -f /var/log/secure ]]; then
        grep "sshd.*Accepted" /var/log/secure | tail -20
    else
        journalctl -u ssh -n 20 | grep "Accepted"
    fi
    
    press_enter
}

view_ssh_connections() {
    print_title "当前SSH连接"
    
    echo -e "${CYAN}活动的SSH连接:${NC}"
    netstat -tnpa | grep ':22 ' | grep ESTABLISHED
    
    echo
    echo -e "${CYAN}当前登录用户:${NC}"
    who
    
    press_enter
}

change_ssh_port() {
    print_title "修改SSH端口"
    
    local current_port=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}' || echo "22")
    echo "当前SSH端口: $current_port"
    
    read -p "请输入新的SSH端口 (1024-65535): " new_port
    
    if ! validate_port "$new_port"; then
        log_error "无效的端口号"
        press_enter
        return
    fi
    
    if [[ "$new_port" -lt 1024 ]]; then
        log_error "建议使用1024以上的端口"
        press_enter
        return
    fi
    
    backup_file "/etc/ssh/sshd_config"
    
    if grep -q "^Port" /etc/ssh/sshd_config; then
        sed -i "s/^Port.*/Port $new_port/" /etc/ssh/sshd_config
    else
        echo "Port $new_port" >> /etc/ssh/sshd_config
    fi
    
    log_success "SSH端口已修改为 $new_port"
    log_warn "请确保防火墙允许新端口，然后重启SSH服务"
    
    if confirm_action "是否立即重启SSH服务？"; then
        systemctl restart sshd
        log_success "SSH服务已重启"
    fi
    
    press_enter
}

disable_root_login() {
    print_title "禁用root SSH登录"
    
    if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
        log_info "root登录已经被禁用"
        press_enter
        return
    fi
    
    log_warn "警告：禁用root登录后，需要使用其他用户登录"
    
    if ! confirm_action "确定要禁用root SSH登录吗？"; then
        return
    fi
    
    backup_file "/etc/ssh/sshd_config"
    
    if grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
        sed -i "s/^PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config
    else
        echo "PermitRootLogin no" >> /etc/ssh/sshd_config
    fi
    
    log_success "root SSH登录已禁用"
    
    if confirm_action "是否立即重启SSH服务？"; then
        systemctl restart sshd
        log_success "SSH服务已重启"
    fi
    
    press_enter
}

enable_key_auth() {
    print_title "启用SSH密钥认证"
    
    backup_file "/etc/ssh/sshd_config"
    
    sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config
    
    log_success "SSH密钥认证已启用"
    
    if confirm_action "是否禁用密码认证？"; then
        sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        log_success "密码认证已禁用"
    fi
    
    if confirm_action "是否立即重启SSH服务？"; then
        systemctl restart sshd
        log_success "SSH服务已重启"
    fi
    
    press_enter
}

view_failed_logins() {
    print_title "失败登录记录"
    
    echo -e "${CYAN}最近的失败登录尝试:${NC}"
    if [[ -f /var/log/auth.log ]]; then
        grep "sshd.*Failed" /var/log/auth.log | tail -20
    elif [[ -f /var/log/secure ]]; then
        grep "sshd.*Failed" /var/log/secure | tail -20
    else
        journalctl -u ssh -n 50 | grep "Failed"
    fi
    
    echo
    echo -e "${CYAN}失败登录统计:${NC}"
    if [[ -f /var/log/auth.log ]]; then
        grep "sshd.*Failed" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | head -10
    elif [[ -f /var/log/secure ]]; then
        grep "sshd.*Failed" /var/log/secure | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | head -10
    fi
    
    press_enter
}

bbr_management() {
    print_title "BBR 网络加速管理"
    
    local current_congestion=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    echo "当前拥塞控制算法: $current_congestion"
    
    if [[ "$current_congestion" == "bbr" ]]; then
        echo -e "${GREEN}BBR已启用${NC}"
        
        if confirm_action "是否禁用BBR？"; then
            disable_bbr
        fi
    else
        echo -e "${YELLOW}BBR未启用${NC}"
        
        if confirm_action "是否启用BBR？"; then
            enable_bbr
        fi
    fi
    
    press_enter
}

enable_bbr() {
    log_info "启用BBR拥塞控制算法..."
    
    local kernel_version=$(uname -r | cut -d. -f1-2)
    local major=$(echo $kernel_version | cut -d. -f1)
    local minor=$(echo $kernel_version | cut -d. -f2)
    
    if [[ $major -lt 4 ]] || [[ $major -eq 4 && $minor -lt 9 ]]; then
        log_error "BBR需要内核版本4.9或更高，当前版本: $(uname -r)"
        return
    fi
    
    echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
    echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
    
    sysctl -p
    
    if [[ $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}') == "bbr" ]]; then
        log_success "BBR启用成功"
    else
        log_error "BBR启用失败"
    fi
}

disable_bbr() {
    log_info "禁用BBR拥塞控制算法..."
    
    sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
    
    sysctl -w net.ipv4.tcp_congestion_control=cubic
    
    log_success "BBR已禁用，恢复为cubic算法"
}

port_management() {
    while true; do
        show_menu "端口管理" \
            "查看端口占用" \
            "查看指定端口" \
            "终止端口进程" \
            "查看网络连接" \
            "端口扫描"
        
        local choice=$(read_choice 5)
        
        case $choice in
            0) return ;;
            1) view_port_usage ;;
            2) check_specific_port ;;
            3) kill_port_process ;;
            4) view_network_connections ;;
            5) port_scan ;;
        esac
    done
}

view_port_usage() {
    print_title "端口占用情况"
    
    echo -e "${CYAN}TCP端口:${NC}"
    netstat -tlnp 2>/dev/null | grep LISTEN | head -20
    
    echo
    echo -e "${CYAN}UDP端口:${NC}"
    netstat -ulnp 2>/dev/null | head -10
    
    press_enter
}

check_specific_port() {
    print_title "查看指定端口"
    
    read -p "请输入端口号: " port
    
    if ! validate_port "$port"; then
        log_error "无效的端口号"
        press_enter
        return
    fi
    
    echo -e "${CYAN}端口 $port 的使用情况:${NC}"
    
    local tcp_result=$(netstat -tlnp 2>/dev/null | grep ":$port ")
    local udp_result=$(netstat -ulnp 2>/dev/null | grep ":$port ")
    
    if [[ -n "$tcp_result" ]]; then
        echo "TCP: $tcp_result"
    fi
    
    if [[ -n "$udp_result" ]]; then
        echo "UDP: $udp_result"
    fi
    
    if [[ -z "$tcp_result" && -z "$udp_result" ]]; then
        echo "端口 $port 未被占用"
    fi
    
    press_enter
}

kill_port_process() {
    print_title "终止端口进程"
    
    read -p "请输入要终止的端口号: " port
    
    if ! validate_port "$port"; then
        log_error "无效的端口号"
        press_enter
        return
    fi
    
    local pid=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1)
    
    if [[ -z "$pid" ]]; then
        log_error "端口 $port 未被占用"
        press_enter
        return
    fi
    
    local process_name=$(ps -p "$pid" -o comm= 2>/dev/null)
    
    log_warn "将要终止进程: $process_name (PID: $pid)"
    
    if confirm_action "确定要终止此进程吗？"; then
        kill "$pid"
        if [[ $? -eq 0 ]]; then
            log_success "进程已终止"
        else
            log_error "终止进程失败"
        fi
    fi
    
    press_enter
}

view_network_connections() {
    print_title "网络连接状态"
    
    echo -e "${CYAN}活动连接:${NC}"
    netstat -tuln | head -20
    
    echo
    echo -e "${CYAN}连接统计:${NC}"
    netstat -s | grep -E '(connections|packets)'
    
    press_enter
}

port_scan() {
    print_title "端口扫描"
    
    read -p "请输入要扫描的主机 (默认: localhost): " host
    host=${host:-localhost}
    
    read -p "请输入端口范围 (例如: 1-1000): " port_range
    
    if [[ -z "$port_range" ]]; then
        port_range="1-1000"
    fi
    
    if ! command -v nmap &> /dev/null; then
        log_warn "nmap未安装，使用简单扫描"
        simple_port_scan "$host" "$port_range"
    else
        log_info "使用nmap扫描 $host 端口 $port_range"
        nmap -p "$port_range" "$host"
    fi
    
    press_enter
}

simple_port_scan() {
    local host="$1"
    local range="$2"
    
    local start_port=$(echo "$range" | cut -d'-' -f1)
    local end_port=$(echo "$range" | cut -d'-' -f2)
    
    log_info "扫描 $host 端口 $start_port-$end_port"
    
    for ((port=start_port; port<=end_port; port++)); do
        if timeout 1 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
            echo "端口 $port: 开放"
        fi
    done
}