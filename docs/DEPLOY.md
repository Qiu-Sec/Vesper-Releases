# Vesper C2 部署文档

## 概述

Vesper C2 是 Sliver C2 框架的 Web 管理面板，提供：
- 会话 / Beacon 管理（HTTP/DNS/mTLS/WireGuard）
- **双模式终端**：Execute（命令模式）+ PTY（持久交互终端）
- 文件浏览器（上传/下载/预览/战利品）
- Playbook 自动化（AI 驱动）
- 监听器 / 载荷 / Pivot 全功能 Web UI
- 主机管理、凭据管理、Crackstation 集成

## 架构

```
┌─────────────┐     gRPC + mTLS     ┌──────────────┐
│  Vesper Web  │ ◄────────────────► │ Sliver Server │
│  (Go / Vue)  │                    │  (C2 核心)    │
└──────┬───────┘                    └──────────────┘
       │ HTTP/WS
       ▼
┌─────────────┐
│  浏览器终端  │
└─────────────┘
```

## 依赖

| 组件 | 版本要求 | 说明 |
|------|---------|------|
| Go | ≥1.23.0 | 后端编译（本项目用 go1.23.4） |
| Node.js | ≥18 | 前端开发/构建 |
| pnpm | ≥8 | 包管理器 |
| Sliver Server | v1.5.x | C2 核心（独立部署） |

## 部署步骤

### 1. 前置条件

确保 Sliver Server 已运行并能通过 gRPC 连接：

```bash
# Sliver 服务端操作机
sliver-server
```

获取操作员配置文件（包含 mTLS 证书）：

```bash
# 在 Sliver 服务端生成操作员
sliver > new-operator --name admin1 --lhost 127.0.0.1

# 将生成的配置文件拷贝到 Vesper 部署机
# 默认路径: ~/.sliver/configs/admin1_127.0.0.1.cfg
```

### 2. 后端部署

```bash
cd Vesper/server

# 编译（必须用 Go 1.23+）
/usr/local/go1.23.4/bin/go build -o ./vesper-server .

# 创建配置
cat > config.json << 'EOF'
{
  "sliver_config_path": "~/.sliver/configs/admin1_127.0.0.1.cfg"
}
EOF

# 创建 .env（默认用户）
cat > .env << 'EOF'
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123
JWT_SECRET=change-me-to-a-random-string-32chars
EOF

# 启动
./vesper-server
```

后端默认监听 `127.0.0.1:8000`。

### 3. 前端部署

#### 开发模式（推荐调试）

```bash
cd Vesper/web
pnpm install
pnpm dev   # 监听 0.0.0.0:9527，代理 API 到后端 8000
```

#### 生产模式

```bash
cd Vesper/web
pnpm build   # 输出到 dist/

# 用 nginx / caddy 托管 dist/，反向代理 /api 到后端 8000
```

nginx 示例：

```nginx
server {
    listen 80;
    server_name c2.example.com;

    root /path/to/Vesper/web/dist;
    index index.html;

    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400s;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

> ⚠️ WebSocket 终端需要长连接，`proxy_read_timeout` 必须足够大。

### 4. 启动检查

```bash
# 后端
ss -tlnp | grep 8000
curl http://127.0.0.1:8000/api/status

# 前端（开发模式）
ss -tlnp | grep 9527
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ADMIN_USERNAME` | `admin` | 登录用户名 |
| `ADMIN_PASSWORD` | `admin123` | 登录密码 |
| `JWT_SECRET` | 内置默认值 | JWT 签名密钥（生产环境务必修改） |
| `SLIVER_CONFIG_PATH` | （config.json 读取） | Sliver 操作员配置文件路径 |

## Sliver 配置

Vesper 通过 Sliver 操作员配置文件连接 C2 服务端：

```json
{
  "operator": "admin1",
  "token": "sliver-操作员-token",
  "lhost": "127.0.0.1",
  "lport": 31337,
  "ca_certificate": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
  "private_key": "-----BEGIN EC PRIVATE KEY-----\n...\n-----END EC PRIVATE KEY-----",
  "certificate": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"
}
```

gRPC 连接使用 mTLS 认证，端口通常是 Sliver Server 的 gRPC 端口（默认 31337）。

## 已知问题

1. **HTTP C2 终端延迟高** — Beacon 60s 间隔下 PTY 逐键延迟明显，建议 mTLS/TCP session 使用 PTY 模式，HTTP Beacon 用 Execute 模式
2. **Windows PTY echo 重叠** — cmd.exe ConPTY 回显与 xterm.js 本地输入叠加，后续版本计划通过本地行编辑模式缓解
3. **Go 编译器版本** — 系统 go1.19 无法编译（go.mod 要求 1.23），需用 `/usr/local/go1.23.4/bin/go`

## 回滚备份

项目关键备份路径：

```
Vesper.bak.20260622_190524/     # 最近完整备份
backups/Vesper-backup-20260621-*.tar.gz                  # 历史备份
```
