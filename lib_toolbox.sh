#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/lib_utils.sh"

TOOLBOX_DIR="/opt/linux-toolbox"
TOOLBOX_BIN="/usr/local/bin/toolbox"
TOOLBOX_CONFIG="$HOME/.toolbox"
TOOLBOX_REPO="https://github.com/your-username/linux-toolbox.git"

toolbox_management() {
    while true; do
        show_menu "工具箱管理" \
            "安装工具箱" \
            "更新工具箱" \
            "卸载工具箱" \
            "查看工具箱信息" \
            "配置管理" \
            "备份配置" \
            "恢复配置" \
            "重置工具箱"
        
        local choice=$(read_choice 8)
        
        case $choice in
            0) return ;;
            1) install_toolbox ;;
            2) update_toolbox ;;
            3) uninstall_toolbox ;;
            4) show_toolbox_info ;;
            5) config_management ;;
            6) backup_config ;;
            7) restore_config ;;
            8) reset_toolbox ;;
        esac
    done
}

install_toolbox() {
    print_title "安装 Linux 工具箱"
    
    if [[ -d "$TOOLBOX_DIR" ]]; then
        log_info "工具箱已安装在 $TOOLBOX_DIR"
        if confirm_action "是否重新安装？"; then
            uninstall_toolbox_silent
        else
            press_enter
            return
        fi
    fi
    
    log_info "开始安装工具箱..."
    
    if ! command -v git &> /dev/null; then
        log_error "Git 未安装，正在安装..."
        local pm=$(get_package_manager)
        case $pm in
            "apt") apt-get update && apt-get install -y git ;;
            "yum") yum install -y git ;;
            "dnf") dnf install -y git ;;
        esac
    fi
    
    mkdir -p "$(dirname "$TOOLBOX_DIR")"
    
    if [[ -n "$TOOLBOX_REPO" ]] && [[ "$TOOLBOX_REPO" != "https://github.com/GamblerIX/linux-toolbox.git" ]]; then
        log_info "从远程仓库克隆..."
        git clone "$TOOLBOX_REPO" "$TOOLBOX_DIR"
    else
        log_info "复制本地文件..."
        local script_dir="$(dirname "${BASH_SOURCE[0]}")"
        cp -r "$script_dir" "$TOOLBOX_DIR"
    fi
    
    chmod +x "$TOOLBOX_DIR"/*.sh
    
    create_toolbox_symlink
    
    create_toolbox_config
    
    log_success "工具箱安装完成！"
    log_info "使用 'toolbox' 命令启动工具箱"
    
    press_enter
}

create_toolbox_symlink() {
    log_info "创建命令链接..."
    
    cat > "$TOOLBOX_BIN" << 'EOF'
#!/bin/bash
exec /opt/linux-toolbox/tool.sh "$@"
EOF
    
    chmod +x "$TOOLBOX_BIN"
    
    if ! echo "$PATH" | grep -q "/usr/local/bin"; then
        echo 'export PATH="/usr/local/bin:$PATH"' >> "$HOME/.bashrc"
        log_info "已添加 /usr/local/bin 到 PATH"
    fi
}

create_toolbox_config() {
    log_info "创建配置文件..."
    
    mkdir -p "$(dirname "$TOOLBOX_CONFIG")"
    
    cat > "$TOOLBOX_CONFIG" << EOF
# Linux Toolbox 配置文件
# 安装时间: $(date)
# 安装路径: $TOOLBOX_DIR

# 工具箱设置
TOOLBOX_AUTO_UPDATE=true
TOOLBOX_CHECK_INTERVAL=7
TOOLBOX_LOG_LEVEL=info
TOOLBOX_BACKUP_COUNT=5

# 网络设置
NETWORK_TIMEOUT=30
DOWNLOAD_MIRROR=auto

# 安全设置
SECURITY_CHECK=true
FIREWALL_AUTO_CONFIG=false

# 软件源设置
APT_MIRROR=auto
YUM_MIRROR=auto

# 备份设置
BACKUP_DIR=$HOME/.toolbox/backups
AUTO_BACKUP=true
EOF
    
    chmod 600 "$TOOLBOX_CONFIG"
}

update_toolbox() {
    print_title "更新工具箱"
    
    if [[ ! -d "$TOOLBOX_DIR" ]]; then
        log_error "工具箱未安装"
        press_enter
        return
    fi
    
    log_info "检查更新..."
    
    local current_version
    if [[ -f "$TOOLBOX_DIR/version" ]]; then
        current_version=$(cat "$TOOLBOX_DIR/version")
    else
        current_version="未知"
    fi
    
    log_info "当前版本: $current_version"
    
    if [[ -d "$TOOLBOX_DIR/.git" ]]; then
        log_info "从Git仓库更新..."
        cd "$TOOLBOX_DIR"
        
        git fetch origin
        local remote_version=$(git describe --tags --abbrev=0 2>/dev/null || echo "main")
        
        log_info "远程版本: $remote_version"
        
        if [[ "$current_version" == "$remote_version" ]]; then
            log_info "已是最新版本"
        else
            if confirm_action "发现新版本，是否更新？" "y"; then
                backup_current_version
                git pull origin main
                chmod +x "$TOOLBOX_DIR"/*.sh
                log_success "更新完成！"
            fi
        fi
    else
        log_info "手动更新模式"
        log_info "请手动下载最新版本并替换文件"
    fi
    
    press_enter
}

backup_current_version() {
    local backup_dir="$HOME/.toolbox/backups"
    local backup_name="toolbox-backup-$(date +%Y%m%d-%H%M%S)"
    
    mkdir -p "$backup_dir"
    
    log_info "备份当前版本到 $backup_dir/$backup_name"
    cp -r "$TOOLBOX_DIR" "$backup_dir/$backup_name"
    
    local backup_count=$(ls -1 "$backup_dir" | wc -l)
    local max_backups=5
    
    if [[ $backup_count -gt $max_backups ]]; then
        log_info "清理旧备份..."
        ls -1t "$backup_dir" | tail -n +$((max_backups + 1)) | xargs -I {} rm -rf "$backup_dir/{}"
    fi
}

uninstall_toolbox() {
    print_title "卸载工具箱"
    
    log_warn "警告：此操作将完全删除工具箱及其配置"
    
    if ! confirm_action "确定要卸载工具箱吗？"; then
        return
    fi
    
    uninstall_toolbox_silent
    
    log_success "工具箱已卸载"
    press_enter
}

uninstall_toolbox_silent() {
    log_info "删除工具箱文件..."
    
    if [[ -d "$TOOLBOX_DIR" ]]; then
        rm -rf "$TOOLBOX_DIR"
    fi
    
    if [[ -f "$TOOLBOX_BIN" ]]; then
        rm -f "$TOOLBOX_BIN"
    fi
    
    if confirm_action "是否删除配置文件？" "n"; then
        rm -rf "$HOME/.toolbox"
    fi
}

show_toolbox_info() {
    print_title "工具箱信息"
    
    if [[ ! -d "$TOOLBOX_DIR" ]]; then
        log_error "工具箱未安装"
        press_enter
        return
    fi
    
    echo -e "${CYAN}安装路径:${NC} $TOOLBOX_DIR"
    echo -e "${CYAN}命令路径:${NC} $TOOLBOX_BIN"
    echo -e "${CYAN}配置文件:${NC} $TOOLBOX_CONFIG"
    echo
    
    if [[ -f "$TOOLBOX_DIR/version" ]]; then
        echo -e "${CYAN}版本信息:${NC} $(cat "$TOOLBOX_DIR/version")"
    fi
    
    if [[ -d "$TOOLBOX_DIR/.git" ]]; then
        echo -e "${CYAN}Git信息:${NC}"
        cd "$TOOLBOX_DIR"
        echo "  分支: $(git branch --show-current 2>/dev/null || echo '未知')"
        echo "  提交: $(git rev-parse --short HEAD 2>/dev/null || echo '未知')"
        echo "  远程: $(git remote get-url origin 2>/dev/null || echo '未知')"
    fi
    
    echo
    echo -e "${CYAN}文件列表:${NC}"
    ls -la "$TOOLBOX_DIR"
    
    echo
    echo -e "${CYAN}磁盘使用:${NC}"
    du -sh "$TOOLBOX_DIR"
    
    press_enter
}

config_management() {
    while true; do
        show_menu "配置管理" \
            "查看配置" \
            "编辑配置" \
            "重置配置" \
            "导出配置" \
            "导入配置" \
            "配置向导"
        
        local choice=$(read_choice 6)
        
        case $choice in
            0) return ;;
            1) view_config ;;
            2) edit_config ;;
            3) reset_config ;;
            4) export_config ;;
            5) import_config ;;
            6) config_wizard ;;
        esac
    done
}

view_config() {
    print_title "查看配置"
    
    if [[ ! -f "$TOOLBOX_CONFIG" ]]; then
        log_error "配置文件不存在"
        press_enter
        return
    fi
    
    echo -e "${CYAN}配置文件内容:${NC}"
    cat "$TOOLBOX_CONFIG"
    
    press_enter
}

edit_config() {
    print_title "编辑配置"
    
    if [[ ! -f "$TOOLBOX_CONFIG" ]]; then
        log_error "配置文件不存在，正在创建..."
        create_toolbox_config
    fi
    
    local editor="nano"
    if command -v vim &> /dev/null; then
        editor="vim"
    fi
    
    log_info "使用 $editor 编辑配置文件"
    $editor "$TOOLBOX_CONFIG"
    
    log_success "配置已保存"
    press_enter
}

reset_config() {
    print_title "重置配置"
    
    if confirm_action "确定要重置配置文件吗？"; then
        create_toolbox_config
        log_success "配置已重置"
    fi
    
    press_enter
}

backup_config() {
    print_title "备份配置"
    
    if [[ ! -f "$TOOLBOX_CONFIG" ]]; then
        log_error "配置文件不存在"
        press_enter
        return
    fi
    
    local backup_dir="$HOME/.toolbox/config-backups"
    local backup_file="config-backup-$(date +%Y%m%d-%H%M%S).conf"
    
    mkdir -p "$backup_dir"
    cp "$TOOLBOX_CONFIG" "$backup_dir/$backup_file"
    
    log_success "配置已备份到: $backup_dir/$backup_file"
    
    local backup_count=$(ls -1 "$backup_dir" | wc -l)
    if [[ $backup_count -gt 10 ]]; then
        log_info "清理旧备份..."
        ls -1t "$backup_dir" | tail -n +11 | xargs -I {} rm -f "$backup_dir/{}"
    fi
    
    press_enter
}

restore_config() {
    print_title "恢复配置"
    
    local backup_dir="$HOME/.toolbox/config-backups"
    
    if [[ ! -d "$backup_dir" ]] || [[ -z "$(ls -A "$backup_dir")" ]]; then
        log_error "没有找到配置备份"
        press_enter
        return
    fi
    
    echo -e "${CYAN}可用的配置备份:${NC}"
    local backups=()
    local i=1
    
    for backup in "$backup_dir"/*; do
        if [[ -f "$backup" ]]; then
            backups+=("$backup")
            echo "$i. $(basename "$backup")"
            ((i++))
        fi
    done
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        log_error "没有找到有效的配置备份"
        press_enter
        return
    fi
    
    echo "0. 返回"
    
    local choice=$(read_choice ${#backups[@]})
    
    if [[ $choice -eq 0 ]]; then
        return
    fi
    
    local selected_backup="${backups[$((choice-1))]}"
    
    if confirm_action "确定要恢复配置 $(basename "$selected_backup") 吗？"; then
        cp "$selected_backup" "$TOOLBOX_CONFIG"
        log_success "配置已恢复"
    fi
    
    press_enter
}

config_wizard() {
    print_title "配置向导"
    
    log_info "欢迎使用配置向导，将引导您完成基本配置"
    
    echo
    echo "1. 自动更新设置"
    if confirm_action "是否启用自动更新？" "y"; then
        auto_update="true"
    else
        auto_update="false"
    fi
    
    echo
    echo "2. 安全检查设置"
    if confirm_action "是否启用安全检查？" "y"; then
        security_check="true"
    else
        security_check="false"
    fi
    
    echo
    echo "3. 自动备份设置"
    if confirm_action "是否启用自动备份？" "y"; then
        auto_backup="true"
    else
        auto_backup="false"
    fi
    
    echo
    echo "4. 日志级别设置"
    echo "请选择日志级别:"
    echo "1. debug (详细)"
    echo "2. info (普通)"
    echo "3. warn (警告)"
    echo "4. error (错误)"
    
    local log_choice=$(read_choice 4)
    case $log_choice in
        1) log_level="debug" ;;
        2) log_level="info" ;;
        3) log_level="warn" ;;
        4) log_level="error" ;;
        *) log_level="info" ;;
    esac
    
    log_info "正在保存配置..."
    
    cat > "$TOOLBOX_CONFIG" << EOF
# Linux Toolbox 配置文件
# 配置时间: $(date)
# 通过配置向导生成

# 工具箱设置
TOOLBOX_AUTO_UPDATE=$auto_update
TOOLBOX_CHECK_INTERVAL=7
TOOLBOX_LOG_LEVEL=$log_level
TOOLBOX_BACKUP_COUNT=5

# 网络设置
NETWORK_TIMEOUT=30
DOWNLOAD_MIRROR=auto

# 安全设置
SECURITY_CHECK=$security_check
FIREWALL_AUTO_CONFIG=false

# 软件源设置
APT_MIRROR=auto
YUM_MIRROR=auto

# 备份设置
BACKUP_DIR=$HOME/.toolbox/backups
AUTO_BACKUP=$auto_backup
EOF
    
    chmod 600 "$TOOLBOX_CONFIG"
    
    log_success "配置向导完成！"
    press_enter
}

reset_toolbox() {
    print_title "重置工具箱"
    
    log_warn "警告：此操作将重置工具箱到初始状态"
    log_warn "这将删除所有配置和备份文件"
    
    if ! confirm_action "确定要重置工具箱吗？"; then
        return
    fi
    
    log_info "重置工具箱..."
    
    rm -rf "$HOME/.toolbox"
    
    if [[ -d "$TOOLBOX_DIR/.git" ]]; then
        cd "$TOOLBOX_DIR"
        git reset --hard HEAD
        git clean -fd
    fi
    
    create_toolbox_config
    
    log_success "工具箱已重置"
    press_enter
}

check_toolbox_update() {
    if [[ ! -f "$TOOLBOX_CONFIG" ]]; then
        return
    fi
    
    source "$TOOLBOX_CONFIG"
    
    if [[ "$TOOLBOX_AUTO_UPDATE" != "true" ]]; then
        return
    fi
    
    local last_check_file="$HOME/.toolbox/.last_update_check"
    local current_time=$(date +%s)
    local check_interval=${TOOLBOX_CHECK_INTERVAL:-7}
    local check_interval_seconds=$((check_interval * 24 * 3600))
    
    if [[ -f "$last_check_file" ]]; then
        local last_check=$(cat "$last_check_file")
        local time_diff=$((current_time - last_check))
        
        if [[ $time_diff -lt $check_interval_seconds ]]; then
            return
        fi
    fi
    
    echo "$current_time" > "$last_check_file"
    
    if [[ -d "$TOOLBOX_DIR/.git" ]]; then
        cd "$TOOLBOX_DIR"
        git fetch origin --quiet 2>/dev/null
        
        local local_commit=$(git rev-parse HEAD)
        local remote_commit=$(git rev-parse origin/main 2>/dev/null)
        
        if [[ "$local_commit" != "$remote_commit" ]]; then
            log_info "发现工具箱更新，使用 'toolbox' 命令进入管理界面更新"
        fi
    fi
}