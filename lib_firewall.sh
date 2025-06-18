#!/bin/bash
# -*- coding: utf-8 -*-

# Linux Toolbox - Firewall Library

# Note: Color variables (RED, GREEN, etc.) are sourced from the global config.sh

function get_active_firewall() {
    if systemctl is-active --quiet firewalld; then
        echo "firewalld"
    elif command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        echo "ufw"
    else
        echo "none"
    fi
}

function firewall_management_menu() {
    local fw; fw=$(get_active_firewall)
    if [ "$fw" == "none" ]; then install_firewall_menu; return; fi
    
    show_header
    echo -e "${YELLOW}====== 防火墙管理 (当前: ${fw}) ======${NC}"
    echo -e "${GREEN}1. 查看状态和规则${NC}"; echo -e "${GREEN}2. 开放端口${NC}"
    echo -e "${GREEN}3. 关闭端口${NC}"; echo -e "${GREEN}4. 启用/禁用防火墙${NC}"
    echo -e "${GREEN}5. 切换防火墙系统${NC}"; echo -e "${GREEN}0. 返回上一级菜单${NC}"
    echo -e "${CYAN}==============================================${NC}"
    
    read -p "请输入选项 [0-5]: " choice < /dev/tty
    case $choice in
        1) if [ "$fw" == "firewalld" ]; then firewall-cmd --list-all; elif [ "$fw" == "ufw" ]; then ufw status verbose; fi ;;
        2) read -p "端口号: " port; read -p "协议(tcp/udp): " proto
           if [ "$fw" == "firewalld" ]; then firewall-cmd --permanent --add-port=${port}/${proto}; firewall-cmd --reload; elif [ "$fw" == "ufw" ]; then ufw allow ${port}/${proto}; fi ;;
        3) read -p "端口号: " port; read -p "协议(tcp/udp): " proto
           if [ "$fw" == "firewalld" ]; then firewall-cmd --permanent --remove-port=${port}/${proto}; firewall-cmd --reload; elif [ "$fw" == "ufw" ]; then ufw delete allow ${port}/${proto}; fi ;;
        4) if [ "$fw" == "firewalld" ]; then if systemctl is-active --quiet firewalld; then systemctl disable --now firewalld && echo "已禁用"; else systemctl enable --now firewalld && echo "已启用"; fi
           elif [ "$fw" == "ufw" ]; then if ufw status | grep -q "active"; then ufw disable && echo "已禁用"; else yes | ufw enable && echo "已启用"; fi; fi ;;
        5) switch_firewall_system ;;
        0) network_tools_menu; return ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
    esac
    press_any_key; firewall_management_menu
}

function install_firewall_menu() {
    show_header
    echo -e "${YELLOW}====== 安装防火墙 ======${NC}"
    echo -e "${YELLOW}未检测到活动的防火墙，请选择安装：${NC}"
    
    local install_cmd="yum"; [ "$OS_TYPE" == "centos" ] && [ "$OS_VERSION" != "7" ] && install_cmd="dnf"
    if [[ "$OS_TYPE" == "ubuntu" || "$OS_TYPE" == "debian" ]]; then
        echo -e "${GREEN}1. 安装 UFW (推荐)${NC}"; echo -e "${GREEN}2. 安装 Firewalld${NC}"
    else
        echo -e "${GREEN}1. 安装 Firewalld (推荐)${NC}"; echo -e "${GREEN}2. 安装 UFW${NC}"
    fi
    echo -e "${GREEN}0. 返回${NC}"; read -p "请输入选项: " choice < /dev/tty
    
    case $choice in
        1) if [[ "$OS_TYPE" == "ubuntu" || "$OS_TYPE" == "debian" ]]; then apt update && apt install -y ufw; yes | ufw enable; else $install_cmd install -y firewalld; systemctl enable --now firewalld; fi ;;
        2) if [[ "$OS_TYPE" == "ubuntu" || "$OS_TYPE" == "debian" ]]; then apt update && apt install -y firewalld; systemctl enable --now firewalld; else $install_cmd install -y ufw; yes | ufw enable; fi ;;
        0) network_tools_menu; return ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1; install_firewall_menu; return ;;
    esac
    echo -e "${GREEN}安装并启用成功。${NC}"; press_any_key; firewall_management_menu
}

function switch_firewall_system() {
    show_header
    echo -e "${YELLOW}====== 切换防火墙系统 ======${NC}"
    echo -e "${RED}警告：这将停用当前防火墙并安装启用新的，可能导致规则丢失！${NC}"
    
    local install_cmd="yum"; [ "$OS_TYPE" == "centos" ] && [ "$OS_VERSION" != "7" ] && install_cmd="dnf"
    if [[ "$OS_TYPE" == "ubuntu" || "$OS_TYPE" == "debian" ]]; then
        echo -e "${GREEN}1. 切换到 firewalld${NC}"; echo -e "${GREEN}2. 切换到 ufw (默认)${NC}"
    else
        echo -e "${GREEN}1. 切换到 firewalld (默认)${NC}"; echo -e "${GREEN}2. 切换到 ufw${NC}"
    fi
    echo -e "${GREEN}0. 取消${NC}"; read -p "请输入你的选择: " choice < /dev/tty
    
    case $choice in
        1) read -p "确定切换到 firewalld? (y/N): " confirm < /dev/tty
           if [[ "$confirm" =~ ^[Yy]$ ]]; then
               command -v ufw &>/dev/null && ufw disable &>/dev/null
               command -v firewall-cmd &>/dev/null || { if [[ "$OS_TYPE" == "ubuntu" || "$OS_TYPE" == "debian" ]]; then apt install -y firewalld; else $install_cmd install -y firewalld; fi; }
               systemctl enable --now firewalld; echo -e "${GREEN}已切换到 firewalld。${NC}"
           fi ;;
        2) read -p "确定切换到 ufw? (y/N): " confirm < /dev/tty
           if [[ "$confirm" =~ ^[Yy]$ ]]; then
               systemctl is-active --quiet firewalld && systemctl disable --now firewalld
               command -v ufw &>/dev/null || { if [[ "$OS_TYPE" == "ubuntu" || "$OS_TYPE" == "debian" ]]; then apt install -y ufw; else $install_cmd install -y ufw; fi; }
               yes | ufw enable; echo -e "${GREEN}已切换到 ufw。${NC}"
           fi ;;
        0) firewall_management_menu; return ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
    esac
    press_any_key; firewall_management_menu
}
