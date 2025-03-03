#!/bin/bash

# 下载 ddns-go 压缩包
wget https://github.com/jeessy2/ddns-go/releases/download/v6.8.1/ddns-go_6.8.1_linux_x86_64.tar.gz

# 解压缩文件
tar -xzvf ddns-go_6.8.1_linux_x86_64.tar.gz

# 给解压出来的文件增加执行权限
chmod +x ddns-go

# 执行 ddns-go 命令
./ddns-go -s install -f 10 -cacheTimes 180 -l :9876

