### 若未安装wget之类,执行
apt update ; apt -y install wget curl cron

### VPS初装一些脚本
wget -O vps_inst.sh https://raw.githubusercontent.com/0xAdamPuk/Test/refs/heads/main/vps_inst.sh && chmod +x vps_inst.sh && clear && ./vps_inst.sh


### 系统信息
wget -O system_info.sh https://raw.githubusercontent.com/0xAdamPuk/Test/refs/heads/main/system_info.sh && chmod +x system_info.sh && clear && ./system_info.sh

### 安装Socks5代理
wget -O install_socks5.sh https://raw.githubusercontent.com/0xAdamPuk/Test/refs/heads/main/install_socks5.sh && chmod +x install_socks5.sh && clear && ./install_socks5.sh

### Xray + Reality 一键脚本
wget -P /root -N --no-check-certificate https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh && chmod 700 /root/install.sh && /root/install.sh
