# 生产部署指南

## 环境要求

- Linux / macOS / Windows 服务器
- 公网 IP 或域名（如需外网监听器）
- 防火墙开放端口：C2 端口 (如 443)、Vesper Web (8088)

## 下载

从 [Vesper-Releases](https://github.com/Qiu-Sec/Vesper-Releases/releases) 下载对应平台二进制，或一键部署：

```bash
curl -fsSL https://raw.githubusercontent.com/Qiu-Sec/Vesper-Releases/main/deploy.sh | bash
```

同时需要 [Sliver Server v1.7.3](https://github.com/BishopFox/sliver/releases) 二进制。

## 手动部署

### 1. 启动 Sliver 守护

```bash
./sliver-server_linux daemon &
# 确认端口
ss -tlnp | grep 31337
```

### 2. 创建 Operator（仅首次）

```bash
./sliver-server_linux operator \
    --name admin1 \
    --lhost 127.0.0.1 \
    --permissions all \
    --save ~/.sliver/configs/admin1_127.0.0.1.cfg
```

### 3. 启动 Vesper

```bash
# 基础启动
./vesper-linux-amd64 --public 0.0.0.0:8088

# HTTPS（自签证书）
./vesper-linux-amd64 --public 0.0.0.0:443 --tls-cert cert.pem --tls-key key.pem

# HTTPS（Let's Encrypt 自动签发，需要 80 端口可访问）
./vesper-linux-amd64 --domain c2.example.com
```

## systemd 守护（推荐）

### Sliver 服务

```ini
# /etc/systemd/system/sliver-daemon.service
[Unit]
Description=Sliver C2 Daemon
After=network.target

[Service]
Type=forking
ExecStart=/opt/vesper/sliver-server_linux daemon
Environment=HOME=/home/sliver
Environment=SLIVER_ROOT_DIR=/home/sliver/.sliver
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### Vesper 服务

```ini
# /etc/systemd/system/vesper.service
[Unit]
Description=Vesper C2 Web Console
After=sliver-daemon.service
Requires=sliver-daemon.service

[Service]
Type=simple
ExecStart=/opt/vesper/vesper-linux-amd64 --public 0.0.0.0:8088
Environment=HOME=/home/sliver
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable sliver-daemon vesper
systemctl start sliver-daemon
sleep 3
systemctl start vesper
```

## 反向代理（Nginx）

```nginx
server {
    listen 443 ssl http2;
    server_name c2.example.com;

    ssl_certificate     /etc/ssl/certs/c2.pem;
    ssl_certificate_key /etc/ssl/private/c2.key;

    location / {
        proxy_pass http://127.0.0.1:8088;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 防火墙

```bash
# Vesper Web
ufw allow 8088/tcp

# C2 监听器示例
ufw allow 443/tcp
ufw allow 53/udp

# 仅限来源
ufw allow from 10.0.0.0/8 to any port 8088
```

## 目录结构

```
/opt/vesper/
├── vesper-linux-amd64        # Vesper 二进制
├── sliver-server_linux       # Sliver 二进制
└── deploy.sh                 # 备用

~/.sliver/                    # Sliver 数据（自动创建）
├── configs/
│   └── admin1_127.0.0.1.cfg # Operator 配置
├── sliver.db                 # SQLite 数据库
├── go/                       # Go 工具链（首次自动安装）
└── logs/
```
