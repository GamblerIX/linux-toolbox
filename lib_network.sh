#!/bin/bash
# -*- coding: utf-8 -*-

# Linux Toolbox - Network Library

function network_tools_menu() {
    show_header
    echo -e "${YELLOW}====== 网络与安全工具 ======${NC}"
    echo -e "${GREEN}1. 网络速度测试${NC}"
    echo -e "${GREEN}2. 查看SSH登录日志${NC}"
    echo -e "${GREEN}3. 防火墙管理${NC}"
    echo -e "${GREEN}4. BBR网络加速管理${NC}"
    echo -e "${GREEN}5. 列出已占用端口${NC}"
    echo -e "${GREEN}0. 返回主菜单${NC}"
    echo -e "${CYAN}==============================================${NC}"

    read -p "请输入选项 [0-5]: " choice < /dev/tty
    case $choice in
        1) network_speed_test ;;
        2) view_ssh_logs_menu ;;
        3) firewall_management_menu ;;
        4) bbr_management_menu ;;
        5) list_used_ports ;;
        0) main_menu ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1; network_tools_menu ;;
    esac
}

function network_speed_test() {
    show_header
    echo -e "${YELLOW}====== 网络速度测试 ======${NC}"
    
    if ! command -v speedtest-cli &> /dev/null; then
        read -p "speedtest-cli 未安装, 是否立即安装? (y/N): " install_speedtest < /dev/tty
        if [[ "$install_speedtest" =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}正在安装 speedtest-cli...${NC}"
            case "$OS_TYPE" in ubuntu|debian) apt-get update && apt-get install -y speedtest-cli ;; *) yum install -y speedtest-cli ;; esac
        else
            echo "已跳过网络测试。"; press_any_key; network_tools_menu; return
        fi
    fi

    if command -v speedtest-cli &> /dev/null; then
        echo "正在测试网络, 请稍候..."
        speedtest_output=$(speedtest-cli --simple 2>/dev/null)
        if [ -n "$speedtest_output" ]; then
            ping=$(echo "$speedtest_output" | grep "Ping" | awk -F': ' '{print $2}')
            download=$(echo "$speedtest_output" | grep "Download" | awk -F': ' '{print $2}')
            upload=$(echo "$speedtest_output" | grep "Upload" | awk -F': ' '{print $2}')
            printf "  %-12s %s\n" "延迟:" "$ping"; printf "  %-12s %s\n" "下载速度:" "$download"; printf "  %-12s %s\n" "上传速度:" "$upload"
        else
            echo -e "  ${RED}网络测试失败, 请检查网络。${NC}"
        fi
    fi
    press_any_key; network_tools_menu
}

function view_ssh_logs_menu() {
    while true; do
        show_header
        echo -e "${YELLOW}====== 查看SSH登录日志 ======${NC}"
        echo -e "${GREEN}1. 查看成功登录记录${NC}"; echo -e "${GREEN}2. 查看失败登录记录${NC}"
        echo -e "${GREEN}3. 查看所有登录记录${NC}"; echo -e "${GREEN}0. 返回上一级菜单${NC}"
        echo -e "${CYAN}==============================================${NC}"
        read -p "请输入选项 [0-3]: " choice < /dev/tty
        case $choice in
            1) _display_ssh_logs "success" ;;
            2) _display_ssh_logs "failure" ;;
            3) _display_ssh_logs "all" ;;
            0) break ;;
            *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
        esac
    done
    network_tools_menu
}

function _display_ssh_logs() {
    local log_type=$1 log_file=""
    if [[ "$OS_TYPE" == "ubuntu" || "$OS_TYPE" == "debian" ]]; then log_file="/var/log/auth.log"; else log_file="/var/log/secure"; fi
    if [ ! -f "$log_file" ]; then echo -e "${RED}错误: 日志文件 $log_file 未找到。${NC}"; sleep 2; return; fi
    
    local success_pattern="Accepted" failure_pattern="Failed password" raw_logs=""
    case $log_type in
        "success") raw_logs=$(grep -a "$success_pattern" "$log_file");;
        "failure") raw_logs=$(grep -a "$failure_pattern" "$log_file");;
        "all") raw_logs=$(grep -a -E "$success_pattern|$failure_pattern" "$log_file");;
    esac
    mapfile -t logs < <(echo "$raw_logs" | sort -r)
    
    local total_records=${#logs[@]}
    if [ $total_records -eq 0 ]; then echo -e "${YELLOW}未找到相关日志记录。${NC}"; sleep 2; return; fi
    
    local page_size=10 total_pages=$(( (total_records + page_size - 1) / page_size )) current_page=1
    while true; do
        show_header
        echo -e "${YELLOW}====== SSH 登录日志 ($log_type) | 总计: $total_records 条 | 页面: $current_page/$total_pages ======${NC}"
        printf "%-20s %-15s %-20s %-10s\n" "时间" "用户名" "来源IP" "状态"; echo "-----------------------------------------------------------------"
        
        local start_index=$(( (current_page - 1) * page_size ))
        for i in $(seq 0 $((page_size - 1))); do
            local index=$((start_index + i)); [ $index -ge $total_records ] && break
            local parsed_line=$(echo "${logs[$index]}" | awk '
                /Accepted/ { printf "%-20s %-15s %-20s %-10s", ($1 " " $2 " " $3), $9, $11, "成功"; }
                /Failed password/ { 
                    user = ($9 == "invalid") ? "invalid_user(" $10 ")" : $9; 
                    ip = ($9 == "invalid") ? $12 : $11;
                    printf "%-20s %-15s %-20s %-10s", ($1 " " $2 " " $3), user, ip, "失败"; 
                }')
            echo -e "${GREEN}${parsed_line}${NC}"
        done
        echo "-----------------------------------------------------------------"
        
        local options=""; [[ $current_page -lt $total_pages ]] && options+="[1]下一页  "; [[ $current_page -gt 1 ]] && options+="[2]上一页  "; options+="[0]返回"
        echo -e "${YELLOW}${options}${NC}"; read -p "请输入选项: " page_choice < /dev/tty
        case $page_choice in 1) [[ $current_page -lt $total_pages ]] && ((current_page++));; 2) [[ $current_page -gt 1 ]] && ((current_page--));; 0) return;; esac
    done
}

function list_used_ports() {
    show_header
    echo -e "${YELLOW}====== 列出已占用的端口 ======${NC}"
    if ! command -v ss &>/dev/null && ! command -v netstat &>/dev/null; then echo -e "${RED}未找到 ss 或 netstat 命令。${NC}"; else
        printf "%-10s %-25s %s\n" "协议" "端口" "进程"; echo "-----------------------------------------------------"
        if command -v ss &>/dev/null; then
            ss -tulnp | tail -n +2 | awk '{proto=$1; split($5,a,":"); port=a[length(a)]; match($7,/"([^"]+)"/); proc=substr($7,RSTART+1,RLENGTH-2); if(proc==""){proc="-"} if(!seen[proto,port,proc]++){printf "%-10s %-25s %s\n", proto, port, proc}}'
        else
            netstat -tulnp | tail -n +3 | awk '{proto=$1; split($4,a,":"); port=a[length(a)]; split($7,p,"/"); proc=p[2]; if(proc==""){proc="-"} if(!seen[proto,port,proc]++){printf "%-10s %-25s %s\n", proto, port, proc}}'
        fi
    fi
    press_any_key; network_tools_menu
}

function bbr_management_menu() {
    show_header
    echo -e "${YELLOW}====== BBR网络加速管理 ======${NC}"
    echo -e "${GREEN}1. 查看BBR状态${NC}"; echo -e "${GREEN}2. 开启BBR${NC}"
    echo -e "${GREEN}3. 关闭BBR${NC}"; echo -e "${GREEN}0. 返回上一级菜单${NC}"
    echo -e "${CYAN}==============================================${NC}"
    read -p "请输入选项 [0-3]: " choice < /dev/tty
    case $choice in
        1) _view_bbr_status ;;
        2) _enable_bbr ;;
        3) _disable_bbr ;;
        0) network_tools_menu; return ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1; bbr_management_menu ;;
    esac
    press_any_key; bbr_management_menu
}

function _view_bbr_status() {
    local status=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    local qdisc=$(sysctl net.core.default_qdisc | awk '{print $3}')
    echo -e "${YELLOW}====== BBR 状态 ======${NC}"
    if [[ "$status" == "bbr" ]]; then echo -e "BBR 状态: ${GREEN}已开启${NC}"; else echo -e "BBR 状态: ${RED}未开启${NC} (当前: ${YELLOW}${status}${NC})"; fi
    if [[ "$qdisc" == "fq" || "$qdisc" == "fq_codel" ]]; then echo -e "队列算法: ${GREEN}${qdisc}${NC}"; else echo -e "队列算法: ${YELLOW}${qdisc}${NC} (推荐 fq/fq_codel)"; fi
    echo -e "\n${CYAN}--- 内核模块 & 系统配置 ---${NC}"
    lsmod | grep bbr; sysctl net.ipv4.tcp_congestion_control; sysctl net.core.default_qdisc
}

function _enable_bbr() {
    if [[ "$OS_TYPE" == "centos" && "$OS_VERSION" == "7" && "$(uname -r | cut -d. -f1)" -lt 4 ]]; then
        echo -e "${RED}CentOS 7 内核过低，需升级内核开启BBR。${NC}"
        read -p "是否现在升级内核？ (y/N): " confirm < /dev/tty
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
            yum install -y https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
            yum --enablerepo=elrepo-kernel install -y kernel-ml
            grub2-set-default 0
            echo -e "${GREEN}内核升级完成！${NC} ${RED}请立即重启(reboot)，然后重跑脚本开启BBR。${NC}"
        else echo -e "${YELLOW}操作已取消。${NC}"; fi; return
    fi
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
    echo -e "${GREEN}BBR 已开启，配置已写入 /etc/sysctl.conf。${NC}"
}

function _disable_bbr() {
    sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
    echo -e "${GREEN}BBR 已关闭，配置已从 /etc/sysctl.conf 移除。${NC}"
}
