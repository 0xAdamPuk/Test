#!/bin/bash

# 获取系统架构
ARCH=$(uname -m)

# 获取最新版本号
LATEST_VERSION=$(curl -s https://api.github.com/repos/jeessy2/ddns-go/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

# 根据系统架构设置下载链接
case $ARCH in
    x86_64)
        FILE_URL="https://github.com/jeessy2/ddns-go/releases/download/v${LATEST_VERSION}/ddns-go_${LATEST_VERSION}_linux_x86_64.tar.gz"
        ;;
    aarch64)
        FILE_URL="https://github.com/jeessy2/ddns-go/releases/download/v${LATEST_VERSION}/ddns-go_${LATEST_VERSION}_linux_arm64.tar.gz"
        ;;
    armv7l)
        FILE_URL="https://github.com/jeessy2/ddns-go/releases/download/v${LATEST_VERSION}/ddns-go_${LATEST_VERSION}_linux_armv7.tar.gz"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# 下载 ddns-go 压缩包
wget $FILE_URL -O ddns-go.tar.gz

# 解压缩文件
tar -xzvf ddns-go.tar.gz

# 给解压出来的文件增加执行权限
chmod +x ddns-go

# 执行 ddns-go 命令
./ddns-go -s install -f 10 -cacheTimes 180 -l :9876

