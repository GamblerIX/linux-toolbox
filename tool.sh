#!/bin/bash
# -*- coding: utf-8 -*-

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

TOOLBOX_DIR="/etc/toolbox"
CONFIG_FILE="$TOOLBOX_DIR/config.cfg"
COUNTER_FILE="$TOOLBOX_DIR/counter"
OS_TYPE=""

function check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${YELLOW}检测到非root用户，正尝试提权至root...${NC}"
        exec sudo -i "$0" "$@"
    fi
}

function detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" == "ubuntu" ]; then
            OS_TYPE="ubuntu"
        elif [ "$ID" == "debian" ]; then
            OS_TYPE="debian"
        elif [ "$ID" == "centos" ]; then
            case "$VERSION_ID" in
                7) OS_TYPE="centos7" ;;
                8) OS_TYPE="centos8" ;;
                *) OS_TYPE="unsupported" ;;
            esac
        else
            OS_TYPE="unsupported"
        fi
    elif [ -f /etc/redhat-release ]; then
        if grep -q "CentOS release 7" /etc/redhat-release; then
            OS_TYPE="centos7"
        elif grep -q "CentOS Stream release 8" /etc/redhat-release; then
            OS_TYPE="centos8"
        else
            OS_TYPE="unsupported"
        fi
    else
        OS_TYPE="unsupported"
    fi

    if [ "$OS_TYPE" == "unsupported" ]; then
        echo -e "${RED}错误：此脚本仅支持 Ubuntu, Debian, CentOS 7/8 系统。${NC}"
        exit 1
    fi
}

init_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        INSTALLED=false
    fi
}

function show_header() {
    clear
    echo -e "${PURPLE}"
    echo -e "██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗"
    echo -e "██║     ██║████╗  ██║██║   ██║╚██╗██╔╝"
    echo -e "██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝ "
    echo -e "██║     ██║██║╚██╗██║██║   ██║ ██╔██╗ "
    echo -e "███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗"
    echo -e "╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "${CYAN}╔═══════════════╗${NC}"
    echo -e "${GREEN}  Linux工具箱 ${NC}"
    echo -e "${CYAN}╚═══════════════╝${NC}"
    
    if [ "$INSTALLED" = "true" ]; then
        echo -e "${BLUE}  运行模式: 已安装 (执行命令: tool) ${NC}"
    else
        echo -e "${BLUE}  运行模式: 直接运行 ${NC}"
    fi
    echo -e "${PURPLE}  检测到系统: ${OS_TYPE} ${NC}"
}

function network_speed_test() {
    show_header
    echo -e "${YELLOW}====== 网络速度测试 ======${NC}"
    
    if ! command -v speedtest-cli &> /dev/null; then
        read -p "speedtest-cli 未安装, 是否立即安装? (y/N): " install_speedtest < /dev/tty
        if [[ "$install_speedtest" =~ ^[Yy]$ ]]; then
            if [ "$OS_TYPE" == "ubuntu" ] || [ "$OS_TYPE" == "debian" ]; then
                apt-get update && apt-get install -y speedtest-cli
            else
                yum install -y speedtest-cli
            fi
        else
            echo "  已跳过网络测试。"
            read -p "按回车键返回..." < /dev/tty
            network_tools_menu
            return
        fi
    fi

    if command -v speedtest-cli &> /dev/null; then
        echo "  正在测试网络, 请稍候..."
        speedtest_output=$(speedtest-cli --simple 2>/dev/null)
        if [ -n "$speedtest_output" ]; then
            ping=$(echo "$speedtest_output" | grep "Ping" | awk -F': ' '{print $2}')
            download=$(echo "$speedtest_output" | grep "Download" | awk -F': ' '{print $2}')
            upload=$(echo "$speedtest_output" | grep "Upload" | awk -F': ' '{print $2}')
            
            printf "  %-12s %s\n" "延迟:" "$ping"
            printf "  %-12s %s\n" "下载速度:" "$download"
            printf "  %-12s %s\n" "上传速度:" "$upload"
        else
            echo -e "  ${RED}网络测试失败, 请检查网络连接。${NC}"
        fi
    fi

    echo
    read -p "按回车键返回..." < /dev/tty
    network_tools_menu
}

function clean_system() {
    show_header
    echo -e "${YELLOW}====== 清理系统垃圾 ======${NC}"
    echo -e "${BLUE}正在清理临时文件...${NC}"
    rm -rf /tmp/*
    rm -rf /var/tmp/*
    echo -e "${BLUE}正在清理旧的内核...${NC}"
    if [ "$OS_TYPE" == "ubuntu" ] || [ "$OS_TYPE" == "debian" ]; then
        apt autoremove --purge -y
    elif [ "$OS_TYPE" == "centos7" ]; then
        if ! command -v package-cleanup &> /dev/null; then
             echo -e "${YELLOW}正在安装 yum-utils...${NC}"
             yum install -y yum-utils
        fi
        package-cleanup --oldkernels --count=1 -y
    elif [ "$OS_TYPE" == "centos8" ]; then
        dnf autoremove -y
    fi
    echo -e "${BLUE}正在清理日志文件...${NC}"
    journalctl --vacuum-time=7d
    echo -e "${GREEN}系统垃圾清理完成！${NC}"
    read -p "按回车键返回..." < /dev/tty
    manage_tools
}

function _change_mirror_apt() {
    local mirror_base_url="$1"
    local mirror_name="$2"
    local codename=$(lsb_release -sc)
    
    echo -e "${CYAN}检测到 $OS_TYPE 系统，正在更换为 $mirror_name 源...${NC}"

    if [ "$OS_TYPE" == "ubuntu" ]; then
        cat > /etc/apt/sources.list <<EOF
deb ${mirror_base_url}/ubuntu/ ${codename} main restricted universe multiverse
deb ${mirror_base_url}/ubuntu/ ${codename}-security main restricted universe multiverse
deb ${mirror_base_url}/ubuntu/ ${codename}-updates main restricted universe multiverse
deb ${mirror_base_url}/ubuntu/ ${codename}-backports main restricted universe multiverse
deb-src ${mirror_base_url}/ubuntu/ ${codename} main restricted universe multiverse
deb-src ${mirror_base_url}/ubuntu/ ${codename}-security main restricted universe multiverse
deb-src ${mirror_base_url}/ubuntu/ ${codename}-updates main restricted universe multiverse
deb-src ${mirror_base_url}/ubuntu/ ${codename}-backports main restricted universe multiverse
EOF
    elif [ "$OS_TYPE" == "debian" ]; then
        local security_mirror_url=""
        if [[ $mirror_base_url == *"aliyun"* ]]; then
            security_mirror_url="http://mirrors.aliyun.com/debian-security"
        elif [[ $mirror_base_url == *"tencent"* ]]; then
            security_mirror_url="http://mirrors.tencent.com/debian-security"
        elif [[ $mirror_base_url == *"ustc"* ]]; then
            security_mirror_url="https://mirrors.ustc.edu.cn/debian-security"
        else
            security_mirror_url="http://security.debian.org/debian-security"
        fi
        
        local components="main contrib non-free non-free-firmware"

        cat > /etc/apt/sources.list <<EOF
deb ${mirror_base_url}/debian/ ${codename} ${components}
deb-src ${mirror_base_url}/debian/ ${codename} ${components}
deb ${security_mirror_url} ${codename}-security ${components}
deb-src ${security_mirror_url} ${codename}-security ${components}
deb ${mirror_base_url}/debian/ ${codename}-updates ${components}
deb-src ${mirror_base_url}/debian/ ${codename}-updates ${components}
deb ${mirror_base_url}/debian/ ${codename}-backports ${components}
deb-src ${mirror_base_url}/debian/ ${codename}-backports ${components}
EOF
    else
        echo -e "${RED}当前系统 ($OS_TYPE) 不适用于APT换源。${NC}"
        return 1
    fi
    
    apt-get update
    echo -e "${GREEN}$OS_TYPE 源已更换为 $mirror_name。${NC}"
    return 0
}

function _change_mirror_yum() {
    local mirror_base_url="$1"
    local mirror_name="$2"
    
    if [ "$OS_TYPE" != "centos7" ]; then
        echo -e "${RED}错误：此YUM换源功能目前仅支持 CentOS 7 系统。${NC}"
        return 1
    fi
    
    echo -e "${CYAN}检测到 CentOS 7 系统，正在更换为 $mirror_name 源...${NC}"
    mkdir -p /etc/yum.repos.d/backup
    mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/
    echo -e "${YELLOW}已备份原有源文件至 /etc/yum.repos.d/backup/${NC}"

    cat > /etc/yum.repos.d/CentOS-Base.repo <<EOF
[base]
name=CentOS-7 - Base - $mirror_name
baseurl=$mirror_base_url/centos/7/os/x86_64/
gpgcheck=1
gpgkey=$mirror_base_url/centos/RPM-GPG-KEY-CentOS-7
[updates]
name=CentOS-7 - Updates - $mirror_name
baseurl=$mirror_base_url/centos/7/updates/x86_64/
gpgcheck=1
gpgkey=$mirror_base_url/centos/RPM-GPG-KEY-CentOS-7
[extras]
name=CentOS-7 - Extras - $mirror_name
baseurl=$mirror_base_url/centos/7/extras/x86_64/
gpgcheck=1
gpgkey=$mirror_base_url/centos/RPM-GPG-KEY-CentOS-7
[centosplus]
name=CentOS-7 - Plus - $mirror_name
baseurl=$mirror_base_url/centos/7/centosplus/x86_64/
gpgcheck=1
gpgkey=$mirror_base_url/centos/RPM-GPG-KEY-CentOS-7
EOF

    yum clean all
    yum makecache
    echo -e "${GREEN}CentOS 7 源已更换为 $mirror_name。${NC}"
    return 0
}

function _restore_official_apt() {
    local codename=$(lsb_release -sc)
    echo -e "${YELLOW}检测到 $OS_TYPE 系统，恢复官方源...${NC}"
    
    if [ "$OS_TYPE" == "ubuntu" ]; then
        cat > /etc/apt/sources.list <<EOF
deb http://archive.ubuntu.com/ubuntu/ ${codename} main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${codename}-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${codename}-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${codename}-backports main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ ${codename} main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ ${codename}-security main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ ${codename}-updates main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ ${codename}-backports main restricted universe multiverse
EOF
    elif [ "$OS_TYPE" == "debian" ]; then
        local components="main contrib non-free non-free-firmware"
        cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian/ ${codename} ${components}
deb-src http://deb.debian.org/debian/ ${codename} ${components}
deb http://security.debian.org/debian-security/ ${codename}-security ${components}
deb-src http://security.debian.org/debian-security/ ${codename}-security ${components}
deb http://deb.debian.org/debian/ ${codename}-updates ${components}
deb-src http://deb.debian.org/debian/ ${codename}-updates ${components}
deb http://deb.debian.org/debian/ ${codename}-backports ${components}
deb-src http://deb.debian.org/debian/ ${codename}-backports ${components}
EOF
    else
        echo -e "${RED}无法为 $OS_TYPE 恢复官方源。${NC}"
        return 1
    fi
    apt-get update
    echo -e "${GREEN}$OS_TYPE 官方源已恢复。${NC}"
    return 0
}

function _restore_official_yum() {
    if [ "$OS_TYPE" != "centos7" ]; then
        echo -e "${RED}错误：此恢复官方源功能仅支持 CentOS 7 系统。${NC}"
        return 1
    fi

    echo -e "${YELLOW}检测到 CentOS 7 系统，正在恢复官方源...${NC}"
    mkdir -p /etc/yum.repos.d/backup
    mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/
    echo -e "${YELLOW}已备份原有源文件至 /etc/yum.repos.d/backup/${NC}"
    curl -o /etc/yum.repos.d/CentOS-Base.repo http://vault.centos.org/centos/7/os/x86_64/CentOS-Base.repo

    if [ $? -eq 0 ]; then
        yum clean all
        yum makecache
        echo -e "${GREEN}CentOS 7 官方源已恢复。${NC}"
        return 0
    else
        echo -e "${RED}下载官方 repo 文件失败。${NC}"
        return 1
    fi
}

function install_singbox_yg() {
    echo -e "${GREEN}即将退出工具箱并开始安装 sing-box-yg 脚本...${NC}"
    sleep 2
    clear
    local cmd="bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)"
    exec bash -c "$cmd"
}

install_bt_lts() {
    echo -e "${GREEN}即将退出工具箱并开始安装稳定国内堡塔lts长期支持版...${NC}"
    sleep 2
    clear
    local cmd="url=https://download.bt.cn/install/install_lts.sh; if [ -f /usr/bin/curl ]; then curl -sSO \$url; else wget -O install_lts.sh \$url; fi; bash install_lts.sh ed8484bec"
    exec bash -c "$cmd"
}

install_1_global() {
    echo -e "${GREEN}即将退出工具箱并开始安装最新国际1Panel社区版...${NC}"
    sleep 2
    clear
    local cmd="curl -sSL https://resource.1panel.pro/quick_start.sh -o quick_start.sh && bash quick_start.sh"
    exec bash -c "$cmd"
}

install_bt_nearest() {
    echo -e "${GREEN}即将退出工具箱并开始安装次新国内堡塔正式版...${NC}"
    sleep 2
    clear
    local cmd="if [ -f /usr/bin/curl ]; then curl -sSO https://download.bt.cn/install/install_nearest.sh; else wget -O install_nearest.sh https://download.bt.cn/install/install_nearest.sh; fi; bash install_nearest.sh ed8484bec"
    exec bash -c "$cmd"
}

install_bt_latest() {
    echo -e "${GREEN}即将退出工具箱并开始安装最新国内堡塔正式版...${NC}"
    sleep 2
    clear
    local cmd="if [ -f /usr/bin/curl ]; then curl -sSO https://download.bt.cn/install/install_panel.sh; else wget -O install_panel.sh https://download.bt.cn/install/install_panel.sh; fi; bash install_panel.sh ed8484bec"
    exec bash -c "$cmd"
}

install_1_cn() {
    echo -e "${GREEN}即将退出工具箱并开始安装最新国内1Panel社区版...${NC}"
    sleep 2
    clear
    local cmd="curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh && bash quick_start.sh"
    exec bash -c "$cmd"
}

install_aa_latest() {
    echo -e "${GREEN}即将退出工具箱并开始安装最新国际堡塔正式版 (aapanel)...${NC}"
    sleep 2
    clear
    local cmd="URL=https://www.aapanel.com/script/install_7.0_en.sh && if [ -f /usr/bin/curl ]; then curl -ksSO \"\$URL\"; else wget --no-check-certificate -O install_7.0_en.sh \"\$URL\"; fi; bash install_7.0_en.sh aapanel"
    exec bash -c "$cmd"
}

function install_toolbox() {
    echo -e "${YELLOW}正在从 https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main/tool.sh 下载并安装...${NC}"
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}此操作需要root权限。${NC}"
        return 1
    fi
    
    if curl -sL https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main/tool.sh -o /usr/local/bin/tool; then
        chmod +x /usr/local/bin/tool
        sed -i 's/\r$//' /usr/local/bin/tool
        mkdir -p "$TOOLBOX_DIR"
        echo "INSTALLED=true" > "$CONFIG_FILE"
        echo "0" > "$COUNTER_FILE"
        echo -e "${GREEN}工具箱安装/更新成功！${NC}"
        echo -e "${YELLOW}正在重启工具箱...${NC}"
        sleep 2
        exec tool
    else
        echo -e "${RED}安装失败。请检查网络或权限。${NC}"
        read -p "按回车键返回..." < /dev/tty
        toolbox_management
    fi
}

function uninstall_toolbox() {
    echo -e "${YELLOW}正在卸载工具箱...${NC}"
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}此操作需要root权限。${NC}"
        return 1
    fi

    if [ ! -f /usr/local/bin/tool ]; then
        echo -e "${RED}工具箱未安装，无需卸载。${NC}"
    else
        rm -f /usr/local/bin/tool
        rm -rf "$TOOLBOX_DIR"
        echo -e "${GREEN}工具箱已成功卸载。${NC}"
    fi
    read -p "按回车键退出..." < /dev/tty
    exit 0
}

function manage_tools() {
    show_header
    echo -e "${YELLOW}====== 系统管理工具 ======${NC}"
    echo -e "${GREEN}1. 清理系统垃圾 ${NC}"
    echo -e "${GREEN}2. 用户管理 ${NC}"
    echo -e "${GREEN}3. 内核管理 ${NC}"
    echo -e "${GREEN}0. 返回主菜单 ${NC}"
    echo -e "${CYAN}==============================================${NC}"
    
    read -p "请输入选项 [0-3]: " choice < /dev/tty
    case $choice in
        1) clean_system ;;
        2) user_management ;;
        3) kernel_management ;;
        0) main_menu ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1; manage_tools ;;
    esac
}

function select_user_interactive() {
    local prompt_message="$1"
    
    mapfile -t users < <(awk -F: '($1 == "root") || ($3 >= 1000 && $7 ~ /^\/bin\/(bash|sh|zsh|dash)$/)' /etc/passwd | cut -d: -f1 | sort)
    
    if [ ${#users[@]} -eq 0 ]; then
        echo -e "${RED}未找到可操作的用户。${NC}" >&2
        return 1
    fi

    echo -e "${YELLOW}${prompt_message}${NC}"
    for i in "${!users[@]}"; do
        echo -e "${GREEN}$((i+1)). ${users[$i]}${NC}"
    done
    echo -e "${GREEN}0. 取消${NC}"

    read -p "请输入选项: " choice < /dev/tty
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -gt "${#users[@]}" ]; then
        echo -e "${RED}无效选项${NC}" >&2 ; sleep 1
        return 1
    fi
    
    if [ "$choice" -eq 0 ]; then
        return 1
    fi
    
    echo "${users[$((choice-1))]}"
    return 0
}


function user_management() {
    show_header
    echo -e "${YELLOW}====== 用户管理 ======${NC}"
    echo -e "${GREEN}1. 列出可登录用户 ${NC}"
    echo -e "${GREEN}2. 创建新用户 ${NC}"
    echo -e "${GREEN}3. 删除用户 ${NC}"
    echo -e "${GREEN}4. 修改密码 ${NC}"
    echo -e "${GREEN}5. 查看用户组 ${NC}"
    echo -e "${GREEN}6. 切换用户 ${NC}"
    echo -e "${GREEN}0. 返回主菜单 ${NC}"
    echo -e "${CYAN}==============================================${NC}"
    
    read -p "请输入选项 [0-6]: " choice < /dev/tty
    case $choice in
        1) 
            awk -F: '($1 == "root") || ($3 >= 1000 && $7 ~ /^\/bin\/(bash|sh|zsh|dash)$/)' /etc/passwd | cut -d: -f1 | sort
            ;;
        2)
            read -p "请输入新用户名: " username < /dev/tty
            if [ "$OS_TYPE" == "ubuntu" ] || [ "$OS_TYPE" == "debian" ]; then adduser "$username"; else useradd "$username" && passwd "$username"; fi
            ;;
        3)
            local user_to_delete
            if user_to_delete=$(select_user_interactive "请选择要删除的用户:"); then
                if [ "$user_to_delete" == "root" ]; then
                    echo -e "${RED}出于安全考虑，禁止删除 root 用户。${NC}"
                else
                    read -p "$(echo -e ${RED}"确定要删除用户 ${user_to_delete} 及其主目录吗？ (y/N): "${NC})" confirm_delete < /dev/tty
                    if [[ "$confirm_delete" =~ ^[Yy]$ ]]; then
                        if [ "$OS_TYPE" == "ubuntu" ] || [ "$OS_TYPE" == "debian" ]; then
                            deluser --remove-home "$user_to_delete"
                        else
                            userdel -r "$user_to_delete"
                        fi
                        echo -e "${GREEN}用户 ${user_to_delete} 已删除。${NC}"
                    else
                        echo -e "${YELLOW}操作已取消。${NC}"
                    fi
                fi
            else
                echo -e "${YELLOW}操作已取消。${NC}" >&2
            fi
            ;;
        4)
            local user_to_change_pw
            if user_to_change_pw=$(select_user_interactive "请选择要修改密码的用户:"); then
                passwd "$user_to_change_pw"
            else
                echo -e "${YELLOW}操作已取消。${NC}" >&2
            fi
            ;;
        5)
            echo -e "${YELLOW}--- 可登录用户的所属用户组 ---${NC}"
            local all_groups=()
            while IFS= read -r user; do
                user_groups=($(id -nG "$user"))
                all_groups+=("${user_groups[@]}")
            done < <(awk -F: '($1 == "root") || ($3 >= 1000 && $7 ~ /^\/bin\/(bash|sh|zsh|dash)$/)' /etc/passwd | cut -d: -f1)
            
            printf "%s\n" "${all_groups[@]}" | sort -u
            ;;
        6) 
            local user_to_switch
            if user_to_switch=$(select_user_interactive "请选择要切换的用户:"); then
                echo -e "${YELLOW}正在切换到用户 ${user_to_switch}...${NC}"
                echo -e "${YELLOW}您将退出此脚本并进入新用户的shell。${NC}"
                sleep 2
                clear
                exec su - "$user_to_switch"
            else
                echo -e "${YELLOW}操作已取消。${NC}" >&2
            fi
            ;;
        0) 
            main_menu; return
            ;;
        *) 
            echo -e "${RED}无效选项${NC}"; sleep 1; user_management
            ;;
    esac
    read -p "按回车键返回..." < /dev/tty
    user_management
}

function kernel_management() {
    show_header
    echo -e "${YELLOW}====== 内核管理 ======${NC}"
    echo -e "${GREEN}1. 查看当前内核版本 ${NC}"
    echo -e "${GREEN}2. 列出所有已安装内核 ${NC}"
    echo -e "${GREEN}3. 删除旧内核 ${NC}"
    echo -e "${GREEN}0. 返回主菜单 ${NC}"
    echo -e "${CYAN}==============================================${NC}"
    
    read -p "请输入选项 [0-3]: " choice < /dev/tty
    case $choice in
        1) uname -r ;;
        2)
            if [ "$OS_TYPE" == "ubuntu" ] || [ "$OS_TYPE" == "debian" ]; then dpkg --list | grep linux-image; elif [ "$OS_TYPE" == "centos7" ] || [ "$OS_TYPE" == "centos8" ]; then rpm -qa | grep kernel; else echo -e "${RED}无法检测包管理器${NC}"; fi ;;
        3)
            if [ "$OS_TYPE" == "ubuntu" ] || [ "$OS_TYPE" == "debian" ]; then apt autoremove --purge; elif [ "$OS_TYPE" == "centos7" ]; then package-cleanup --oldkernels --count=1 -y; elif [ "$OS_TYPE" == "centos8" ]; then dnf autoremove -y; else echo -e "${RED}无法清理旧内核${NC}"; fi ;;
        0) main_menu; return ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1; kernel_management ;;
    esac
    read -p "按回车键返回..." < /dev/tty
    kernel_management
}

function change_source() {
    show_header
    echo -e "${YELLOW}====== 一键换源加速 ======${NC}"
    echo -e "${GREEN}1. 换源 (阿里云) ${NC}"
    echo -e "${GREEN}2. 换源 (腾讯云) ${NC}"
    echo -e "${GREEN}3. 换源 (中科大) ${NC}"
    echo -e "${GREEN}4. 恢复官方源 ${NC}"
    echo -e "${GREEN}0. 返回主菜单 ${NC}"
    echo -e "${CYAN}==============================================${NC}"
    
    local is_apt=false
    if [ "$OS_TYPE" == "ubuntu" ] || [ "$OS_TYPE" == "debian" ]; then is_apt=true; fi
    local is_yum=false
    if [ "$OS_TYPE" == "centos7" ]; then is_yum=true; fi

    read -p "请输入选项 [0-4]: " choice < /dev/tty
    case $choice in
        1)
            read -p "确定更换为阿里云源吗？(y/N): " confirm < /dev/tty
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                if $is_apt; then _change_mirror_apt "http://mirrors.aliyun.com" "阿里云"; elif $is_yum; then _change_mirror_yum "http://mirrors.aliyun.com" "阿里云"; else echo -e "${RED}当前系统 ($OS_TYPE) 不支持此功能。${NC}"; fi
            else echo -e "${RED}操作已取消。${NC}"; fi ;;
        2) 
            read -p "确定更换为腾讯云源吗？(y/N): " confirm < /dev/tty
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                if $is_apt; then _change_mirror_apt "http://mirrors.tencent.com" "腾讯云"; elif $is_yum; then _change_mirror_yum "https://mirrors.tencent.com" "腾讯云"; else echo -e "${RED}当前系统 ($OS_TYPE) 不支持此功能。${NC}"; fi
            else echo -e "${RED}操作已取消。${NC}"; fi ;;
        3) 
            read -p "确定更换为中科大源吗？(y/N): " confirm < /dev/tty
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                if $is_apt; then _change_mirror_apt "https://mirrors.ustc.edu.cn" "中科大"; elif $is_yum; then _change_mirror_yum "https://mirrors.ustc.edu.cn" "中科大"; else echo -e "${RED}当前系统 ($OS_TYPE) 不支持此功能。${NC}"; fi
            else echo -e "${RED}操作已取消。${NC}"; fi ;;
        4) 
            read -p "确定要恢复官方源吗？(y/N): " confirm < /dev/tty
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                if $is_apt; then _restore_official_apt; elif $is_yum; then _restore_official_yum; else echo -e "${RED}当前系统 ($OS_TYPE) 不支持此功能。${NC}"; fi
            else echo -e "${RED}操作已取消。${NC}"; fi ;;
        0) main_menu ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1; change_source ;;
    esac
    read -p "按回车键继续..." < /dev/tty
    change_source
}

panel_installation() {
    show_header
    echo -e "${YELLOW}====== 面板安装 ======${NC}"
    echo -e "${GREEN}1. 安装国内堡塔lts版 ${NC}"
    echo -e "${GREEN}2. 安装国际1Panel社区版 ${NC}"
    echo -e "${GREEN}3. 安装国内堡塔次新版 ${NC}"
	echo -e "${GREEN}4. 安装国内堡塔最新版 ${NC}"
	echo -e "${GREEN}5. 安装国内1Panel社区版 ${NC}"
	echo -e "${GREEN}6. 安装国际堡塔最新版 (aapanel) ${NC}"
    echo -e "${GREEN}0. 返回主菜单 ${NC}"
	echo -e "${GREEN}提示：1Panel侧重Docker，堡塔侧重直接部署 ${NC}"
    echo -e "${CYAN}==============================================${NC}"
    
    read -p "请输入选项 [0-6] (回车默认: 1): " choice < /dev/tty
    choice=${choice:-1}
    case $choice in
        1) install_bt_lts ;;
        2) install_1_global ;;
        3) install_bt_nearest ;;
        4) install_bt_latest ;;
        5) install_1_cn ;;
        6) install_aa_latest ;;
        0) main_menu ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1; panel_installation ;;
    esac
}

function toolbox_management() {
    show_header
    echo -e "${YELLOW}====== 工具箱管理 ======${NC}"
    echo -e "${GREEN}1. 安装/更新 工具箱 ${NC}"
    echo -e "${GREEN}2. 卸载工具箱 ${NC}"
    echo -e "${GREEN}0. 返回主菜单 ${NC}"
    echo -e "${CYAN}==============================================${NC}"
    
    read -p "请输入选项 [0-2]: " choice < /dev/tty
    case $choice in
        1) install_toolbox ;;
        2) uninstall_toolbox ;;
        0) main_menu ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1; toolbox_management ;;
    esac
}

function display_logs() {
    local log_type=$1
    local log_file=""
    if [ "$OS_TYPE" == "ubuntu" ] || [ "$OS_TYPE" == "debian" ]; then
        log_file="/var/log/auth.log"
    else
        log_file="/var/log/secure"
    fi

    if [ ! -f "$log_file" ]; then
        echo -e "${RED}错误: 日志文件 $log_file 未找到。${NC}"
        sleep 2
        return
    fi
    
    local success_pattern="Accepted"
    local failure_pattern="Failed password"
    
    local raw_logs=""
    case $log_type in
        "success")
            raw_logs=$(grep -a "$success_pattern" "$log_file")
            ;;
        "failure")
            raw_logs=$(grep -a "$failure_pattern" "$log_file")
            ;;
        "all")
            raw_logs=$(grep -a -E "$success_pattern|$failure_pattern" "$log_file")
            ;;
    esac

    mapfile -t logs < <(echo "$raw_logs" | sort -r)
    
    local total_records=${#logs[@]}
    if [ $total_records -eq 0 ]; then
        echo -e "${YELLOW}未找到相关日志记录。${NC}"
        sleep 2
        return
    fi
    
    local page_size=10
    local total_pages=$(( (total_records + page_size - 1) / page_size ))
    local current_page=1

    while true; do
        show_header
        echo -e "${YELLOW}====== SSH 登录日志 ($log_type) ======${NC}"
        echo -e "${CYAN}总计: $total_records 条记录 | 页面: $current_page / $total_pages${NC}"
        printf "%-20s %-15s %-20s %-10s\n" "时间" "用户名" "来源IP" "状态"
        echo "-----------------------------------------------------------------"
        
        local start_index=$(( (current_page - 1) * page_size ))
        
        for i in $(seq 0 $((page_size - 1))); do
            local index=$((start_index + i))
            [ $index -ge $total_records ] && break
            local line="${logs[$index]}"
            
            local parsed_line=$(echo "$line" | awk '
                /Accepted/ {
                    time=$1 " " $2 " " $3;
                    user=$9;
                    ip=$11;
                    status="成功";
                    printf "%-20s %-15s %-20s %-10s\n", time, user, ip, status;
                }
                /Failed password/ {
                    time=$1 " " $2 " " $3;
                    if ($9 == "invalid") {
                        user="invalid_user(" $10 ")";
                        ip=$12;
                    } else {
                        user=$9;
                        ip=$11;
                    }
                    status="失败";
                    printf "%-20s %-15s %-20s %-10s\n", time, user, ip, status;
                }
            ')
            echo -e "${GREEN}${parsed_line}${NC}"
        done
        
        echo "-----------------------------------------------------------------"
        
        local options=""
        if [ $current_page -lt $total_pages ]; then
            options+="[1] 下一页  "
        fi
        if [ $current_page -gt 1 ]; then
            options+="[2] 上一页  "
        fi
        options+="[0] 返回"
        echo -e "${YELLOW}${options}${NC}"
        
        read -p "请输入选项: " page_choice < /dev/tty
        
        case $page_choice in
            1)
                [ $current_page -lt $total_pages ] && current_page=$((current_page + 1))
                ;;
            2)
                [ $current_page -gt 1 ] && current_page=$((current_page - 1))
                ;;
            0)
                return
                ;;
            *)
                ;;
        esac
    done
}

function view_ssh_logs() {
    while true; do
        show_header
        echo -e "${YELLOW}====== 查看SSH登录日志 ======${NC}"
        echo -e "${GREEN}1. 查看成功登录记录 ${NC}"
        echo -e "${GREEN}2. 查看失败登录记录 ${NC}"
        echo -e "${GREEN}3. 查看所有登录记录 ${NC}"
        echo -e "${GREEN}0. 返回上一级菜单 ${NC}"
        echo -e "${CYAN}==============================================${NC}"
        read -p "请输入选项 [0-3]: " choice < /dev/tty
        case $choice in
            1) display_logs "success" ;;
            2) display_logs "failure" ;;
            3) display_logs "all" ;;
            0) break ;;
            *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
        esac
    done
    network_tools_menu
}

function list_used_ports() {
    show_header
    echo -e "${YELLOW}====== 列出已占用的端口 ======${NC}"
    if ! command -v ss &> /dev/null && ! command -v netstat &> /dev/null; then
        echo -e "${RED}未找到 ss 或 netstat 命令。${NC}"
    else
        printf "%-10s %-25s %s\n" "协议" "端口" "进程"
        echo "-----------------------------------------------------"
        if command -v ss &>/dev/null; then
            ss -tulnp | tail -n +2 | awk '{
                proto=$1; 
                split($5, a, ":"); 
                port = a[length(a)]; 
                match($7, /"([^"]+)"/); 
                proc = substr($7, RSTART + 1, RLENGTH - 2);
                if (proc == "") { proc = "-"; }
                if (!seen[proto,port,proc]++) {
                    printf "%-10s %-25s %s\n", proto, port, proc;
                }
            }'
        else
            netstat -tulnp | tail -n +3 | awk '{
                proto=$1; 
                split($4, a, ":"); 
                port = a[length(a)]; 
                split($7, p, "/"); 
                proc = p[2];
                if (proc == "") { proc = "-"; }
                if (!seen[proto,port,proc]++) {
                    printf "%-10s %-25s %s\n", proto, port, proc;
                }
            }'
        fi
    fi
    echo
    read -p "按回车键返回..." < /dev/tty
    network_tools_menu
}

function get_active_firewall() {
    if systemctl is-active --quiet firewalld; then
        echo "firewalld"
    elif command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        echo "ufw"
    else
        echo "none"
    fi
}

function install_firewall_menu() {
    show_header
    echo -e "${YELLOW}====== 安装防火墙 ======${NC}"
    echo -e "${YELLOW}未检测到活动的防火墙。请选择一个进行安装：${NC}"
    
    local install_cmd=""
    if [ "$OS_TYPE" == "centos8" ]; then install_cmd="dnf"; else install_cmd="yum"; fi

    if [ "$OS_TYPE" == "ubuntu" ] || [ "$OS_TYPE" == "debian" ]; then
        echo -e "${GREEN}1. 安装 UFW (推荐 for Debian/Ubuntu) ${NC}"
        echo -e "${GREEN}2. 安装 Firewalld ${NC}"
    else
        echo -e "${GREEN}1. 安装 Firewalld (推荐 for CentOS) ${NC}"
        echo -e "${GREEN}2. 安装 UFW ${NC}"
    fi
    echo -e "${GREEN}0. 返回 ${NC}"
    
    read -p "请输入选项: " choice < /dev/tty
    case $choice in
        1)
            if [ "$OS_TYPE" == "ubuntu" ] || [ "$OS_TYPE" == "debian" ]; then
                apt update && apt install -y ufw
                yes | ufw enable
                echo -e "${GREEN}UFW 安装并启用成功。${NC}"
            else
                $install_cmd install -y firewalld
                systemctl enable --now firewalld
                echo -e "${GREEN}Firewalld 安装并启用成功。${NC}"
            fi
            ;;
        2)
            if [ "$OS_TYPE" == "ubuntu" ] || [ "$OS_TYPE" == "debian" ]; then
                apt update && apt install -y firewalld
                systemctl enable --now firewalld
                echo -e "${GREEN}Firewalld 安装并启用成功。${NC}"
            else
                $install_cmd install -y ufw
                yes | ufw enable
                echo -e "${GREEN}UFW 安装并启用成功。${NC}"
            fi
            ;;
        0)
            network_tools_menu
            return
            ;;
        *)
            echo -e "${RED}无效选项${NC}"; sleep 1
            ;;
    esac
    read -p "操作完成，按回车键继续..." < /dev/tty
    firewall_management
}

function firewall_management() {
    local fw=$(get_active_firewall)
    if [ "$fw" == "none" ]; then
        install_firewall_menu
        return
    fi
    
    show_header
    echo -e "${YELLOW}====== 防火墙管理 ======${NC}"
    echo -e "${BLUE}当前活动防火墙: ${fw}${NC}"
    echo -e "${GREEN}1. 查看防火墙状态和规则 ${NC}"
    echo -e "${GREEN}2. 开放端口 ${NC}"
    echo -e "${GREEN}3. 关闭端口 ${NC}"
    echo -e "${GREEN}4. 启用/禁用防火墙 ${NC}"
    echo -e "${GREEN}5. 切换防火墙系统 ${NC}"
    echo -e "${GREEN}0. 返回网络工具菜单 ${NC}"
    echo -e "${CYAN}==============================================${NC}"
    
    read -p "请输入选项 [0-5]: " choice < /dev/tty
    case $choice in
        1) 
            if [ "$fw" == "firewalld" ]; then firewall-cmd --list-all; elif [ "$fw" == "ufw" ]; then ufw status verbose; elif [ "$fw" == "iptables" ]; then iptables -L -n -v; fi
            ;;
        2)
            read -p "请输入要开放的端口号: " port; read -p "请输入协议 (tcp/udp): " proto
            if [ "$fw" == "firewalld" ]; then firewall-cmd --permanent --add-port=${port}/${proto} && firewall-cmd --reload; elif [ "$fw" == "ufw" ]; then ufw allow ${port}/${proto}; else echo -e "${RED}操作不支持或没有活动的防火墙。${NC}"; fi
            ;;
        3)
            read -p "请输入要关闭的端口号: " port; read -p "请输入协议 (tcp/udp): " proto
            if [ "$fw" == "firewalld" ]; then firewall-cmd --permanent --remove-port=${port}/${proto} && firewall-cmd --reload; elif [ "$fw" == "ufw" ]; then ufw delete allow ${port}/${proto}; else echo -e "${RED}操作不支持或没有活动的防火墙。${NC}"; fi
            ;;
        4)
            if [ "$fw" == "firewalld" ]; then
                if systemctl is-active --quiet firewalld; then systemctl disable --now firewalld && echo "Firewalld已禁用"; else systemctl enable --now firewalld && echo "Firewalld已启用"; fi
            elif [ "$fw" == "ufw" ]; then
                if ufw status | grep -q "Status: active"; then ufw disable && echo "UFW已禁用"; else yes | ufw enable && echo "UFW已启用"; fi
            else
                echo -e "${RED}没有可管理的防火墙 (firewalld/ufw)。${NC}";
            fi
            ;;
        5) switch_firewall_system ;;
        0) network_tools_menu; return ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
    esac
    read -p "操作完成，按回车键返回..." < /dev/tty
    firewall_management
}

function switch_firewall_system() {
    show_header
    echo -e "${YELLOW}====== 切换防火墙系统 ======${NC}"
    echo -e "${RED}警告：切换防火墙将停用当前的防火墙并安装/启用新的防火墙，可能导致现有规则丢失！${NC}"
    
    local install_cmd=""
    if [ "$OS_TYPE" == "centos8" ]; then install_cmd="dnf"; else install_cmd="yum"; fi

    if [ "$OS_TYPE" == "ubuntu" ] || [ "$OS_TYPE" == "debian" ]; then
        echo -e "${GREEN}1. 切换到 firewalld ${NC}"
        echo -e "${GREEN}2. 切换到 ufw (当前系统默认) ${NC}"
    else
        echo -e "${GREEN}1. 切换到 firewalld (当前系统默认) ${NC}"
        echo -e "${GREEN}2. 切换到 ufw ${NC}"
    fi
    echo -e "${GREEN}0. 取消 ${NC}"
    
    read -p "请输入你的选择: " choice < /dev/tty
    case $choice in
        1) 
            read -p "确定要切换到 firewalld 吗? (y/N): " confirm < /dev/tty
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                if command -v ufw &>/dev/null; then echo "正在禁用 ufw..."; ufw disable &>/dev/null; fi
                if ! command -v firewall-cmd &>/dev/null; then
                    echo "正在安装 firewalld..."
                    if [ "$OS_TYPE" == "ubuntu" ] || [ "$OS_TYPE" == "debian" ]; then apt update && apt install -y firewalld; else $install_cmd install -y firewalld; fi
                fi
                echo "正在启用 firewalld..."
                systemctl enable --now firewalld
                echo -e "${GREEN}已切换到 firewalld。${NC}"
            fi
            ;;
        2) 
            read -p "确定要切换到 ufw 吗? (y/N): " confirm < /dev/tty
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                if systemctl is-active --quiet firewalld; then echo "正在禁用 firewalld..."; systemctl disable --now firewalld; fi
                if ! command -v ufw &>/dev/null; then
                    echo "正在安装 ufw..."
                    if [ "$OS_TYPE" == "ubuntu" ] || [ "$OS_TYPE" == "debian" ]; then apt update && apt install -y ufw; else $install_cmd install -y ufw; fi
                fi
                echo "正在启用 ufw..."
                yes | ufw enable
                echo -e "${GREEN}已切换到 ufw。${NC}"
            fi
            ;;
        0) firewall_management; return ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
    esac
    read -p "操作完成，按回车键返回..." < /dev/tty
    firewall_management
}

function view_bbr_status() {
    local status=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    local qdisc=$(sysctl net.core.default_qdisc | awk '{print $3}')
    show_header
    echo -e "${YELLOW}====== BBR 状态 ======${NC}"
    if [[ "$status" == "bbr" ]]; then
        echo -e "BBR 状态: ${GREEN}已开启${NC}"
    else
        echo -e "BBR 状态: ${RED}未开启${NC}"
        echo -e "当前拥塞控制算法: ${YELLOW}${status}${NC}"
    fi
    if [[ "$qdisc" == "fq" || "$qdisc" == "fq_codel" ]]; then
        echo -e "队列算法: ${GREEN}${qdisc}${NC}"
    else
        echo -e "队列算法: ${YELLOW}${qdisc}${NC} (推荐 fq 或 fq_codel)"
    fi
    
    echo -e "\n${CYAN}--- 内核模块 ---${NC}"
    lsmod | grep bbr
    
    echo -e "\n${CYAN}--- 系统配置 ---${NC}"
    sysctl net.ipv4.tcp_congestion_control
    sysctl net.core.default_qdisc
}

function enable_bbr() {
    show_header
    echo -e "${YELLOW}====== 开启 BBR ======${NC}"
    if [ "$OS_TYPE" == "centos7" ]; then
        local kernel_version=$(uname -r | awk -F'.' '{print $1"."$2}')
        if [[ "$(echo "$kernel_version < 4.9" | bc)" -eq 1 ]]; then
            echo -e "${RED}CentOS 7 内核版本过低，需要升级内核才能开启BBR。${NC}"
            read -p "是否现在升级内核？ (y/N): " confirm < /dev/tty
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo "正在导入 ELRepo GPG key..."
                rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
                echo "正在安装 ELRepo..."
                yum install -y https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
                echo "正在安装最新主线内核 (kernel-ml)..."
                yum --enablerepo=elrepo-kernel install -y kernel-ml
                echo "正在设置新的内核为默认启动项..."
                grub2-set-default 0
                echo -e "${GREEN}内核升级完成！${NC}"
                echo -e "${RED}请立即重启系统 (reboot)，然后再次运行此脚本来开启BBR。${NC}"
                return
            else
                echo -e "${YELLOW}操作已取消。${NC}"
                return
            fi
        fi
    fi

    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    
    sysctl -p >/dev/null 2>&1
    echo -e "${GREEN}BBR 已开启，配置已写入 /etc/sysctl.conf。${NC}"
}

function disable_bbr() {
    show_header
    echo -e "${YELLOW}====== 关闭 BBR ======${NC}"
    sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
    echo -e "${GREEN}BBR 已关闭，配置已从 /etc/sysctl.conf 移除。${NC}"
    echo -e "${YELLOW}拥塞控制算法已恢复为系统默认 (通常是 cubic)。${NC}"
}

function bbr_management() {
    show_header
    echo -e "${YELLOW}====== BBR网络加速管理 ======${NC}"
    echo -e "${GREEN}1. 查看BBR状态 ${NC}"
    echo -e "${GREEN}2. 开启BBR ${NC}"
    echo -e "${GREEN}3. 关闭BBR ${NC}"
    echo -e "${GREEN}0. 返回网络工具菜单 ${NC}"
    echo -e "${CYAN}==============================================${NC}"
    read -p "请输入选项 [0-3]: " choice < /dev/tty
    case $choice in
        1) view_bbr_status ;;
        2) enable_bbr ;;
        3) disable_bbr ;;
        0) network_tools_menu; return ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1; bbr_management ;;
    esac
    read -p "操作完成，按回车键返回..." < /dev/tty
    bbr_management
}

function network_tools_menu() {
    show_header
    echo -e "${YELLOW}====== 网络与安全工具 ======${NC}"
    echo -e "${GREEN}1. 网络速度测试 ${NC}"
    echo -e "${GREEN}2. 查看SSH登录日志 ${NC}"
    echo -e "${GREEN}3. 防火墙管理 ${NC}"
    echo -e "${GREEN}4. BBR网络加速管理 ${NC}"
    echo -e "${GREEN}5. 列出已占用端口 ${NC}"
    echo -e "${GREEN}0. 返回主菜单 ${NC}"
    echo -e "${CYAN}==============================================${NC}"

    read -p "请输入选项 [0-5]: " choice < /dev/tty
    case $choice in
        1) network_speed_test ;;
        2) view_ssh_logs ;;
        3) firewall_management ;;
        4) bbr_management ;;
        5) list_used_ports ;;
        0) main_menu ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1; network_tools_menu ;;
    esac
}

function main_menu() {
    show_header
    echo -e "${GREEN}1. 系统管理工具 ${NC}"
    echo -e "${GREEN}2. 网络与安全工具 ${NC}"
    echo -e "${GREEN}3. 一键换源加速 ${NC}"
    echo -e "${GREEN}4. 一键安装面板 ${NC}"
    echo -e "${GREEN}5. 一键安装singbox-yg脚本 ${NC}"
    echo -e "${GREEN}6. 工具箱管理 ${NC}"
    echo -e "${GREEN}0. 退出 ${NC}"
    echo -e "${CYAN}==============================================${NC}"
    
    read -p "请输入选项 [0-6]: " choice < /dev/tty
    case $choice in
        1) manage_tools ;;
        2) network_tools_menu ;;
        3) change_source ;;
        4) panel_installation ;;
        5) install_singbox_yg ;;
        6) toolbox_management ;;
        0)
            if [ "$INSTALLED" = "false" ]; then
                echo -e "\n${YELLOW}一键运行命令: ${CYAN}curl -Ls https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main/tool.sh | bash${NC}\n"
            fi
            exit 0
            ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1; main_menu ;;
    esac
}

check_root
detect_os
init_config
main_menu
