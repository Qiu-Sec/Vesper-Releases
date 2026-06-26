# Vesper C2 — Sliver Web 控制台

基于 Sliver C2 框架的 Web 端红队指挥中心。Vue3 + Go Gin + Sliver gRPC，单二进制部署。

## 截图

| 登录 | 总览 |
|------|------|
| ![登录](docs/screenshots/login.png) | ![总览](docs/screenshots/dashboard.png) |

| 主机管理 | 右键菜单 | 拓扑图 |
|---------|----------|--------|
| ![主机管理](docs/screenshots/hosts.png) | ![右键菜单](docs/screenshots/context-menu.png) | ![拓扑图](docs/screenshots/topology.png) |

| 交互终端 | 木马生成 |
|----------|----------|
| ![终端](docs/screenshots/terminal.png) | ![生成马](docs/screenshots/payloads.png) |

| AI Agent | AI 辅助 |
|----------|---------|
| ![AI](docs/screenshots/aichat.png) | ![AI辅助](docs/screenshots/ai-assistant.png) |

## 一键部署

```bash
curl -fsSL https://raw.githubusercontent.com/Qiu-Sec/Vesper-Releases/master/deploy.sh | bash
```

访问 `http://<IP>:8088`，登录 `admin / admin123`

## 手动部署

需先下载 [Sliver Server](https://github.com/BishopFox/sliver/releases) 放入项目目录。

### Linux / macOS

```bash
# 1. Sliver 守护
./sliver-server_linux daemon &

# 2. 初始化 operator（仅首次）
./sliver-server_linux operator --name admin1 --lhost 127.0.0.1 --permissions all \
    --save ~/.sliver/configs/admin1_127.0.0.1.cfg

# 3. 启动 Vesper
./vesper-linux-amd64 --public 0.0.0.0:8088
```

### Windows

> ⚠️ Windows 原生载荷生成可能失败（Go 版本兼容性），推荐用 Linux Vesper 交叉编译。

```cmd
start /B sliver-server_windows-amd64.exe daemon
sliver-server_windows-amd64.exe operator --name admin1 --lhost 127.0.0.1 --permissions all --save %USERPROFILE%\.sliver\configs\admin1_127.0.0.1.cfg
vesper-windows-amd64.exe --public 0.0.0.0:8088
```

### HTTPS（可选）

```bash
./vesper-linux-amd64 --public 0.0.0.0:443 --tls-cert cert.pem --tls-key key.pem
./vesper-linux-amd64 --domain c2.example.com               # Let's Encrypt
```

## 功能

| 页面 | 功能 |
|------|------|
| 仪表盘 | 统计卡片 + 快捷入口 + 会话图表 |
| 主机管理 | Beacon/Session 列表 + 右键工具菜单 |
| 交互终端 | xterm + beacon 命令 + 文件浏览器 |
| 监听器 | HTTP/HTTPS/MTLS/DNS/WG 启动/停止 |
| 木马生成 | 多格式 payload 配置 + C2 地址 + 构建记录 |
| AI Agent | 多模型对话 (DeepSeek/OpenAI/Anthropic) |
| 代理管理 | SOCKS5/HTTP 代理启停 |
| 凭据收集 | 自动提取 + 哈希破解记录 |
| 战利品 | 文件浏览 + 下载 |

## 环境要求

**开发：** Go 1.21+ / Node.js 18+ / pnpm  
**生产：** 零额外依赖，单二进制运行

## 默认账号

`admin` / `admin123`

## 注意事项

Sliver v1.7.3 配合 Vesper 使用时存在兼容性问题，详见文档。
