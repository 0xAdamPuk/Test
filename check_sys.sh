#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 必须以 Root 运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误：请使用 sudo 或 root 用户运行此脚本，否则无法查看部分进程和日志。${NC}"
   exit 1
fi

print_header() {
    echo -e "\n${BLUE}==========================================================${NC}"
    echo -e "${BLUE}    $1 ${NC}"
    echo -e "${BLUE}==========================================================${NC}"
}

echo -e "${GREEN}正在开始系统快速体检...${NC}"

# ================= 1. 系统负载检查 =================
print_header "1. 系统负载 (Load Average)"
uptime_info=$(uptime)
load_15m=$(echo $uptime_info | awk -F'load average:' '{print $2}' | awk -F',' '{print $3}')
cpu_cores=$(nproc)
echo -e "系统运行时间: $(uptime -p)"
echo -e "CPU 核心数: ${YELLOW}$cpu_cores${NC}"
echo -e "当前负载 (1/5/15min): $(echo $uptime_info | awk -F'load average:' '{print $2}')"

# 简单的负载警告逻辑
if (( $(echo "$load_15m > $cpu_cores" | bc -l 2>/dev/null || echo 0) )); then
    echo -e "${RED}[警告] 15分钟平均负载 ($load_15m) 已超过 CPU 核心数，系统可能过载！${NC}"
else
    echo -e "${GREEN}[正常] 系统负载在合理范围内。${NC}"
fi

# ================= 2. CPU 占用 TOP 5 =================
print_header "2. CPU 占用最高的 5 个进程"
ps -eo pid,ppid,%cpu,%mem,cmd --sort=-%cpu | head -n 6

# ================= 3. 内存使用 & OOM 检查 =================
print_header "3. 内存使用情况 (Memory)"
free -h
echo -e "\n--- 内存占用最高的 5 个进程 ---"
ps -eo pid,ppid,%mem,%cpu,cmd --sort=-%mem | head -n 6

echo -e "\n--- 检查最近的 OOM (Out of Memory) 记录 ---"
# 检查 dmesg 或日志文件
oom_log=$(dmesg -T | grep -i "out of memory" | tail -n 3)
if [ -z "$oom_log" ]; then
    echo -e "${GREEN}[正常] 未在内核日志中发现近期 OOM 记录。${NC}"
else
    echo -e "${RED}[警告] 发现内存溢出记录：${NC}"
    echo "$oom_log"
fi

# ================= 4. 磁盘空间检查 =================
print_header "4. 磁盘空间 (Disk Usage)"
df -h | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 }' | while read output;
do
  usep=$(echo $output | awk '{ print $1}' | cut -d'%' -f1  )
  partition=$(echo $output | awk '{ print $2 }' )
  if [ $usep -ge 85 ]; then
    echo -e "${RED}[警告] 分区 $partition 使用率已达 $usep%${NC}"
  else
    echo -e "${GREEN}[正常] 分区 $partition 使用率: $usep%${NC}"
  fi
done

echo -e "\n--- 检查已删除但未释放的“幽灵”文件 (会导致磁盘满但找不到文件) ---"
deleted_files=$(lsof | grep deleted | sort -k7 -nr | head -n 5)
if [ -z "$deleted_files" ]; then
    echo -e "${GREEN}[正常] 未发现大量未释放的删除文件。${NC}"
else
    echo -e "${YELLOW}[提示] 发现以下文件被删除但仍占用空间 (Top 5)：${NC}"
    echo "$deleted_files"
fi

# ================= 5. 磁盘 I/O 检查 =================
print_header "5. 磁盘 I/O 瓶颈检查"
# 使用 vmstat 检查 wa (wait) 值
io_wait=$(vmstat 1 2 | tail -1 | awk '{print $16}')
echo -e "当前 CPU 等待 I/O (wa): ${YELLOW}$io_wait%${NC}"
if [ "$io_wait" -ge 20 ]; then
     echo -e "${RED}[警告] I/O 等待过高！可能存在磁盘读写瓶颈。${NC}"
     echo -e "建议运行 'iotop' (需安装) 查看具体进程。"
else
     echo -e "${GREEN}[正常] I/O 状态良好。${NC}"
fi

# ================= 6. 网络连接统计 =================
print_header "6. 网络连接统计 (TCP)"
if command -v ss &> /dev/null; then
    ss -ant | awk '{print $1}' | sort | uniq -c | sort -rn
else
    netstat -ant | awk '{print $6}' | sort | uniq -c | sort -rn
fi
# 简单判断
time_wait=$(ss -ant | grep TIME_WAIT | wc -l)
if [ "$time_wait" -ge 5000 ]; then
     echo -e "${YELLOW}[提示] TIME_WAIT 连接数较多 ($time_wait)，高并发场景下请注意内核调优。${NC}"
fi

# ================= 7. 异常日志预览 =================
print_header "7. 系统关键日志预览 (最后 5 行错误)"
if [ -f /var/log/messages ]; then
    grep -i "error" /var/log/messages | tail -n 5
elif [ -f /var/log/syslog ]; then
    grep -i "error" /var/log/syslog | tail -n 5
else
    echo "未找到标准系统日志文件。"
fi

echo -e "\n${BLUE}================ 体检结束 =================${NC}"
