#!/bin/bash

set -Eeuo pipefail
IFS=$'\n\t'

trap 'ltbx_error_handler "${BASH_SOURCE[0]}" "${LINENO}" "${FUNCNAME[0]:-main}" "$?"' ERR

ltbx_toolbox_management_menu() {
    if [ "${LTBX_NON_INTERACTIVE:-false}" = "true" ]; then
        printf "${YELLOW}非交互模式，跳过工具箱管理${NC}\n"
        return 0
    fi

    if [ ! -t 0 ] || [ ! -t 1 ]; then
        printf "${YELLOW}非TTY环境，跳过工具箱管理${NC}\n"
        return 0
    fi

    ltbx_show_header
    printf "${CYAN}╔═══════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║              工具箱管理               ║${NC}\n"
    printf "${CYAN}╠═══════════════════════════════════════╣${NC}\n"
    printf "${GREEN}║  1) 安装/更新工具箱                  ║${NC}\n"
    printf "${RED}║  2) 卸载工具箱                        ║${NC}\n"
    printf "${CYAN}║  0) 返回主菜单                        ║${NC}\n"
    printf "${CYAN}╚═══════════════════════════════════════╝${NC}\n"

    printf "${YELLOW}请选择操作: ${NC}"
    read -r choice < /dev/tty

    case "$choice" in
        1)
            ltbx_install_or_update_toolbox
            ;;
        2)
            printf "${RED}确认要卸载工具箱吗？这将删除所有相关文件。(y/N): ${NC}"
            read -r confirm < /dev/tty
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                ltbx_uninstall_toolbox
            else
                printf "${YELLOW}已取消卸载操作。${NC}\n"
                ltbx_press_any_key
                ltbx_toolbox_management_menu
            fi
            ;;
        0)
            return 0
            ;;
        *)
            printf "${RED}无效选择，请重新输入${NC}\n"
            ltbx_press_any_key
            ltbx_toolbox_management_menu
            ;;
    esac
}

ltbx_install_or_update_toolbox() {
    printf "${YELLOW}正在从 GitHub 下载最新安装脚本并执行...${NC}\n"
    local install_script_url="https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main/install.sh"
    local expected_sha256=""
    local temp_script
temp_script=$(mktemp)

    ltbx_log "开始下载安装脚本: $install_script_url" "info"

    if command -v curl &>/dev/null; then
        if ! curl -sL "${install_script_url}" -o "$temp_script"; then
            ltbx_log "curl下载失败" "error"
            printf "${RED}错误: 下载安装脚本失败${NC}\n"
            rm -f "$temp_script"
            ltbx_press_any_key
            ltbx_toolbox_management_menu
            return 1
        fi
    elif command -v wget &>/dev/null; then
        if ! wget -qO "$temp_script" "${install_script_url}"; then
            ltbx_log "wget下载失败" "error"
            printf "${RED}错误: 下载安装脚本失败${NC}\n"
            rm -f "$temp_script"
            ltbx_press_any_key
            ltbx_toolbox_management_menu
            return 1
        fi
    else
        ltbx_log "缺少下载工具" "error"
        printf "${RED}错误: curl 或 wget 未安装，无法下载安装脚本。${NC}\n"
        ltbx_press_any_key
        ltbx_toolbox_management_menu
        return 1
    fi

    if [ -n "$expected_sha256" ] && command -v sha256sum &>/dev/null; then
        local actual_sha256
actual_sha256=$(sha256sum "$temp_script" | cut -d' ' -f1)
        if [ "$actual_sha256" != "$expected_sha256" ]; then
            ltbx_log "SHA256校验失败: 期望 $expected_sha256, 实际 $actual_sha256" "error"
            printf "${RED}错误: 安装脚本校验失败，可能存在安全风险${NC}\n"
            rm -f "$temp_script"
            ltbx_press_any_key
            ltbx_toolbox_management_menu
            return 1
        fi
        ltbx_log "SHA256校验通过" "info"
    fi

    local install_output
install_output=$(bash "$temp_script" 2>&1)
    local install_exit_code=$?

    rm -f "$temp_script"

    printf "%s\n" "$install_output"

    if [ $install_exit_code -eq 0 ] && [[ "$install_output" == *"安装/更新 成功"* ]]; then
        ltbx_log "工具箱安装/更新成功" "info"
        printf "${GREEN}更新成功！正在重启工具箱...${NC}\n"
        sleep 2
        exec tool
    else
        ltbx_log "工具箱安装/更新失败，退出码: $install_exit_code" "error"
        printf "${RED}更新似乎失败了，请检查上面的输出。${NC}\n"
        ltbx_press_any_key
        ltbx_toolbox_management_menu
    fi
}

ltbx_uninstall_toolbox() {
    printf "${YELLOW}正在卸载工具箱...${NC}\n"

    local tool_executable="${LTBX_TOOL_EXECUTABLE:-/usr/local/bin/tool}"
    local toolbox_install_dir="${LTBX_TOOLBOX_INSTALL_DIR:-/usr/local/share/linux-toolbox}"
    local toolbox_lib_dir="${LTBX_TOOLBOX_LIB_DIR:-/usr/local/lib/linux-toolbox}"

    if [ ! -f "$tool_executable" ]; then
        ltbx_log "工具箱未安装" "info"
        printf "${RED}工具箱未安装，无需卸载。${NC}\n"
    else
        ltbx_log "开始卸载工具箱" "info"
        rm -f "$tool_executable"
        rm -rf "$toolbox_install_dir"
        rm -rf "$toolbox_lib_dir"
        hash -r 2>/dev/null || true
        ltbx_log "工具箱卸载完成" "info"
        printf "${GREEN}工具箱已成功卸载。${NC}\n"
        printf "${YELLOW}为了确保所有更改生效，建议您关闭并重新打开终端。${NC}\n"
    fi

    if [ "${LTBX_NON_INTERACTIVE:-false}" != "true" ] && [ -t 0 ] && [ -t 1 ]; then
        read -p "按回车键退出..." < /dev/tty
    fi
    exit 0
}

ltbx_check_version() {
    local current_version="${LTBX_VERSION:-unknown}"
    local remote_version_url="https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main/VERSION"
    local remote_version

    printf "${BLUE}当前版本: %s${NC}\n" "$current_version"

    if command -v curl &>/dev/null; then
remote_version=$(curl -s "$remote_version_url" 2>/dev/null | tr -d '\n\r' || echo "unknown")
    elif command -v wget &>/dev/null; then
remote_version=$(wget -qO- "$remote_version_url" 2>/dev/null | tr -d '\n\r' || echo "unknown")
    else
        printf "${YELLOW}无法检查远程版本：缺少 curl 或 wget${NC}\n"
        return 1
    fi

    printf "${BLUE}远程版本: %s${NC}\n" "$remote_version"

    if [ "$current_version" != "$remote_version" ] && [ "$remote_version" != "unknown" ]; then
        printf "${YELLOW}发现新版本！建议更新。${NC}\n"
        return 1
    else
        printf "${GREEN}当前版本是最新的。${NC}\n"
        return 0
    fi
}

ltbx_auto_update_check() {
    local last_check_file="${LTBX_CONFIG_DIR:-/tmp}/last_update_check"
    local current_time
current_time=$(date +%s)
    local check_interval=${LTBX_UPDATE_CHECK_INTERVAL:-86400}

    if [ -f "$last_check_file" ]; then
        local last_check
last_check=$(cat "$last_check_file" 2>/dev/null || echo "0")
        local time_diff=$((current_time - last_check))

        if [ $time_diff -lt $check_interval ]; then
            return 0
        fi
    fi

    mkdir -p "$(dirname "$last_check_file")"
    echo "$current_time" > "$last_check_file"

    if ! ltbx_check_version >/dev/null 2>&1; then
        printf "${YELLOW}提示：发现新版本可用，使用 'tool manage' 进行更新。${NC}\n"
    fi
}

ltbx_backup_config() {
    local backup_dir="${LTBX_BACKUP_DIR:-$HOME/.linux-toolbox-backup}"
    local timestamp
timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/config_backup_$timestamp.tar.gz"

    mkdir -p "$backup_dir"

    printf "${BLUE}正在备份配置...${NC}\n"

    if tar -czf "$backup_file" -C / \
        usr/local/bin/tool \
        usr/local/share/linux-toolbox \
        usr/local/lib/linux-toolbox \
        2>/dev/null; then
        printf "${GREEN}配置已备份到: %s${NC}\n" "$backup_file"
        ltbx_log "配置备份成功: $backup_file" "info"
    else
        printf "${RED}配置备份失败${NC}\n"
        ltbx_log "配置备份失败" "error"
        return 1
    fi
}

ltbx_restore_config() {
    local backup_dir="${LTBX_BACKUP_DIR:-$HOME/.linux-toolbox-backup}"

    if [ ! -d "$backup_dir" ]; then
        printf "${RED}备份目录不存在: %s${NC}\n" "$backup_dir"
        return 1
    fi

    printf "${CYAN}可用的备份文件:${NC}\n"
    local backup_files
    mapfile -t backup_files < <(find "$backup_dir" -name "config_backup_*.tar.gz" -type f | sort -r)

    if [ ${#backup_files[@]} -eq 0 ]; then
        printf "${RED}未找到备份文件${NC}\n"
        return 1
    fi

    local i
    for i in "${!backup_files[@]}"; do
        local filename
filename=$(basename "${backup_files[i]}")
        printf "${GREEN}%d) %s${NC}\n" "$((i+1))" "$filename"
    done

    printf "${YELLOW}请选择要恢复的备份 [1-%d]: ${NC}" "${#backup_files[@]}"
    read -r choice < /dev/tty

    if ltbx_validate_number "$choice" 1 "${#backup_files[@]}"; then
        local selected_backup="${backup_files[$((choice-1))]}"
        printf "${BLUE}正在恢复配置...${NC}\n"

        if tar -xzf "$selected_backup" -C / 2>/dev/null; then
            printf "${GREEN}配置恢复成功${NC}\n"
            ltbx_log "配置恢复成功: $selected_backup" "info"
        else
            printf "${RED}配置恢复失败${NC}\n"
            ltbx_log "配置恢复失败: $selected_backup" "error"
            return 1
        fi
    else
        printf "${RED}无效选择${NC}\n"
        return 1
    fi
}
