#!/bin/bash

# 生成随机用户名（1-8位小写字母）
generate_username() {
    local length=$(( RANDOM % 8 + 1 ))
    tr -dc 'a-zA-Z' </dev/urandom | head -c "$length"
}

# 生成强密码（16位，包含大小写字母和特殊符号）
generate_password() {
    local password=""
    local chars_lower='abcdefghijklmnopqrstuvwxyz'
    local chars_upper='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local chars_special='!@#$%^&*()-_=+[]{}|;:,.<>/?'
    
    # 确保至少包含每个字符类别
    password+="${chars_lower:$((RANDOM % ${#chars_lower})):1}"
    password+="${chars_upper:$((RANDOM % ${#chars_upper})):1}"
    password+="${chars_special:$((RANDOM % ${#chars_special})):1}"
    
    # 生成剩余13个字符
    local all_chars="${chars_lower}${chars_upper}${chars_special}"
    password+=$(tr -dc "$all_chars" </dev/urandom | head -c 13)
    
    # 打乱字符顺序
    echo "$password" | fold -w1 | shuf | tr -d '\n'
}

# 获取用户名
read -p "请输入用户名（留空生成随机用户名）：" input_username
if [[ -z "$input_username" ]]; then
    username=$(generate_username)
    echo "生成随机用户名：$username"
else
    username="$input_username"
fi

# 获取密码
read -p "请输入密码（留空生成强密码）：" input_password
if [[ -z "$input_password" ]]; then
    password=$(generate_password)
    echo "生成随机密码：$password"
else
    password="$input_password"
fi

# 确认是否安装vertex
read -p "是否安装vertex？[y/N] " install_vertex
install_vertex=${install_vertex,,}

# 构建命令参数
command_args=(
    "-u" "$username"
    "-p" "$password"
    "-c" "3072"
    "-q" "5.0.3"
    "-l" "v2.0.11"
    "-b" "-r" "-x"
)

if [[ "$install_vertex" == "y" ]]; then
    command_args+=("-v")
fi

command_args+=("-o")

# 执行安装命令
echo "正在启动安装流程..."
bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) "${command_args[@]}"
