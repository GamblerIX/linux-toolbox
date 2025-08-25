#!/bin/bash

set -Eeuo pipefail
IFS=$'\n\t'

trap 'ltbx_error_handler "${BASH_SOURCE[0]}" "${LINENO}" "${FUNCNAME[0]:-main}" "$?"' ERR

function ltbx_network_tools_menu() {
    ltbx_show_header
    printf "${YELLOW}====== 网络与安全工具 ======${NC}\n"
    printf "${GREEN} 1. 网络速度测试${NC}\n"
    printf "${GREEN} 2. 查看SSH登录日志${NC}\n"
    printf "${GREEN} 3. 防火墙管理${NC}\n"
    printf "${GREEN} 4. BBR网络加速管理${NC}\n"
    printf "${GREEN} 5. 列出已占用端口${NC}\n"
    printf "${GREEN} 6. 终止端口占用进程${NC}\n"
    printf "${GREEN} 0. 返回主菜单${NC}\n"
    printf "${CYAN}==============================================${NC}\n"

    if [ "${LTBX_NON_INTERACTIVE:-false}" = "true" ]; then
        ltbx_log "WARN" "非交互模式，跳过网络工具菜单"
        return 1
    fi

    local choice
    read -p " 请输入选项 [0-6]: " choice < /dev/tty
    case $choice in
        1) ltbx_network_speed_test_menu ;;
        2) ltbx_view_ssh_logs_menu ;;
        3) ltbx_firewall_management_menu ;;
        4) ltbx_bbr_management_menu ;;
        5) ltbx_list_used_ports ;;
        6) ltbx_kill_port_menu ;;
        0) return ;;
        *) printf "${RED}无效选项${NC}\n"; sleep 1; ltbx_network_tools_menu ;;
    esac
}

function ltbx_network_speed_test_menu() {
    if [[ "${LTBX_NON_INTERACTIVE:-false}" == "true" ]]; then
        ltbx_log "WARN" "Non-interactive mode detected, skipping network speed test menu"
        return 1
    fi

    local choice
    ltbx_show_header
    printf "${YELLOW}====== 网络速度测试 ======${NC}\n"
    printf "${GREEN} 1. 使用 speedtest-cli 测试${NC}\n"
    printf "${GREEN} 2. 使用 Superbench 综合测试${NC}\n"
    printf "${GREEN} 0. 返回上一级菜单${NC}\n"
    printf "${CYAN}==============================================${NC}\n\n"

    read -p " 请输入选项 [0-2]: " choice < /dev/tty
    case $choice in
        1) ltbx_run_speedtest_cli ;;
        2) ltbx_run_superbench ;;
        0) ltbx_network_tools_menu; return ;;
        *) printf "${RED}无效选项${NC}\n"; sleep 1; ltbx_network_speed_test_menu ;;
    esac
    ltbx_press_any_key
    ltbx_network_tools_menu
}

function ltbx_run_speedtest_cli() {
    local install_speedtest speedtest_output ping download upload

    ltbx_show_header
    printf "${YELLOW}====== 网络速度测试 (Speedtest-cli) ======${NC}\n"

    if ! command -v speedtest-cli &> /dev/null; then
        read -p "speedtest-cli 未安装, 是否立即安装? (y/N): " install_speedtest < /dev/tty
        if [[ "$install_speedtest" =~ ^[Yy]$ ]]; then
            printf "${CYAN}正在安装 speedtest-cli...${NC}\n"
            case "${LTBX_OS_TYPE:-}" in
                ubuntu|debian) apt-get update 2>/dev/null && apt-get install -y speedtest-cli 2>/dev/null ;;
                *) yum install -y speedtest-cli 2>/dev/null ;;
            esac
        else
            printf "已跳过网络测试。\n"
            return
        fi
    fi

    if command -v speedtest-cli &> /dev/null; then
        printf "正在使用 speedtest-cli 测试网络, 请稍候...\n"
speedtest_output=$(speedtest-cli --simple 2>/dev/null)
        if [ -n "$speedtest_output" ]; then
ping=$(echo "$speedtest_output" | grep "Ping" | awk -F': ' '{print $2}')
download=$(echo "$speedtest_output" | grep "Download" | awk -F': ' '{print $2}')
upload=$(echo "$speedtest_output" | grep "Upload" | awk -F': ' '{print $2}')
            printf "  %-12s %s\n" "延迟:" "$ping"
            printf "  %-12s %s\n" "下载速度:" "$download"
            printf "  %-12s %s\n" "上传速度:" "$upload"
        else
            printf "  ${RED}网络测试失败, 请检查网络或尝试使用 Superbench。${NC}\n"
        fi
    fi
}

function ltbx_run_superbench() {
    ltbx_show_header
    printf "${YELLOW}====== 综合性能测试 (Superbench) ======${NC}\n"
    printf "${CYAN}即将执行本地集成的 Superbench 测试脚本...${NC}\n"
    printf "测试将需要几分钟时间，请耐心等待。\n"
    sleep 2

    if command -v run_superbench_test &> /dev/null; then
        run_superbench_test
    else
        printf "${RED}错误: 未找到 'run_superbench_test' 函数。${NC}\n"
        printf "${YELLOW}请确保 lib_superbench.sh 已正确安装并被 tool.sh 加载。${NC}\n"
    fi
}

function ltbx_view_ssh_logs_menu() {
    if [[ "${LTBX_NON_INTERACTIVE:-false}" == "true" ]]; then
        ltbx_log "WARN" "Non-interactive mode detected, skipping SSH logs menu"
        return 1
    fi

    local choice
    while true; do
        ltbx_show_header
        printf "${YELLOW}====== 查看SSH登录日志 ======${NC}\n"
        printf "${GREEN} 1. 查看成功登录记录${NC}\n"
        printf "${GREEN} 2. 查看失败登录记录${NC}\n"
        printf "${GREEN} 3. 查看所有登录记录${NC}\n"
        printf "${GREEN} 0. 返回上一级菜单${NC}\n"
        printf "${CYAN}==============================================${NC}\n"
        read -p " 请输入选项 [0-3]: " choice < /dev/tty
        case $choice in
            1) ltbx_display_ssh_logs "success" ;;
            2) ltbx_display_ssh_logs "failure" ;;
            3) ltbx_display_ssh_logs "all" ;;
            0) break ;;
            *) printf "${RED}无效选项${NC}\n"; sleep 1 ;;
        esac
    done
    ltbx_network_tools_menu
}

function ltbx_display_ssh_logs() {
    local log_type=$1
    local log_file=""
    local success_pattern="Accepted" failure_pattern="Failed password" raw_logs=""
    local total_records page_size=10

    if [[ "${LTBX_OS_TYPE:-}" == "ubuntu" || "${LTBX_OS_TYPE:-}" == "debian" ]]; then
log_file="/var/log/auth.log"
    else
log_file="/var/log/secure"
    fi

    if [ ! -f "$log_file" ]; then
        printf "${RED}错误: 日志文件 $log_file 未找到。${NC}\n"
        sleep 2
        return
    fi

    case $log_type in
        "success") raw_logs=$(grep -a "$success_pattern" "$log_file" 2>/dev/null);;
        "failure") raw_logs=$(grep -a "$failure_pattern" "$log_file" 2>/dev/null);;
        "all") raw_logs=$(grep -a -E "$success_pattern|$failure_pattern" "$log_file" 2>/dev/null);;
    esac

    if [ -z "$raw_logs" ]; then
        printf "${YELLOW}未找到相关日志记录。${NC}\n"
        sleep 2
        return
    fi

    mapfile -t logs < <(echo "$raw_logs" | sort -r)

    total_records=${#logs[@]}
    local total_pages=$(( (total_records + page_size - 1) / page_size ))
    local current_page=1 page_choice start_index i index parsed_line options

    while true; do
        ltbx_show_header
        printf "${YELLOW}====== SSH 登录日志 ($log_type) | 总计: $total_records 条 | 页面: $current_page/$total_pages ======${NC}\n"
        printf "%-20s %-15s %-20s %-10s\n" "时间" "用户名" "来源IP" "状态"
        printf "-----------------------------------------------------------------\n"

        start_index=$(( (current_page - 1) * page_size ))
        for i in $(seq 0 $((page_size - 1))); do
            index=$((start_index + i))
            [ $index -ge $total_records ] && break

            parsed_line=$(echo "${logs[$index]}" | awk '
                /Accepted/ { printf "%-20s %-15s %-20s %-10s", ($1 " " $2 " " $3), $9, $11, "成功"; }
                /Failed password/ {
                    user=($9 == "invalid") ? "invalid(" $10 ")" : $9;
                    ip=($9 == "invalid") ? $12 : $11;
                    printf "%-20s %-15s %-20s %-10s", ($1 " " $2 " " $3), user, ip, "失败";
                }')

            if [[ "$parsed_line" == *"成功"* ]]; then
                printf "${GREEN}${parsed_line}${NC}\n"
            else
                printf "${RED}${parsed_line}${NC}\n"
            fi
        done
        printf "-----------------------------------------------------------------\n"

options=""
        [[ $current_page -lt $total_pages ]] && options+="[1]下一页  "
        [[ $current_page -gt 1 ]] && options+="[2]上一页  "
        options+="[0]返回"
        printf "${YELLOW}${options}${NC}\n"
        read -p " 请输入选项: " page_choice < /dev/tty
        case $page_choice in
            1) [[ $current_page -lt $total_pages ]] && ((current_page++));;
            2) [[ $current_page -gt 1 ]] && ((current_page--));;
            0) return;;
        esac
    done
}

function ltbx_list_used_ports() {
    ltbx_show_header
    printf "${YELLOW}====== 列出已占用的端口 ======${NC}\n"

    if ! command -v ss &>/dev/null && ! command -v netstat &>/dev/null; then
        printf "${RED}未找到 ss 或 netstat 命令。${NC}\n"
    else
        printf "%-10s %-25s %s\n" "协议" "端口" "进程"
        printf "-----------------------------------------------------\n"
        if command -v ss &>/dev/null; then
            ss -tulnp 2>/dev/null | tail -n +2 | awk '{proto=$1; split($5,a,":"); port=a[length(a)]; match($7,/"([^"]+)"/); proc=substr($7,RSTART+1,RLENGTH-2); if(proc=="") {proc="-"} if(!seen[proto,port,proc]++) {printf "%-10s %-25s %s\n", proto, port, proc}}'
        else
            netstat -tulnp 2>/dev/null | tail -n +3 | awk '{proto=$1; split($4,a,":"); port=a[length(a)]; split($7,p,"/"); proc=p[2]; if(proc=="") {proc="-"} if(!seen[proto,port,proc]++) {printf "%-10s %-25s %s\n", proto, port, proc}}'
        fi
    fi

    ltbx_press_any_key
    ltbx_network_tools_menu
}

function ltbx_kill_port_process() {
    local port=$1
    local pids
    
    if [[ -z "$port" ]]; then
        printf "${RED}错误: 请提供端口号${NC}\n"
        return 1
    fi
    
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        printf "${RED}错误: 端口号必须是数字${NC}\n"
        return 1
    fi
    
    printf "${YELLOW}正在查找占用端口 $port 的进程...${NC}\n"
    
    if command -v ss &>/dev/null; then
        pids=$(ss -tulnp 2>/dev/null | awk -v port="$port" '$5 ~ ":"port"$" {match($7,/pid=([0-9]+)/,a); if(a[1]) print a[1]}' | sort -u)
    elif command -v netstat &>/dev/null; then
        pids=$(netstat -tulnp 2>/dev/null | awk -v port="$port" '$4 ~ ":"port"$" {split($7,p,"/"); if(p[1] && p[1] != "-") print p[1]}' | sort -u)
    else
        printf "${RED}未找到 ss 或 netstat 命令${NC}\n"
        return 1
    fi
    
    if [[ -z "$pids" ]]; then
        printf "${YELLOW}端口 $port 未被占用${NC}\n"
        return 0
    fi
    
    printf "${CYAN}找到以下进程占用端口 $port:${NC}\n"
    for pid in $pids; do
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            local cmd_info
            cmd_info=$(ps -p "$pid" -o pid,ppid,cmd --no-headers 2>/dev/null || echo "$pid - 未知进程")
            printf "  PID: %s - %s\n" "$pid" "$cmd_info"
        fi
    done
    
    if [[ "${LTBX_NON_INTERACTIVE:-false}" == "true" ]]; then
        printf "${YELLOW}非交互模式，跳过确认直接终止进程${NC}\n"
        local confirm="y"
    else
        local confirm
        read -p "${RED}确定要终止这些进程吗? (y/N): ${NC}" confirm < /dev/tty
    fi
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        for pid in $pids; do
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                if kill "$pid" 2>/dev/null; then
                    printf "${GREEN}已终止进程 PID: $pid${NC}\n"
                    sleep 1
                    if kill -0 "$pid" 2>/dev/null; then
                        printf "${YELLOW}进程 $pid 仍在运行，强制终止...${NC}\n"
                        kill -9 "$pid" 2>/dev/null && printf "${GREEN}强制终止成功${NC}\n" || printf "${RED}强制终止失败${NC}\n"
                    fi
                else
                    printf "${RED}终止进程 $pid 失败${NC}\n"
                fi
            fi
        done
    else
        printf "${YELLOW}已取消操作${NC}\n"
    fi
}

function ltbx_kill_port_menu() {
    ltbx_show_header
    printf "${YELLOW}====== 终止端口占用进程 ======${NC}\n"
    
    if [[ "${LTBX_NON_INTERACTIVE:-false}" == "true" ]]; then
        printf "${RED}错误: 此功能需要交互模式${NC}\n"
        return 1
    fi
    
    local port
    read -p "请输入要释放的端口号: " port < /dev/tty
    
    if [[ -n "$port" ]]; then
        ltbx_kill_port_process "$port"
    else
        printf "${RED}端口号不能为空${NC}\n"
    fi
    
    ltbx_press_any_key
    ltbx_network_tools_menu
}

function ltbx_bbr_management_menu() {
    if [[ "${LTBX_NON_INTERACTIVE:-false}" == "true" ]]; then
        ltbx_log "WARN" "Non-interactive mode detected, skipping BBR management menu"
        return 1
    fi

    local choice
    ltbx_show_header
    printf "${YELLOW}====== BBR网络加速管理 ======${NC}\n"
    printf "${GREEN} 1. 查看BBR状态${NC}\n"
    printf "${GREEN} 2. 开启BBR${NC}\n"
    printf "${GREEN} 3. 关闭BBR${NC}\n"
    printf "${GREEN} 0. 返回上一级菜单${NC}\n"
    printf "${CYAN}==============================================${NC}\n"
    read -p " 请输入选项 [0-3]: " choice < /dev/tty
    case $choice in
        1) ltbx_view_bbr_status ;;
        2) ltbx_enable_bbr ;;
        3) ltbx_disable_bbr ;;
        0) ltbx_network_tools_menu; return ;;
        *) printf "${RED}无效选项${NC}\n"; sleep 1; ltbx_bbr_management_menu ;;
    esac
    ltbx_press_any_key
    ltbx_bbr_management_menu
}

function ltbx_view_bbr_status() {
    local status qdisc
    status=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    qdisc=$(sysctl net.core.default_qdisc 2>/dev/null | awk '{print $3}')

    printf "${YELLOW}====== BBR 状态 ======${NC}\n"
    if [[ "$status" == "bbr" ]]; then
        printf " BBR 状态: ${GREEN}已开启${NC}\n"
    else
        printf " BBR 状态: ${RED}未开启${NC} (当前: ${YELLOW}${status}${NC})\n"
    fi

    if [[ "$qdisc" == "fq" || "$qdisc" == "fq_codel" ]]; then
        printf " 队列算法: ${GREEN}${qdisc}${NC}\n"
    else
        printf " 队列算法: ${YELLOW}${qdisc}${NC} (推荐 fq/fq_codel)\n"
    fi

    printf "\n${CYAN}--- 内核模块 & 系统配置 ---${NC}\n"
    lsmod | grep bbr 2>/dev/null || true
    sysctl net.ipv4.tcp_congestion_control 2>/dev/null || true
    sysctl net.core.default_qdisc 2>/dev/null || true
}

function ltbx_enable_bbr() {
    local confirm
    printf "${YELLOW}====== 开启 BBR ======${NC}\n"

    if [[ "$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')" == "bbr" ]]; then
        printf "${GREEN}BBR 已经开启${NC}\n"
        return
    fi

    if [[ "${LTBX_OS_TYPE:-}" == "centos" && "${LTBX_OS_VERSION:-}" == "7" && "$(uname -r | cut -d. -f1)" -lt 4 ]]; then
        printf "${RED}CentOS 7 内核过低，需升级内核开启BBR。${NC}\n"
        read -p "是否现在升级内核？ (y/N): " confirm < /dev/tty
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            printf "${CYAN}正在升级内核...${NC}\n"
            rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org 2>/dev/null || true
            yum install -y https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm 2>/dev/null || true
            yum --enablerepo=elrepo-kernel install -y kernel-ml 2>/dev/null || true
            grub2-set-default 0 2>/dev/null || true
            printf "${GREEN}内核升级完成！${NC} ${RED}请立即重启(reboot)，然后重跑脚本开启BBR。${NC}\n"
        else
            printf "${YELLOW}操作已取消。${NC}\n"
        fi
        return
    fi

    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf 2>/dev/null || true
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1 || true
    printf "${GREEN}BBR 已开启，配置已写入 /etc/sysctl.conf。${NC}\n"
}

function ltbx_disable_bbr() {
    printf "${YELLOW}====== 关闭 BBR ======${NC}\n"

    if [[ "$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')" != "bbr" ]]; then
        printf "${YELLOW}BBR 未开启${NC}\n"
        return
    fi

    sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf 2>/dev/null || true
    sysctl -p >/dev/null 2>&1 || true
    printf "${GREEN}BBR 已关闭，配置已从 /etc/sysctl.conf 移除。${NC}\n"
}
