#!/bin/bash

# Function to generate a random string of given length
generate_random_string() {
    local length=$1
    local result=""
    local characters="0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    for i in $(seq 1 $length); do
        result+=${characters:RANDOM%${#characters}:1}
    done
    echo $result
}

# Function to check if a port is in use
is_port_in_use() {
    local port=$1
    if lsof -i:$port >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check if ufw is enabled
is_ufw_enabled() {
    if ufw status | grep -q "Status: active"; then
        return 0
    else
        return 1
    fi
}

# Function to install
install() {
    wget --no-check-certificate https://raw.github.com/Lozy/danted/master/install.sh -O install.sh

    # Ask user for port input
    read -p "请输入端口号（留空使用随机端口）: " user_port
    
    if [ -z "$user_port" ]; then
        # Generate a random port between 2000 and 9999 that is not in use
        while true; do
            port=$(shuf -i 2000-9999 -n 1)
            if ! is_port_in_use $port; then
                break
            fi
        done
    else
        port=$user_port
        if is_port_in_use $port; then
            echo "端口 $port 已被占用，请选择其他端口。"
            return
        fi
    fi

    # Generate random user and password
    user=$(generate_random_string 16)
    passwd=$(generate_random_string 16)

    # Execute the install script with generated values
    bash install.sh --port=$port --user=$user --passwd=$passwd

    # Check if ufw is enabled and allow the port if it is
    if is_ufw_enabled; then
        ufw allow $port
        echo "ufw 已允许端口: $port"
    fi
}

# Function to view logs
view_logs() {
    service sockd tail
}

# Main menu
while true; do
    echo "请选择功能:"
    echo "1. 安装"
    echo "2. 查看日志"
    echo "3. 退出"
    read -p "请输入数字选择功能: " choice

    case $choice in
        1)
            install
            ;;
        2)
            view_logs
            ;;
        3)
            echo "退出"
            break
            ;;
        *)
            echo "无效的选择，请重新输入。"
            ;;
    esac
done
