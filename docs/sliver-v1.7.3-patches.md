# Sliver v1.7.3 补丁文档

> 适用版本: Sliver v1.5.x ~ v1.7.x
> 升级 Sliver 版本后需重新验证全部修改

---

## 概览

本次修改 Sliver 解决三个问题：
1. **DNS 金丝雀触发后前端报 500** — GORM 列名不匹配 + 日志等级太低
2. **Telegram 通知静默失败** — 无 IPv6 环境下 HTTP 默认走 IPv6 超时
3. **Token 被自动截断** — server.yaml 里的 token 只剩 14 字符

---

## 编译环境

```bash
cd /tmp/sliver-src
export PATH=/tmp/go/bin:$PATH
go version  # go1.23.4

# 必须用 CGO + server,go_sqlite 两个 tag
CGO_ENABLED=1 go build -mod=vendor -tags "server,go_sqlite" -o /tmp/sliver-server-patched ./server/
```

`-tags "server,go_sqlite"` 缺一不可。

---

## 部署

```bash
pkill -f "sliver-server"
cp /root/sliver-server /root/sliver-server.bak.$(date +%Y%m%d-%H%M)
cp /tmp/sliver-server-patched /root/sliver-server
/root/sliver-server daemon &
```

---

## 补丁 1：提升 handleCanary 日志等级

**文件**：`server/c2/dns.go`

**为什么**：金丝雀触发后 `UpdateCanary` 失败，`Errorf` 级别可能被过滤。加入口日志区分"没触发"还是"没走到 handler"。

```diff
 func handleCanary(domain string, c2 *SlimeC2Server) {
+    dnsLog.Warnf("[canary] handleCanary called for domain: %s", domain)
     for _, canary := range c2.serverConfig.GetCanaries() {
         if canary.ImplantName != "" && canary.Domain != "" && canary.Domain == domain {
-            dnsLog.Errorf("[canary] DNS canary tripped for '%s'", canary.ImplantName)
+            dnsLog.Warnf("[canary] DNS canary tripped for '%s'", canary.ImplantName)
             go db.UpdateCanary(canary.ImplantName, canary.Domain)
         }
     }
 }
```

---

## 补丁 2：修复 GORM 列名映射

**文件**：`server/db/models/canary.go`

**SQL**：`ALTER TABLE dns_canaries RENAME COLUMN first_trigger TO first_triggered;`

**为什么**：SQLite 迁移列名是 `first_trigger`，GORM 字段 `FirstTriggered` 默认映射 `first_triggered`，不匹配 → `no such column` → 前端 500。

```diff
 type DNSCanary struct {
     ...
-    FirstTriggered time.Time
+    FirstTriggered time.Time `gorm:"column:first_triggered"`
     ...
 }
```

---

## 补丁 3：UpdateCanary 统一用 GORM 模型

**文件**：`server/db/db.go`

**为什么**：旧版可能直接拼 SQL 或 protobuf 结构体操作，列名仍是 `first_trigger`。统一用 `models.DNSCanary` + GORM。

```go
func UpdateCanary(implantName, domain string) {
    dbSession := Session()
    var canary models.DNSCanary
    result := dbSession.Where(&models.DNSCanary{
        ImplantName: implantName,
        Domain:      domain,
    }).First(&canary)

    if result.Error != nil {
        dnsLog.Errorf("Failed to find canary: %s", result.Error)
        return
    }

    canary.Triggered = true
    if canary.FirstTriggered.IsZero() {
        canary.FirstTriggered = time.Now()
    }
    canary.Count++
    dbSession.Save(&canary)
}
```

---

## 补丁 4：强制 IPv4 Telegram 通知

**文件**：`server/notifications/builder.go`

**为什么**：`go-telegram-bot-api` 默认 HTTP 客户端不强制 IPv4。无 IPv6 VPS 上 DNS 先返回 AAAA → 连接超时 → 通知静默失败。

- DNS 解析强制走 `8.8.8.8:53`
- Dialer 只允许 TCPv4
- 用 `tgbotapi.NewBotAPIWithClient(token, httpClient)` 替代默认客户端

---

## Token 陷阱

**现象**：日志显示 `Telegram notifications disabled: Not Found`

**根因**：自动打码截断 token 为 14 字符，Telegram API 返回 404。

**检查**：
```bash
python3 -c "
import yaml
with open('/root/.sliver/configs/server.yaml') as f:
    cfg = yaml.safe_load(f)
t = cfg['notifications']['services']['telegram']['api_token']
print(f'len={len(t)}')  # 正常 46，异常 14
"
```

**修复**：从 SQLite 取真实 token 写回：
```bash
sqlite3 /root/.sliver/sliver.db \
  "SELECT api_key FROM monitoring_providers WHERE type='telegram';"
```

---

## 验证

```bash
# Telegram 通知
tail -10 /root/.sliver/logs/sliver.log | grep -i "notif\|telegram"

# DNS 金丝雀
dig @127.0.0.1 -p 5358 p60ex1n.random-blog-2024.net +short

# 数据库记录
sqlite3 /root/.sliver/sliver.db \
  "SELECT implant_name, triggered, count FROM dns_canaries WHERE domain LIKE '%random-blog%';"

# 监听端口
ss -tulnp | grep 5358
```
