#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/lib_utils.sh"

firewall_management() {
    while true; do
        show_menu "防火墙管理" \
            "查看防火墙状态" \
            "启用防火墙" \
            "禁用防火墙" \
            "添加端口规则" \
            "删除端口规则" \
            "查看防火墙规则" \
            "重置防火墙规则"
        
        local choice=$(read_choice 7)
        
        case $choice in
            0) return ;;
            1) show_firewall_status ;;
            2) enable_firewall ;;
            3) disable_firewall ;;
            4) add_port_rule ;;
            5) remove_port_rule ;;
            6) show_firewall_rules ;;
            7) reset_firewall_rules ;;
        esac
    done
}

get_firewall_type() {
    if command -v ufw &> /dev/null; then
        echo "ufw"
    elif command -v firewall-cmd &> /dev/null; then
        echo "firewalld"
    elif command -v iptables &> /dev/null; then
        echo "iptables"
    else
        echo "none"
    fi
}

install_firewall() {
    local pm=$(get_package_manager)
    
    case $pm in
        "apt")
            log_info "安装 ufw..."
            apt-get update
            apt-get install -y ufw
            ;;
        "yum")
            log_info "启用 firewalld..."
            yum install -y firewalld
            systemctl enable firewalld
            ;;
        "dnf")
            log_info "启用 firewalld..."
            dnf install -y firewalld
            systemctl enable firewalld
            ;;
    esac
}

show_firewall_status() {
    print_title "防火墙状态"
    
    local fw_type=$(get_firewall_type)
    
    case $fw_type in
        "ufw")
            echo -e "${CYAN}UFW状态:${NC}"
            ufw status verbose
            ;;
        "firewalld")
            echo -e "${CYAN}Firewalld状态:${NC}"
            firewall-cmd --state 2>/dev/null && echo "运行中" || echo "未运行"
            echo
            echo -e "${CYAN}默认区域:${NC}"
            firewall-cmd --get-default-zone 2>/dev/null
            echo
            echo -e "${CYAN}活动区域:${NC}"
            firewall-cmd --get-active-zones 2>/dev/null
            ;;
        "iptables")
            echo -e "${CYAN}iptables规则:${NC}"
            iptables -L -n --line-numbers
            ;;
        "none")
            log_error "未检测到防火墙软件"
            if confirm_action "是否安装防火墙？" "y"; then
                install_firewall
            fi
            ;;
    esac
    
    press_enter
}

enable_firewall() {
    print_title "启用防火墙"
    
    local fw_type=$(get_firewall_type)
    
    if [[ "$fw_type" == "none" ]]; then
        log_error "未检测到防火墙软件"
        if confirm_action "是否安装防火墙？" "y"; then
            install_firewall
            fw_type=$(get_firewall_type)
        else
            press_enter
            return
        fi
    fi
    
    case $fw_type in
        "ufw")
            if ufw status | grep -q "Status: active"; then
                log_info "UFW防火墙已经启用"
            else
                log_warn "启用防火墙可能会断开当前SSH连接"
                if confirm_action "确定要启用UFW防火墙吗？"; then
                    ufw --force enable
                    log_success "UFW防火墙已启用"
                fi
            fi
            ;;
        "firewalld")
            if systemctl is-active --quiet firewalld; then
                log_info "Firewalld已经运行"
            else
                systemctl start firewalld
                systemctl enable firewalld
                log_success "Firewalld已启用"
            fi
            ;;
        "iptables")
            log_info "iptables防火墙管理需要手动配置"
            ;;
    esac
    
    press_enter
}

disable_firewall() {
    print_title "禁用防火墙"
    
    local fw_type=$(get_firewall_type)
    
    log_warn "警告：禁用防火墙会降低系统安全性"
    
    if ! confirm_action "确定要禁用防火墙吗？"; then
        return
    fi
    
    case $fw_type in
        "ufw")
            ufw --force disable
            log_success "UFW防火墙已禁用"
            ;;
        "firewalld")
            systemctl stop firewalld
            systemctl disable firewalld
            log_success "Firewalld已禁用"
            ;;
        "iptables")
            iptables -F
            iptables -X
            iptables -t nat -F
            iptables -t nat -X
            iptables -t mangle -F
            iptables -t mangle -X
            iptables -P INPUT ACCEPT
            iptables -P FORWARD ACCEPT
            iptables -P OUTPUT ACCEPT
            log_success "iptables规则已清空"
            ;;
        "none")
            log_error "未检测到防火墙软件"
            ;;
    esac
    
    press_enter
}

add_port_rule() {
    print_title "添加端口规则"
    
    local fw_type=$(get_firewall_type)
    
    if [[ "$fw_type" == "none" ]]; then
        log_error "未检测到防火墙软件"
        press_enter
        return
    fi
    
    read -p "请输入端口号: " port
    
    if ! validate_port "$port"; then
        log_error "无效的端口号"
        press_enter
        return
    fi
    
    echo "请选择协议:"
    echo "1. TCP"
    echo "2. UDP"
    echo "3. 两者都有"
    
    local protocol_choice=$(read_choice 3)
    local protocols=()
    
    case $protocol_choice in
        1) protocols=("tcp") ;;
        2) protocols=("udp") ;;
        3) protocols=("tcp" "udp") ;;
        0) return ;;
    esac
    
    echo "请选择规则类型:"
    echo "1. 允许 (ALLOW)"
    echo "2. 拒绝 (DENY)"
    
    local action_choice=$(read_choice 2)
    local action
    
    case $action_choice in
        1) action="allow" ;;
        2) action="deny" ;;
        0) return ;;
    esac
    
    for protocol in "${protocols[@]}"; do
        case $fw_type in
            "ufw")
                ufw $action $port/$protocol
                log_success "UFW规则已添加: $action $port/$protocol"
                ;;
            "firewalld")
                if [[ "$action" == "allow" ]]; then
                    firewall-cmd --permanent --add-port=$port/$protocol
                    firewall-cmd --reload
                    log_success "Firewalld规则已添加: allow $port/$protocol"
                else
                    log_warn "Firewalld不直接支持deny规则，请使用rich rules"
                fi
                ;;
            "iptables")
                if [[ "$action" == "allow" ]]; then
                    iptables -A INPUT -p $protocol --dport $port -j ACCEPT
                    log_success "iptables规则已添加: allow $port/$protocol"
                else
                    iptables -A INPUT -p $protocol --dport $port -j DROP
                    log_success "iptables规则已添加: deny $port/$protocol"
                fi
                ;;
        esac
    done
    
    press_enter
}

remove_port_rule() {
    print_title "删除端口规则"
    
    local fw_type=$(get_firewall_type)
    
    if [[ "$fw_type" == "none" ]]; then
        log_error "未检测到防火墙软件"
        press_enter
        return
    fi
    
    read -p "请输入要删除的端口号: " port
    
    if ! validate_port "$port"; then
        log_error "无效的端口号"
        press_enter
        return
    fi
    
    echo "请选择协议:"
    echo "1. TCP"
    echo "2. UDP"
    echo "3. 两者都有"
    
    local protocol_choice=$(read_choice 3)
    local protocols=()
    
    case $protocol_choice in
        1) protocols=("tcp") ;;
        2) protocols=("udp") ;;
        3) protocols=("tcp" "udp") ;;
        0) return ;;
    esac
    
    for protocol in "${protocols[@]}"; do
        case $fw_type in
            "ufw")
                ufw delete allow $port/$protocol 2>/dev/null
                ufw delete deny $port/$protocol 2>/dev/null
                log_success "UFW规则已删除: $port/$protocol"
                ;;
            "firewalld")
                firewall-cmd --permanent --remove-port=$port/$protocol
                firewall-cmd --reload
                log_success "Firewalld规则已删除: $port/$protocol"
                ;;
            "iptables")
                iptables -D INPUT -p $protocol --dport $port -j ACCEPT 2>/dev/null
                iptables -D INPUT -p $protocol --dport $port -j DROP 2>/dev/null
                log_success "iptables规则已删除: $port/$protocol"
                ;;
        esac
    done
    
    press_enter
}

show_firewall_rules() {
    print_title "防火墙规则"
    
    local fw_type=$(get_firewall_type)
    
    case $fw_type in
        "ufw")
            echo -e "${CYAN}UFW规则:${NC}"
            ufw status numbered
            ;;
        "firewalld")
            echo -e "${CYAN}Firewalld规则:${NC}"
            echo "端口规则:"
            firewall-cmd --list-ports 2>/dev/null
            echo
            echo "服务规则:"
            firewall-cmd --list-services 2>/dev/null
            echo
            echo "Rich规则:"
            firewall-cmd --list-rich-rules 2>/dev/null
            ;;
        "iptables")
            echo -e "${CYAN}iptables规则:${NC}"
            iptables -L -n --line-numbers
            ;;
        "none")
            log_error "未检测到防火墙软件"
            ;;
    esac
    
    press_enter
}

reset_firewall_rules() {
    print_title "重置防火墙规则"
    
    local fw_type=$(get_firewall_type)
    
    log_warn "警告：此操作将删除所有自定义防火墙规则"
    
    if ! confirm_action "确定要重置防火墙规则吗？"; then
        return
    fi
    
    case $fw_type in
        "ufw")
            ufw --force reset
            log_success "UFW规则已重置"
            ;;
        "firewalld")
            firewall-cmd --complete-reload
            log_success "Firewalld规则已重置"
            ;;
        "iptables")
            iptables -F
            iptables -X
            iptables -t nat -F
            iptables -t nat -X
            iptables -t mangle -F
            iptables -t mangle -X
            iptables -P INPUT ACCEPT
            iptables -P FORWARD ACCEPT
            iptables -P OUTPUT ACCEPT
            log_success "iptables规则已重置"
            ;;
        "none")
            log_error "未检测到防火墙软件"
            ;;
    esac
    
    press_enter
}

quick_firewall_setup() {
    print_title "快速防火墙设置"
    
    local fw_type=$(get_firewall_type)
    
    if [[ "$fw_type" == "none" ]]; then
        log_error "未检测到防火墙软件"
        if confirm_action "是否安装防火墙？" "y"; then
            install_firewall
            fw_type=$(get_firewall_type)
        else
            press_enter
            return
        fi
    fi
    
    log_info "配置基本防火墙规则..."
    
    case $fw_type in
        "ufw")
            ufw --force reset
            ufw default deny incoming
            ufw default allow outgoing
            
            ufw allow ssh
            ufw allow 80/tcp
            ufw allow 443/tcp
            
            if confirm_action "是否启用防火墙？" "y"; then
                ufw --force enable
            fi
            
            log_success "UFW基本规则配置完成"
            ;;
        "firewalld")
            systemctl start firewalld
            systemctl enable firewalld
            
            firewall-cmd --set-default-zone=public
            firewall-cmd --permanent --add-service=ssh
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --reload
            
            log_success "Firewalld基本规则配置完成"
            ;;
        "iptables")
            iptables -F
            iptables -P INPUT DROP
            iptables -P FORWARD DROP
            iptables -P OUTPUT ACCEPT
            
            iptables -A INPUT -i lo -j ACCEPT
            iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -A INPUT -p tcp --dport 22 -j ACCEPT
            iptables -A INPUT -p tcp --dport 80 -j ACCEPT
            iptables -A INPUT -p tcp --dport 443 -j ACCEPT
            
            log_success "iptables基本规则配置完成"
            log_warn "请手动保存iptables规则以持久化"
            ;;
    esac
    
    press_enter
}