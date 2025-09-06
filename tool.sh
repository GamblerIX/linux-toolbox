#!/bin/bash

VERSION="1.0.1"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}请使用root权限运行此脚本${NC}"
        exit 1
    fi
}

get_system_info() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [[ -f /etc/redhat-release ]]; then
        OS="CentOS"
        VER=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release))
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
}

install_package() {
    local package=$1
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y "$package"
    elif command -v yum >/dev/null 2>&1; then
        yum install -y "$package"
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y "$package"
    else
        echo -e "${RED}不支持的包管理器${NC}"
        return 1
    fi
}

check_service_status() {
    local service=$1
    if systemctl is-active --quiet "$service"; then
        echo -e "${GREEN}运行中${NC}"
    else
        echo -e "${RED}已停止${NC}"
    fi
}

firewall_menu() {
    while true; do
        clear
        echo -e "${CYAN}${BOLD}=== 防火墙管理 ===${NC}"
        echo -e "${WHITE}1.${NC} ${GREEN}查看防火墙状态${NC}"
        echo -e "${WHITE}2.${NC} ${GREEN}启动防火墙${NC}"
        echo -e "${WHITE}3.${NC} ${GREEN}停止防火墙${NC}"
        echo -e "${WHITE}4.${NC} ${GREEN}重启防火墙${NC}"
        echo -e "${WHITE}5.${NC} ${GREEN}查看防火墙规则${NC}"
        echo -e "${WHITE}0.${NC} ${YELLOW}返回上级菜单${NC}"
        echo -e "${BLUE}请选择操作:${NC} "
        read -r choice
        
        case $choice in
            1)
                echo -e "${CYAN}防火墙状态:${NC}"
                if command -v ufw >/dev/null 2>&1; then
                    ufw status
                elif command -v firewall-cmd >/dev/null 2>&1; then
                    firewall-cmd --state
                elif command -v iptables >/dev/null 2>&1; then
                    iptables -L
                else
                    echo -e "${RED}未找到防火墙工具${NC}"
                fi
                read -r -p "按回车继续..." _
                ;;
            2)
                echo -e "${CYAN}启动防火墙...${NC}"
                if command -v ufw >/dev/null 2>&1; then
                    ufw --force enable
                elif command -v firewall-cmd >/dev/null 2>&1; then
                    systemctl start firewalld
                    systemctl enable firewalld
                elif command -v iptables >/dev/null 2>&1; then
                    systemctl start iptables
                    systemctl enable iptables
                else
                    echo -e "${RED}未找到防火墙工具${NC}"
                fi
                read -r -p "按回车继续..." _
                ;;
            3)
                echo -e "${CYAN}停止防火墙...${NC}"
                if command -v ufw >/dev/null 2>&1; then
                    ufw --force disable
                elif command -v firewall-cmd >/dev/null 2>&1; then
                    systemctl stop firewalld
                    systemctl disable firewalld
                elif command -v iptables >/dev/null 2>&1; then
                    systemctl stop iptables
                    systemctl disable iptables
                else
                    echo -e "${RED}未找到防火墙工具${NC}"
                fi
                read -r -p "按回车继续..." _
                ;;
            4)
                echo -e "${CYAN}重启防火墙...${NC}"
                if command -v ufw >/dev/null 2>&1; then
                    ufw --force disable
                    ufw --force enable
                elif command -v firewall-cmd >/dev/null 2>&1; then
                    systemctl restart firewalld
                elif command -v iptables >/dev/null 2>&1; then
                    systemctl restart iptables
                else
                    echo -e "${RED}未找到防火墙工具${NC}"
                fi
                read -r -p "按回车继续..." _
                ;;
            5)
                echo -e "${CYAN}防火墙规则:${NC}"
                if command -v ufw >/dev/null 2>&1; then
                    ufw status numbered
                elif command -v firewall-cmd >/dev/null 2>&1; then
                    firewall-cmd --list-all
                elif command -v iptables >/dev/null 2>&1; then
                    iptables -L -n
                else
                    echo -e "${RED}未找到防火墙工具${NC}"
                fi
                read -r -p "按回车继续..." _
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                read -r -p "按回车继续..." _
                ;;
        esac
    done
}

network_menu() {
    while true; do
        clear
        echo -e "${CYAN}${BOLD}=== 网络管理 ===${NC}"
        echo -e "${WHITE}1.${NC} ${GREEN}防火墙管理${NC}"
        echo -e "${WHITE}2.${NC} ${GREEN}端口管理${NC}"
        echo -e "${WHITE}3.${NC} ${GREEN}网络测试${NC}"
        echo -e "${WHITE}4.${NC} ${GREEN}查看网络连接${NC}"
        echo -e "${WHITE}5.${NC} ${GREEN}查看路由表${NC}"
        echo -e "${WHITE}0.${NC} ${YELLOW}返回上级菜单${NC}"
        echo -e "${BLUE}请选择操作:${NC} "
        read -r choice
        
        case $choice in
            1)
                firewall_menu
                ;;
            2)
                port_menu
                ;;
            3)
                echo -e "${CYAN}网络测试:${NC}"
                echo -e "${WHITE}1.${NC} ${GREEN}ping测试${NC}"
                echo -e "${WHITE}2.${NC} ${GREEN}网速测试${NC}"
                echo -e "${BLUE}请选择:${NC} "
                read -r test_choice
                case $test_choice in
                    1)
                        echo -e "${BLUE}请输入要ping的地址:${NC} "
                        read -r ping_addr
                        ping -c 4 "$ping_addr"
                        ;;
                    2)
                        if ! command -v speedtest-cli >/dev/null 2>&1; then
                            echo -e "${YELLOW}正在安装speedtest-cli...${NC}"
                            if command -v apt-get >/dev/null 2>&1; then
                                apt-get update && apt-get install -y speedtest-cli
                            elif command -v yum >/dev/null 2>&1; then
                                yum install -y epel-release
                                yum install -y python-pip
                                pip install speedtest-cli
                            elif command -v dnf >/dev/null 2>&1; then
                                dnf install -y python3-pip
                                pip3 install speedtest-cli
                            else
                                echo -e "${RED}无法安装speedtest-cli${NC}"
                                read -r -p "按回车继续..." _
                                continue
                            fi
                        fi
                        speedtest-cli
                        ;;
                esac
                read -r -p "按回车继续..." _
                ;;
            4)
                echo -e "${CYAN}网络连接:${NC}"
                netstat -tuln
                read -r -p "按回车继续..." _
                ;;
            5)
                echo -e "${CYAN}路由表:${NC}"
                route -n
                read -r -p "按回车继续..." _
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                read -r -p "按回车继续..." _
                ;;
        esac
    done
}

bbr_menu() {
    while true; do
        clear
        echo -e "${CYAN}${BOLD}=== BBR管理 ===${NC}"
        echo -e "${WHITE}1.${NC} ${GREEN}查看BBR状态${NC}"
        echo -e "${WHITE}2.${NC} ${GREEN}启用BBR${NC}"
        echo -e "${WHITE}3.${NC} ${GREEN}禁用BBR${NC}"
        echo -e "${WHITE}0.${NC} ${YELLOW}返回上级菜单${NC}"
        echo -e "${BLUE}请选择操作:${NC} "
        read -r choice
        
        case $choice in
            1)
                echo -e "${CYAN}BBR状态:${NC}"
                if lsmod | grep -q bbr; then
                    echo -e "${GREEN}BBR已启用${NC}"
                else
                    echo -e "${RED}BBR未启用${NC}"
                fi
                echo -e "${CYAN}当前拥塞控制算法:${NC}"
                sysctl net.ipv4.tcp_congestion_control
                read -r -p "按回车继续..." _
                ;;
            2)
                echo -e "${CYAN}启用BBR...${NC}"
                if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
                    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
                fi
                if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
                    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
                fi
                sysctl -p
                echo -e "${GREEN}BBR已启用${NC}"
                read -r -p "按回车继续..." _
                ;;
            3)
                echo -e "${CYAN}禁用BBR...${NC}"
                sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf
                sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
                sysctl -p
                echo -e "${GREEN}BBR已禁用${NC}"
                read -r -p "按回车继续..." _
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                read -r -p "按回车继续..." _
                ;;
        esac
    done
}

add_port_rule() {
    echo -e "${BLUE}请输入端口号:${NC} "
    read -r port
    
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${RED}无效的端口号，请输入1-65535之间的数字${NC}"
        return 1
    fi
    
    echo -e "${BLUE}请选择协议:${NC}"
    echo -e "${WHITE}1.${NC} ${GREEN}TCP${NC}"
    echo -e "${WHITE}2.${NC} ${GREEN}UDP${NC}"
    echo -e "${WHITE}3.${NC} ${GREEN}TCP和UDP${NC}"
    echo -e "${BLUE}请选择:${NC} "
    read -r protocol_choice
    
    case $protocol_choice in
        1)
            protocol="tcp"
            ;;
        2)
            protocol="udp"
            ;;
        3)
            protocol="both"
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            return 1
            ;;
    esac
    
    if command -v ufw >/dev/null 2>&1; then
        if [ "$protocol" = "both" ]; then
            ufw allow "$port"/tcp
            ufw allow "$port"/udp
        else
            ufw allow "$port"/"$protocol"
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        if [ "$protocol" = "both" ]; then
            firewall-cmd --permanent --add-port="$port"/tcp
            firewall-cmd --permanent --add-port="$port"/udp
        else
            firewall-cmd --permanent --add-port="$port"/"$protocol"
        fi
        firewall-cmd --reload
    else
        echo -e "${RED}未找到防火墙工具${NC}"
        return 1
    fi
    
    echo -e "${GREEN}端口规则添加成功${NC}"
}

port_menu() {
    while true; do
        clear
        echo -e "${CYAN}${BOLD}=== 端口管理 ===${NC}"
        echo -e "${WHITE}1.${NC} ${GREEN}查看开放端口${NC}"
        echo -e "${WHITE}2.${NC} ${GREEN}添加端口规则${NC}"
        echo -e "${WHITE}3.${NC} ${GREEN}删除端口规则${NC}"
        echo -e "${WHITE}0.${NC} ${YELLOW}返回上级菜单${NC}"
        echo -e "${BLUE}请选择操作:${NC} "
        read -r choice
        
        case $choice in
            1)
                echo -e "${CYAN}开放端口:${NC}"
                if command -v ufw >/dev/null 2>&1; then
                    ufw status numbered
                elif command -v firewall-cmd >/dev/null 2>&1; then
                    firewall-cmd --list-ports
                else
                    netstat -tuln
                fi
                read -r -p "按回车继续..." _
                ;;
            2)
                add_port_rule
                read -r -p "按回车继续..." _
                ;;
            3)
                echo -e "${BLUE}请输入要删除的端口号:${NC} "
                read -r port
                if command -v ufw >/dev/null 2>&1; then
                    ufw delete allow "$port"
                elif command -v firewall-cmd >/dev/null 2>&1; then
                    firewall-cmd --permanent --remove-port="$port"/tcp
                    firewall-cmd --permanent --remove-port="$port"/udp
                    firewall-cmd --reload
                else
                    echo -e "${RED}未找到防火墙工具${NC}"
                fi
                read -r -p "按回车继续..." _
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                read -r -p "按回车继续..." _
                ;;
        esac
    done
}

user_menu() {
    while true; do
        clear
        echo -e "${CYAN}${BOLD}=== 用户管理 ===${NC}"
        echo -e "${WHITE}1.${NC} ${GREEN}查看用户列表${NC}"
        echo -e "${WHITE}2.${NC} ${GREEN}添加用户${NC}"
        echo -e "${WHITE}3.${NC} ${GREEN}删除用户${NC}"
        echo -e "${WHITE}4.${NC} ${GREEN}修改用户密码${NC}"
        echo -e "${WHITE}5.${NC} ${GREEN}查看登录日志${NC}"
        echo -e "${WHITE}0.${NC} ${YELLOW}返回上级菜单${NC}"
        echo -e "${BLUE}请选择操作:${NC} "
        read -r choice
        
        case $choice in
            1)
                echo -e "${CYAN}用户列表:${NC}"
                cat /etc/passwd | grep -E "/(bin/bash|bin/sh)$" | cut -d: -f1
                read -r -p "按回车继续..." _
                ;;
            2)
                echo -e "${BLUE}请输入用户名:${NC} "
                read -r username
                
                if ! [[ "$username" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
                    echo -e "${RED}无效的用户名格式${NC}"
                    read -r -p "按回车继续..." _
                    continue
                fi
                
                if id "$username" >/dev/null 2>&1; then
                    echo -e "${RED}用户已存在${NC}"
                    read -r -p "按回车继续..." _
                    continue
                fi
                
                useradd -m -s /bin/bash "$username"
                echo -e "${BLUE}请设置用户密码:${NC}"
                passwd "$username"
                echo -e "${GREEN}用户创建成功${NC}"
                read -r -p "按回车继续..." _
                ;;
            3)
                echo -e "${BLUE}请输入要删除的用户名:${NC} "
                read -r username
                
                if ! id "$username" >/dev/null 2>&1; then
                    echo -e "${RED}用户不存在${NC}"
                    read -r -p "按回车继续..." _
                    continue
                fi
                
                echo -e "${YELLOW}确认删除用户 $username 吗？(y/N):${NC} "
                read -r confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    userdel -r "$username"
                    echo -e "${GREEN}用户删除成功${NC}"
                else
                    echo -e "${YELLOW}操作已取消${NC}"
                fi
                read -r -p "按回车继续..." _
                ;;
            4)
                echo -e "${BLUE}请输入用户名:${NC} "
                read -r username
                
                if ! id "$username" >/dev/null 2>&1; then
                    echo -e "${RED}用户不存在${NC}"
                    read -r -p "按回车继续..." _
                    continue
                fi
                
                passwd "$username"
                read -r -p "按回车继续..." _
                ;;
            5)
                echo -e "${CYAN}登录日志:${NC}"
                if [[ -f /var/log/auth.log ]]; then
                    tail -20 /var/log/auth.log | grep -E "(sshd|login)"
                elif [[ -f /var/log/secure ]]; then
                    tail -20 /var/log/secure | grep -E "(sshd|login)"
                else
                    echo -e "${RED}未找到登录日志文件${NC}"
                fi
                read -r -p "按回车继续..." _
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                read -r -p "按回车继续..." _
                ;;
        esac
    done
}

system_menu() {
    while true; do
        clear
        echo -e "${CYAN}${BOLD}=== 系统管理 ===${NC}"
        echo -e "${WHITE}1.${NC} ${GREEN}用户管理${NC}"
        echo -e "${WHITE}2.${NC} ${GREEN}网络管理${NC}"
        echo -e "${WHITE}3.${NC} ${GREEN}BBR管理${NC}"
        echo -e "${WHITE}4.${NC} ${GREEN}系统信息${NC}"
        echo -e "${WHITE}5.${NC} ${GREEN}系统更新${NC}"
        echo -e "${WHITE}6.${NC} ${GREEN}清理系统${NC}"
        echo -e "${WHITE}0.${NC} ${YELLOW}返回主菜单${NC}"
        echo -e "${BLUE}请选择操作:${NC} "
        read -r choice
        
        case $choice in
            1)
                user_menu
                ;;
            2)
                network_menu
                ;;
            3)
                bbr_menu
                ;;
            4)
                echo -e "${CYAN}系统信息:${NC}"
                get_system_info
                echo -e "${WHITE}操作系统:${NC} $OS"
                echo -e "${WHITE}版本:${NC} $VER"
                echo -e "${WHITE}内核版本:${NC} $(uname -r)"
                echo -e "${WHITE}CPU信息:${NC}"
                grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2
                echo -e "${WHITE}内存信息:${NC}"
                free -h
                echo -e "${WHITE}磁盘信息:${NC}"
                df -h
                read -r -p "按回车继续..." _
                ;;
            5)
                echo -e "${CYAN}系统更新...${NC}"
                if command -v apt-get >/dev/null 2>&1; then
                    apt-get update && apt-get upgrade -y
                elif command -v yum >/dev/null 2>&1; then
                    yum update -y
                elif command -v dnf >/dev/null 2>&1; then
                    dnf update -y
                else
                    echo -e "${RED}不支持的包管理器${NC}"
                fi
                read -r -p "按回车继续..." _
                ;;
            6)
                echo -e "${CYAN}清理系统...${NC}"
                if command -v apt-get >/dev/null 2>&1; then
                    apt-get autoremove -y
                    apt-get autoclean
                elif command -v yum >/dev/null 2>&1; then
                    yum autoremove -y
                    yum clean all
                elif command -v dnf >/dev/null 2>&1; then
                    dnf autoremove -y
                    dnf clean all
                else
                    echo -e "${RED}不支持的包管理器${NC}"
                fi
                echo -e "${GREEN}系统清理完成${NC}"
                read -r -p "按回车继续..." _
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                read -r -p "按回车继续..." _
                ;;
        esac
    done
}

install_bt_panel() {
    echo -e "${CYAN}${BOLD}=== 宝塔面板安装 ===${NC}"
    echo -e "${WHITE}1.${NC} ${GREEN}最新正式版${NC}"
    echo -e "${WHITE}2.${NC} ${GREEN}最新测试版${NC}"
    echo -e "${WHITE}0.${NC} ${YELLOW}返回上级菜单${NC}"
    echo -e "${BLUE}请选择版本:${NC} "
    read -r bt_choice
    
    case $bt_choice in
        1)
            echo -e "${CYAN}正在安装宝塔面板最新正式版...${NC}"
            temp_dir=$(mktemp -d)
            cd "$temp_dir" || { echo -e "${RED}创建临时目录失败${NC}"; return 1; }
            
            if command -v curl >/dev/null 2>&1; then
                curl -sSO http://download.bt.cn/install/install_panel.sh
            elif command -v wget >/dev/null 2>&1; then
                wget -q http://download.bt.cn/install/install_panel.sh
            else
                echo -e "${RED}未找到curl或wget，无法下载安装脚本${NC}"
                cd - >/dev/null
                rm -rf "$temp_dir"
                return 1
            fi
            
            if [[ ! -f install_panel.sh ]] || [[ ! -s install_panel.sh ]]; then
                echo -e "${RED}下载安装脚本失败${NC}"
                cd - >/dev/null
                rm -rf "$temp_dir"
                return 1
            fi
            
            chmod +x install_panel.sh
            
            if bash install_panel.sh; then
                echo -e "${GREEN}宝塔面板安装完成${NC}"
            else
                echo -e "${RED}宝塔面板安装失败${NC}"
            fi
            
            cd - >/dev/null
            rm -rf "$temp_dir"
            ;;
        2)
            echo -e "${CYAN}正在安装宝塔面板最新测试版...${NC}"
            if command -v curl >/dev/null 2>&1; then
                curl -sSO http://download.bt.cn/install/install_panel.sh && bash install_panel.sh
            elif command -v wget >/dev/null 2>&1; then
                wget -O install.sh http://download.bt.cn/install/install_panel.sh && bash install.sh
            else
                echo -e "${RED}未找到curl或wget${NC}"
            fi
            echo -e "${GREEN}安装脚本执行完成${NC}"
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            ;;
    esac
}

install_1panel() {
    echo -e "${CYAN}正在安装1Panel面板...${NC}"
    if command -v curl >/dev/null 2>&1; then
        curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh | bash
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- https://resource.fit2cloud.com/1panel/package/quick_start.sh | bash
    else
        echo -e "${RED}未找到curl或wget${NC}"
    fi
    echo -e "${GREEN}安装脚本执行完成${NC}"
}

install_singbox() {
    echo -e "${CYAN}正在安装Sing-box...${NC}"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL https://sing-box.sagernet.org/install.sh | bash
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- https://sing-box.sagernet.org/install.sh | bash
    else
        echo -e "${RED}未找到curl或wget${NC}"
    fi
    echo -e "${GREEN}安装脚本执行完成${NC}"
}

third_party_menu() {
    while true; do
        clear
        echo -e "${CYAN}${BOLD}=== 第三方工具安装 ===${NC}"
        echo -e "${WHITE}1.${NC} ${GREEN}宝塔面板${NC}"
        echo -e "${WHITE}2.${NC} ${GREEN}1Panel面板${NC}"
        echo -e "${WHITE}3.${NC} ${GREEN}Sing-box${NC}"
        echo -e "${WHITE}0.${NC} ${YELLOW}返回主菜单${NC}"
        echo -e "${BLUE}请选择要安装的工具:${NC} "
        read -r choice
        
        case $choice in
            1)
                install_bt_panel
                read -r -p "按回车继续..." _
                ;;
            2)
                install_1panel
                read -r -p "按回车继续..." _
                ;;
            3)
                install_singbox
                read -r -p "按回车继续..." _
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                read -r -p "按回车继续..." _
                ;;
        esac
    done
}

update_toolbox() {
    echo -e "${CYAN}正在更新工具箱...${NC}"
    if command -v curl >/dev/null 2>&1; then
        curl -o /tmp/tool.sh https://raw.githubusercontent.com/your-repo/linux-toolbox/main/tool.sh
    elif command -v wget >/dev/null 2>&1; then
        wget -O /tmp/tool.sh https://raw.githubusercontent.com/your-repo/linux-toolbox/main/tool.sh
    else
        echo -e "${RED}未找到curl或wget${NC}"
        return 1
    fi
    
    if [[ -f /tmp/tool.sh ]]; then
        chmod +x /tmp/tool.sh
        mv /tmp/tool.sh "$0"
        echo -e "${GREEN}工具箱更新完成${NC}"
        echo -e "${YELLOW}请重新运行脚本以使用新版本${NC}"
        exit 0
    else
        echo -e "${RED}更新失败${NC}"
        return 1
    fi
}

self_manage_menu() {
    while true; do
        clear
        echo -e "${CYAN}${BOLD}=== 工具箱管理 ===${NC}"
        echo -e "${WHITE}1.${NC} ${GREEN}安装/更新工具箱${NC}"
        echo -e "${WHITE}2.${NC} ${GREEN}查看版本信息${NC}"
        echo -e "${WHITE}3.${NC} ${GREEN}卸载工具箱${NC}"
        echo -e "${WHITE}0.${NC} ${YELLOW}返回主菜单${NC}"
        echo -e "${BLUE}请选择操作:${NC} "
        read -r choice
        
        case $choice in
            1)
                update_toolbox
                read -r -p "按回车继续..." _
                ;;
            2)
                echo -e "${CYAN}版本信息:${NC}"
                echo -e "${WHITE}工具箱版本:${NC} $VERSION"
                echo -e "${WHITE}脚本路径:${NC} $0"
                read -r -p "按回车继续..." _
                ;;
            3)
                echo -e "${YELLOW}确认卸载工具箱吗？(y/N):${NC} "
                read -r confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    rm -f "$0"
                    echo -e "${GREEN}工具箱已卸载${NC}"
                    exit 0
                else
                    echo -e "${YELLOW}操作已取消${NC}"
                fi
                read -r -p "按回车继续..." _
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                read -r -p "按回车继续..." _
                ;;
        esac
    done
}

main_menu() {
    while true; do
        clear
        echo -e "${PURPLE}${BOLD}╔══════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}${BOLD}║           Linux 服务器工具箱         ║${NC}"
        echo -e "${PURPLE}${BOLD}║              版本: $VERSION              ║${NC}"
        echo -e "${PURPLE}${BOLD}╚══════════════════════════════════════╝${NC}"
        echo
        echo -e "${WHITE}1.${NC} ${GREEN}工具箱管理${NC}"
        echo -e "${WHITE}2.${NC} ${GREEN}系统管理${NC}"
        echo -e "${WHITE}3.${NC} ${GREEN}第三方工具安装${NC}"
        echo -e "${WHITE}0.${NC} ${RED}退出${NC}"
        echo
        echo -e "${BLUE}请选择操作:${NC} "
        read -r choice
        
        case $choice in
            1)
                self_manage_menu
                ;;
            2)
                system_menu
                ;;
            3)
                third_party_menu
                ;;
            0)
                echo -e "${GREEN}感谢使用Linux服务器工具箱！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                read -r -p "按回车继续..." _
                ;;
        esac
    done
}

check_root
main_menu