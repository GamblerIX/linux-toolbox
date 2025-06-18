#!/bin/bash
# -*- coding: utf-8 -*-

# Linux Toolbox - System Management Library

# --- High-Intensity Bright & Bold Color Definitions ---
RED=$'\e[1;91m'
GREEN=$'\e[1;92m'
YELLOW=$'\e[1;93m'
BLUE=$'\e[1;94m'
CYAN=$'\e[1;96m'
NC=$'\e[0m'

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
    echo -e "${GREEN}1. 列出可登录用户${NC}"; echo -e "${GREEN}2. 创建新用户${NC}"
    echo -e "${GREEN}3. 删除用户${NC}"; echo -e "${GREEN}4. 修改密码${NC}"
    echo -e "${GREEN}5. 查看用户组${NC}"; echo -e "${GREEN}6. 切换用户${NC}"
    echo -e "${GREEN}0. 返回上一级${NC}"; echo -e "${CYAN}==============================================${NC}"
    
    read -p "请输入选项 [0-6]: " choice < /dev/tty
    case $choice in
        1) awk -F: '($1 == "root") || ($3 >= 1000 && $7 ~ /^\/bin\/(bash|sh|zsh|dash)$/)' /etc/passwd | cut -d: -f1 | sort ;;
        2) read -p "请输入新用户名: " username < /dev/tty
           if [[ "$OS_TYPE" == "ubuntu" || "$OS_TYPE" == "debian" ]]; then adduser "$username"; else useradd "$username" && passwd "$username"; fi ;;
        3) user_to_delete=$(select_user_interactive "请选择要删除的用户:");
           if [[ -n "$user_to_delete" ]]; then
               if [[ "$user_to_delete" == "root" ]]; then echo -e "${RED}禁止删除 root 用户。${NC}"; else
                   read -p "$(echo -e ${RED}"确定删除 ${user_to_delete} 及其主目录？(y/N): "${NC})" confirm < /dev/tty
                   if [[ "$confirm" =~ ^[Yy]$ ]]; then
                       if [[ "$OS_TYPE" == "ubuntu" || "$OS_TYPE" == "debian" ]]; then deluser --remove-home "$user_to_delete"; else userdel -r "$user_to_delete"; fi
                       echo -e "${GREEN}用户 ${user_to_delete} 已删除。${NC}"
                   else echo -e "${YELLOW}操作已取消。${NC}"; fi
               fi
           fi ;;
        4) user_to_change_pw=$(select_user_interactive "请选择要修改密码的用户:");
           [[ -n "$user_to_change_pw" ]] && passwd "$user_to_change_pw" ;;
        5) local all_groups=()
           while IFS= read -r user; do all_groups+=($(id -nG "$user")); done < <(awk -F: '($1 == "root") || ($3 >= 1000 && $7 ~ /^\/bin\/(bash|sh|zsh|dash)$/)' /etc/passwd | cut -d: -f1)
           printf "%s\n" "${all_groups[@]}" | sort -u ;;
        6) user_to_switch=$(select_user_interactive "请选择要切换的用户:");
           if [[ -n "$user_to_switch" ]]; then
               echo -e "${YELLOW}正在切换到 ${user_to_switch}... 您将退出此脚本。${NC}"; sleep 2; clear; exec su - "$user_to_switch"
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
