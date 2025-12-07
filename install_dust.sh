#!/bin/bash

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Dust 智能安装脚本 ===${NC}\n"

# 1. 获取最新版本号
echo -e "${YELLOW}[1/5] 获取最新版本...${NC}"
LATEST_VERSION=$(curl -s https://api.github.com/repos/bootandy/dust/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    echo -e "${RED}错误: 无法获取最新版本号${NC}"
    exit 1
fi
echo "      最新版本: $LATEST_VERSION"

# 2. 检测系统架构
echo -e "${YELLOW}[2/5] 检测系统架构...${NC}"
ARCH=$(uname -m)
OS=$(uname -s)

echo "      系统: $OS"
echo "      架构: $ARCH"

# 检查是否为 Linux
if [ "$OS" != "Linux" ]; then
    echo -e "${RED}错误: 此脚本仅支持 Linux 系统${NC}"
    exit 1
fi

# 映射架构名称
case "$ARCH" in
    x86_64)
        TARGET="x86_64-unknown-linux-gnu"
        ;;
    aarch64)
        TARGET="aarch64-unknown-linux-gnu"
        ;;
    armv7l)
        TARGET="arm-unknown-linux-gnueabihf"
        ;;
    i686|i386)
        TARGET="i686-unknown-linux-gnu"
        ;;
    *)
        echo -e "${RED}错误: 不支持的架构 $ARCH${NC}"
        exit 1
        ;;
esac
echo "      目标平台: $TARGET"

# 3. 构建下载链接
echo -e "${YELLOW}[3/5] 构建下载链接...${NC}"
FILENAME="dust-${LATEST_VERSION}-${TARGET}.tar.gz"
DOWNLOAD_URL="https://github.com/bootandy/dust/releases/download/${LATEST_VERSION}/${FILENAME}"
echo "      下载地址: $DOWNLOAD_URL"

# 4. 下载文件
echo -e "${YELLOW}[4/5] 下载文件...${NC}"
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

if command -v wget &> /dev/null; then
    wget -q --show-progress "$DOWNLOAD_URL" -O "$FILENAME"
elif command -v curl &> /dev/null; then
    curl -L --progress-bar "$DOWNLOAD_URL" -o "$FILENAME"
else
    echo -e "${RED}错误: 需要 wget 或 curl${NC}"
    exit 1
fi

# 5. 解压并安装
echo -e "${YELLOW}[5/5] 解压并安装...${NC}"
tar -xzf "$FILENAME"

# 查找 dust 可执行文件
DUST_BIN=$(find . -name "dust" -type f -executable 2>/dev/null | head -1)
if [ -z "$DUST_BIN" ]; then
    DUST_BIN=$(find . -name "dust" -type f 2>/dev/null | head -1)
fi

if [ -z "$DUST_BIN" ]; then
    echo -e "${RED}错误: 解压后未找到 dust 可执行文件${NC}"
    exit 1
fi

# 安装到 /usr/local/bin
INSTALL_DIR="/usr/local/bin"
if [ -w "$INSTALL_DIR" ]; then
    mv "$DUST_BIN" "$INSTALL_DIR/dust"
    chmod +x "$INSTALL_DIR/dust"
else
    echo "      需要 sudo 权限安装到 $INSTALL_DIR"
    sudo mv "$DUST_BIN" "$INSTALL_DIR/dust"
    sudo chmod +x "$INSTALL_DIR/dust"
fi

# 清理临时文件
cd /
rm -rf "$TMP_DIR"

# 验证安装
echo -e "\n${GREEN}=== 安装完成 ===${NC}"
echo -e "安装位置: $(which dust)"
echo -e "版本信息: $(dust --version)"
echo -e "\n${GREEN}使用示例: dust /path/to/directory${NC}"
