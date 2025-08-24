#!/bin/bash
# -*- coding: utf-8 -*-

# Linux Toolbox - System Management Library

# Note: Color variables (RED, GREEN, etc.) are sourced from the global config.sh

function manage_tools_menu() {
    show_header
    echo -e "${YELLOW}====== 系统管理工具 ======${NC}"
    echo -e "${GREEN}1. 清理系统垃圾${NC}"
    echo -e "${GREEN}2. 用户管理${NC}"
    echo -e "${GREEN}3. 内核管理${NC}"
    echo -e "${GREEN}0. 返回主菜单${NC}"
    echo -e "${CYAN}==============================================${NC}"
    
    read -p "请输入选项 [0-3]: " choice < /dev/tty
    case $choice in
        1) clean_system ;;
        2) user_management_menu ;;
        3) kernel_management_menu ;;
        0) main_menu ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1; manage_tools_menu ;;
    esac
}

function clean_system() {
    show_header
    echo -e "${YELLOW}====== 清理系统垃圾 ======${NC}"
    echo -e "${BLUE}清理临时文件...${NC}"; rm -rf /tmp/*; rm -rf /var/tmp/*
    echo -e "${BLUE}清理包管理器缓存...${NC}";
    case "$OS_TYPE" in ubuntu|debian) apt-get clean -y;; centos) yum clean all;; esac
    echo -e "${BLUE}卸载无用包和旧内核...${NC}";
    case "$OS_TYPE" in
        ubuntu|debian) apt-get autoremove --purge -y;;
        centos)
             if [[ "$OS_VERSION" == "7" ]]; then
                 command -v package-cleanup &> /dev/null || yum install -y yum-utils
                 package-cleanup --oldkernels --count=1 -y
             else
                 dnf autoremove -y
             fi ;;
    esac
    echo -e "${BLUE}清理日志文件 (保留7天)...${NC}"; journalctl --vacuum-time=7d
    echo -e "${GREEN}系统垃圾清理完成！${NC}"; press_any_key; manage_tools_menu
}

function user_management_menu() {
    show_header
    echo -e "${YELLOW}====== 用户管理 ======${NC}"
    echo -e "${CYAN}┌─────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}1.${NC} 列出可登录用户 ${BLUE}(查看系统中所有可登录用户)${NC} ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}2.${NC} 创建新用户     ${BLUE}(添加新的系统用户账户)${NC} ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}3.${NC} 删除用户       ${BLUE}(移除用户及其主目录)${NC}   ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}4.${NC} 修改密码       ${BLUE}(更改用户登录密码)${NC}     ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}5.${NC} 查看用户组     ${BLUE}(显示所有用户组信息)${NC}   ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}6.${NC} 切换用户       ${BLUE}(切换到其他用户身份)${NC}   ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${RED}0.${NC} 返回上一级     ${BLUE}(返回系统管理菜单)${NC}     ${CYAN}│${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"
    echo -e "${YELLOW}请选择您要执行的操作：${NC}"
    
    read -p "输入选项编号 [0-6]: " choice < /dev/tty
    case $choice in
        1) awk -F: '($1 == "root") || ($3 >= 1000 && $7 ~ /^\/bin\/(bash|sh|zsh|dash)$/)' /etc/passwd | cut -d: -f1 | sort ;;
        2) echo -e "${CYAN}┌─────────────────────────────────────┐${NC}"
           echo -e "${CYAN}│${NC} ${BLUE}创建新用户${NC}                      ${CYAN}│${NC}"
           echo -e "${CYAN}└─────────────────────────────────────┘${NC}"
           echo -e "${YELLOW}提示：用户名只能包含字母、数字、下划线和连字符${NC}"
           read -p "请输入新用户名: " username < /dev/tty
           if [ -z "$username" ]; then
               echo -e "${RED}错误：用户名不能为空，请重新输入。${NC}" ; sleep 2 ; user_management_menu ; return
           fi
           if ! [[ "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
               echo -e "${RED}错误：用户名格式不正确，只能包含字母、数字、下划线和连字符。${NC}" ; sleep 2 ; user_management_menu ; return
           fi
           if id "$username" &>/dev/null; then
               echo -e "${RED}错误：用户 $username 已存在，请选择其他用户名。${NC}" ; sleep 2 ; user_management_menu ; return
           fi
           echo -e "${YELLOW}请设置用户密码（输入时不显示）：${NC}"
           read -s -p "输入密码: " password < /dev/tty ; echo
           if [ -z "$password" ]; then
               echo -e "${RED}错误：密码不能为空，请重新输入。${NC}" ; sleep 2 ; user_management_menu ; return
           fi
           read -s -p "确认密码: " password_confirm < /dev/tty ; echo
           if [ "$password" != "$password_confirm" ]; then
               echo -e "${RED}错误：两次输入的密码不一致，请重新操作。${NC}" ; sleep 2 ; user_management_menu ; return
           fi
           echo -e "${YELLOW}正在创建用户...${NC}"
           useradd -m -s /bin/bash "$username" && echo "$username:$password" | chpasswd
           if [ $? -eq 0 ]; then
               echo -e "${GREEN}✓ 用户 $username 创建成功！${NC}"
               echo -e "${BLUE}用户主目录：/home/$username${NC}"
               echo -e "${BLUE}默认Shell：/bin/bash${NC}"
           else
               echo -e "${RED}✗ 用户创建失败，请检查系统权限或用户名是否合规。${NC}"
           fi ;;
        3) echo -e "${CYAN}┌─────────────────────────────────────┐${NC}"
           echo -e "${CYAN}│${NC} ${BLUE}删除用户${NC}                        ${CYAN}│${NC}"
           echo -e "${CYAN}└─────────────────────────────────────┘${NC}"
           echo -e "${RED}警告：删除用户将同时删除其主目录和所有文件！${NC}"
           user_to_delete=$(select_user_interactive "请选择要删除的用户:");
           if [[ -n "$user_to_delete" ]]; then
               if [[ "$user_to_delete" == "root" ]]; then
                   echo -e "${RED}✗ 安全限制：不能删除root超级管理员账户。${NC}"
                   sleep 2
               else
                   echo -e "${YELLOW}即将删除用户：${RED}$user_to_delete${NC}"
                   echo -e "${YELLOW}主目录路径：${RED}/home/$user_to_delete${NC}"
                   echo -e "${RED}此操作不可逆，请谨慎确认！${NC}"
                   echo
                   read -p "确认删除用户 $user_to_delete 及其主目录? 输入 'DELETE' 确认: " confirm < /dev/tty
                   if [[ "$confirm" == "DELETE" ]]; then
                       echo -e "${YELLOW}正在删除用户...${NC}"
                       if [[ "$OS_TYPE" == "ubuntu" || "$OS_TYPE" == "debian" ]]; then deluser --remove-home "$user_to_delete"; else userdel -r "$user_to_delete"; fi
                       if [ $? -eq 0 ]; then
                           echo -e "${GREEN}✓ 用户 $user_to_delete 及其主目录已成功删除。${NC}"
                       else
                           echo -e "${RED}✗ 删除失败，可能是用户正在使用或权限不足。${NC}"
                           echo -e "${YELLOW}提示：请确保用户未登录且没有运行中的进程。${NC}"
                       fi
                   else
                       echo -e "${YELLOW}操作已取消，用户未被删除。${NC}"
                   fi
               fi
           fi ;;
        4) echo -e "${CYAN}┌─────────────────────────────────────┐${NC}"
           echo -e "${CYAN}│${NC} ${BLUE}修改用户密码${NC}                    ${CYAN}│${NC}"
           echo -e "${CYAN}└─────────────────────────────────────┘${NC}"
           echo -e "${YELLOW}提示：建议使用包含字母、数字和特殊字符的强密码${NC}"
           user_to_modify=$(select_user_interactive "请选择要修改密码的用户:");
           if [[ -n "$user_to_modify" ]]; then
               echo -e "${YELLOW}正在为用户 ${GREEN}$user_to_modify${YELLOW} 设置新密码${NC}"
               echo -e "${BLUE}密码要求：建议至少8位，包含大小写字母、数字${NC}"
               echo
               read -s -p "请输入新密码（输入时不显示）: " new_password < /dev/tty ; echo
               if [ -z "$new_password" ]; then
                   echo -e "${RED}错误：密码不能为空，操作已取消。${NC}"
                   sleep 2
               elif [ ${#new_password} -lt 6 ]; then
                   echo -e "${RED}错误：密码长度至少6位，操作已取消。${NC}"
                   sleep 2
               else
                   read -s -p "请确认新密码: " confirm_password < /dev/tty ; echo
                   if [ "$new_password" != "$confirm_password" ]; then
                       echo -e "${RED}错误：两次输入的密码不一致，操作已取消。${NC}"
                       sleep 2
                   else
                       echo -e "${YELLOW}正在更新密码...${NC}"
                       echo "$user_to_modify:$new_password" | chpasswd
                       if [ $? -eq 0 ]; then
                           echo -e "${GREEN}✓ 用户 $user_to_modify 的密码修改成功！${NC}"
                           echo -e "${BLUE}提示：请妥善保管新密码，建议用户首次登录后再次修改。${NC}"
                       else
                           echo -e "${RED}✗ 密码修改失败，请检查系统权限或用户状态。${NC}"
                       fi
                   fi
               fi
           fi ;;
        5) echo -e "${CYAN}┌─────────────────────────────────────┐${NC}"
            echo -e "${CYAN}│${NC} ${BLUE}查看用户组信息${NC}                  ${CYAN}│${NC}"
            echo -e "${CYAN}└─────────────────────────────────────┘${NC}"
            echo -e "${YELLOW}系统中所有用户组列表：${NC}"
            echo -e "${CYAN}┌─────────────────────────────────────┐${NC}"
            local all_groups=()
            while IFS= read -r user; do all_groups+=($(id -nG "$user")); done < <(awk -F: '($1 == "root") || ($3 >= 1000 && $7 ~ /^\/bin\/(bash|sh|zsh|dash)$/)' /etc/passwd | cut -d: -f1)
            local unique_groups=($(printf '%s\n' "${all_groups[@]}" | sort -u))
            local count=1
            for group in "${unique_groups[@]}"; do
                local group_info=""
                if getent group "$group" >/dev/null 2>&1; then
                    local members=$(getent group "$group" | cut -d: -f4)
                    if [ -n "$members" ]; then
                        group_info="${GREEN}(成员: $members)${NC}"
                    else
                        group_info="${YELLOW}(无成员)${NC}"
                    fi
                fi
                printf "${CYAN}│${NC} ${GREEN}%2d.${NC} %-15s %s ${CYAN}│${NC}\n" "$count" "$group" "$group_info"
                ((count++))
            done
            echo -e "${CYAN}└─────────────────────────────────────┘${NC}"
            echo -e "${BLUE}提示：显示了所有可登录用户所属的用户组${NC}"
            press_any_key ;;
        6) echo -e "${CYAN}┌─────────────────────────────────────┐${NC}"
           echo -e "${CYAN}│${NC} ${BLUE}切换用户身份${NC}                    ${CYAN}│${NC}"
           echo -e "${CYAN}└─────────────────────────────────────┘${NC}"
           echo -e "${YELLOW}提示：切换后将进入目标用户的Shell环境${NC}"
           echo -e "${BLUE}使用 'exit' 命令可返回当前用户${NC}"
           user_to_switch=$(select_user_interactive "请选择要切换的用户:");
           if [[ -n "$user_to_switch" ]]; then
               echo -e "${YELLOW}正在切换到用户 ${GREEN}$user_to_switch${YELLOW}...${NC}"
               echo -e "${BLUE}当前用户：${GREEN}$(whoami)${NC} → 目标用户：${GREEN}$user_to_switch${NC}"
               echo -e "${CYAN}════════════════════════════════════${NC}"
               su - "$user_to_switch"
               echo -e "${CYAN}════════════════════════════════════${NC}"
               echo -e "${YELLOW}已返回用户：${GREEN}$(whoami)${NC}"
           fi ;;
        0) manage_tools_menu; return ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
    esac
    press_any_key; user_management_menu
}

function kernel_management_menu() {
    show_header
    echo -e "${YELLOW}====== 内核管理 ======${NC}"; echo -e "${GREEN}1. 查看当前内核版本${NC}"
    echo -e "${GREEN}2. 列出所有已安装内核${NC}"; echo -e "${GREEN}3. 清理旧内核${NC}"
    echo -e "${GREEN}0. 返回上一级${NC}"; echo -e "${CYAN}==============================================${NC}"
    
    read -p "请输入选项 [0-3]: " choice < /dev/tty
    case $choice in
        1) uname -r ;;
        2) if [[ "$OS_TYPE" == "ubuntu" || "$OS_TYPE" == "debian" ]]; then dpkg --list | grep linux-image; else rpm -qa | grep kernel; fi ;;
        3) case "$OS_TYPE" in ubuntu|debian) apt autoremove --purge -y;; centos) if [[ "$OS_VERSION" == "7" ]]; then package-cleanup --oldkernels --count=1 -y; else dnf autoremove -y; fi;; esac ;;
        0) manage_tools_menu; return ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
    esac
    press_any_key; kernel_management_menu
}

function change_source_menu() {
    show_header
    echo -e "${YELLOW}====== 一键换源加速 ======${NC}"; echo -e "${GREEN}1. 换源 (阿里云)${NC}"
    echo -e "${GREEN}2. 换源 (腾讯云)${NC}"; echo -e "${GREEN}3. 换源 (中科大)${NC}"
    echo -e "${GREEN}4. 恢复官方源${NC}"; echo -e "${GREEN}0. 返回主菜单${NC}"
    echo -e "${CYAN}==============================================${NC}"
    
    read -p "请输入选项 [0-4]: " choice < /dev/tty
    case $choice in
        1) _change_mirror "aliyun" ;;
        2) _change_mirror "tencent" ;;
        3) _change_mirror "ustc" ;;
        4) _restore_official_mirror ;;
        0) main_menu; return ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1; change_source_menu ;;
    esac
    press_any_key; change_source_menu
}

function _change_mirror() {
    local provider="$1" mirror_url="" mirror_name=""
    case "$provider" in
        aliyun) mirror_url="http://mirrors.aliyun.com"; mirror_name="阿里云";;
        tencent) mirror_url="http://mirrors.tencent.com"; mirror_name="腾讯云";;
        ustc) mirror_url="https://mirrors.ustc.edu.cn"; mirror_name="中科大";;
        *) echo -e "${RED}未知的源。${NC}"; return 1 ;;
    esac
    read -p "确定更换为 ${mirror_name} 源吗？(y/N): " confirm < /dev/tty
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then echo -e "${YELLOW}操作已取消。${NC}"; return; fi
    
    local backup_dir="/etc/apt/sources.list.d.bak"; [[ "$OS_TYPE" == "centos" ]] && backup_dir="/etc/yum.repos.d.bak"
    mkdir -p "$backup_dir"; mv /etc/apt/sources.list "$backup_dir/sources.list.$(date +%F-%T)" 2>/dev/null
    [[ "$OS_TYPE" == "centos" ]] && mv /etc/yum.repos.d/*.repo "$backup_dir/" 2>/dev/null
    echo -e "${YELLOW}已备份原有源文件至 ${backup_dir}${NC}"

    case "$OS_TYPE" in
        ubuntu) _change_mirror_ubuntu "$mirror_url" ;;
        debian) _change_mirror_debian "$mirror_url" ;;
        centos) _change_mirror_centos "$mirror_url" ;;
    esac
    echo -e "${GREEN}源已更换为 ${mirror_name}。正在更新缓存...${NC}"
    case "$OS_TYPE" in ubuntu|debian) apt-get update;; centos) yum makecache;; esac
    echo -e "${GREEN}缓存更新完毕！${NC}"
}

function _change_mirror_ubuntu() {
    cat > /etc/apt/sources.list <<EOF
deb $1/ubuntu/ ${OS_CODENAME} main restricted universe multiverse
deb $1/ubuntu/ ${OS_CODENAME}-security main restricted universe multiverse
deb $1/ubuntu/ ${OS_CODENAME}-updates main restricted universe multiverse
deb $1/ubuntu/ ${OS_CODENAME}-backports main restricted universe multiverse
deb-src $1/ubuntu/ ${OS_CODENAME} main restricted universe multiverse
deb-src $1/ubuntu/ ${OS_CODENAME}-security main restricted universe multiverse
deb-src $1/ubuntu/ ${OS_CODENAME}-updates main restricted universe multiverse
deb-src $1/ubuntu/ ${OS_CODENAME}-backports main restricted universe multiverse
EOF
}

function _change_mirror_debian() {
    local components="main contrib non-free non-free-firmware"
    cat > /etc/apt/sources.list <<EOF
deb $1/debian/ ${OS_CODENAME} ${components}
deb-src $1/debian/ ${OS_CODENAME} ${components}
deb http://security.debian.org/debian-security/ ${OS_CODENAME}-security ${components}
deb-src http://security.debian.org/debian-security/ ${OS_CODENAME}-security ${components}
deb $1/debian/ ${OS_CODENAME}-updates ${components}
deb-src $1/debian/ ${OS_CODENAME}-updates ${components}
deb $1/debian/ ${OS_CODENAME}-backports ${components}
deb-src $1/debian/ ${OS_CODENAME}-backports ${components}
EOF
}

function _change_mirror_centos() {
    if [[ "$OS_VERSION" != "7" ]]; then echo -e "${RED}YUM换源暂仅支持CentOS 7。${NC}"; return 1; fi
    cat > /etc/yum.repos.d/CentOS-Base.repo <<EOF
[base]
name=CentOS-7 - Base
baseurl=$1/centos/7/os/x86_64/
gpgcheck=1
gpgkey=$1/centos/RPM-GPG-KEY-CentOS-7
[updates]
name=CentOS-7 - Updates
baseurl=$1/centos/7/updates/x86_64/
gpgcheck=1
gpgkey=$1/centos/RPM-GPG-KEY-CentOS-7
[extras]
name=CentOS-7 - Extras
baseurl=$1/centos/7/extras/x86_64/
gpgcheck=1
gpgkey=$1/centos/RPM-GPG-KEY-CentOS-7
[centosplus]
name=CentOS-7 - Plus
baseurl=$1/centos/7/centosplus/x86_64/
gpgcheck=1
gpgkey=$1/centos/RPM-GPG-KEY-CentOS-7
EOF
}

function _restore_official_mirror() {
    read -p "确定要恢复官方源吗？(y/N): " confirm < /dev/tty
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then echo -e "${YELLOW}操作已取消。${NC}"; return; fi
    case "$OS_TYPE" in
        ubuntu)
            cat > /etc/apt/sources.list <<EOF
deb http://archive.ubuntu.com/ubuntu/ ${OS_CODENAME} main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${OS_CODENAME}-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${OS_CODENAME}-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${OS_CODENAME}-backports main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ ${OS_CODENAME} main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ ${OS_CODENAME}-security main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ ${OS_CODENAME}-updates main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ ${OS_CODENAME}-backports main restricted universe multiverse
EOF
            apt-get update;;
        debian)
            local components="main contrib non-free non-free-firmware"
            cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian/ ${OS_CODENAME} ${components}
deb-src http://deb.debian.org/debian/ ${OS_CODENAME} ${components}
deb http://security.debian.org/debian-security/ ${OS_CODENAME}-security ${components}
deb-src http://security.debian.org/debian-security/ ${OS_CODENAME}-security ${components}
deb http://deb.debian.org/debian/ ${OS_CODENAME}-updates ${components}
deb-src http://deb.debian.org/debian/ ${OS_CODENAME}-updates ${components}
deb http://deb.debian.org/debian/ ${OS_CODENAME}-backports ${components}
deb-src http://deb.debian.org/debian/ ${OS_CODENAME}-backports ${components}
EOF
            apt-get update;;
        centos)
            if [[ "$OS_VERSION" != "7" ]]; then echo -e "${RED}恢复功能暂仅支持CentOS 7。${NC}"; return 1; fi
            mv /etc/yum.repos.d/*.repo /etc/yum.repos.d.bak/
            curl -o /etc/yum.repos.d/CentOS-Base.repo http://vault.centos.org/centos/7/os/x86_64/CentOS-Base.repo
            yum clean all && yum makecache;;
    esac
    echo -e "${GREEN}官方源已恢复并更新缓存。${NC}"
}
