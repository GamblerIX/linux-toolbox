#!/bin/bash

VERSION="1.0.1"
GITHUB_URL="https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main"
GITEE_URL="https://gitee.com/GamblerIX/linux-toolbox/raw/main"

if [ -t 1 ] && [ -z "$NO_COLOR" ]; then
    if command -v tput >/dev/null 2>&1; then
        colors=$(tput colors 2>/dev/null || echo 0)
    else
        colors=0
    fi
    if [ "$colors" -ge 8 ]; then
        C_RESET="\033[0m"
        C_TITLE="\033[95m"
        C_OPTION="\033[93m"
        C_PROMPT="\033[96m"
        C_SUCCESS="\033[92m"
        C_ERROR="\033[91m"
        C_WARN="\033[33m"
        C_INFO="\033[36m"
        C_LINE="\033[94m"
    else
        C_RESET=""; C_TITLE=""; C_OPTION=""; C_PROMPT=""; C_SUCCESS=""; C_ERROR=""; C_WARN=""; C_INFO=""; C_LINE=""
    fi
else
    C_RESET=""; C_TITLE=""; C_OPTION=""; C_PROMPT=""; C_SUCCESS=""; C_ERROR=""; C_WARN=""; C_INFO=""; C_LINE=""
fi

hr(){ printf "%b\n" "${C_LINE}==========================================${C_RESET}"; }
title(){ printf "%b\n" "${C_TITLE}$1${C_RESET}"; }
option(){ printf "%b\n" "${C_OPTION}$1${C_RESET}"; }
prompt(){ printf "%b" "${C_PROMPT}$1${C_RESET}"; }
success(){ printf "%b\n" "${C_SUCCESS}$1${C_RESET}"; }
error(){ printf "%b\n" "${C_ERROR}$1${C_RESET}"; }
info(){ printf "%b\n" "${C_INFO}$1${C_RESET}"; }
warn(){ printf "%b\n" "${C_WARN}$1${C_RESET}"; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "请使用root权限运行此脚本"
        exit 1
    fi
}

check_system() {
    if [ -f /etc/debian_version ]; then
        OS="debian"
        PM="apt"
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
        PM="yum"
    elif [ -f /etc/arch-release ]; then
        OS="arch"
        PM="pacman"
    else
        error "不支持的操作系统"
        exit 1
    fi
}

test_speed() {
    local url=$1
    local time=$(curl -o /dev/null -s -w "%{time_total}" --connect-timeout 3 "$url/VERSION" 2>/dev/null || echo "999")
    echo $time
}

get_fastest_source() {
    github_time=$(test_speed $GITHUB_URL)
    gitee_time=$(test_speed $GITEE_URL)
    if awk "BEGIN{exit !($github_time < $gitee_time)}"; then
        echo $GITHUB_URL
    else
        echo $GITEE_URL
    fi
}

install_tool() {
    info "开始安装/更新工具箱..."
    info "正在测试源速度..."
    fastest_source=$(get_fastest_source)
    info "使用源: $fastest_source"
    tmp_file=$(mktemp) || { error "创建临时文件失败"; exit 1; }
    trap 'rm -f "$tmp_file"' RETURN
    if ! curl -fsSL "$fastest_source/tool.sh" -o "$tmp_file"; then
        error "下载失败，请检查网络连接"
        exit 1
    fi
    if [ ! -s "$tmp_file" ]; then
        error "下载文件为空或失败"
        exit 1
    fi
    if ! mv "$tmp_file" /usr/local/bin/tool; then
        error "移动文件失败"
        exit 1
    fi
    if ! chmod +x /usr/local/bin/tool; then
        error "设置可执行权限失败"
        exit 1
    fi
    success "工具箱安装/更新完成！"
    info "启动命令: tool"
    exit 0
}

update_tool() {
    info "正在更新工具箱..."
    install_tool
}

uninstall_tool() {
    info "确定要卸载工具箱吗？(y/N)"
    read -r confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        if rm -f /usr/local/bin/tool; then
            success "工具箱已卸载"
        else
            error "卸载失败"
            return 1
        fi
    else
        warn "取消卸载"
    fi
}

show_version() {
    info "Linux工具箱 v$VERSION"
}

firewall_status() {
    if command -v ufw >/dev/null 2>&1; then
        ufw status
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --state
    else
        info "未检测到防火墙管理工具"
    fi
}

enable_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        if ufw --force enable; then
            success "防火墙已启用"
        else
            error "防火墙启用失败"
            return 1
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        if systemctl enable --now firewalld >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
            success "防火墙已启用"
        else
            error "防火墙启用失败"
            return 1
        fi
    else
        info "未检测到防火墙管理工具"
        return 1
    fi
}

disable_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        if ufw --force disable; then
            success "防火墙已禁用"
        else
            error "防火墙禁用失败"
            return 1
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        if systemctl disable --now firewalld >/dev/null 2>&1; then
            success "防火墙已禁用"
        else
            error "防火墙禁用失败"
            return 1
        fi
    else
        info "未检测到防火墙管理工具"
        return 1
    fi
}

add_port_rule() {
    info "请输入要开放的端口号或范围(示例: 80 或 1000-2000):"
    read -r port
    info "请选择协议: 1) TCP 2) UDP 3) 同时(TCP+UDP)"
    read -r proto_choice
    case "$proto_choice" in
        1) proto="tcp" ;;
        2) proto="udp" ;;
        3) proto="both" ;;
        *) error "无效选择"; return 1 ;;
    esac
    if [[ $port =~ ^[0-9]+$ ]]; then
        if [ $port -lt 1 ] || [ $port -gt 65535 ]; then error "无效的端口号"; return 1; fi
        if command -v ufw >/dev/null 2>&1; then
            if [ "$proto" = "both" ]; then
                ufw allow "$port/tcp" >/dev/null 2>&1
                r1=$?
                ufw allow "$port/udp" >/dev/null 2>&1
                r2=$?
                if [ $r1 -eq 0 ] && [ $r2 -eq 0 ]; then success "端口 $port 已开放"; else error "端口 $port 开放失败"; return 1; fi
            else
                if ufw allow "$port/$proto"; then success "端口 $port 已开放"; else error "端口 $port 开放失败"; return 1; fi
            fi
        elif command -v firewall-cmd >/dev/null 2>&1; then
            ok=0
            if [ "$proto" = "both" ]; then
                firewall-cmd --permanent --add-port="$port/tcp" && ok=$((ok+1))
                firewall-cmd --permanent --add-port="$port/udp" && ok=$((ok+1))
                if [ $ok -eq 2 ] && firewall-cmd --reload; then success "端口 $port 已开放"; else error "端口 $port 开放失败"; return 1; fi
            else
                if firewall-cmd --permanent --add-port="$port/$proto" && firewall-cmd --reload; then success "端口 $port 已开放"; else error "端口 $port 开放失败"; return 1; fi
            fi
        else
            info "未检测到防火墙管理工具"
            return 1
        fi
    elif [[ $port =~ ^([0-9]+)-([0-9]+)$ ]]; then
        start_port=${BASH_REMATCH[1]}
        end_port=${BASH_REMATCH[2]}
        if [ "$start_port" -lt 1 ] || [ "$end_port" -gt 65535 ] || [ "$start_port" -gt "$end_port" ]; then error "无效的端口范围"; return 1; fi
        if command -v ufw >/dev/null 2>&1; then
            range_spec="${start_port}:${end_port}"
            if [ "$proto" = "both" ]; then
                ufw allow "$range_spec/tcp" >/dev/null 2>&1
                r1=$?
                ufw allow "$range_spec/udp" >/dev/null 2>&1
                r2=$?
                if [ $r1 -eq 0 ] && [ $r2 -eq 0 ]; then success "端口范围 $start_port-$end_port 已开放"; else error "端口范围 $start_port-$end_port 开放失败"; return 1; fi
            else
                if ufw allow "$range_spec/$proto"; then success "端口范围 $start_port-$end_port 已开放"; else error "端口范围 $start_port-$end_port 开放失败"; return 1; fi
            fi
        elif command -v firewall-cmd >/dev/null 2>&1; then
            range_spec="${start_port}-${end_port}"
            if [ "$proto" = "both" ]; then
                ok=0
                firewall-cmd --permanent --add-port="$range_spec/tcp" && ok=$((ok+1))
                firewall-cmd --permanent --add-port="$range_spec/udp" && ok=$((ok+1))
                if [ $ok -eq 2 ] && firewall-cmd --reload; then success "端口范围 $start_port-$end_port 已开放"; else error "端口范围 $start_port-$end_port 开放失败"; return 1; fi
            else
                if firewall-cmd --permanent --add-port="$range_spec/$proto" && firewall-cmd --reload; then success "端口范围 $start_port-$end_port 已开放"; else error "端口范围 $start_port-$end_port 开放失败"; return 1; fi
            fi
        else
            info "未检测到防火墙管理工具"
            return 1
        fi
    else
        error "无效的端口输入"
        return 1
    fi
}

remove_port_rule() {
    info "请输入要关闭的端口号或范围(示例: 80 或 1000-2000):"
    read -r port
    info "请选择协议: 1) TCP 2) UDP 3) 同时(TCP+UDP)"
    read -r proto_choice
    case "$proto_choice" in
        1) proto="tcp" ;;
        2) proto="udp" ;;
        3) proto="both" ;;
        *) error "无效选择"; return 1 ;;
    esac
    if [[ $port =~ ^[0-9]+$ ]]; then
        if [ $port -lt 1 ] || [ $port -gt 65535 ]; then error "无效的端口号"; return 1; fi
        if command -v ufw >/dev/null 2>&1; then
            if [ "$proto" = "both" ]; then
                ufw delete allow "$port/tcp" >/dev/null 2>&1
                r1=$?
                ufw delete allow "$port/udp" >/dev/null 2>&1
                r2=$?
                if [ $r1 -eq 0 ] && [ $r2 -eq 0 ]; then success "端口 $port 已关闭"; else error "端口 $port 关闭失败"; return 1; fi
            else
                if ufw delete allow "$port/$proto" >/dev/null 2>&1; then success "端口 $port 已关闭"; else error "端口 $port 关闭失败"; return 1; fi
            fi
        elif command -v firewall-cmd >/dev/null 2>&1; then
            if [ "$proto" = "both" ]; then
                ok=0
                firewall-cmd --permanent --remove-port="$port/tcp" && ok=$((ok+1))
                firewall-cmd --permanent --remove-port="$port/udp" && ok=$((ok+1))
                if [ $ok -eq 2 ] && firewall-cmd --reload; then success "端口 $port 已关闭"; else error "端口 $port 关闭失败"; return 1; fi
            else
                if firewall-cmd --permanent --remove-port="$port/$proto" && firewall-cmd --reload; then success "端口 $port 已关闭"; else error "端口 $port 关闭失败"; return 1; fi
            fi
        else
            info "未检测到防火墙管理工具"
            return 1
        fi
    elif [[ $port =~ ^([0-9]+)-([0-9]+)$ ]]; then
        start_port=${BASH_REMATCH[1]}
        end_port=${BASH_REMATCH[2]}
        if [ "$start_port" -lt 1 ] || [ "$end_port" -gt 65535 ] || [ "$start_port" -gt "$end_port" ]; then error "无效的端口范围"; return 1; fi
        if command -v ufw >/dev/null 2>&1; then
            range_spec="${start_port}:${end_port}"
            if [ "$proto" = "both" ]; then
                ufw delete allow "$range_spec/tcp" >/dev/null 2>&1
                r1=$?
                ufw delete allow "$range_spec/udp" >/dev/null 2>&1
                r2=$?
                if [ $r1 -eq 0 ] && [ $r2 -eq 0 ]; then success "端口范围 $start_port-$end_port 已关闭"; else error "端口范围 $start_port-$end_port 关闭失败"; return 1; fi
            else
                if ufw delete allow "$range_spec/$proto" >/dev/null 2>&1; then success "端口范围 $start_port-$end_port 已关闭"; else error "端口范围 $start_port-$end_port 关闭失败"; return 1; fi
            fi
        elif command -v firewall-cmd >/dev/null 2>&1; then
            range_spec="${start_port}-${end_port}"
            if [ "$proto" = "both" ]; then
                ok=0
                firewall-cmd --permanent --remove-port="$range_spec/tcp" && ok=$((ok+1))
                firewall-cmd --permanent --remove-port="$range_spec/udp" && ok=$((ok+1))
                if [ $ok -eq 2 ] && firewall-cmd --reload; then success "端口范围 $start_port-$end_port 已关闭"; else error "端口范围 $start_port-$end_port 关闭失败"; return 1; fi
            else
                if firewall-cmd --permanent --remove-port="$range_spec/$proto" && firewall-cmd --reload; then success "端口范围 $start_port-$end_port 已关闭"; else error "端口范围 $start_port-$end_port 关闭失败"; return 1; fi
            fi
        else
            info "未检测到防火墙管理工具"
            return 1
        fi
    else
        error "无效的端口输入"
        return 1
    fi
}

show_network_info() {
    title "网络信息"
    if command -v ip >/dev/null 2>&1; then
        info "网卡与地址"
        ip -brief addr show
    elif command -v ifconfig >/dev/null 2>&1; then
        info "网卡与地址"
        ifconfig -a
    else
        info "主机地址"
        hostname -I 2>/dev/null || true
    fi
    if command -v ip >/dev/null 2>&1; then
        local def
        def=$(ip route show default 2>/dev/null | head -n1)
        if [ -n "$def" ]; then info "默认路由: $def"; else info "未找到默认路由"; fi
    elif command -v route >/dev/null 2>&1; then
        local def
        def=$(route -n 2>/dev/null | awk '$1=="0.0.0.0"{print; exit}')
        if [ -n "$def" ]; then info "默认路由: $def"; else info "未找到默认路由"; fi
    else
        info "未找到路由工具"
    fi
}

speed_test() {
    if ! command -v speedtest-cli >/dev/null 2>&1; then
        info "正在安装 speedtest-cli..."
        if [ "$OS" = "debian" ]; then
            apt update && apt install -y speedtest-cli || { error "speedtest-cli 安装失败"; return 1; }
        elif [ "$OS" = "centos" ]; then
            yum install -y epel-release && yum install -y speedtest-cli || { error "speedtest-cli 安装失败"; return 1; }
        elif [ "$OS" = "arch" ]; then
            pacman -Sy --noconfirm speedtest-cli || { error "speedtest-cli 安装失败"; return 1; }
        fi
    fi
    if command -v speedtest-cli >/dev/null 2>&1; then
        info "正在进行网络速度测试..."
        speedtest-cli
    else
        error "speedtest-cli 安装失败"
    fi
}

ssh_logs() {
    local log_file=""
    if [ -f /var/log/auth.log ]; then
        log_file=/var/log/auth.log
    elif [ -f /var/log/secure ]; then
        log_file=/var/log/secure
    else
        info "未找到SSH日志文件"
        return 1
    fi
    tail -n 200 "$log_file"
}

enable_bbr() {
    info "正在启用 BBR 加速..."
    local backup="/etc/sysctl.conf.bak.$(date +%s)"
    cp /etc/sysctl.conf "$backup" 2>/dev/null
    if grep -q '^net.core.default_qdisc=' /etc/sysctl.conf; then
        sed -i 's|^net.core.default_qdisc=.*|net.core.default_qdisc=fq|' /etc/sysctl.conf
    else
        echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
    fi
    if grep -q '^net.ipv4.tcp_congestion_control=' /etc/sysctl.conf; then
        sed -i 's|^net.ipv4.tcp_congestion_control=.*|net.ipv4.tcp_congestion_control=bbr|' /etc/sysctl.conf
    else
        echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
    fi
    if ! sysctl -p; then
        error "应用内核参数失败，回滚配置"
        [ -f "$backup" ] && cp "$backup" /etc/sysctl.conf && sysctl -p
        return 1
    fi
    success "BBR 加速已启用"
}

disable_bbr() {
    info "正在禁用 BBR 加速..."
    sed -i '/^net.core.default_qdisc=fq$/d' /etc/sysctl.conf
    sed -i '/^net.ipv4.tcp_congestion_control=bbr$/d' /etc/sysctl.conf
    if ! sysctl -p; then
        error "应用内核参数失败"
        return 1
    fi
    success "BBR 加速已禁用"
}

check_bbr() {
    if sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
        info "BBR 加速已启用"
    else
        info "BBR 加速未启用"
    fi
}

show_ports() {
    title "端口占用情况"
    if command -v ss >/dev/null 2>&1; then
        ss -tulpn | grep LISTEN || true
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tulpn | grep LISTEN || true
    else
        info "未找到网络工具"
        return 1
    fi
}

kill_port() {
    info "请输入要终止的端口号:"
    read -r port
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
        if command -v lsof >/dev/null 2>&1; then
            pid=$(lsof -ti:"$port" 2>/dev/null)
            if [ -n "$pid" ]; then
                if kill -9 $pid 2>/dev/null; then
                    success "端口 $port 上的进程已终止"
                else
                    error "终止失败"
                    return 1
                fi
            else
                info "端口 $port 未被占用"
            fi
        elif command -v fuser >/dev/null 2>&1; then
            if fuser -k "${port}/tcp" 2>/dev/null || fuser -k "${port}/udp" 2>/dev/null; then
                success "已尝试终止端口 $port 的相关进程"
            else
                info "未找到占用该端口的进程"
            fi
        else
            info "缺少 lsof/fuser 工具，无法终止端口进程"
            return 1
        fi
    else
        error "无效的端口号"
        return 1
    fi
}

clean_system() {
    info "正在清理系统垃圾文件..."
    if [ "$OS" = "debian" ]; then
        apt autoremove -y >/dev/null 2>&1 || true
        apt autoclean >/dev/null 2>&1 || true
        apt clean >/dev/null 2>&1 || true
    elif [ "$OS" = "centos" ]; then
        if command -v yum >/dev/null 2>&1; then
            yum autoremove -y >/dev/null 2>&1 || true
            yum clean all >/dev/null 2>&1 || true
        elif command -v dnf >/dev/null 2>&1; then
            dnf autoremove -y >/dev/null 2>&1 || true
            dnf clean all >/dev/null 2>&1 || true
        fi
    elif [ "$OS" = "arch" ]; then
        pacman -Sc --noconfirm >/dev/null 2>&1 || true
    fi
    rm -rf /tmp/* 2>/dev/null || true
    rm -rf /var/tmp/* 2>/dev/null || true
    find /var/log -name "*.log" -type f -mtime +30 -delete 2>/dev/null || true
    success "系统清理完成"
}

show_users() {
    title "系统用户列表"
    cut -d: -f1 /etc/passwd | sort
}

create_user() {
    info "请输入新用户名:"
    read -r username
    if [ -z "$username" ]; then
        error "用户名不能为空"
        return 1
    fi
    if ! [[ $username =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        error "用户名不合法"
        return 1
    fi
    if id -u "$username" >/dev/null 2>&1; then
        error "用户 $username 已存在"
        return 1
    fi
    if useradd -m -s /bin/bash "$username"; then
        info "请设置用户密码:"
        passwd "$username"
        success "用户 $username 创建成功"
    else
        error "用户创建失败"
        return 1
    fi
}

delete_user() {
    info "请输入要删除的用户名:"
    read -r username
    if [ -z "$username" ]; then
        error "用户名不能为空"
        return 1
    fi
    if [ "$username" = "root" ]; then
        error "禁止删除root用户"
        return 1
    fi
    if ! id -u "$username" >/dev/null 2>&1; then
        error "用户 $username 不存在"
        return 1
    fi
    info "确定要删除用户 $username 吗？(y/N)"
    read -r confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        if userdel -r "$username"; then
            success "用户 $username 已删除"
        else
            error "删除失败"
            return 1
        fi
    else
        warn "取消删除"
    fi
}

add_sudo() {
    info "请输入要添加到sudo组的用户名:"
    read -r username
    if [ -z "$username" ]; then
        error "用户名不能为空"
        return 1
    fi
    if ! id -u "$username" >/dev/null 2>&1; then
        error "用户 $username 不存在"
        return 1
    fi
    if getent group sudo >/dev/null 2>&1; then
        if usermod -aG sudo "$username"; then
            success "用户 $username 已添加到sudo组"
        else
            error "操作失败"
            return 1
        fi
    elif getent group wheel >/dev/null 2>&1; then
        if usermod -aG wheel "$username"; then
            success "用户 $username 已添加到wheel组(具备sudo权限)"
        else
            error "操作失败"
            return 1
        fi
    else
        info "系统未找到sudo或wheel组"
        return 1
    fi
}

change_source() {
    if [ "$OS" != "debian" ] && [ "$OS" != "centos" ]; then
        info "此功能仅支持Debian/Ubuntu/CentOS系统"
        return 1
    fi
    echo "请选择软件源:"
    echo "1. 阿里云"
    echo "2. 腾讯云"
    echo "3. 中科大"
    echo "4. 谷歌"
    echo "5. Azure"
    echo "6. AWS"
    echo "7. 官方源"
    read -r choice
    if [ "$OS" = "debian" ]; then
        [ -f /etc/os-release ] && . /etc/os-release
        local id_l=${ID:-debian}
        local backup="/etc/apt/sources.list.bak.$(date +%s)"
        cp /etc/apt/sources.list "$backup" 2>/dev/null
        if [ "$id_l" = "ubuntu" ]; then
            case $choice in
                1) main_mirror="http://mirrors.aliyun.com" ; sec_mirror="http://mirrors.aliyun.com" ;;
                2) main_mirror="http://mirrors.cloud.tencent.com" ; sec_mirror="http://mirrors.cloud.tencent.com" ;;
                3) main_mirror="http://mirrors.ustc.edu.cn" ; sec_mirror="http://mirrors.ustc.edu.cn" ;;
                4) main_mirror="http://archive.ubuntu.com" ; sec_mirror="http://security.ubuntu.com" ;;
                5) main_mirror="http://azure.archive.ubuntu.com" ; sec_mirror="http://azure.archive.ubuntu.com" ;;
                6) main_mirror="http://us-east-1.ec2.archive.ubuntu.com" ; sec_mirror="http://us-east-1.ec2.archive.ubuntu.com" ;;
                7) main_mirror="http://archive.ubuntu.com" ; sec_mirror="http://security.ubuntu.com" ;;
                *) error "无效选择"; return 1 ;;
            esac
            sed -ri "s|https?://[^ ]*archive\.ubuntu\.com|$main_mirror|g" /etc/apt/sources.list
            sed -ri "s|https?://[^ ]*security\.ubuntu\.com|$sec_mirror|g" /etc/apt/sources.list
        else
            case $choice in
                1) main_mirror="http://mirrors.aliyun.com/debian" ; sec_mirror="http://mirrors.aliyun.com/debian-security" ;;
                2) main_mirror="http://mirrors.cloud.tencent.com/debian" ; sec_mirror="http://mirrors.cloud.tencent.com/debian-security" ;;
                3) main_mirror="http://mirrors.ustc.edu.cn/debian" ; sec_mirror="http://mirrors.ustc.edu.cn/debian-security" ;;
                4|5|6) main_mirror="http://deb.debian.org/debian" ; sec_mirror="http://security.debian.org/debian-security" ;;
                7) main_mirror="http://deb.debian.org/debian" ; sec_mirror="http://security.debian.org/debian-security" ;;
                *) error "无效选择"; return 1 ;;
            esac
            sed -ri "s|https?://[^ ]*deb\.debian\.org/debian|$main_mirror|g" /etc/apt/sources.list
            sed -ri "s|https?://[^ ]*security\.debian\.org/debian-security|$sec_mirror|g" /etc/apt/sources.list
        fi
        if ! apt update; then
            warn "更新索引失败，回滚软件源"
            [ -f "$backup" ] && cp "$backup" /etc/apt/sources.list && apt update
        else
            success "软件源更新完成"
        fi
    elif [ "$OS" = "centos" ]; then
        local ts=$(date +%s)
        local repo_dir="/etc/yum.repos.d"
        local backup_dir="${repo_dir}.bak.$ts"
        cp -r "$repo_dir" "$backup_dir" 2>/dev/null
        case $choice in
            1) domain="mirrors.aliyun.com" ;;
            2) domain="mirrors.cloud.tencent.com" ;;
            3) domain="mirrors.ustc.edu.cn" ;;
            4|5|6|7) domain="mirror.centos.org" ;;
            *) error "无效选择"; return 1 ;;
        esac
        for f in "$repo_dir"/*.repo; do
            [ -f "$f" ] || continue
            sed -i 's/^mirrorlist=/#mirrorlist=/' "$f"
            sed -i 's/^#baseurl=/baseurl=/' "$f"
            sed -ri "s|^(baseurl=.*://)[^/]+|\1$domain|g" "$f"
        done
        if ! yum makecache -y; then
            warn "生成缓存失败，回滚软件源"
            rm -rf "$repo_dir" && cp -r "$backup_dir" "$repo_dir" && yum makecache -y
        else
            success "软件源更新完成"
        fi
    fi
}

install_bt_panel() {
    echo "请选择宝塔面板版本:"
    echo "1. LTS 稳定版"
    echo "2. 最新正式版"
    echo "3. 开发版"
    read -r choice
    case $choice in
        1)
            echo "确定安装宝塔面板 LTS 稳定版吗？(y/N)"
            read -r confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                info "正在安装宝塔面板 LTS 稳定版..."
                exec bash -lc 'set -euo pipefail; (curl -fsSL https://download.bt.cn/install/install_lts.sh || wget -qO- https://download.bt.cn/install/install_lts.sh) | bash'
            fi
            ;;
        2)
            echo "确定安装宝塔面板最新正式版吗？(y/N)"
            read -r confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                info "正在安装宝塔面板最新正式版..."
                exec bash -lc 'set -euo pipefail; (curl -fsSL https://download.bt.cn/install/install_panel.sh || wget -qO- https://download.bt.cn/install/install_panel.sh) | bash -s ed8484bec'
            fi
            ;;
        3)
            echo "确定安装宝塔面板开发版吗？(y/N)"
            read -r confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                info "正在安装宝塔面板开发版..."
                exec bash -lc 'set -euo pipefail; (curl -fsSL https://download.bt.cn/install/install_panel.sh || wget -qO- https://download.bt.cn/install/install_panel.sh) | bash'
            fi
            ;;
        *)
            error "无效选择"
            ;;
    esac
}

install_1panel() {
    echo "请选择1Panel版本:"
    echo "1. 国内版"
    echo "2. 国际版"
    read -r choice
    case $choice in
        1)
            echo "确定安装1Panel国内版吗？(y/N)"
            read -r confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                info "正在安装1Panel国内版..."
                exec bash -lc 'set -euo pipefail; (curl -fsSL https://resource.fit2cloud.com/1panel/package/quick_start.sh || wget -qO- https://resource.fit2cloud.com/1panel/package/quick_start.sh) | bash'
            fi
            ;;
        2)
            echo "确定安装1Panel国际版吗？(y/N)"
            read -r confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                info "正在安装1Panel国际版..."
                exec bash -lc 'set -euo pipefail; (curl -fsSL https://resource.1panel.pro/quick_start.sh || wget -qO- https://resource.1panel.pro/quick_start.sh) | bash'
            fi
            ;;
        *)
            error "无效选择"
            ;;
    esac
}

install_singbox() {
    echo "确定安装sing-box-yg代理工具吗？(y/N)"
    read -r confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        info "正在安装sing-box-yg代理工具..."
        exec bash -lc 'set -euo pipefail; (curl -fsSL https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh || wget -qO- https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh) | bash'
    fi
}

firewall_menu() {
    while true; do
        clear
        hr
        title "防火墙管理"
        hr
        option "1. 查看防火墙状态"
        option "2. 启用防火墙"
        option "3. 禁用防火墙"
        option "4. 添加端口规则"
        option "5. 删除端口规则"
        option "0. 返回上级菜单"
        prompt "请选择: "
        read -r choice
        case $choice in
            1) firewall_status ;;
            2) enable_firewall ;;
            3) disable_firewall ;;
            4) add_port_rule ;;
            5) remove_port_rule ;;
            0) break ;;
            *) error "无效选择"; prompt "按回车继续..."; read -r _ ;;
        esac
    done
}

network_menu() {
    while true; do
        clear
        hr
        title "网络管理"
        hr
        option "1. 查看网络信息"
        option "2. 防火墙管理"
        option "3. 网络速度测试"
        option "4. SSH登录日志"
        option "5. BBR加速管理"
        option "6. 端口管理"
        option "0. 返回上级菜单"
        prompt "请选择: "
        read -r choice
        case $choice in
            1) show_network_info ;;
            2) firewall_menu ;;
            3) speed_test ;;
            4) ssh_logs ;;
            5) bbr_menu ;;
            6) port_menu ;;
            0) break ;;
            *) error "无效选择"; prompt "按回车继续..."; read -r _ ;;
        esac
    done
}

bbr_menu() {
    while true; do
        clear
        hr
        title "BBR加速管理"
        hr
        option "1. 查看BBR状态"
        option "2. 启用BBR加速"
        option "3. 禁用BBR加速"
        option "0. 返回上级菜单"
        prompt "请选择: "
        read -r choice
        case $choice in
            1) check_bbr ;;
            2) enable_bbr ;;
            3) disable_bbr ;;
            0) break ;;
            *) error "无效选择"; prompt "按回车继续..."; read -r _ ;;
        esac
    done
}

port_menu() {
    while true; do
        clear
        hr
        title "端口管理"
        hr
        option "1. 查看端口占用"
        option "2. 终止端口进程"
        option "0. 返回上级菜单"
        prompt "请选择: "
        read -r choice
        case $choice in
            1) show_ports ;;
            2) kill_port ;;
            0) break ;;
            *) error "无效选择"; prompt "按回车继续..."; read -r _ ;;
        esac
    done
}

user_menu() {
    while true; do
        clear
        hr
        title "用户管理"
        hr
        option "1. 查看所有用户"
        option "2. 创建用户"
        option "3. 删除用户"
        option "4. 添加用户到sudo组"
        option "0. 返回上级菜单"
        prompt "请选择: "
        read -r choice
        case $choice in
            1) show_users ;;
            2) create_user ;;
            3) delete_user ;;
            4) add_sudo ;;
            0) break ;;
            *) error "无效选择"; prompt "按回车继续..."; read -r _ ;;
        esac
    done
}

system_menu() {
    while true; do
        clear
        hr
        title "系统管理"
        hr
        option "1. 网络管理"
        option "2. 系统清理"
        option "3. 用户管理"
        option "4. 软件源管理"
        option "0. 返回主菜单"
        prompt "请选择: "
        read -r choice
        case $choice in
            1) network_menu ;;
            2) clean_system ;;
            3) user_menu ;;
            4) change_source ;;
            0) break ;;
            *) error "无效选择"; prompt "按回车继续..."; read -r _ ;;
        esac
    done
}

third_party_menu() {
    while true; do
        clear
        hr
        title "第三方工具安装"
        hr
        option "1. 宝塔面板"
        option "2. 1Panel"
        option "3. sing-box-yg代理工具"
        option "0. 返回主菜单"
        prompt "请选择: "
        read -r choice
        case $choice in
            1) install_bt_panel ;;
            2) install_1panel ;;
            3) install_singbox ;;
            0) break ;;
            *) error "无效选择"; prompt "按回车继续..."; read -r _ ;;
        esac
    done
}

self_manage_menu() {
    while true; do
        clear
        hr
        title "工具箱管理"
        hr
        option "1. 安装/更新工具箱"
        option "2. 卸载工具箱"
        option "3. 查看版本"
        option "0. 返回主菜单"
        prompt "请选择: "
        read -r choice
        case $choice in
            1) install_tool ;;
            2) uninstall_tool ;;
            3) show_version ;;
            0) break ;;
            *) error "无效选择"; prompt "按回车继续..."; read -r _ ;;
        esac
    done
}

main_menu() {
    while true; do
        clear
        hr
        title "Linux 工具箱 v$VERSION"
        hr
        option "1. 工具箱管理"
        option "2. 系统管理"
        option "3. 第三方工具安装"
        option "0. 退出"
        hr
        prompt "请选择功能: "
        read -r choice
        case $choice in
            1) self_manage_menu ;;
            2) system_menu ;;
            3) third_party_menu ;;
            0) success "感谢使用！"; exit 0 ;;
            *) error "无效选择，请重新输入"; prompt "按回车继续..."; read -r _ ;;
        esac
    done
}

check_root
check_system
main_menu