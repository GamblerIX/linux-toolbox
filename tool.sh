#!/bin/bash

VERSION="1.0.0"
GITHUB_URL="https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main"
GITEE_URL="https://gitee.com/GamblerIX/linux-toolbox/raw/main"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "请使用root权限运行此脚本"
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
        echo "不支持的操作系统"
        exit 1
    fi
}

test_speed() {
    local url=$1
    local time=$(curl -o /dev/null -s -w "%{time_total}" --connect-timeout 3 "$url/VERSION" 2>/dev/null || echo "999")
    echo $time
}

get_fastest_source() {
    echo "正在测试源速度..."
    github_time=$(test_speed $GITHUB_URL)
    gitee_time=$(test_speed $GITEE_URL)
    if awk "BEGIN{exit !($github_time < $gitee_time)}"; then
        echo $GITHUB_URL
    else
        echo $GITEE_URL
    fi
}

install_tool() {
    echo "开始安装/更新工具箱..."
    fastest_source=$(get_fastest_source)
    echo "使用源: $fastest_source"
    tmp_file=$(mktemp) || { echo "创建临时文件失败"; exit 1; }
    trap 'rm -f "$tmp_file"' RETURN
    if ! curl -fsSL "$fastest_source/tool.sh" -o "$tmp_file"; then
        echo "下载失败，请检查网络连接"
        exit 1
    fi
    if [ ! -s "$tmp_file" ]; then
        echo "下载文件为空或失败"
        exit 1
    fi
    if ! mv "$tmp_file" /usr/local/bin/tool; then
        echo "移动文件失败"
        exit 1
    fi
    if ! chmod +x /usr/local/bin/tool; then
        echo "设置可执行权限失败"
        exit 1
    fi
    echo "工具箱安装/更新完成！"
    echo "启动命令: tool"
    exit 0
}

update_tool() {
    echo "正在更新工具箱..."
    install_tool
}

uninstall_tool() {
    echo "确定要卸载工具箱吗？(y/N)"
    read -r confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        rm -f /usr/local/bin/tool
        echo "工具箱已卸载"
    else
        echo "取消卸载"
    fi
}

show_version() {
    echo "Linux工具箱 v$VERSION"
}

firewall_status() {
    if command -v ufw >/dev/null 2>&1; then
        ufw status
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --state
    else
        echo "未检测到防火墙管理工具"
    fi
}

enable_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        ufw --force enable
        echo "防火墙已启用"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        systemctl enable firewalld
        systemctl start firewalld
        echo "防火墙已启用"
    else
        echo "未检测到防火墙管理工具"
    fi
}

disable_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        ufw --force disable
        echo "防火墙已禁用"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        systemctl stop firewalld
        systemctl disable firewalld
        echo "防火墙已禁用"
    else
        echo "未检测到防火墙管理工具"
    fi
}

add_port_rule() {
    echo "请输入要开放的端口号:"
    read -r port
    echo "请选择协议: 1) TCP 2) UDP 3) 同时(TCP+UDP)"
    read -r proto_choice
    case "$proto_choice" in
        1) proto="tcp" ;;
        2) proto="udp" ;;
        3) proto="both" ;;
        *) echo "无效选择"; return ;;
    esac
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
        if command -v ufw >/dev/null 2>&1; then
            if [ "$proto" = "both" ]; then
                ufw allow "$port/tcp" && ufw allow "$port/udp"
            else
                ufw allow "$port/$proto"
            fi
            echo "端口 $port 已开放"
        elif command -v firewall-cmd >/dev/null 2>&1; then
            if [ "$proto" = "both" ]; then
                firewall-cmd --permanent --add-port="$port/tcp"
                firewall-cmd --permanent --add-port="$port/udp"
            else
                firewall-cmd --permanent --add-port="$port/$proto"
            fi
            firewall-cmd --reload
            echo "端口 $port 已开放"
        else
            echo "未检测到防火墙管理工具"
        fi
    else
        echo "无效的端口号"
    fi
}

remove_port_rule() {
    echo "请输入要关闭的端口号:"
    read -r port
    echo "请选择协议: 1) TCP 2) UDP 3) 同时(TCP+UDP)"
    read -r proto_choice
    case "$proto_choice" in
        1) proto="tcp" ;;
        2) proto="udp" ;;
        3) proto="both" ;;
        *) echo "无效选择"; return ;;
    esac
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
        if command -v ufw >/dev/null 2>&1; then
            if [ "$proto" = "both" ]; then
                ufw delete allow "$port/tcp" && ufw delete allow "$port/udp"
            else
                ufw delete allow "$port/$proto"
            fi
            echo "端口 $port 已关闭"
        elif command -v firewall-cmd >/dev/null 2>&1; then
            if [ "$proto" = "both" ]; then
                firewall-cmd --permanent --remove-port="$port/tcp"
                firewall-cmd --permanent --remove-port="$port/udp"
            else
                firewall-cmd --permanent --remove-port="$port/$proto"
            fi
            firewall-cmd --reload
            echo "端口 $port 已关闭"
        else
            echo "未检测到防火墙管理工具"
        fi
    else
        echo "无效的端口号"
    fi
}

speed_test() {
    if ! command -v speedtest-cli >/dev/null 2>&1; then
        echo "正在安装 speedtest-cli..."
        if [ "$OS" = "debian" ]; then
            apt update && apt install -y speedtest-cli || { echo "speedtest-cli 安装失败"; return 1; }
        elif [ "$OS" = "centos" ]; then
            yum install -y epel-release && yum install -y speedtest-cli || { echo "speedtest-cli 安装失败"; return 1; }
        elif [ "$OS" = "arch" ]; then
            pacman -Sy --noconfirm speedtest-cli || { echo "speedtest-cli 安装失败"; return 1; }
        fi
    fi
    if command -v speedtest-cli >/dev/null 2>&1; then
        echo "正在进行网络速度测试..."
        speedtest-cli
    else
        echo "speedtest-cli 安装失败"
    fi
}

ssh_logs() {
    local log_file=""
    if [ -f /var/log/auth.log ]; then
        log_file=/var/log/auth.log
    elif [ -f /var/log/secure ]; then
        log_file=/var/log/secure
    else
        echo "未找到SSH日志文件"
        return
    fi
    echo "=== SSH 登录成功记录 ==="
    grep "Accepted" "$log_file" 2>/dev/null | tail -20
    echo ""
    echo "=== SSH 登录失败记录 ==="
    grep "Failed" "$log_file" 2>/dev/null | tail -20
}

enable_bbr() {
    echo "正在启用 BBR 加速..."
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
        echo "应用内核参数失败，回滚配置"
        [ -f "$backup" ] && cp "$backup" /etc/sysctl.conf && sysctl -p
        return 1
    fi
    echo "BBR 加速已启用"
}

disable_bbr() {
    echo "正在禁用 BBR 加速..."
    sed -i '/^net.core.default_qdisc=fq$/d' /etc/sysctl.conf
    sed -i '/^net.ipv4.tcp_congestion_control=bbr$/d' /etc/sysctl.conf
    if ! sysctl -p; then
        echo "应用内核参数失败"
        return 1
    fi
    echo "BBR 加速已禁用"
}

check_bbr() {
    if sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
        echo "BBR 加速已启用"
    else
        echo "BBR 加速未启用"
    fi
}

show_ports() {
    echo "=== 端口占用情况 ==="
    if command -v ss >/dev/null 2>&1; then
        ss -tulpn | grep LISTEN || true
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tulpn | grep LISTEN || true
    else
        echo "未找到网络工具"
    fi
}

kill_port() {
    echo "请输入要终止的端口号:"
    read -r port
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
        if command -v lsof >/dev/null 2>&1; then
            pid=$(lsof -ti:"$port")
            if [ -n "$pid" ]; then
                kill -9 $pid && echo "端口 $port 上的进程已终止" || echo "终止失败"
            else
                echo "端口 $port 未被占用"
            fi
        elif command -v fuser >/dev/null 2>&1; then
            fuser -k "${port}/tcp" 2>/dev/null || fuser -k "${port}/udp" 2>/dev/null || echo "未找到占用该端口的进程"
        else
            echo "缺少 lsof/fuser 工具，无法终止端口进程"
        fi
    else
        echo "无效的端口号"
    fi
}

clean_system() {
    echo "正在清理系统垃圾文件..."
    if [ "$OS" = "debian" ]; then
        apt autoremove -y
        apt autoclean
        apt clean
    elif [ "$OS" = "centos" ]; then
        yum autoremove -y
        yum clean all
    fi
    
    rm -rf /tmp/*
    rm -rf /var/tmp/*
    find /var/log -name "*.log" -type f -mtime +30 -delete
    echo "系统清理完成"
}

show_users() {
    echo "=== 系统用户列表 ==="
    cut -d: -f1 /etc/passwd | sort
}

create_user() {
    echo "请输入新用户名:"
    read -r username
    if [ -z "$username" ]; then
        echo "用户名不能为空"
        return
    fi
    if ! [[ $username =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        echo "用户名不合法"
        return
    fi
    if id -u "$username" >/dev/null 2>&1; then
        echo "用户 $username 已存在"
        return
    fi
    if useradd -m -s /bin/bash "$username"; then
        echo "请设置用户密码:"
        passwd "$username"
        echo "用户 $username 创建成功"
    else
        echo "用户创建失败"
    fi
}

delete_user() {
    echo "请输入要删除的用户名:"
    read -r username
    if [ -z "$username" ]; then
        echo "用户名不能为空"
        return
    fi
    if [ "$username" = "root" ]; then
        echo "禁止删除root用户"
        return
    fi
    if ! id -u "$username" >/dev/null 2>&1; then
        echo "用户 $username 不存在"
        return
    fi
    echo "确定要删除用户 $username 吗？(y/N)"
    read -r confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        if userdel -r "$username"; then
            echo "用户 $username 已删除"
        else
            echo "删除失败"
        fi
    else
        echo "取消删除"
    fi
}

add_sudo() {
    echo "请输入要添加到sudo组的用户名:"
    read -r username
    if [ -z "$username" ]; then
        echo "用户名不能为空"
        return
    fi
    if ! id -u "$username" >/dev/null 2>&1; then
        echo "用户 $username 不存在"
        return
    fi
    if getent group sudo >/dev/null 2>&1; then
        usermod -aG sudo "$username" && echo "用户 $username 已添加到sudo组" || echo "操作失败"
    elif getent group wheel >/dev/null 2>&1; then
        usermod -aG wheel "$username" && echo "用户 $username 已添加到wheel组(具备sudo权限)" || echo "操作失败"
    else
        echo "系统未找到sudo或wheel组"
    fi
}

change_source() {
    if [ "$OS" != "debian" ] && [ "$OS" != "centos" ]; then
        echo "此功能仅支持Debian/Ubuntu/CentOS系统"
        return
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
                *) echo "无效选择"; return ;;
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
                *) echo "无效选择"; return ;;
            esac
            sed -ri "s|https?://[^ ]*deb\.debian\.org/debian|$main_mirror|g" /etc/apt/sources.list
            sed -ri "s|https?://[^ ]*security\.debian\.org/debian-security|$sec_mirror|g" /etc/apt/sources.list
        fi
        if ! apt update; then
            echo "更新索引失败，回滚软件源"
            [ -f "$backup" ] && cp "$backup" /etc/apt/sources.list && apt update
        else
            echo "软件源更新完成"
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
            *) echo "无效选择"; return ;;
        esac
        for f in "$repo_dir"/*.repo; do
            [ -f "$f" ] || continue
            sed -i 's/^mirrorlist=/#mirrorlist=/' "$f"
            sed -i 's/^#baseurl=/baseurl=/' "$f"
            sed -ri "s|^(baseurl=.*://)[^/]+|\1$domain|g" "$f"
        done
        if ! yum makecache -y; then
            echo "生成缓存失败，回滚软件源"
            rm -rf "$repo_dir" && cp -r "$backup_dir" "$repo_dir" && yum makecache -y
        else
            echo "软件源更新完成"
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
                echo "正在安装宝塔面板 LTS 稳定版..."
                bash <(curl -sSL https://download.bt.cn/install/install_lts.sh)
                echo "安装脚本执行完成"
            fi
            ;;
        2)
            echo "确定安装宝塔面板最新正式版吗？(y/N)"
            read -r confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                echo "正在安装宝塔面板最新正式版..."
                tmp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t btinst) || { echo "临时目录创建失败"; return 1; }
                script="$tmp_dir/install_panel.sh"
                if command -v curl >/dev/null 2>&1; then
                    if ! curl -sSLo "$script" https://download.bt.cn/install/install_panel.sh; then
                        echo "下载脚本失败"
                        rm -rf "$tmp_dir"
                        return 1
                    fi
                elif command -v wget >/dev/null 2>&1; then
                    if ! wget -O "$script" https://download.bt.cn/install/install_panel.sh; then
                        echo "下载脚本失败"
                        rm -rf "$tmp_dir"
                        return 1
                    fi
                else
                    echo "未检测到curl或wget，无法下载"
                    rm -rf "$tmp_dir"
                    return 1
                fi
                if [ ! -s "$script" ]; then
                    echo "下载的脚本为空或不存在"
                    rm -rf "$tmp_dir"
                    return 1
                fi
                chmod +x "$script" || true
                if bash "$script" ed8484bec; then
                    echo "安装脚本执行完成"
                else
                    echo "安装脚本执行失败"
                    rm -rf "$tmp_dir"
                    return 1
                fi
                rm -rf "$tmp_dir"
            fi
            ;;
        3)
            echo "确定安装宝塔面板开发版吗？(y/N)"
            read -r confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                echo "正在安装宝塔面板开发版..."
                bash <(curl -sSL https://download.bt.cn/install/install_panel.sh)
                echo "安装脚本执行完成"
            fi
            ;;
        *)
            echo "无效选择"
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
                echo "正在安装1Panel国内版..."
                bash <(curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh)
                echo "安装脚本执行完成"
            fi
            ;;
        2)
            echo "确定安装1Panel国际版吗？(y/N)"
            read -r confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                echo "正在安装1Panel国际版..."
                bash <(curl -sSL https://resource.1panel.pro/quick_start.sh)
                echo "安装脚本执行完成"
            fi
            ;;
        *)
            echo "无效选择"
            ;;
    esac
}

install_singbox() {
    echo "确定安装sing-box-yg代理工具吗？(y/N)"
    read -r confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo "正在安装sing-box-yg代理工具..."
        bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
        echo "安装脚本执行完成"
    fi
}

firewall_menu() {
    while true; do
        echo ""
        echo "=== 防火墙管理 ==="
        echo "1. 查看防火墙状态"
        echo "2. 启用防火墙"
        echo "3. 禁用防火墙"
        echo "4. 添加端口规则"
        echo "5. 删除端口规则"
        echo "0. 返回上级菜单"
        echo -n "请选择: "
        read -r choice
        
        case $choice in
            1) firewall_status ;;
            2) enable_firewall ;;
            3) disable_firewall ;;
            4) add_port_rule ;;
            5) remove_port_rule ;;
            0) break ;;
            *) echo "无效选择" ;;
        esac
    done
}

network_menu() {
    while true; do
        echo ""
        echo "=== 网络管理 ==="
        echo "1. 防火墙管理"
        echo "2. 网络速度测试"
        echo "3. SSH登录日志"
        echo "4. BBR加速管理"
        echo "5. 端口管理"
        echo "0. 返回上级菜单"
        echo -n "请选择: "
        read -r choice
        
        case $choice in
            1) firewall_menu ;;
            2) speed_test ;;
            3) ssh_logs ;;
            4) bbr_menu ;;
            5) port_menu ;;
            0) break ;;
            *) echo "无效选择" ;;
        esac
    done
}

bbr_menu() {
    while true; do
        echo ""
        echo "=== BBR加速管理 ==="
        echo "1. 查看BBR状态"
        echo "2. 启用BBR加速"
        echo "3. 禁用BBR加速"
        echo "0. 返回上级菜单"
        echo -n "请选择: "
        read -r choice
        
        case $choice in
            1) check_bbr ;;
            2) enable_bbr ;;
            3) disable_bbr ;;
            0) break ;;
            *) echo "无效选择" ;;
        esac
    done
}

port_menu() {
    while true; do
        echo ""
        echo "=== 端口管理 ==="
        echo "1. 查看端口占用"
        echo "2. 终止端口进程"
        echo "0. 返回上级菜单"
        echo -n "请选择: "
        read -r choice
        
        case $choice in
            1) show_ports ;;
            2) kill_port ;;
            0) break ;;
            *) echo "无效选择" ;;
        esac
    done
}

user_menu() {
    while true; do
        echo ""
        echo "=== 用户管理 ==="
        echo "1. 查看所有用户"
        echo "2. 创建用户"
        echo "3. 删除用户"
        echo "4. 添加用户到sudo组"
        echo "0. 返回上级菜单"
        echo -n "请选择: "
        read -r choice
        
        case $choice in
            1) show_users ;;
            2) create_user ;;
            3) delete_user ;;
            4) add_sudo ;;
            0) break ;;
            *) echo "无效选择" ;;
        esac
    done
}

system_menu() {
    while true; do
        echo ""
        echo "=== 系统管理 ==="
        echo "1. 网络管理"
        echo "2. 系统清理"
        echo "3. 用户管理"
        echo "4. 软件源管理"
        echo "0. 返回主菜单"
        echo -n "请选择: "
        read -r choice
        
        case $choice in
            1) network_menu ;;
            2) clean_system ;;
            3) user_menu ;;
            4) change_source ;;
            0) break ;;
            *) echo "无效选择" ;;
        esac
    done
}

third_party_menu() {
    while true; do
        echo ""
        echo "=== 第三方工具安装 ==="
        echo "1. 宝塔面板"
        echo "2. 1Panel"
        echo "3. sing-box-yg代理工具"
        echo "0. 返回主菜单"
        echo -n "请选择: "
        read -r choice
        
        case $choice in
            1) install_bt_panel ;;
            2) install_1panel ;;
            3) install_singbox ;;
            0) break ;;
            *) echo "无效选择" ;;
        esac
    done
}

self_manage_menu() {
    while true; do
        echo ""
        echo "=== 工具箱管理 ==="
        echo "1. 更新工具箱"
        echo "2. 卸载工具箱"
        echo "3. 查看版本"
        echo "0. 返回主菜单"
        echo -n "请选择: "
        read -r choice
        
        case $choice in
            1) update_tool ;;
            2) uninstall_tool ;;
            3) show_version ;;
            0) break ;;
            *) echo "无效选择" ;;
        esac
    done
}

main_menu() {
    while true; do
        clear
        echo "=========================================="
        echo "           Linux 工具箱 v$VERSION"
        echo "=========================================="
        echo "1. 安装/更新工具箱"
        echo "2. 工具箱管理"
        echo "3. 系统管理"
        echo "4. 第三方工具安装"
        echo "0. 退出"
        echo "=========================================="
        echo -n "请选择功能: "
        read -r choice
        
        case $choice in
            1) install_tool ;;
            2) self_manage_menu ;;
            3) system_menu ;;
            4) third_party_menu ;;
            0) echo "感谢使用！"; exit 0 ;;
            *) echo "无效选择，请重新输入" ;;
        esac
    done
}

check_root
check_system
main_menu