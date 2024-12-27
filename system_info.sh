#!/bin/bash

# from https://github.com/spiritLHLS/ecs

_blue() { echo -e "\033[36m\033[01m$@\033[0m"; }

calc_disk() {
    local total_size=0
    local array=$@
    for size in ${array[@]}; do
        [ "${size}" == "0" ] && size_t=0 || size_t=$(echo ${size:0:${#size}-1})
        [ "$(echo ${size:(-1)})" == "K" ] && size=0
        [ "$(echo ${size:(-1)})" == "M" ] && size=$(awk 'BEGIN{printf "%.1f", '$size_t' / 1024}')
        [ "$(echo ${size:(-1)})" == "T" ] && size=$(awk 'BEGIN{printf "%.1f", '$size_t' * 1024}')
        [ "$(echo ${size:(-1)})" == "G" ] && size=${size_t}
        [ "$(echo ${size:(-1)})" == "E" ] && size=$(awk 'BEGIN{printf "%.1f", '$size_t' * 1024 * 1024}')
        total_size=$(awk 'BEGIN{printf "%.1f", '$total_size' + '$size'}')
    done
    echo ${total_size}
}

# -> 系统信息模块 (Collector) -> 获取内存及Swap信息
function BenchAPI_Systeminfo_GetMemoryinfo() {
    # 内存信息
    local r_memtotal_kib && r_memtotal_kib="$(awk '/MemTotal/{print $2}' /proc/meminfo | head -n1)"
    local r_memtotal_mib && r_memtotal_mib="$(echo "$r_memtotal_kib" | awk '{printf "%.2f\n",$1/1024}')"
    local r_memtotal_gib && r_memtotal_gib="$(echo "$r_memtotal_kib" | awk '{printf "%.2f\n",$1/1048576}')"
    local r_meminfo_memfree_kib && r_meminfo_memfree_kib="$(awk '/MemFree/{print $2}' /proc/meminfo | head -n1)"
    local r_meminfo_buffers_kib && r_meminfo_buffers_kib="$(awk '/Buffers/{print $2}' /proc/meminfo | head -n1)"
    local r_meminfo_cached_kib && r_meminfo_cached_kib="$(awk '/Cached/{print $2}' /proc/meminfo | head -n1)"
    local r_memfree_kib && r_memfree_kib="$(echo "$r_meminfo_memfree_kib" "$r_meminfo_buffers_kib" "$r_meminfo_cached_kib" | awk '{printf $1+$2+$3}')"
    local r_memfree_mib && r_memfree_mib="$(echo "$r_memfree_kib" | awk '{printf "%.2f\n",$1/1024}')"
    local r_memfree_gib && r_memfree_gib="$(echo "$r_memfree_kib" | awk '{printf "%.2f\n",$1/1048576}')"
    local r_memused_kib && r_memused_kib="$(echo "$r_memtotal_kib" "$r_memfree_kib" | awk '{printf $1-$2}')"
    local r_memused_mib && r_memused_mib="$(echo "$r_memused_kib" | awk '{printf "%.2f\n",$1/1024}')"
    local r_memused_gib && r_memused_gib="$(echo "$r_memused_kib" | awk '{printf "%.2f\n",$1/1048576}')"
    # 交换信息
    local r_swaptotal_kib && r_swaptotal_kib="$(awk '/SwapTotal/{print $2}' /proc/meminfo | head -n1)"
    local r_swaptotal_mib && r_swaptotal_mib="$(echo "$r_swaptotal_kib" | awk '{printf "%.2f\n",$1/1024}')"
    local r_swaptotal_gib && r_swaptotal_gib="$(echo "$r_swaptotal_kib" | awk '{printf "%.2f\n",$1/1048576}')"
    local r_swapfree_kib && r_swapfree_kib="$(awk '/SwapFree/{print $2}' /proc/meminfo | head -n1)"
    local r_swapfree_mib && r_swapfree_mib="$(echo "$r_swapfree_kib" | awk '{printf "%.2f\n",$1/1024}')"
    local r_swapfree_gib && r_swapfree_gib="$(echo "$r_swapfree_kib" | awk '{printf "%.2f\n",$1/1048576}')"
    local r_swapused_kib && r_swapused_kib="$(echo "$r_swaptotal_kib" "${r_swapfree_kib}" | awk '{printf $1-$2}')"
    local r_swapused_mib && r_swapused_mib="$(echo "$r_swapused_kib" | awk '{printf "%.2f\n",$1/1024}')"
    local r_swapused_gib && r_swapused_gib="$(echo "$r_swapused_kib" | awk '{printf "%.2f\n",$1/1048576}')"
    # 数据加工
    if [ "$r_memused_kib" -lt "1024" ] && [ "$r_memtotal_kib" -lt "1048576" ]; then
        Result_Systeminfo_Memoryinfo="$r_memused_kib KiB / $r_memtotal_mib MiB"
    elif [ "$r_memused_kib" -lt "1048576" ] && [ "$r_memtotal_kib" -lt "1048576" ]; then
        Result_Systeminfo_Memoryinfo="$r_memused_mib MiB / $r_memtotal_mib MiB"
    elif [ "$r_memused_kib" -lt "1048576" ] && [ "$r_memtotal_kib" -lt "1073741824" ]; then
        Result_Systeminfo_Memoryinfo="$r_memused_mib MiB / $r_memtotal_gib GiB"
    else
        Result_Systeminfo_Memoryinfo="$r_memused_gib GiB / $r_memtotal_gib GiB"
    fi
    if [ "$r_swaptotal_kib" -eq "0" ]; then
        Result_Systeminfo_Swapinfo="[ no swap partition or swap file detected ]"
    elif [ "$r_swapused_kib" -lt "1024" ] && [ "$r_swaptotal_kib" -lt "1048576" ]; then
        Result_Systeminfo_Swapinfo="$r_swapused_kib KiB / $r_swaptotal_mib MiB"
    elif [ "$r_swapused_kib" -lt "1024" ] && [ "$r_swaptotal_kib" -lt "1073741824" ]; then
        Result_Systeminfo_Swapinfo="$r_swapused_kib KiB / $r_swaptotal_gib GiB"
    elif [ "$r_swapused_kib" -lt "1048576" ] && [ "$r_swaptotal_kib" -lt "1048576" ]; then
        Result_Systeminfo_Swapinfo="$r_swapused_mib MiB / $r_swaptotal_mib MiB"
    elif [ "$r_swapused_kib" -lt "1048576" ] && [ "$r_swaptotal_kib" -lt "1073741824" ]; then
        Result_Systeminfo_Swapinfo="$r_swapused_mib MiB / $r_swaptotal_gib GiB"
    else
        Result_Systeminfo_Swapinfo="$r_swapused_gib GiB / $r_swaptotal_gib GiB"
    fi
}

# -> 系统信息模块 (Collector) -> 获取磁盘信息
function BenchAPI_Systeminfo_GetDiskinfo() {
    # 磁盘信息
    local r_diskpath_root && r_diskpath_root="$(df -x tmpfs / | awk "NR>1" | sed ":a;N;s/\\n//g;ta" | awk '{print $1}')"
    local r_disktotal_kib && r_disktotal_kib="$(df -x tmpfs / | grep -oE "[0-9]{4,}" | awk 'NR==1 {print $1}')"
    local r_disktotal_mib && r_disktotal_mib="$(echo "$r_disktotal_kib" | awk '{printf "%.2f\n",$1/1024}')"
    local r_disktotal_gib && r_disktotal_gib="$(echo "$r_disktotal_kib" | awk '{printf "%.2f\n",$1/1048576}')"
    local r_disktotal_tib && r_disktotal_tib="$(echo "$r_disktotal_kib" | awk '{printf "%.2f\n",$1/1073741824}')"
    local r_diskused_kib && r_diskused_kib="$(df -x tmpfs / | grep -oE "[0-9]{4,}" | awk 'NR==2 {print $1}')"
    local r_diskused_mib && r_diskused_mib="$(echo "$r_diskused_kib" | awk '{printf "%.2f\n",$1/1024}')"
    local r_diskused_gib && r_diskused_gib="$(echo "$r_diskused_kib" | awk '{printf "%.2f\n",$1/1048576}')"
    local r_diskused_tib && r_diskused_tib="$(echo "$r_diskused_kib" | awk '{printf "%.2f\n",$1/1073741824}')"
    local r_diskfree_kib && r_diskfree_kib="$(df -x tmpfs / | grep -oE "[0-9]{4,}" | awk 'NR==3 {print $1}')"
    local r_diskfree_mib && r_diskfree_mib="$(echo "$r_diskfree_kib" | awk '{printf "%.2f\n",$1/1024}')"
    local r_diskfree_gib && r_diskfree_gib="$(echo "$r_diskfree_kib" | awk '{printf "%.2f\n",$1/1048576}')"
    local r_diskfree_tib && r_diskfree_tib="$(echo "$r_diskfree_kib" | awk '{printf "%.2f\n",$1/1073741824}')"
    # 数据加工
    Result_Systeminfo_DiskRootPath="$r_diskpath_root"
    if [ "$r_diskused_kib" -lt "1048576" ]; then
        Result_Systeminfo_Diskinfo="$r_diskused_mib MiB / $r_disktotal_mib MiB"
    elif [ "$r_diskused_kib" -lt "1048576" ] && [ "$r_disktotal_kib" -lt "1073741824" ]; then
        Result_Systeminfo_Diskinfo="$r_diskused_mib MiB / $r_disktotal_gib GiB"
    elif [ "$r_diskused_kib" -lt "1073741824" ] && [ "$r_disktotal_kib" -lt "1073741824" ]; then
        Result_Systeminfo_Diskinfo="$r_diskused_gib GiB / $r_disktotal_gib GiB"
    elif [ "$r_diskused_kib" -lt "1073741824" ] && [ "$r_disktotal_kib" -ge "1073741824" ]; then
        Result_Systeminfo_Diskinfo="$r_diskused_gib GiB / $r_disktotal_tib TiB"
    else
        Result_Systeminfo_Diskinfo="$r_diskused_tib TiB / $r_disktotal_tib TiB"
    fi
}

disk_size1=($(LC_ALL=C df -hPl | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem|udev|docker|snapd' | awk '{print $2}'))
disk_size2=($(LC_ALL=C df -hPl | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem|udev|docker|snapd' | awk '{print $3}'))
disk_total_size=$(calc_disk "${disk_size1[@]}")
disk_used_size=$(calc_disk "${disk_size2[@]}")

cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
cores=$(awk -F: '/processor/ {core++} END {print core}' /proc/cpuinfo)

if command -v free >/dev/null 2>&1; then
    if free -m | grep -q '内存'; then # 如果输出中包含 "内存" 关键词
        tram=$(free -m | awk '/内存/{print $2}')
        uram=$(free -m | awk '/内存/{print $3}')
        swap=$(free -m | awk '/交换/{print $2}')
        uswap=$(free -m | awk '/交换/{print $3}')
    else # 否则，假定输出是英文的
        tram=$(
            LANG=C
            free -m | awk '/Mem/ {print $2}'
        )
        uram=$(
            LANG=C
            free -m | awk '/Mem/ {print $3}'
        )
        swap=$(
            LANG=C
            free -m | awk '/Swap/ {print $2}'
        )
        uswap=$(
            LANG=C
            free -m | awk '/Swap/ {print $3}'
        )
    fi
else
    tram=$($sysctl_path -n hw.physmem | awk '{printf "%.0f", $1/1024/1024}')
    uram=$($sysctl_path -n vm.stats.vm.v_active_count | awk '{printf "%.0f", $1/1024}')
    swap=$(swapinfo -k | awk 'NR>1{sum+=$2} END{printf "%.0f", sum/1024}')
    uswap=$(swapinfo -k | awk 'NR>1{sum+=$4} END{printf "%.0f", sum/1024}')
fi

BenchAPI_Systeminfo_GetMemoryinfo
BenchAPI_Systeminfo_GetDiskinfo

echo " CPU 型号          : $(_blue "$cname")"
echo " CPU 核心数        : $(_blue "$cores")"
echo " 内存              : $(_blue "$Result_Systeminfo_Memoryinfo")"
echo " 硬盘空间          : $(_blue "$Result_Systeminfo_Diskinfo")"
