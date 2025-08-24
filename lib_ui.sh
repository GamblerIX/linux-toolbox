#!/bin/bash

set -Eeuo pipefail
IFS=$'\n\t'

trap 'ltbx_error_handler "${BASH_SOURCE[0]}" "${LINENO}" "${FUNCNAME[0]:-main}" "$?"' ERR

ltbx_press_any_key() {
    printf "\n"
    if [ "${LTBX_NON_INTERACTIVE:-false}" = "true" ]; then
        printf "${YELLOW}非交互模式，跳过等待${NC}\n"
        return 0
    fi

    if [ "${LTBX_NON_INTERACTIVE:-false}" != "true" ] && [ -t 0 ] && [ -t 1 ]; then
        read -p "按任意键继续..." -n 1 -r < /dev/tty
        printf "\n"
    fi
}

ltbx_select_user_interactive() {
    local prompt_message="$1"

    if [ "${LTBX_NON_INTERACTIVE:-false}" = "true" ]; then
        printf "${YELLOW}非交互模式，返回root用户${NC}\n"
        echo "root"
        return 0
    fi

    if ! [ -t 0 ] || ! [ -t 1 ]; then
        printf "${YELLOW}非TTY环境，返回root用户${NC}\n"
        echo "root"
        return 0
    fi

    mapfile -t users < <(awk -F: '($1 == "root") || ($3 >= 1000 && $7 ~ /^\/bin\/(bash|sh|zsh|dash)$/)' /etc/passwd | cut -d: -f1 | sort)

    if [ ${#users[@]} -eq 0 ]; then
        printf "${RED}错误：未找到可用用户${NC}\n"
        echo "root"
        return 1
    fi

    printf "${CYAN}╔═════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║              用户选择               ║${NC}\n"
    printf "${CYAN}╠═════════════════════════════════════╣${NC}\n"

    local i
    for i in "${!users[@]}"; do
        if [ "${users[i]}" = "root" ]; then
            printf "${RED}║  %d) %-30s ║${NC}\n" "$i" "${users[i]} (管理员)"
        else
            printf "${GREEN}║  %d) %-30s ║${NC}\n" "$i" "${users[i]}"
        fi
    done

    printf "${CYAN}└─────────────────────────────────────┘${NC}\n"
    printf "${YELLOW}请选择要操作的用户：${NC}\n"

    read -p "输入用户编号 [0-${#users[@]}]: " choice < /dev/tty

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -lt "${#users[@]}" ]; then
        echo "${users[choice]}"
    else
        printf "${RED}无效选择，默认使用root用户${NC}\n"
        echo "root"
    fi
}

ltbx_show_menu_header() {
    local title="$1"
    local width=${2:-50}

    printf "${CYAN}"
    printf "╔"
    printf "═%.0s" $(seq 1 $((width - 2)))
    printf "╗${NC}\n"

    local title_len=${#title}
    local padding=$(( (width - title_len - 2) / 2 ))

    printf "${CYAN}║"
    printf " %.0s" $(seq 1 $padding)
    printf "${GREEN}%s${CYAN}" "$title"
    printf " %.0s" $(seq 1 $((width - title_len - padding - 2)))
    printf "║${NC}\n"

    printf "${CYAN}"
    printf "╠"
    printf "═%.0s" $(seq 1 $((width - 2)))
    printf "╣${NC}\n"
}

ltbx_show_menu_footer() {
    local width=${1:-50}

    printf "${CYAN}"
    printf "╚"
    printf "═%.0s" $(seq 1 $((width - 2)))
    printf "╝${NC}\n"
}

ltbx_show_menu_item() {
    local number="$1"
    local text="$2"
    local color="${3:-GREEN}"
    local width=${4:-50}

    local item_text="$number) $text"
    local item_len=${#item_text}
    local padding=$((width - item_len - 4))

    printf "${CYAN}║  ${!color}%s${CYAN}" "$item_text"
    printf " %.0s" $(seq 1 $padding)
    printf "║${NC}\n"
}

ltbx_validate_number() {
    local input="$1"
    local min="${2:-0}"
    local max="${3:-999}"

    if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge "$min" ] && [ "$input" -le "$max" ]; then
        return 0
    else
        return 1
    fi
}

ltbx_validate_yes_no() {
    local input="$1"

    if [[ "$input" =~ ^[YyNn]$ ]]; then
        return 0
    else
        return 1
    fi
}

ltbx_show_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-处理中}"
    local width=${4:-50}

    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    printf "\r${CYAN}%s [" "$message"
    printf "${GREEN}█%.0s" $(seq 1 $filled)
    printf "${GRAY}░%.0s" $(seq 1 $empty)
    printf "${CYAN}] %d%%${NC}" "$percent"

    if [ "$current" -eq "$total" ]; then
        printf "\n"
    fi
}

ltbx_confirm_action() {
    local message="$1"
    local default="${2:-N}"

    if [ "${LTBX_NON_INTERACTIVE:-false}" = "true" ]; then
        printf "${YELLOW}非交互模式，使用默认选择: %s${NC}\n" "$default"
        [[ "$default" =~ ^[Yy]$ ]]
        return $?
    fi

    if [ ! -t 0 ] || [ ! -t 1 ]; then
        printf "${YELLOW}非TTY环境，使用默认选择: %s${NC}\n" "$default"
        [[ "$default" =~ ^[Yy]$ ]]
        return $?
    fi

    local prompt
    if [[ "$default" =~ ^[Yy]$ ]]; then
prompt="(Y/n)"
    else
prompt="(y/N)"
    fi

    while true; do
        printf "${YELLOW}%s %s: ${NC}" "$message" "$prompt"
        read -r response < /dev/tty

        if [ -z "$response" ]; then
response="$default"
        fi

        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                printf "${RED}请输入 y 或 n${NC}\n"
                ;;
        esac
    done
}

ltbx_show_status() {
    local status="$1"
    local message="$2"

    case "$status" in
        "success"|"ok")
            printf "${GREEN}[✓]${NC} %s\n" "$message"
            ;;
        "error"|"fail")
            printf "${RED}[✗]${NC} %s\n" "$message"
            ;;
        "warning"|"warn")
            printf "${YELLOW}[!]${NC} %s\n" "$message"
            ;;
        "info")
            printf "${BLUE}[i]${NC} %s\n" "$message"
            ;;
        "loading")
            printf "${CYAN}[...]${NC} %s\n" "$message"
            ;;
        *)
            printf "[%s] %s\n" "$status" "$message"
            ;;
    esac
}
