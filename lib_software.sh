#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/lib_utils.sh"

software_management() {
    while true; do
        show_menu "第三方软件管理" \
            "Docker 管理" \
            "Nginx 管理" \
            "MySQL/MariaDB 管理" \
            "Redis 管理" \
            "Node.js 管理" \
            "Python 管理" \
            "Java 管理" \
            "常用工具安装" \
            "软件卸载"
        
        local choice=$(read_choice 9)
        
        case $choice in
            0) return ;;
            1) docker_management ;;
            2) nginx_management ;;
            3) mysql_management ;;
            4) redis_management ;;
            5) nodejs_management ;;
            6) python_management ;;
            7) java_management ;;
            8) common_tools_install ;;
            9) software_uninstall ;;
        esac
    done
}

docker_management() {
    while true; do
        show_menu "Docker 管理" \
            "安装 Docker" \
            "启动 Docker" \
            "停止 Docker" \
            "查看 Docker 状态" \
            "Docker 容器管理" \
            "Docker 镜像管理" \
            "安装 Docker Compose"
        
        local choice=$(read_choice 7)
        
        case $choice in
            0) return ;;
            1) install_docker ;;
            2) start_docker ;;
            3) stop_docker ;;
            4) docker_status ;;
            5) docker_container_management ;;
            6) docker_image_management ;;
            7) install_docker_compose ;;
        esac
    done
}

install_docker() {
    print_title "安装 Docker"
    
    if command -v docker &> /dev/null; then
        log_info "Docker 已安装"
        docker --version
        press_enter
        return
    fi
    
    local pm=$(get_package_manager)
    
    case $pm in
        "apt")
            log_info "安装 Docker (Ubuntu/Debian)..."
            apt-get update
            apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
            
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io
            ;;
        "yum")
            log_info "安装 Docker (CentOS/RHEL)..."
            yum install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install -y docker-ce docker-ce-cli containerd.io
            ;;
        "dnf")
            log_info "安装 Docker (Fedora)..."
            dnf -y install dnf-plugins-core
            dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            dnf install -y docker-ce docker-ce-cli containerd.io
            ;;
    esac
    
    systemctl enable docker
    systemctl start docker
    
    usermod -aG docker $USER
    
    log_success "Docker 安装完成"
    log_info "请重新登录以使用户组生效"
    
    press_enter
}

start_docker() {
    print_title "启动 Docker"
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装"
        press_enter
        return
    fi
    
    systemctl start docker
    systemctl enable docker
    
    log_success "Docker 已启动"
    press_enter
}

stop_docker() {
    print_title "停止 Docker"
    
    systemctl stop docker
    
    log_success "Docker 已停止"
    press_enter
}

docker_status() {
    print_title "Docker 状态"
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装"
        press_enter
        return
    fi
    
    echo -e "${CYAN}Docker 版本:${NC}"
    docker --version
    echo
    
    echo -e "${CYAN}Docker 服务状态:${NC}"
    systemctl status docker --no-pager
    echo
    
    echo -e "${CYAN}Docker 容器:${NC}"
    docker ps -a
    echo
    
    echo -e "${CYAN}Docker 镜像:${NC}"
    docker images
    
    press_enter
}

nginx_management() {
    while true; do
        show_menu "Nginx 管理" \
            "安装 Nginx" \
            "启动 Nginx" \
            "停止 Nginx" \
            "重启 Nginx" \
            "查看 Nginx 状态" \
            "编辑配置文件" \
            "测试配置" \
            "查看访问日志" \
            "查看错误日志"
        
        local choice=$(read_choice 9)
        
        case $choice in
            0) return ;;
            1) install_nginx ;;
            2) start_nginx ;;
            3) stop_nginx ;;
            4) restart_nginx ;;
            5) nginx_status ;;
            6) edit_nginx_config ;;
            7) test_nginx_config ;;
            8) view_nginx_access_log ;;
            9) view_nginx_error_log ;;
        esac
    done
}

install_nginx() {
    print_title "安装 Nginx"
    
    if command -v nginx &> /dev/null; then
        log_info "Nginx 已安装"
        nginx -v
        press_enter
        return
    fi
    
    local pm=$(get_package_manager)
    
    case $pm in
        "apt")
            apt-get update
            apt-get install -y nginx
            ;;
        "yum")
            yum install -y epel-release
            yum install -y nginx
            ;;
        "dnf")
            dnf install -y nginx
            ;;
    esac
    
    systemctl enable nginx
    systemctl start nginx
    
    log_success "Nginx 安装完成"
    press_enter
}

start_nginx() {
    systemctl start nginx
    log_success "Nginx 已启动"
    press_enter
}

stop_nginx() {
    systemctl stop nginx
    log_success "Nginx 已停止"
    press_enter
}

restart_nginx() {
    systemctl restart nginx
    log_success "Nginx 已重启"
    press_enter
}

nginx_status() {
    print_title "Nginx 状态"
    
    if ! command -v nginx &> /dev/null; then
        log_error "Nginx 未安装"
        press_enter
        return
    fi
    
    echo -e "${CYAN}Nginx 版本:${NC}"
    nginx -v
    echo
    
    echo -e "${CYAN}Nginx 服务状态:${NC}"
    systemctl status nginx --no-pager
    echo
    
    echo -e "${CYAN}监听端口:${NC}"
    netstat -tlnp | grep nginx
    
    press_enter
}

mysql_management() {
    while true; do
        show_menu "MySQL/MariaDB 管理" \
            "安装 MySQL" \
            "安装 MariaDB" \
            "启动数据库" \
            "停止数据库" \
            "重启数据库" \
            "查看数据库状态" \
            "安全配置" \
            "连接数据库" \
            "备份数据库" \
            "恢复数据库"
        
        local choice=$(read_choice 10)
        
        case $choice in
            0) return ;;
            1) install_mysql ;;
            2) install_mariadb ;;
            3) start_database ;;
            4) stop_database ;;
            5) restart_database ;;
            6) database_status ;;
            7) secure_database ;;
            8) connect_database ;;
            9) backup_database ;;
            10) restore_database ;;
        esac
    done
}

install_mysql() {
    print_title "安装 MySQL"
    
    if command -v mysql &> /dev/null; then
        log_info "MySQL 已安装"
        mysql --version
        press_enter
        return
    fi
    
    local pm=$(get_package_manager)
    
    case $pm in
        "apt")
            apt-get update
            apt-get install -y mysql-server mysql-client
            ;;
        "yum")
            yum install -y mysql-server mysql
            ;;
        "dnf")
            dnf install -y mysql-server mysql
            ;;
    esac
    
    systemctl enable mysqld 2>/dev/null || systemctl enable mysql
    systemctl start mysqld 2>/dev/null || systemctl start mysql
    
    log_success "MySQL 安装完成"
    log_info "请运行安全配置来设置root密码"
    
    press_enter
}

install_mariadb() {
    print_title "安装 MariaDB"
    
    if command -v mariadb &> /dev/null || command -v mysql &> /dev/null; then
        log_info "MariaDB/MySQL 已安装"
        mysql --version 2>/dev/null || mariadb --version
        press_enter
        return
    fi
    
    local pm=$(get_package_manager)
    
    case $pm in
        "apt")
            apt-get update
            apt-get install -y mariadb-server mariadb-client
            ;;
        "yum")
            yum install -y mariadb-server mariadb
            ;;
        "dnf")
            dnf install -y mariadb-server mariadb
            ;;
    esac
    
    systemctl enable mariadb
    systemctl start mariadb
    
    log_success "MariaDB 安装完成"
    log_info "请运行安全配置来设置root密码"
    
    press_enter
}

redis_management() {
    while true; do
        show_menu "Redis 管理" \
            "安装 Redis" \
            "启动 Redis" \
            "停止 Redis" \
            "重启 Redis" \
            "查看 Redis 状态" \
            "连接 Redis" \
            "编辑配置文件" \
            "查看日志"
        
        local choice=$(read_choice 8)
        
        case $choice in
            0) return ;;
            1) install_redis ;;
            2) start_redis ;;
            3) stop_redis ;;
            4) restart_redis ;;
            5) redis_status ;;
            6) connect_redis ;;
            7) edit_redis_config ;;
            8) view_redis_log ;;
        esac
    done
}

install_redis() {
    print_title "安装 Redis"
    
    if command -v redis-server &> /dev/null; then
        log_info "Redis 已安装"
        redis-server --version
        press_enter
        return
    fi
    
    local pm=$(get_package_manager)
    
    case $pm in
        "apt")
            apt-get update
            apt-get install -y redis-server
            ;;
        "yum")
            yum install -y epel-release
            yum install -y redis
            ;;
        "dnf")
            dnf install -y redis
            ;;
    esac
    
    systemctl enable redis
    systemctl start redis
    
    log_success "Redis 安装完成"
    press_enter
}

nodejs_management() {
    while true; do
        show_menu "Node.js 管理" \
            "安装 Node.js (官方源)" \
            "安装 Node.js (NodeSource)" \
            "安装 NVM" \
            "查看 Node.js 版本" \
            "安装 npm 包管理器" \
            "更新 npm" \
            "安装 Yarn" \
            "全局包管理"
        
        local choice=$(read_choice 8)
        
        case $choice in
            0) return ;;
            1) install_nodejs_official ;;
            2) install_nodejs_nodesource ;;
            3) install_nvm ;;
            4) nodejs_version ;;
            5) install_npm ;;
            6) update_npm ;;
            7) install_yarn ;;
            8) global_packages_management ;;
        esac
    done
}

install_nodejs_official() {
    print_title "安装 Node.js (官方源)"
    
    if command -v node &> /dev/null; then
        log_info "Node.js 已安装"
        node --version
        press_enter
        return
    fi
    
    local pm=$(get_package_manager)
    
    case $pm in
        "apt")
            apt-get update
            apt-get install -y nodejs npm
            ;;
        "yum")
            yum install -y epel-release
            yum install -y nodejs npm
            ;;
        "dnf")
            dnf install -y nodejs npm
            ;;
    esac
    
    log_success "Node.js 安装完成"
    node --version
    npm --version
    
    press_enter
}

common_tools_install() {
    while true; do
        show_menu "常用工具安装" \
            "Git" \
            "Vim/Nano" \
            "Curl/Wget" \
            "Htop/Btop" \
            "Tree" \
            "Zip/Unzip" \
            "Screen/Tmux" \
            "开发工具包" \
            "网络工具包"
        
        local choice=$(read_choice 9)
        
        case $choice in
            0) return ;;
            1) install_git ;;
            2) install_editors ;;
            3) install_download_tools ;;
            4) install_system_monitors ;;
            5) install_tree ;;
            6) install_compression_tools ;;
            7) install_terminal_multiplexers ;;
            8) install_dev_tools ;;
            9) install_network_tools ;;
        esac
    done
}

install_git() {
    print_title "安装 Git"
    
    if command -v git &> /dev/null; then
        log_info "Git 已安装"
        git --version
        press_enter
        return
    fi
    
    local pm=$(get_package_manager)
    
    case $pm in
        "apt")
            apt-get update
            apt-get install -y git
            ;;
        "yum")
            yum install -y git
            ;;
        "dnf")
            dnf install -y git
            ;;
    esac
    
    log_success "Git 安装完成"
    git --version
    
    press_enter
}

install_editors() {
    print_title "安装编辑器"
    
    local pm=$(get_package_manager)
    
    case $pm in
        "apt")
            apt-get update
            apt-get install -y vim nano
            ;;
        "yum")
            yum install -y vim nano
            ;;
        "dnf")
            dnf install -y vim nano
            ;;
    esac
    
    log_success "编辑器安装完成"
    press_enter
}

install_dev_tools() {
    print_title "安装开发工具包"
    
    local pm=$(get_package_manager)
    
    case $pm in
        "apt")
            apt-get update
            apt-get install -y build-essential gcc g++ make cmake
            ;;
        "yum")
            yum groupinstall -y "Development Tools"
            yum install -y gcc gcc-c++ make cmake
            ;;
        "dnf")
            dnf groupinstall -y "Development Tools"
            dnf install -y gcc gcc-c++ make cmake
            ;;
    esac
    
    log_success "开发工具包安装完成"
    press_enter
}

software_uninstall() {
    while true; do
        show_menu "软件卸载" \
            "卸载 Docker" \
            "卸载 Nginx" \
            "卸载 MySQL/MariaDB" \
            "卸载 Redis" \
            "卸载 Node.js" \
            "清理无用包" \
            "清理缓存"
        
        local choice=$(read_choice 7)
        
        case $choice in
            0) return ;;
            1) uninstall_docker ;;
            2) uninstall_nginx ;;
            3) uninstall_database ;;
            4) uninstall_redis ;;
            5) uninstall_nodejs ;;
            6) cleanup_packages ;;
            7) cleanup_cache ;;
        esac
    done
}

uninstall_docker() {
    print_title "卸载 Docker"
    
    if ! command -v docker &> /dev/null; then
        log_info "Docker 未安装"
        press_enter
        return
    fi
    
    log_warn "警告：此操作将删除所有Docker容器和镜像"
    
    if ! confirm_action "确定要卸载Docker吗？"; then
        return
    fi
    
    systemctl stop docker
    systemctl disable docker
    
    local pm=$(get_package_manager)
    
    case $pm in
        "apt")
            apt-get remove -y docker-ce docker-ce-cli containerd.io
            apt-get autoremove -y
            ;;
        "yum")
            yum remove -y docker-ce docker-ce-cli containerd.io
            ;;
        "dnf")
            dnf remove -y docker-ce docker-ce-cli containerd.io
            ;;
    esac
    
    rm -rf /var/lib/docker
    rm -rf /etc/docker
    
    log_success "Docker 已卸载"
    press_enter
}

cleanup_packages() {
    print_title "清理无用包"
    
    local pm=$(get_package_manager)
    
    case $pm in
        "apt")
            apt-get autoremove -y
            apt-get autoclean
            ;;
        "yum")
            yum autoremove -y
            ;;
        "dnf")
            dnf autoremove -y
            ;;
    esac
    
    log_success "无用包清理完成"
    press_enter
}

cleanup_cache() {
    print_title "清理缓存"
    
    local pm=$(get_package_manager)
    
    case $pm in
        "apt")
            apt-get clean
            ;;
        "yum")
            yum clean all
            ;;
        "dnf")
            dnf clean all
            ;;
    esac
    
    log_success "缓存清理完成"
    press_enter
}