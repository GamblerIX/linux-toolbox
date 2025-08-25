#!/bin/bash

set -Eeuo pipefail
IFS=$'\n\t'

trap 'ltbx_error_handler "${BASH_SOURCE[0]}" "${LINENO}" "${FUNCNAME[0]:-main}" "$?"' ERR

ltbx_get_active_firewall() {
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        echo "firewalld"
    elif command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
        echo "ufw"
    else
        echo "none"
    fi
}

ltbx_firewall_management_menu() {
    if [[ "${LTBX_NON_INTERACTIVE:-false}" == "true" ]]; then
        ltbx_log "WARN" "Non-interactive mode detected, skipping firewall management menu"
        return 0
    fi

    local fw choice
fw=$(ltbx_get_active_firewall)
    if [[ "$fw" == "none" ]]; then
        ltbx_install_firewall_menu
        return
    fi

    ltbx_show_header
    printf "${YELLOW}====== 防火墙管理 (当前: ${fw}) ======${NC}\n"
    printf "${GREEN}1. 查看状态和规则${NC}\n"
    printf "${GREEN}2. 开放端口${NC}\n"
    printf "${GREEN}3. 关闭端口${NC}\n"
    printf "${GREEN}4. 启用/禁用防火墙${NC}\n"
    printf "${GREEN}5. 切换防火墙系统${NC}\n"
    printf "${GREEN}0. 返回上一级菜单${NC}\n"
    printf "${CYAN}==============================================${NC}\n"

    read -p "请输入选项 [0-5]: " choice < /dev/tty
    case $choice in
        1) if [[ "$fw" == "firewalld" ]]; then
               firewall-cmd --list-all 2>/dev/null || ltbx_log "ERROR" "Failed to list firewalld rules"
           elif [[ "$fw" == "ufw" ]]; then
               ufw status verbose 2>/dev/null || ltbx_log "ERROR" "Failed to show ufw status"
           fi ;;
        2) local port proto
           read -p "端口号: " port < /dev/tty
           read -p "协议(tcp/udp): " proto < /dev/tty
           if [[ "$fw" == "firewalld" ]]; then
               firewall-cmd --permanent --add-port="${port}/${proto}" 2>/dev/null && firewall-cmd --reload 2>/dev/null
               printf "${GREEN}端口 ${port}/${proto} 已开放。${NC}\n"
           elif [[ "$fw" == "ufw" ]]; then
               ufw allow "${port}/${proto}" 2>/dev/null
               printf "${GREEN}端口 ${port}/${proto} 已开放。${NC}\n"
           fi ;;
        3) local port proto
           read -p "端口号: " port < /dev/tty
           read -p "协议(tcp/udp): " proto < /dev/tty
           if [[ "$fw" == "firewalld" ]]; then
               firewall-cmd --permanent --remove-port="${port}/${proto}" 2>/dev/null && firewall-cmd --reload 2>/dev/null
               printf "${GREEN}端口 ${port}/${proto} 已关闭。${NC}\n"
           elif [[ "$fw" == "ufw" ]]; then
               ufw delete allow "${port}/${proto}" 2>/dev/null
               printf "${GREEN}端口 ${port}/${proto} 已关闭。${NC}\n"
           fi ;;
        4) if [[ "$fw" == "firewalld" ]]; then
               if systemctl is-active --quiet firewalld 2>/dev/null; then
                   systemctl disable --now firewalld 2>/dev/null && printf "${GREEN}防火墙已禁用${NC}\n"
               else
                   systemctl enable --now firewalld 2>/dev/null && printf "${GREEN}防火墙已启用${NC}\n"
               fi
           elif [[ "$fw" == "ufw" ]]; then
               if ufw status 2>/dev/null | grep -q "active"; then
                   ufw disable 2>/dev/null && printf "${GREEN}防火墙已禁用${NC}\n"
               else
                   yes | ufw enable 2>/dev/null && printf "${GREEN}防火墙已启用${NC}\n"
               fi
           fi ;;
        5) ltbx_switch_firewall_system ;;
        0) return 0 ;;
        *) printf "${RED}无效选项${NC}\n"; sleep 1 ;;
    esac
    ltbx_press_any_key
    ltbx_firewall_management_menu
}

ltbx_install_firewall_menu() {
    if [[ "${LTBX_NON_INTERACTIVE:-false}" == "true" ]]; then
        ltbx_log "WARN" "Non-interactive mode detected, skipping firewall installation menu"
        return 0
    fi

    local choice install_cmd="yum"
    [[ "${LTBX_OS_TYPE:-}" == "centos" ]] && [[ "${LTBX_OS_VERSION:-}" != "7" ]] && install_cmd="dnf"

    ltbx_show_header
    printf "${YELLOW}====== 安装防火墙 ======${NC}\n"
    printf "${YELLOW}未检测到活动的防火墙，请选择安装：${NC}\n"

    if [[ "${LTBX_OS_TYPE:-}" == "ubuntu" || "${LTBX_OS_TYPE:-}" == "debian" ]]; then
        printf "${GREEN}1. 安装 UFW (推荐)${NC}\n"
        printf "${GREEN}2. 安装 Firewalld${NC}\n"
    else
        printf "${GREEN}1. 安装 Firewalld (推荐)${NC}\n"
        printf "${GREEN}2. 安装 UFW${NC}\n"
    fi
    printf "${GREEN}0. 返回${NC}\n"
    read -p "请输入选项: " choice < /dev/tty

    case $choice in
        1) if [[ "${LTBX_OS_TYPE:-}" == "ubuntu" || "${LTBX_OS_TYPE:-}" == "debian" ]]; then
               apt update 2>/dev/null && apt install -y ufw 2>/dev/null && yes | ufw enable 2>/dev/null
           else
               $install_cmd install -y firewalld 2>/dev/null && systemctl enable --now firewalld 2>/dev/null
           fi ;;
        2) if [[ "${LTBX_OS_TYPE:-}" == "ubuntu" || "${LTBX_OS_TYPE:-}" == "debian" ]]; then
               apt update 2>/dev/null && apt install -y firewalld 2>/dev/null && systemctl enable --now firewalld 2>/dev/null
           else
               $install_cmd install -y ufw 2>/dev/null && yes | ufw enable 2>/dev/null
           fi ;;
        0) return 0 ;;
        *) printf "${RED}无效选项${NC}\n"; sleep 1; ltbx_install_firewall_menu; return ;;
    esac
    printf "${GREEN}安装并启用成功。${NC}\n"
    ltbx_press_any_key
    ltbx_firewall_management_menu
}

ltbx_switch_firewall_system() {
    if [[ "${LTBX_NON_INTERACTIVE:-false}" == "true" ]]; then
        ltbx_log "WARN" "Non-interactive mode detected, skipping firewall system switch"
        return 0
    fi

    local choice confirm install_cmd="yum"
    [[ "${LTBX_OS_TYPE:-}" == "centos" ]] && [[ "${LTBX_OS_VERSION:-}" != "7" ]] && install_cmd="dnf"

    ltbx_show_header
    printf "${YELLOW}====== 切换防火墙系统 ======${NC}\n"
    printf "${RED}警告：这将停用当前防火墙并安装启用新的，可能导致规则丢失！${NC}\n"

    if [[ "${LTBX_OS_TYPE:-}" == "ubuntu" || "${LTBX_OS_TYPE:-}" == "debian" ]]; then
        printf "${GREEN}1. 切换到 firewalld${NC}\n"
        printf "${GREEN}2. 切换到 ufw (默认)${NC}\n"
    else
        printf "${GREEN}1. 切换到 firewalld (默认)${NC}\n"
        printf "${GREEN}2. 切换到 ufw${NC}\n"
    fi
    printf "${GREEN}0. 取消${NC}\n"
    read -p "请输入你的选择: " choice < /dev/tty

    case $choice in
        1) read -p "确定切换到 firewalld? (y/N): " confirm < /dev/tty
           if [[ "$confirm" =~ ^[Yy]$ ]]; then
               command -v ufw &>/dev/null && ufw disable &>/dev/null
               command -v firewall-cmd &>/dev/null || {
                   if [[ "${LTBX_OS_TYPE:-}" == "ubuntu" || "${LTBX_OS_TYPE:-}" == "debian" ]]; then
                       apt install -y firewalld 2>/dev/null
                   else
                       $install_cmd install -y firewalld 2>/dev/null
                   fi
               }
               systemctl enable --now firewalld 2>/dev/null
               printf "${GREEN}已切换到 firewalld。${NC}\n"
           fi ;;
        2) read -p "确定切换到 ufw? (y/N): " confirm < /dev/tty
           if [[ "$confirm" =~ ^[Yy]$ ]]; then
               systemctl is-active --quiet firewalld 2>/dev/null && systemctl disable --now firewalld 2>/dev/null
               command -v ufw &>/dev/null || {
                   if [[ "${LTBX_OS_TYPE:-}" == "ubuntu" || "${LTBX_OS_TYPE:-}" == "debian" ]]; then
                       apt install -y ufw 2>/dev/null
                   else
                       $install_cmd install -y ufw 2>/dev/null
                   fi
               }
               yes | ufw enable 2>/dev/null
               printf "${GREEN}已切换到 ufw。${NC}\n"
           fi ;;
        0) ltbx_firewall_management_menu; return ;;
        *) printf "${RED}无效选项${NC}\n"; sleep 1 ;;
    esac
    ltbx_press_any_key
    ltbx_firewall_management_menu
}
