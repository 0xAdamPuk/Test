### 若未安装wget之类,执行
```bash
apt update ; apt -y install wget curl cron
```

### VPS初装一些脚本
```bash
wget -O vps_inst.sh https://raw.githubusercontent.com/0xAdamPuk/Test/refs/heads/main/vps_inst.sh && chmod +x vps_inst.sh && clear && ./vps_inst.sh
```

### 系统信息
```bash
wget -O system_info.sh https://raw.githubusercontent.com/0xAdamPuk/Test/refs/heads/main/system_info.sh && chmod +x system_info.sh && clear && ./system_info.sh
```

### 融合怪
```bash
curl -L https://github.com/spiritLHLS/ecs/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh
```
```bash
bash <(wget -qO- bash.spiritlhl.net/ecs)
```

### 安装Socks5代理
```bash
wget -O install_socks5.sh https://raw.githubusercontent.com/0xAdamPuk/Test/refs/heads/main/install_socks5.sh && chmod +x install_socks5.sh && clear && ./install_socks5.sh
```

### Vless + Reality 一键脚本
```bash
wget -P /root -N --no-check-certificate https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh && chmod 700 /root/install.sh && /root/install.sh
```
```bash
wget -O xrayvless.sh https://raw.githubusercontent.com/0xAdamPuk/Test/refs/heads/main/xrayvless.sh && chmod +x xrayvless.sh && clear && ./xrayvless.sh
```

### SublinkX自制订阅:
```bash
curl -s -H "Cache-Control: no-cache" -H "Pragma: no-cache" https://raw.githubusercontent.com/gooaclok819/sublinkX/main/install.sh | sudo bash
```

### CloudFlare优选IP
```bash
wget -O install_cloudflarest.sh https://raw.githubusercontent.com/0xAdamPuk/Test/refs/heads/main/install_cloudflarest.sh && chmod +x install_cloudflarest.sh && clear && ./install_cloudflarest.sh
```

### ddns-go安装
#### 若未装docker
```bash
curl -fsSL https://get.docker.com | bash -s docker
```
#### docker安装之后
```bash
docker run -d --name ddns-go --restart=always --net=host -v /opt/ddns-go:/root jeessy/ddns-go
```
#### 安装完,用浏览器访问机器的9876端口进行配置
