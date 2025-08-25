#!/usr/bin/env bash

BrowserUA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
GeekbenchTest='Y'
LOG_FILE="/tmp/superbench_$(date +%s).log"
SPEED_LOG_FILE="/tmp/speedtest_$(date +%s).log"

function ltbx_sb_about() {
    printf "\n"
    printf " ========================================================= \n"
    printf " \\      Superbench Integration for Linux Toolbox         / \n"
    printf " \\       Basic system info, I/O test and speedtest       / \n"
    printf " \\                   v1.3.13 (Optimized)                 / \n"
    printf " ========================================================= \n"
    printf "\n"
}

function ltbx_sb_cancel() {
    printf "\n"
    ltbx_sb_next
    printf " Abort ...\n"
    printf " Cleanup ...\n"
    ltbx_sb_cleanup
    printf " Done\n"
    exit
}

function ltbx_sb_benchinit() {
    [[ $EUID -ne 0 ]] && printf "${RED}Error:${PLAIN} This script must be run as root!\n" && exit 1

ARCH=$(uname -m)
    if [[ $ARCH = *x86_64* ]]; then
ARCH="x64"
    elif [[ $ARCH = *i?86* ]]; then
ARCH="x86"
    elif [[ $ARCH = *aarch* || $ARCH = *arm* ]]; then
KERNEL_BIT=$(getconf LONG_BIT)
        if [[ $KERNEL_BIT = *64* ]]; then
ARCH="aarch64"
        else
ARCH="arm"
        fi
        echo -e "\nARM compatibility is considered *experimental*"
    else
        printf "Architecture not supported by Superbench.\n"
        exit 1
    fi

    for pkg in dmidecode curl tar wget unzip; do
        if ! command -v $pkg &> /dev/null; then
            printf " Installing $pkg ...\n"
            if [[ "${LTBX_OS_TYPE:-}" == "ubuntu" || "${LTBX_OS_TYPE:-}" == "debian" ]]; then
                apt-get update > /dev/null 2>&1
                apt-get -y install $pkg > /dev/null 2>&1
            else
                yum -y install $pkg > /dev/null 2>&1
            fi
        fi
    done

    if [ ! -e './speedtest-cli/speedtest' ]; then
        printf " Installing Speedtest-cli ...\n"
        wget --no-check-certificate -qO speedtest.tgz https://down.vpsaff.net/linux/speedtest/ookla-speedtest/1.2.0/ookla-speedtest-1.2.0-linux-$(uname -m).tgz > /dev/null 2>&1
        mkdir -p speedtest-cli && tar zxvf speedtest.tgz -C ./speedtest-cli/ > /dev/null 2>&1 && chmod a+rx ./speedtest-cli/speedtest
    fi

    if [ ! -e './nexttrace' ]; then
        printf " Installing NextTrace...\n"
        local arch=$(uname -m)
        local nexttrace_url=""
        case "$arch" in
            x86_64|amd64) nexttrace_url="https://down.vpsaff.net/linux/nexttrace/nexttrace_linux_amd64" ;;
            i386|i686) nexttrace_url="https://down.vpsaff.net/linux/nexttrace/nexttrace_linux_386" ;;
            aarch64|arm64) nexttrace_url="https://down.vpsaff.net/linux/nexttrace/nexttrace_linux_arm64" ;;
            *) printf " Warning: Unsupported architecture: %s\n" "$arch" ;;
        esac
        if [ -n "$nexttrace_url" ]; then
            wget --no-check-certificate -T 10 -qO nexttrace "$nexttrace_url" > /dev/null 2>&1
            chmod +x ./nexttrace
        fi
    fi

    start_time=$(date +%s)
}

function ltbx_sb_get_opsy() {
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

function ltbx_sb_next() {
    printf "%-82s\n" "-" | sed 's/\s/-/g' | tee -a $LOG_FILE
}

function ltbx_sb_speed_test() {
    local server_id=$1
    local node_name=$2
    local extra_args=""
    if [ -z "$server_id" ]; then
extra_args="-p no"
    else
extra_args="-p no -s $server_id"
    fi

    ./speedtest-cli/speedtest $extra_args --accept-license --accept-gdpr > $SPEED_LOG_FILE 2>&1

    if grep -q 'Upload' $SPEED_LOG_FILE; then
        local download=$(awk -F ' ' '/Download/{print $3}' $SPEED_LOG_FILE)
        local upload=$(awk -F ' ' '/Upload/{print $3}' $SPEED_LOG_FILE)
        local latency=$(awk -F ' ' '/Idle/{print $3}' $SPEED_LOG_FILE)
        local packet_loss=$(awk -F ' ' '/Packet/{print $3}' $SPEED_LOG_FILE)

        if grep -q "Packet Loss: Not available." $SPEED_LOG_FILE; then
packet_loss="N/A"
        fi

        if [[ $(echo "$download" | cut -d'.' -f1) -gt 0 ]]; then
            printf "${YELLOW}%-18s${GREEN}%-18s${RED}%-20s${SKYBLUE}%-12s${PLAIN}%-20s\n" " ${node_name}" "${upload} Mbit/s" "${download} Mbit/s" "${latency} ms" "${packet_loss}" | tee -a $LOG_FILE
        fi
    fi
}

function ltbx_sb_print_china_speedtest() {
    printf "%-18s%-18s%-20s%-12s%-20s\n" " Node Name" "Upload Speed" "Download Speed" "Latency" "Packet Loss" | tee -a $LOG_FILE
    ltbx_sb_speed_test '' 'Speedtest.net'
    ltbx_sb_speed_test '36663' 'Zhenjiang 5G CT'
    ltbx_sb_speed_test '26352' 'Nanjing 5G   CT'
    ltbx_sb_speed_test '5145'  'Beijing      CU'
    ltbx_sb_speed_test '24447' 'Shanghai 5G  CU'
    ltbx_sb_speed_test '13704' 'Nanjing      CU'
    ltbx_sb_speed_test '25637' 'Shanghai 5G  CM'
    ltbx_sb_speed_test '25858' 'Beijing      CM'
    ltbx_sb_speed_test '4575'  'Chengdu      CM'
}

function ltbx_sb_print_global_speedtest() {
    printf "%-18s%-18s%-20s%-12s%-20s\n" " Node Name" "Upload Speed" "Download Speed" "Latency" "Packet Loss" | tee -a $LOG_FILE
    ltbx_sb_speed_test '1536'  'Hong Kong    CN'
    ltbx_sb_speed_test '18611' 'Taiwan       CN'
    ltbx_sb_speed_test '40508' 'Singapore    SG'
    ltbx_sb_speed_test '56935' 'Tokyo        JP'
    ltbx_sb_speed_test '18229' 'Los Angeles  US'
    ltbx_sb_speed_test '24281' 'London       UK'
    ltbx_sb_speed_test '53651' 'Frankfurt    DE'
}

function ltbx_sb_io_test() {
    (LANG=C dd if=/dev/zero of=test_file_$$ bs=512K count=$1 conv=fdatasync && rm -f test_file_$$ ) 2>&1 | awk -F, '{io=$NF} END { print io}' | sed 's/^[ \t]*//;s/[ \t]*$//'
}

function ltbx_sb_freedisk() {
    local freespace
freespace=$( df -m . | awk 'NR==2 {print $4}' )
    if [[ -z $freespace ]]; then
freespace=$( df -m . | awk 'NR==3 {print $3}' )
    fi

    if [[ $freespace -gt 1024 ]]; then printf "2048";
    elif [[ $freespace -gt 512 ]]; then printf "1024";
    elif [[ $freespace -gt 256 ]]; then printf "512";
    elif [[ $freespace -gt 128 ]]; then printf "256";
    else printf "1";
    fi
}

function ltbx_sb_print_io() {
    local writemb=$(ltbx_sb_freedisk)

    if [[ $writemb != "1" ]]; then
        local writemb_size="$(( writemb / 2 ))MB"
        [[ $writemb_size == "1024MB" ]] && writemb_size="1.0GB"

        printf " I/O Test (3 runs, %s each):\n" "$writemb_size" | tee -a $LOG_FILE
        local io1=$(ltbx_sb_io_test $writemb)
        local io2=$(ltbx_sb_io_test $writemb)
        local io3=$(ltbx_sb_io_test $writemb)

        local ioraw1=$(echo "$io1" | awk '{print $1}')
        [[ "$(echo "$io1" | awk '{print $2}')" == "GB/s" ]] && ioraw1=$(awk 'BEGIN{print '$ioraw1' * 1024}')
        local ioraw2=$(echo "$io2" | awk '{print $1}')
        [[ "$(echo "$io2" | awk '{print $2}')" == "GB/s" ]] && ioraw2=$(awk 'BEGIN{print '$ioraw2' * 1024}')
        local ioraw3=$(echo "$io3" | awk '{print $1}')
        [[ "$(echo "$io3" | awk '{print $2}')" == "GB/s" ]] && ioraw3=$(awk 'BEGIN{print '$ioraw3' * 1024}')

        local ioavg=$(awk 'BEGIN{printf "%.1f", ('$ioraw1' + '$ioraw2' + '$ioraw3') / 3}')

        printf "    Run 1           : ${YELLOW}%s${PLAIN}\n" "$io1" | tee -a $LOG_FILE
        printf "    Run 2           : ${YELLOW}%s${PLAIN}\n" "$io2" | tee -a $LOG_FILE
        printf "    Run 3           : ${YELLOW}%s${PLAIN}\n" "$io3" | tee -a $LOG_FILE
        printf "    Average         : ${YELLOW}%s MB/s${PLAIN}\n" "$ioavg" | tee -a $LOG_FILE
    else
        printf " I/O Test             : ${RED}Not enough space to run test!${PLAIN}\n" | tee -a $LOG_FILE
    fi
}

function ltbx_sb_print_system_info() {
	printf " CPU Model            : ${SKYBLUE}%s${PLAIN}\n" "$cname" | tee -a $LOG_FILE
	printf " CPU Cores            : ${YELLOW}%s Cores @ ${SKYBLUE}%s MHz${PLAIN}\n" "$cores" "$freq" | tee -a $LOG_FILE
	printf " CPU Flags            : ${SKYBLUE}AES-NI %s & VM-x/AMD-V %s${PLAIN}\n" "$aes" "$virt" | tee -a $LOG_FILE
	printf " OS                   : ${SKYBLUE}%s (%s Bit) ${YELLOW}%s${PLAIN}\n" "$opsy" "$lbit" "$virtual" | tee -a $LOG_FILE
	printf " Kernel               : ${SKYBLUE}%s${PLAIN}\n" "$kern" | tee -a $LOG_FILE
	printf " Total Space          : ${SKYBLUE}%s GB / ${YELLOW}%s GB ${PLAIN}\n" "$disk_used_size" "$disk_total_size" | tee -a $LOG_FILE
	printf " Total RAM            : ${SKYBLUE}%s MB / ${YELLOW}%s MB ${PLAIN}\n" "$uram" "$tram" | tee -a $LOG_FILE
	printf " Uptime               : ${SKYBLUE}%s${PLAIN}\n" "$up" | tee -a $LOG_FILE
	printf " Load Average         : ${SKYBLUE}%s${PLAIN}\n" "$load" | tee -a $LOG_FILE
	printf " TCP CC               : ${YELLOW}%s${PLAIN}\n" "$tcpctrl" | tee -a $LOG_FILE
}

function ltbx_sb_calc_disk() {
    local total_size=0; local size_t=0
    for size in "$@"; do
        [[ "${size: -1}" == "K" ]] && size_t=$(awk 'BEGIN{printf "%.1f", '${size:0:${#size}-1}' / 1024 / 1024}')
        [[ "${size: -1}" == "M" ]] && size_t=$(awk 'BEGIN{printf "%.1f", '${size:0:${#size}-1}' / 1024}')
        [[ "${size: -1}" == "G" ]] && size_t=${size:0:${#size}-1}
        [[ "${size: -1}" == "T" ]] && size_t=$(awk 'BEGIN{printf "%.1f", '${size:0:${#size}-1}' * 1024}')
        total_size=$(awk 'BEGIN{printf "%.1f", '$total_size' + '$size_t'}')
    done
    printf "%s" "$total_size"
}

function ltbx_sb_get_system_info() {
cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
cores=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)
freq=$(awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
aes=$(grep -q 'aes' /proc/cpuinfo && echo "Enabled" || echo "Disabled")
virt=$(grep -q -E 'vmx|svm' /proc/cpuinfo && echo "Enabled" || echo "Disabled")
tram=$(free -m | awk '/Mem/ {print $2}')
uram=$(free -m | awk '/Mem/ {print $3}')
up=$(awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days, %d hours, %d minutes",a,b,c)}' /proc/uptime)
load=$(awk '{print $1" "$2" "$3}' /proc/loadavg)
opsy=$(ltbx_sb_get_opsy)
lbit=$(getconf LONG_BIT)
kern=$(uname -r)
tcpctrl=$(sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}')

    local disk_size1; disk_size1=($(LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs' | awk '{print $2}'))
    local disk_size2; disk_size2=($(LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs' | awk '{print $3}'))
disk_total_size=$(ltbx_sb_calc_disk "${disk_size1[@]}")
disk_used_size=$(ltbx_sb_calc_disk "${disk_size2[@]}")

	if grep -qa 'docker\|lxc' /proc/1/cgroup; then
virtual="Container"
	elif [[ -f /proc/user_beancounters ]]; then
virtual="OpenVZ"
	elif [[ $(dmesg) == *kvm-clock* ]]; then
virtual="KVM"
	elif [[ $(dmesg) == *"VMware Virtual Platform"* ]]; then
virtual="VMware"
	elif [[ -e /proc/xen ]]; then
virtual="Xen"
	else
        virtual="Dedicated"
	fi
}

function ltbx_sb_traceroute_test() {
    local ip=$1
    local mode=$2
    local max_hop=$3
    local location=$4

    if command -v ./nexttrace &> /dev/null; then
        printf "\nNextTrace to %s (%s, %s Mode, Max %s Hop)\n" "$location" "$ip" "$mode" "$max_hop" | tee -a $LOG_FILE
        printf "============================================================\n" | tee -a $LOG_FILE
        ./nexttrace "$ip" -m "$max_hop" -g en -q 1 ${mode:+-T} 2>&1 | tail -n +4 | head -n -1 | tee -a $LOG_FILE
    fi
}

function ltbx_sb_print_traceroute_test() {
    ltbx_sb_traceroute_test "113.108.209.1" "TCP" "30" "China, Guangzhou CT"
    ltbx_sb_traceroute_test "180.153.28.5"  "TCP" "30" "China, Shanghai CT"
    ltbx_sb_traceroute_test "210.21.4.130"  "TCP" "30" "China, Guangzhou CU"
    ltbx_sb_traceroute_test "58.247.8.158"  "TCP" "30" "China, Shanghai CU"
    ltbx_sb_traceroute_test "120.196.212.25" "TCP" "30" "China, Guangzhou CM"
    ltbx_sb_traceroute_test "221.183.55.22" "TCP" "30" "China, Shanghai CM"
}

function ltbx_sb_print_end_time() {
    local end_time; end_time=$(date +%s)
    local time_diff=$((end_time - start_time))
    local minutes=$((time_diff / 60))
    local seconds=$((time_diff % 60))

    printf " Test finished in: %s min %s sec\n" "$minutes" "$seconds" | tee -a $LOG_FILE

    local bj_time; bj_time=$(curl -s https://api.idcoffer.com/time)
    if [[ $bj_time == *"html"* ]]; then
bj_time=$(date -u '+%Y-%m-%d %H:%M:%S')
    fi
    printf " Timestamp       : %s GMT+8\n" "$bj_time" | tee -a $LOG_FILE
    printf " Results log     : %s\n" "$LOG_FILE"
}

function ltbx_sb_cleanup() {
    rm -f test_file_* 2>/dev/null || true
    rm -rf speedtest* 2>/dev/null || true
    rm -f nexttrace 2>/dev/null || true
    rm -f "$LOG_FILE" 2>/dev/null || true
    rm -f "$SPEED_LOG_FILE" 2>/dev/null || true
    find /tmp -name "superbench_*.log" -type f -mtime +1 -delete 2>/dev/null || true
    find /tmp -name "speedtest_*.log" -type f -mtime +1 -delete 2>/dev/null || true
}

function run_superbench_test() {
    trap 'ltbx_sb_cancel' SIGINT

    > "$LOG_FILE"
    > "$SPEED_LOG_FILE"

    ltbx_sb_about | tee -a $LOG_FILE
    ltbx_sb_benchinit

    clear
    ltbx_sb_next
    printf " Superbench Test for Linux-Toolbox\n" | tee -a $LOG_FILE
    printf " Author: GamblerIX\n" | tee -a $LOG_FILE
    ltbx_sb_next

    ltbx_sb_get_system_info
    ltbx_sb_print_system_info
    ltbx_sb_next

    ltbx_sb_print_io
    ltbx_sb_next

    printf " China Speedtest:\n" | tee -a $LOG_FILE
    ltbx_sb_print_china_speedtest
    ltbx_sb_next

    printf " Global Speedtest:\n" | tee -a $LOG_FILE
    ltbx_sb_print_global_speedtest
    ltbx_sb_next

    printf " Traceroute Test:\n" | tee -a $LOG_FILE
    ltbx_sb_print_traceroute_test
    ltbx_sb_next

    ltbx_sb_print_end_time
    ltbx_sb_next

    ltbx_sb_cleanup
}
