#!/bin/bash

function anykey() {
    read -n 1 -s -r -p "按任意键返回主菜单"
}

# 定义功能函数
function upgrade_softwares() {
    # 更新软件库
    apt update -y && apt upgrade -y

    # 更新、安装必备软件
    apt install sudo curl wget nano
    anykey
}

function set_timezone() {
    sudo timedatectl set-timezone Asia/Shanghai
    anykey
}

function set_bbr() {
    bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Tune/main/tune.sh) -x
    echo "重启 VPS、使内核更新和BBR设置都生效"
    echo "执行sudo reboot"
    echo "执行lsmod | grep bbr查看设置情况"
    anykey
}

function check_bbr() {
    lsmod | grep bbr
    anykey
}

function add_swap() {
    wget -O swap.sh https://raw.githubusercontent.com/yuju520/Script/main/swap.sh && chmod +x swap.sh && clear && ./swap.sh
    echo "执行free -m查看内存"
    anykey
}

function check_nettools() {
    # 检查 netstat 是否安装
    if ! command -v netstat &> /dev/null
    then
        echo "netstat 未安装。正在安装 net-tools..."
        # 根据操作系统的包管理器进行安装
        if [ -f /etc/debian_version ]; then
            sudo apt-get install -y net-tools
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y net-tools
        elif [ -f /etc/arch-release ]; then
            sudo pacman -Syu net-tools
        else
            echo "不支持的操作系统。请手动安装 net-tools。"
            exit 1
        fi
        echo "netstat 安装完成。"
    else
        echo "netstat 已经安装。"
    fi
}

# 生成一个随机端口号
function generate_random_port() {
    # 生成一个介于1024到65535之间的随机端口号
    echo $((RANDOM % 64511 + 1024))
}

# 检查端口是否被占用
function check_port() {
    local port=$1
    # 使用netstat检查端口是否被占用
    if netstat -an | grep -q ":$port "; then
        return 1  # 端口被占用
    else
        return 0  # 端口未被占用
    fi
}

function generate_port() {
    local port
    while true; do
        port=$(generate_random_port)
        check_port $port
        if [ $? -eq 0 ]; then
            echo "随机生成的可用端口号是: $port"
            break
        fi
    done
    echo $port
}

function change_ssh_port() {
    check_nettools
    local port
    port = $(generate_port)
    sudo sed -i "s/^#\?Port 22.*/Port $port/g" /etc/ssh/sshd_config
    echo "执行sudo systemctl restart sshd重启sshd服务"
    anykey
}

function set_ssh_private_key(){
    wget -O key.sh https://raw.githubusercontent.com/yuju520/Script/main/key.sh && chmod +x key.sh && clear && ./key.sh
    echo "！！！注意：请牢记你生成的密钥，否则会有无法连接SSH的后果。！！！"
    anykey
}

# 显示菜单
function show_menu() {
    clear
    echo "请选择要执行的功能:"
    echo "1) 更新软件库"
    echo "2) 校正系统时间"
    echo "3) 开启BBRX加速"
    echo "4) 添加SWAP"
    echo "5) 修改SSH端口"
    echo "6) 修改SSH密钥登录"
    echo "7) 退出"
}

# 主循环
while true; do
    show_menu
    read -p "请输入功能编号: " choice
    case $choice in
        1)
            upgrade_softwares
            ;;
        2)
            set_timezone
            ;;
        3)
            set_bbr
            ;;
        4)
            add_swap
            ;;
        5)
            change_ssh_port
            ;;
        6)
            set_ssh_private_key
            ;;
        7)
            echo "退出脚本."
            exit 0
            ;;
        *)
            echo "无效的选择，请重新输入."
            ;;
    esac
done
