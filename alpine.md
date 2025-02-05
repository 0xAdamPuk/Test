### Alpine安装xray
#### 安装cURL
```bash
apk add curl
```

#### 下载并安装xray
```bash
curl -O https://raw.githubusercontent.com/XTLS/alpinelinux-install-xray/main/install-release.sh
ash install-release.sh
```

#### 启动xray
```bash
rc-update add xray
rc-service xray start
```

#### 配置文件存在/usr/local/etc/xray这个路径下
