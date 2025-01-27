#!/bin/bash

folder_name="CloudflareST"

# 判断文件夹是否存在
if [ ! -d "$folder_name" ]; then
  # 如果文件夹不存在，则创建
  mkdir "$folder_name"
fi

cd "$folder_name"

# 获取最新版本信息的URL
api_url="https://api.github.com/repos/XIU2/CloudflareSpeedTest/releases/latest"

# 使用curl命令获取最新版本信息，并使用jq解析版本号
latest_version=$(curl -s $api_url | jq -r '.tag_name')

# 检查是否成功获取版本号
if [ -z "$latest_version" ]; then
  echo "Failed to get the latest version."
  exit 1
fi

echo "Latest version: $latest_version"

# 获取系统架构
architecture=$(uname -m)

# 定义基础URL
base_url="https://github.com/XIU2/CloudflareSpeedTest/releases/download/$latest_version/"

# 根据架构选择对应的文件名
case $architecture in
    x86_64)
        file_name="CloudflareST_linux_amd64.tar.gz"
        ;;
    i386 | i686)
        file_name="CloudflareST_linux_386.tar.gz"
        ;;
    aarch64)
        file_name="CloudflareST_linux_arm64.tar.gz"
        ;;
    armv7l)
        file_name="CloudflareST_linux_armv7.tar.gz"
        ;;
    armv6l)
        file_name="CloudflareST_linux_armv6.tar.gz"
        ;;
    armv5te)
        file_name="CloudflareST_linux_armv5.tar.gz"
        ;;
    mips)
        file_name="CloudflareST_linux_mips.tar.gz"
        ;;
    mips64)
        file_name="CloudflareST_linux_mips64.tar.gz"
        ;;
    mips64le)
        file_name="CloudflareST_linux_mips64le.tar.gz"
        ;;
    mipsel)
        file_name="CloudflareST_linux_mipsle.tar.gz"
        ;;
    *)
        echo "Unsupported architecture: $architecture"
        exit 1
        ;;
esac

# 生成完整的下载URL
download_url="${base_url}${file_name}"

# 输出下载URL
echo "Download URL: $download_url"

# 下载 CloudflareST 压缩包
wget -N $download_url

# 解压
tar -zxf $file_name

# 赋予执行权限
chmod +x CloudflareST

# 运行（不带参数）
./CloudflareST
