#!/bin/bash

function anykey() {
    read -n 1 -s -r -p "按任意键返回主菜单"
}

# 定义功能函数
function upgrade_softwares() {
    # 更新软件库
    apt update -y && apt upgrade -y

    # 更新、安装必备软件
    apt install sudo curl wget nano ufw
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
            # echo "随机生成的可用端口号是: $port"
            break
        fi
    done
    echo $port
}

function change_ssh_port() {
    check_nettools
    local port
    port=$(generate_port)
    sudo sed -i "s/^#\?Port 22.*/Port $port/g" /etc/ssh/sshd_config
    echo "SSH端口号改为: $port"
    echo "执行sudo systemctl restart sshd重启sshd服务"
    anykey
}

function set_ssh_private_key(){
    wget -O key.sh https://raw.githubusercontent.com/yuju520/Script/main/key.sh && chmod +x key.sh && clear && ./key.sh
    echo "！！！注意：请牢记你生成的密钥，否则会有无法连接SSH的后果。！！！"
    anykey
}

function check_dependencies(){
    # 判断jq是否已经安装
    if ! command -v jq &> /dev/null
    then
        echo "jq is not installed. Installing jq..."
        
        # 检查操作系统类型
        if [ -f /etc/debian_version ]; then
            # Debian/Ubuntu 系统
            sudo apt-get update
            sudo apt-get install -y jq
        elif [ -f /etc/redhat-release ]; then
            # RedHat/CentOS 系统
            sudo yum install -y jq
        elif [ -f /etc/arch-release ]; then
            # Arch 系统
            sudo pacman -S jq
        else
            echo "Unsupported operating system. Please install jq manually."
            exit 1
        fi
        
        echo "jq has been installed."
    else
        echo "jq is already installed."
    fi
}

function install_docker(){
    curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
    docker -v
    systemctl enable docker
    
    # Edit /etc/docker/daemon.json to add iptables configuration
    # sudo mkdir -p /etc/docker
    # if [ -f /etc/docker/daemon.json ]; then
    #     sudo jq '.iptables = false' /etc/docker/daemon.json | sudo tee /etc/docker/daemon.json > /dev/null
    # else
    #     echo '{ "iptables": false }' | sudo tee /etc/docker/daemon.json > /dev/null
    # fi
    
    anykey
}

function install_dockercompose(){
    check_dependencies
    # 获取最新版本信息的URL
    api_url="https://api.github.com/repos/docker/compose/releases/latest"
    
    # 使用curl命令获取最新版本信息，并使用jq解析版本号
    latest_version=$(curl -s $api_url | jq -r '.tag_name')

    # 检查是否成功获取版本号
    if [ -z "$latest_version" ]; then
      echo "Failed to get the latest version."
      exit 1
    fi
    
    echo "Latest version: $latest_version"

    curl -L "https://github.com/docker/compose/releases/download/${latest_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
}

function install_nodejs() {
    # https://nodejs.org/zh-cn/download
    # Download and install nvm:
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    
    # in lieu of restarting the shell
    \. "$HOME/.nvm/nvm.sh"
    
    # Download and install Node.js:
    nvm install 22
    
    # Verify the Node.js version:
    node -v # Should print "v22.15.0".
    nvm current # Should print "v22.15.0".
    
    # Verify npm version:
    npm -v # Should print "10.9.2".

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
    echo "7) 安装Docker&Compose"
    echo "8) 安装Node.js"
    echo "9) 退出"
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
            install_docker
            ;;
        8)
            install_nodejs
            ;;
        9)
            echo "退出脚本."
            exit 0
            ;;
        *)
            echo "无效的选择，请重新输入."
            ;;
    esac
done
