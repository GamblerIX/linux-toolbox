#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/lib_utils.sh"

system_cleanup() {
    print_title "系统清理"
    
    if ! confirm_action "确定要清理系统垃圾文件吗？"; then
        return
    fi
    
    log_info "开始清理系统垃圾文件..."
    
    local pm=$(get_package_manager)
    local cleaned_size=0
    
    case $pm in
        "apt")
            log_info "清理APT缓存..."
            apt-get clean
            apt-get autoclean
            apt-get autoremove -y
            ;;
        "yum")
            log_info "清理YUM缓存..."
            yum clean all
            package-cleanup --oldkernels --count=1 -y 2>/dev/null || true
            ;;
        "dnf")
            log_info "清理DNF缓存..."
            dnf clean all
            dnf autoremove -y
            ;;
    esac
    
    log_info "清理临时文件..."
    find /tmp -type f -atime +7 -delete 2>/dev/null || true
    find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
    
    log_info "清理日志文件..."
    find /var/log -name "*.log" -type f -size +100M -exec truncate -s 0 {} \; 2>/dev/null || true
    journalctl --vacuum-time=7d 2>/dev/null || true
    
    log_info "清理用户缓存..."
    find /home -name ".cache" -type d -exec rm -rf {} + 2>/dev/null || true
    find /root -name ".cache" -type d -exec rm -rf {} + 2>/dev/null || true
    
    log_success "系统清理完成"
    
    df -h | grep -E '^/dev/'
    press_enter
}

user_management() {
    while true; do
        show_menu "用户管理" \
            "查看所有用户" \
            "创建新用户" \
            "删除用户" \
            "添加用户到sudo组" \
            "修改用户密码" \
            "锁定/解锁用户"
        
        local choice=$(read_choice 6)
        
        case $choice in
            0) return ;;
            1) list_users ;;
            2) create_user ;;
            3) delete_user ;;
            4) add_user_to_sudo ;;
            5) change_user_password ;;
            6) toggle_user_lock ;;
        esac
    done
}

list_users() {
    print_title "系统用户列表"
    
    echo -e "${CYAN}普通用户:${NC}"
    awk -F: '$3 >= 1000 && $3 < 65534 {print $1 " (UID: " $3 ")"}' /etc/passwd
    
    echo
    echo -e "${CYAN}系统用户:${NC}"
    awk -F: '$3 < 1000 {print $1 " (UID: " $3 ")"}' /etc/passwd | head -10
    
    echo
    echo -e "${CYAN}sudo组成员:${NC}"
    getent group sudo | cut -d: -f4 | tr ',' '\n' | grep -v '^$' || echo "无"
    
    press_enter
}

create_user() {
    print_title "创建新用户"
    
    read -p "请输入用户名: " username
    
    if [[ -z "$username" ]]; then
        log_error "用户名不能为空"
        press_enter
        return
    fi
    
    if id "$username" &>/dev/null; then
        log_error "用户 $username 已存在"
        press_enter
        return
    fi
    
    useradd -m -s /bin/bash "$username"
    
    if [[ $? -eq 0 ]]; then
        log_success "用户 $username 创建成功"
        
        if confirm_action "是否设置密码？"; then
            passwd "$username"
        fi
        
        if confirm_action "是否添加到sudo组？"; then
            usermod -aG sudo "$username"
            log_success "用户 $username 已添加到sudo组"
        fi
    else
        log_error "用户创建失败"
    fi
    
    press_enter
}

delete_user() {
    print_title "删除用户"
    
    read -p "请输入要删除的用户名: " username
    
    if [[ -z "$username" ]]; then
        log_error "用户名不能为空"
        press_enter
        return
    fi
    
    if ! id "$username" &>/dev/null; then
        log_error "用户 $username 不存在"
        press_enter
        return
    fi
    
    if [[ "$username" == "root" ]] || [[ "$username" == "$(whoami)" ]]; then
        log_error "不能删除root用户或当前用户"
        press_enter
        return
    fi
    
    log_warn "警告：此操作将删除用户 $username 及其主目录"
    
    if confirm_action "确定要删除用户 $username 吗？"; then
        userdel -r "$username" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            log_success "用户 $username 删除成功"
        else
            log_error "用户删除失败"
        fi
    fi
    
    press_enter
}

add_user_to_sudo() {
    print_title "添加用户到sudo组"
    
    read -p "请输入用户名: " username
    
    if [[ -z "$username" ]]; then
        log_error "用户名不能为空"
        press_enter
        return
    fi
    
    if ! id "$username" &>/dev/null; then
        log_error "用户 $username 不存在"
        press_enter
        return
    fi
    
    usermod -aG sudo "$username"
    
    if [[ $? -eq 0 ]]; then
        log_success "用户 $username 已添加到sudo组"
    else
        log_error "添加失败"
    fi
    
    press_enter
}

change_user_password() {
    print_title "修改用户密码"
    
    read -p "请输入用户名: " username
    
    if [[ -z "$username" ]]; then
        log_error "用户名不能为空"
        press_enter
        return
    fi
    
    if ! id "$username" &>/dev/null; then
        log_error "用户 $username 不存在"
        press_enter
        return
    fi
    
    passwd "$username"
    press_enter
}

toggle_user_lock() {
    print_title "锁定/解锁用户"
    
    read -p "请输入用户名: " username
    
    if [[ -z "$username" ]]; then
        log_error "用户名不能为空"
        press_enter
        return
    fi
    
    if ! id "$username" &>/dev/null; then
        log_error "用户 $username 不存在"
        press_enter
        return
    fi
    
    if passwd -S "$username" | grep -q "L"; then
        if confirm_action "用户 $username 已被锁定，是否解锁？"; then
            usermod -U "$username"
            log_success "用户 $username 已解锁"
        fi
    else
        if confirm_action "确定要锁定用户 $username 吗？"; then
            usermod -L "$username"
            log_success "用户 $username 已锁定"
        fi
    fi
    
    press_enter
}

source_management() {
    while true; do
        show_menu "软件源管理" \
            "查看当前软件源" \
            "更换为阿里云源" \
            "更换为腾讯云源" \
            "更换为中科大源" \
            "更换为华为云源" \
            "恢复官方源" \
            "更新软件包列表"
        
        local choice=$(read_choice 7)
        
        case $choice in
            0) return ;;
            1) show_current_sources ;;
            2) change_source "aliyun" ;;
            3) change_source "tencent" ;;
            4) change_source "ustc" ;;
            5) change_source "huawei" ;;
            6) change_source "official" ;;
            7) update_package_list ;;
        esac
    done
}

show_current_sources() {
    print_title "当前软件源"
    
    local pm=$(get_package_manager)
    
    case $pm in
        "apt")
            if [[ -f /etc/apt/sources.list ]]; then
                echo -e "${CYAN}/etc/apt/sources.list:${NC}"
                grep -v '^#' /etc/apt/sources.list | grep -v '^$'
            fi
            ;;
        "yum")
            echo -e "${CYAN}YUM仓库:${NC}"
            yum repolist
            ;;
        "dnf")
            echo -e "${CYAN}DNF仓库:${NC}"
            dnf repolist
            ;;
    esac
    
    press_enter
}

change_source() {
    local source_type="$1"
    local pm=$(get_package_manager)
    
    print_title "更换软件源"
    
    if [[ "$pm" != "apt" ]]; then
        log_error "当前系统不支持自动更换软件源"
        press_enter
        return
    fi
    
    backup_file "/etc/apt/sources.list"
    
    get_os_info
    local codename
    
    if [[ "$OS" == *"Ubuntu"* ]]; then
        codename=$(lsb_release -cs 2>/dev/null || echo "focal")
    elif [[ "$OS" == *"Debian"* ]]; then
        codename=$(lsb_release -cs 2>/dev/null || echo "bullseye")
    else
        log_error "不支持的操作系统"
        press_enter
        return
    fi
    
    case $source_type in
        "aliyun")
            log_info "更换为阿里云源..."
            if [[ "$OS" == *"Ubuntu"* ]]; then
                cat > /etc/apt/sources.list << EOF
deb https://mirrors.aliyun.com/ubuntu/ $codename main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $codename-security main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $codename-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $codename-backports main restricted universe multiverse
EOF
            else
                cat > /etc/apt/sources.list << EOF
deb https://mirrors.aliyun.com/debian/ $codename main contrib non-free
deb https://mirrors.aliyun.com/debian/ $codename-updates main contrib non-free
deb https://mirrors.aliyun.com/debian-security/ $codename-security main contrib non-free
EOF
            fi
            ;;
        "tencent")
            log_info "更换为腾讯云源..."
            if [[ "$OS" == *"Ubuntu"* ]]; then
                cat > /etc/apt/sources.list << EOF
deb https://mirrors.cloud.tencent.com/ubuntu/ $codename main restricted universe multiverse
deb https://mirrors.cloud.tencent.com/ubuntu/ $codename-security main restricted universe multiverse
deb https://mirrors.cloud.tencent.com/ubuntu/ $codename-updates main restricted universe multiverse
deb https://mirrors.cloud.tencent.com/ubuntu/ $codename-backports main restricted universe multiverse
EOF
            else
                cat > /etc/apt/sources.list << EOF
deb https://mirrors.cloud.tencent.com/debian/ $codename main contrib non-free
deb https://mirrors.cloud.tencent.com/debian/ $codename-updates main contrib non-free
deb https://mirrors.cloud.tencent.com/debian-security/ $codename-security main contrib non-free
EOF
            fi
            ;;
        "ustc")
            log_info "更换为中科大源..."
            if [[ "$OS" == *"Ubuntu"* ]]; then
                cat > /etc/apt/sources.list << EOF
deb https://mirrors.ustc.edu.cn/ubuntu/ $codename main restricted universe multiverse
deb https://mirrors.ustc.edu.cn/ubuntu/ $codename-security main restricted universe multiverse
deb https://mirrors.ustc.edu.cn/ubuntu/ $codename-updates main restricted universe multiverse
deb https://mirrors.ustc.edu.cn/ubuntu/ $codename-backports main restricted universe multiverse
EOF
            else
                cat > /etc/apt/sources.list << EOF
deb https://mirrors.ustc.edu.cn/debian/ $codename main contrib non-free
deb https://mirrors.ustc.edu.cn/debian/ $codename-updates main contrib non-free
deb https://mirrors.ustc.edu.cn/debian-security/ $codename-security main contrib non-free
EOF
            fi
            ;;
        "huawei")
            log_info "更换为华为云源..."
            if [[ "$OS" == *"Ubuntu"* ]]; then
                cat > /etc/apt/sources.list << EOF
deb https://mirrors.huaweicloud.com/ubuntu/ $codename main restricted universe multiverse
deb https://mirrors.huaweicloud.com/ubuntu/ $codename-security main restricted universe multiverse
deb https://mirrors.huaweicloud.com/ubuntu/ $codename-updates main restricted universe multiverse
deb https://mirrors.huaweicloud.com/ubuntu/ $codename-backports main restricted universe multiverse
EOF
            else
                cat > /etc/apt/sources.list << EOF
deb https://mirrors.huaweicloud.com/debian/ $codename main contrib non-free
deb https://mirrors.huaweicloud.com/debian/ $codename-updates main contrib non-free
deb https://mirrors.huaweicloud.com/debian-security/ $codename-security main contrib non-free
EOF
            fi
            ;;
        "official")
            log_info "恢复官方源..."
            if [[ "$OS" == *"Ubuntu"* ]]; then
                cat > /etc/apt/sources.list << EOF
deb http://archive.ubuntu.com/ubuntu/ $codename main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $codename-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $codename-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $codename-backports main restricted universe multiverse
EOF
            else
                cat > /etc/apt/sources.list << EOF
deb http://deb.debian.org/debian/ $codename main contrib non-free
deb http://deb.debian.org/debian/ $codename-updates main contrib non-free
deb http://security.debian.org/debian-security/ $codename-security main contrib non-free
EOF
            fi
            ;;
    esac
    
    log_success "软件源更换完成"
    
    if confirm_action "是否立即更新软件包列表？" "y"; then
        update_package_list
    fi
    
    press_enter
}

update_package_list() {
    print_title "更新软件包列表"
    
    local pm=$(get_package_manager)
    
    case $pm in
        "apt")
            log_info "更新APT软件包列表..."
            apt-get update
            ;;
        "yum")
            log_info "更新YUM软件包列表..."
            yum makecache
            ;;
        "dnf")
            log_info "更新DNF软件包列表..."
            dnf makecache
            ;;
    esac
    
    log_success "软件包列表更新完成"
    press_enter
}

system_info() {
    print_title "系统信息"
    
    get_system_info
    
    echo
    echo -e "${CYAN}内存使用情况:${NC}"
    free -h
    
    echo
    echo -e "${CYAN}磁盘使用情况:${NC}"
    df -h | grep -E '^/dev/'
    
    echo
    echo -e "${CYAN}CPU信息:${NC}"
    lscpu | grep -E '^(Model name|CPU\(s\)|Thread|Core)'
    
    echo
    echo -e "${CYAN}网络接口:${NC}"
    ip addr show | grep -E '^[0-9]+:' | awk '{print $2}' | tr -d ':'
    
    press_enter
}