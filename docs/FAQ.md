# 常见问题

## 部署相关

### 如何修改默认密码

```bash
# 环境变量覆盖
VESPER_ADMIN_USER=admin VESPER_ADMIN_PASS=MyNewP@ssw0rd ./vesper-linux-amd64 --public 0.0.0.0:8088
```

默认账号 `admin / changeme`，首次部署务必修改。

## 载荷生成

### 生成载荷返回 500 错误

**原因**：Sliver 自带的 Go 工具链与当前代码不兼容（Go ≥1.24 对 unused import 严格检查）。

**解决**：
- Linux/macOS：Vesper v0.3.2+ 启动时会自动安装 Go 包装器，无需手动处理
- Windows：暂不支持原生生成，使用 Linux Vesper 交叉编译 Windows 载荷
- 如果自动安装失败，重启 Vesper 即可重试

### 载荷生成成功但目标不执行

检查：
1. 目标操作系统和架构是否匹配
2. C2 地址是否正确（IP/域名可达）
3. 监听器是否已启动且协议匹配
4. 目标是否有杀软拦截（加壳、混淆）

## Sliver 连接

### "Sliver 断开" 提示

| 现象 | 原因 | 解决 |
|------|------|------|
| gRPC — | Sliver 守护未启动 | `./sliver-server_linux daemon &` |
| 断开 | Sliver 进程崩溃 | 检查 `~/.sliver/logs/` |
| 首次连不上 | Operator 未初始化 | 执行 operator 命令创建配置 |

### Operator 配置丢失

```bash
# 重新创建
./sliver-server_linux operator \
    --name admin1 --lhost 127.0.0.1 --permissions all \
    --save ~/.sliver/configs/admin1_127.0.0.1.cfg
```

### 数据库锁定

```bash
# 停止 Sliver，删除 WAL/SHM 文件，重启
pkill sliver-server_l
rm -f ~/.sliver/sliver.db-wal ~/.sliver/sliver.db-shm
./sliver-server_linux daemon &
```

## 监听器

### 无法启动监听器

1. 检查端口是否被占用：`ss -tlnp | grep <端口>`
2. 低于 1024 的端口需要 root 权限
3. 确保防火墙开放端口

### 监听器启动后 implant 连不上

1. 检查 C2 地址中的 IP 是否公网可达
2. 确认防火墙规则
3. 协议匹配（mtls 对应 MTLS 监听器，不能连 HTTPS）

## 部署相关

### 如何配置 HTTPS

```bash
# 自签证书（测试用）
./vesper-linux-amd64 --public 0.0.0.0:443 --tls-cert cert.pem --tls-key key.pem

# Let's Encrypt（需要公网域名 + 80 端口可达）
./vesper-linux-amd64 --domain c2.example.com
```

### 端口冲突

Vesper 默认 8088，Sliver 默认 31337。修改 Vesper 端口：

```bash
./vesper-linux-amd64 --public 0.0.0.0:9090
```

### 磁盘空间不足

Sliver 日志和数据库持续增长，定期清理：

```bash
# 清理旧日志
find ~/.sliver/logs/ -name "*.log" -mtime +30 -delete

# 清理构建缓存（载荷生成产生的）
rm -rf ~/.sliver/builds/
```

### 如何备份

```bash
# 备份 Sliver 完整数据
tar czf sliver-backup-$(date +%Y%m%d).tar.gz ~/.sliver/

# 仅备份数据库
cp ~/.sliver/sliver.db sliver.db.bak.$(date +%Y%m%d)
```

## Sliver 兼容性

### DNS 金丝雀触发后前端报 500

**现象**：DNS 金丝雀被目标触发后，Vesper 前端返回 500 错误。

**原因**：Sliver 内部 GORM 模型列名 `FirstTriggered` 默认映射 `first_triggered`，但 SQLite 实际列名是 `first_trigger`，不匹配导致 `no such column`。

**解决**：需从源码编译 Sliver 打补丁，详见 [Sliver 兼容性补丁](docs/sliver-v1.7.3-patches.md)。

### Telegram 通知静默失败

**现象**：Sliver 配置了 Telegram 通知但从未收到消息。

**原因**：服务器无 IPv6 环境时，Go 的 HTTP 客户端默认可能走 IPv6 连接 Telegram API，超时后静默失败。

**解决**：需从源码编译 Sliver，强制 HTTP 客户端走 IPv4。详见补丁文档。

### Token 被自动截断

**现象**：Telegram 显示 `Not Found`，Sliver 日志中 token 只剩 14 字符。

**原因**：`server.yaml` 中配置的 Telegram token 被自动截断。

**修复**：

```bash
# 从 SQLite 取真实 token 写回 server.yaml
sqlite3 ~/.sliver/sliver.db \
  "SELECT api_key FROM monitoring_providers WHERE type='telegram';"
```

### 更多兼容性问题

以上问题均需从源码编译 Sliver 修复，完整补丁清单见 [Sliver v1.7.3 兼容性补丁](docs/sliver-v1.7.3-patches.md)。升级 Sliver 版本后需重新验证。

## AI Chat

### AI 对话无响应

1. 确认 API Key 已配置且有效
2. 检查 Provider Base URL 是否正确
3. 网络可达（需要能访问对应 API 域名）
4. 查看日志：`tail -f /tmp/vesper-prod.log`
