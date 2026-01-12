#!/bin/bash

# --- 配置 ---
MIN_PORT=30000  # 最小端口号
MAX_PORT=65535  # 最大端口号 (TCP/UDP 端口范围最大值)

# --- 函数定义 ---

# 检查端口是否被占用
# 参数: 端口号
# 返回: 0 如果端口未被占用， 1 如果端口已被占用
is_port_in_use() {
    local port=$1
    # ss -tuln: 列出所有监听状态的TCP和UDP端口 (t:tcp, u:udp, l:listen, n:numeric)
    # grep -q ":$port\b": 查找包含 ":<port_number>" 的行，\b 确保是精确匹配端口号，
    # 而不是匹配端口号的一部分 (例如，避免 30000 匹配 300001)
    # &>/dev/null: 将所有输出重定向到 /dev/null (静默执行)
    ss -tuln | grep -q ":$port\b" &>/dev/null
    return $? # 返回 grep 的退出状态码 (0 表示找到, 1 表示未找到)
}

# --- 主逻辑 ---

echo "正在寻找一个可用的随机端口 (范围: $MIN_PORT - $MAX_PORT)..."

FOUND_PORT=""

# 循环直到找到一个未被占用的端口
while true; do
    # 生成一个 MIN_PORT 到 MAX_PORT 之间的随机整数
    # $RANDOM 产生 0-32767 之间的数
    # 为了得到更大的范围，可能需要调整计算方法，或者简单地利用其范围。
    # 这里使用 (MAX_PORT - MIN_PORT + 1) 来确保范围的完整性，然后加上 MIN_PORT
    RANDOM_PORT=$(( ( RANDOM % (MAX_PORT - MIN_PORT + 1) ) + MIN_PORT ))

    echo "尝试端口: $RANDOM_PORT"

    if ! is_port_in_use "$RANDOM_PORT"; then
        FOUND_PORT="$RANDOM_PORT"
        break # 找到可用端口，退出循环
    fi

    # 稍微延迟一下，避免过于频繁地检查和生成，虽然对于端口检查来说通常不是问题
    sleep 0.1
done

echo "-----------------------------------"
echo "成功找到一个可用的端口: $FOUND_PORT"
echo "-----------------------------------"

# 如果你需要将这个端口号用于其他命令，可以输出它
# echo "$FOUND_PORT"
