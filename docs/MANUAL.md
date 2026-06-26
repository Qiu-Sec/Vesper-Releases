# Vesper C2 用户手册

## 目录

1. [登录与首页](#登录与首页)
2. [会话管理](#会话管理)
3. [终端模式](#终端模式)
4. [文件浏览器](#文件浏览器)
5. [Beacon 管理](#beacon-管理)
6. [监听器与载荷](#监听器与载荷)
7. [Pivot 与代理](#pivot-与代理)
8. [AI 助手](#ai-助手)

---

## 登录与首页

访问 `http://<部署地址>:9527`，默认凭据：
- 用户名: `admin`
- 密码: `admin123`

首页显示当前 Sliver 服务端状态：连接状态、版本、活跃会话/Beacon 数量。

---

## 会话管理

**会话列表**（左侧菜单 → Implants → Sessions）：查看所有活跃会话，包括主机名、操作系统、架构、协议类型。

操作菜单（右键）：
- **打开终端** → 跳转到终端页面
- **Kill** → 终止会话
- **Task** → 下发 BOF/任务

---

## 终端模式

Vesper 提供**双模式终端**，在终端页面工具栏切换：

### Execute 模式（默认）

适用场景：单次命令执行（whoami、ls、cat、ipconfig 等）。

```
[Execute] [PTY] ← 点击切换
```

**工作方式**：
- 命令在本地 xterm 输入框编辑（支持上下键历史记录）
- 按 Enter 后整行发给远端执行
- 每条命令启动独立 shell 进程（Execute RPC）
- 输出经 GBK→UTF-8 转码 + tab 展开后渲染

**优点**：输出干净、无回显重叠、HTTP Beacon 友好
**限制**：不支持交互式程序（vim、python、top 等）

### PTY 模式

适用场景：交互式程序（vim/nano、python REPL、powershell、mysql 客户端、top/htop、ping -t 等）。

```
[Execute] [PTY] ← 点击切换
```

**工作方式**：
- 哑终端：每按一个键直接飞到远端 shell
- Sliver 创建持久 PTY 进程（Shell RPC → CreateTunnel → TunnelData 双向流）
- 后端 5ms 缓冲合并 gRPC 分包，避免 xterm 渲染撕裂
- 窗口缩放自动同步到远端（ShellResize RPC）

**优点**：完整交互支持、Ctrl+C 原生打断、real-time 流
**限制**：HTTP Beacon 逐键延迟较高（建议 mTLS/TCP session）

### 切换模式

1. 断开当前连接
2. 点击 Execute 或 PTY 选择模式
3. 选择 session，点「连接」

> ⚠️ 连接中不可切换模式，先断开再切。

---

## 文件浏览器

终端页面下方可展开文件浏览器：

**功能**：
- 📁 目录浏览（点击文件夹进入）
- ⬆ 返回上级
- 🔍 路径跳转
- 📄 文本预览（自动检测二进制，最大 1MB）
- ⬇ 文件下载
- 📤 文件上传
- 💎 加入战利品
- 🗑 删除文件/目录

---

## Beacon 管理

**路径**：Implants → Beacons

**功能**：
- Beacon 列表（主机名、OS、协议、间隔、最后回连时间）
- 下发任务（命令/脚本/DLL）
- 任务状态追踪（pending → sent → completed）
- 取消任务
- 打开交互式会话

### Beacon 任务超时

| 超时设置 | 时间 |
|---------|------|
| 后端轮询 | 120s（每 3s 查一次） |
| 前端等待 | 130s |
| Vite 代理 | 130s |

---

## 监听器与载荷

### 创建监听器

**路径**：Weapons → Listeners

支持的协议：
- HTTP / HTTPS
- DNS
- mTLS
- WireGuard
- TCP Stager

### 生成载荷

**路径**：Weapons → Payloads

参数：
- 目标 OS / 架构（Windows/Linux/macOS，amd64/arm64）
- C2 URL（如 `mtls://192.168.1.6:8888`）
- 格式（EXE/DLL/Shellcode/Service）
- Beacon 模式（间隔/抖动）
- 混淆、编码器、金丝雀域名、限时失效

生成后可在 Builds 页面下载。

---

## Pivot 与代理

### Socks5 代理

```
POST /api/sessions/:id/socks/start
POST /api/sessions/:id/socks/stop
```

将会话作为 Socks5 代理入口，通过植入探针内网。

### 端口转发

```
POST /api/sessions/:id/portfwd/start
POST /api/sessions/:id/portfwd/stop
```

本地端口 → 远程主机：端口转发。

### 反向端口转发

```
POST /api/sessions/:id/rportfwd/start
POST /api/sessions/:id/rportfwd/stop
```

远程端口 → 本地服务：让植入机器上的端口转发回 C2 机器。

---

## AI 助手

**路径**：AI → Chat / Playbooks

**AI Chat**：对话式操作助手，支持自然语言命令。

**Playbooks**（自动化剧本）：
- 扫描内网 → 横向移动 → 提权 → 持久化
- 一键信息收集
- 自定义 playbook（JSON/YAML）

AI 模型配置：Settings → AI Settings

---

## 常见问题

### Q: 终端输出乱码/阶梯对齐？

Execute 模式已内置 `expandTabs` 和 `\r` 补全修复。如果仍有问题，检查目标机器 shell 设置。

### Q: PTY 模式下 Windows cmd 显示混乱？

cmd.exe 的 ConPTY 回显与 xterm.js 渲染有重叠，已知现象。建议 Windows 下优先使用 powershell（`powershell` 命令进入），显示质量显著更好。

### Q: 连接 Sliver 失败？

检查：
1. Sliver Server 是否运行
2. 操作员配置文件路径是否正确（默认 `~/.sliver/configs/`）
3. 网络连通性（gRPC 端口默认 31337）
4. mTLS 证书是否过期

### Q: 编译报错 `go.mod file not found`？

必须用 Go 1.23+ 编译器：
```bash
/usr/local/go1.23.4/bin/go build -o ./vesper-server .
```
