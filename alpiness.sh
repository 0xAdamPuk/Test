#!/bin/ash

# 安装curl
apk add curl -q

# 下载并安装Xray
curl -sO https://raw.githubusercontent.com/XTLS/alpinelinux-install-xray/main/install-release.sh
ash install-release.sh

# 生成随机端口函数
generate_random_port() {
    while :; do
        port=$((RANDOM % (65535 - 10000 + 1) + 10000))
        (ss -ln | grep -q ":$port ") || break
    done
    echo $port
}

# 获取用户输入或生成随机端口
read -p "请输入端口号(留空自动生成): " custom_port
if [ -z "$custom_port" ]; then
    port=$(generate_random_port)
else
    port=$custom_port
fi

# 生成UUID密码
password=$(cat /proc/sys/kernel/random/uuid)

# 创建配置目录
mkdir -p /usr/local/etc/xray

# 生成inbound配置
cat > /usr/local/etc/xray/05_inbounds.json <<EOF
{
    "inbounds": [
        {
            "port": $port,
            "protocol": "shadowsocks",
            "settings": {
                "method": "aes-256-gcm",
                "password": "$password",
                "network": "tcp,udp",
                "level": 0
            }
        }
    ]
}
EOF

# 生成outbound配置
cat > /usr/local/etc/xray/06_outbounds.json <<EOF
{
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        }
    ]
}
EOF

# 获取公网IP(需要联网)
public_ip=$(curl -s4 ifconfig.co)

# 生成SS链接
ss_uri="aes-256-gcm:$password"
base64_uri=$(echo -n $ss_uri | base64 -w0)
ss_link="ss://$base64_uri@$public_ip:$port"

# 显示配置信息
echo "================================"
echo "Shadowsocks 配置信息:"
echo "地址: $public_ip"
echo "端口: $port"
echo "密码: $password"
echo "加密方式: aes-256-gcm"
echo "SS链接: $ss_link"
echo "================================"

# 启动服务
rc-update add xray
rc-service xray restart

echo "安装完成！请使用上述SS链接连接"
