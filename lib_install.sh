#!/bin/bash

set -Eeuo pipefail
IFS=$'\n\t'

trap 'ltbx_error_handler "${BASH_SOURCE[0]}" "${LINENO}" "${FUNCNAME[0]:-main}" "$?"' ERR

function ltbx_toolbox_management_menu() {
    if [ "${LTBX_NON_INTERACTIVE:-false}" = "true" ]; then
        printf "${YELLOW}非交互模式模跳过，跳过过工具箱管理?{NC}\n"
        return 0
    fi

    if [ ! -t 0 ] || [ ! -t 1 ]; then
        printf "${YELLOW}非濼TY鐜，岃烦进囧工具箱管理${NC}\n"
        return 0
    fi

    ltbx_show_header
    printf "${CYAN}★斺晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★?{NC}\n"
    printf "${CYAN}★?             工具箱管理?              ★?{NC}\n"
    printf "${CYAN}★犫晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★?{NC}\n"
    printf "${GREEN}★? 1) 安装/更新工具箱                 ★?{NC}\n"
    printf "${RED}★? 2) 卸载工具箱                       ★?{NC}\n"
    printf "${CYAN}★? 0) 返回主菜单?                       ★?{NC}\n"
    printf "${CYAN}★氣晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★愨晲★?{NC}\n"

    printf "${YELLOW}璇烽更嫨鎿嶄綔: ${NC}"
    read -r choice < /dev/tty

    case "$choice" in
        1)
            ltbx_install_or_update_toolbox
            ;;
        2)
            printf "${RED}确认瑕佸卸载到工具箱鍚楋紵进欏将删除所用夌浉具虫件件躲?y/N): ${NC}"
            read -r confirm < /dev/tty
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                ltbx_uninstall_toolbox
            else
                printf "${YELLOW}已备彇娑堝卸载文搷使溿?{NC}\n"
                ltbx_press_any_key
                ltbx_toolbox_management_menu
            fi
            ;;
        0)
            return 0
            ;;
        *)
            printf "${RED}无效选择，岃新打新输入${NC}\n"
            ltbx_press_any_key
            ltbx_toolbox_management_menu
            ;;
    esac
}

function ltbx_install_or_update_toolbox() {
    printf "${YELLOW}正在下载用版板安装脚脚用重执行...${NC}\n"
    local install_script_url="https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main/install.sh"
    local expected_sha256=""
    local temp_script
    temp_script=$(ltbx_create_temp_file "install_script") || {
        printf "${RED}错误: 无犳硶鍒涘缓新新椂文件${NC}\n"
        ltbx_press_any_key
        ltbx_toolbox_management_menu
        return 1
    }

    ltbx_log "跳始嬩笅载到安装脚脚用? $install_script_url" "info"

    if ! ltbx_download_with_auto_source "$install_script_url" "$temp_script"; then
        ltbx_log "下载安装脚本失败" "error"
        printf "${RED}错误: 下载安装脚本失败${NC}\n"
        rm -f "$temp_script" 2>/dev/null || true
        ltbx_press_any_key
        ltbx_toolbox_management_menu
        return 1
    fi

    if [ -n "$expected_sha256" ] && command -v sha256sum &>/dev/null; then
        local actual_sha256
actual_sha256=$(sha256sum "$temp_script" | cut -d' ' -f1)
        if [ "$actual_sha256" != "$expected_sha256" ]; then
            ltbx_log "SHA256校验失败: 用熸期 $expected_sha256, 实际 $actual_sha256" "error"
            printf "${RED}错误: 安装脚本校验失败，外可鑳到新在安安具ㄩ闄?{NC}\n"
            rm -f "$temp_script"
            ltbx_press_any_key
            ltbx_toolbox_management_menu
            return 1
        fi
        ltbx_log "SHA256校验閫氳过" "info"
    fi

    local install_output
    printf "${CYAN}正在执行安装脚本...${NC}\n"
    if ! install_output=$(timeout 300 bash "$temp_script" 2>&1); then
        local install_exit_code=$?
        if [ $install_exit_code -eq 124 ]; then
            ltbx_log "安装脚本执行瓒呮椂" "error"
            printf "${RED}错误: 安装脚本执行瓒呮椂，堣秴进?鍒挓，?{NC}\n"
        else
            ltbx_log "安装脚本执行失败，退出出码: $install_exit_code" "error"
            printf "${RED}错误: 安装脚本执行失败${NC}\n"
        fi
        rm -f "$temp_script"
        ltbx_press_any_key
        ltbx_toolbox_management_menu
        return 1
    fi
    local install_exit_code=0

    rm -f "$temp_script"

    printf "%s\n" "$install_output"

    if [ $install_exit_code -eq 0 ] && [[ "$install_output" == *"安装/更新 成功"* ]]; then
        ltbx_log "工具箱卞安装?更新成功" "info"
        printf "${GREEN}更新成功，佹在ㄩ噸鍚工具箱...${NC}\n"
        sleep 2
        exec tool
    else
        ltbx_log "工具箱卞安装?更新失败，退出出码: $install_exit_code" "error"
        printf "${RED}更新浼间箮失败模嗭，璇锋鏌ヤ笂非㈢殑输出。?{NC}\n"
        ltbx_press_any_key
        ltbx_toolbox_management_menu
    fi
}

function ltbx_uninstall_toolbox() {
    printf "${YELLOW}正在卸载工具箱..${NC}\n"

    local tool_executable="${LTBX_TOOL_EXECUTABLE:-/usr/local/bin/tool}"
    local toolbox_install_dir="${LTBX_TOOLBOX_INSTALL_DIR:-/usr/local/share/linux-toolbox}"
    local toolbox_lib_dir="${LTBX_TOOLBOX_LIB_DIR:-/usr/local/lib/linux-toolbox}"

    if [ ! -f "$tool_executable" ]; then
        ltbx_log "工具箱辨未安装" "info"
        printf "${RED}工具箱辨未安装，成棤闇卸载。?{NC}\n"
    else
        ltbx_log "跳始跳卸载到工具箱" "info"
        rm -f "$tool_executable"
        rm -rf "$toolbox_install_dir"
        rm -rf "$toolbox_lib_dir"
        hash -r 2>/dev/null || true
        ltbx_log "工具箱卞卸载到完或? "info"
        printf "${GREEN}工具箱卞凡成功卸载。?{NC}\n"
        printf "${YELLOW}新轰簡确认保所用更改生效生效效，建议您安闭并重新打新所端跳终端。?{NC}\n"
    fi

    if [ "${LTBX_NON_INTERACTIVE:-false}" != "true" ]; then
        read -p "鎸安回载﹂敭退出.."
    fi
    exit 0
}

function ltbx_check_version() {
    local current_version="${LTBX_VERSION:-unknown}"
    local remote_version_url="https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main/VERSION"
    local remote_version

    printf "${BLUE}褰端墠版本: %s${NC}\n" "$current_version"

    local temp_version_file
    temp_version_file=$(ltbx_create_temp_file "version_check") || {
        printf "${YELLOW}无犳硶妫查询繙稳嬬可用細鍒涘缓新新椂文件失败${NC}\n"
        return 1
    }

    if ltbx_download_with_auto_source "$remote_version_url" "$temp_version_file"; then
        remote_version=$(cat "$temp_version_file" 2>/dev/null | tr -d '\n\r' || echo "unknown")
        rm -f "$temp_version_file" 2>/dev/null || true
    else
        printf "${YELLOW}无犳硶妫查询繙稳嬬可用細下载失败${NC}\n"
        rm -f "$temp_version_file" 2>/dev/null || true
        return 1
    fi

    printf "${BLUE}进滅程版本: %s${NC}\n" "$remote_version"

    if [ "$current_version" != "$remote_version" ] && [ "$remote_version" != "unknown" ]; then
        printf "${YELLOW}发现新版本可用紒建议更新。?{NC}\n"
        return 1
    else
        printf "${GREEN}褰端墠版本鏄需版本殑。?{NC}\n"
        return 0
    fi
}

function ltbx_auto_update_check() {
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

    if mkdir -p "$(dirname "$last_check_file")" 2>/dev/null && echo "$current_time" > "$last_check_file" 2>/dev/null; then
        : # 成功鍐欏叆妫鏌以椂并?    else
        ltbx_log "WARN" "无犳硶鍐欏叆更新妫鏌以件件讹，跳过过无堕棿记录"
    fi

    if ! ltbx_check_version >/dev/null 2>&1; then
        printf "${YELLOW}提示，氬彂鐜版新版本发用，屼娇用?'tool manage' 进行更新。?{NC}\n"
    fi
}

function ltbx_backup_config() {
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
        printf "${GREEN}配置已备件到到: %s${NC}\n" "$backup_file"
        ltbx_log "配置备份成功: $backup_file" "info"
    else
        printf "${RED}配置备份失败${NC}\n"
        ltbx_log "配置备份失败" "error"
        return 1
    fi
}

function ltbx_restore_config() {
    local backup_dir="${LTBX_BACKUP_DIR:-$HOME/.linux-toolbox-backup}"

    if [ ! -d "$backup_dir" ]; then
        printf "${RED}备份录不新在新在? %s${NC}\n" "$backup_dir"
        return 1
    fi

    printf "${CYAN}发用的备件文件件?${NC}\n"
    local backup_files
    mapfile -t backup_files < <(find "$backup_dir" -name "config_backup_*.tar.gz" -type f | sort -r)

    if [ ${#backup_files[@]} -eq 0 ]; then
        printf "${RED}用壘鍒板件文件件?{NC}\n"
        return 1
    fi

    local i
    for i in "${!backup_files[@]}"; do
        local filename
filename=$(basename "${backup_files[i]}")
        printf "${GREEN}%d) %s${NC}\n" "$((i+1))" "$filename"
    done

    printf "${YELLOW}璇烽更嫨瑕佹仮备置殑备份 [1-%d]: ${NC}" "${#backup_files[@]}"
    read -r choice < /dev/tty

    if ltbx_validate_number "$choice" 1 "${#backup_files[@]}"; then
        local selected_backup="${backup_files[$((choice-1))]}"
        printf "${BLUE}正在恢复配置...${NC}\n"

        if tar -xzf "$selected_backup" -C / 2>/dev/null; then
            printf "${GREEN}配置恢复成功${NC}\n"
            ltbx_log "配置恢复成功: $selected_backup" "info"
        else
            printf "${RED}配置恢复失败${NC}\n"
            ltbx_log "配置恢复失败: $selected_backup" "error"
            return 1
        fi
    else
        printf "${RED}无效选择${NC}\n"
        return 1
    fi
}
