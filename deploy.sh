#!/bin/bash
# Vesper C2 — 一键部署脚本
# curl -fsSL https://raw.githubusercontent.com/Qiu-Sec/Vesper-Releases/main/deploy.sh | bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VESPER_VER="${VESPER_VER:-v0.3.8}"
SLIVER_VER="${SLIVER_VER:-v1.7.3}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/vesper}"
PUBLIC_ADDR="${PUBLIC_ADDR:-0.0.0.0:8088}"
OPERATOR_NAME="${OPERATOR_NAME:-admin1}"
LHOST="${LHOST:-127.0.0.1}"
SLIVER_ROOT="${SLIVER_ROOT:-$HOME/.sliver}"

echo -e "${GREEN}=== Vesper C2 一键部署 ${VESPER_VER} ===${NC}"
echo "安装目录: ${INSTALL_DIR}"
echo "Sliver 目录: ${SLIVER_ROOT}"
echo ""

# ── 环境检测 ──
echo -e "${YELLOW}[0/4] 环境检测...${NC}"
MISSING=""

check_cmd() {
    local name="$1" pkg="$2"
    if ! command -v "$name" &>/dev/null; then
        MISSING="$MISSING  $name"
        echo -e "  ${RED}✗${NC} $name（安装: $pkg）"
    else
        echo -e "  ${GREEN}✓${NC} $name"
    fi
}

check_cmd curl    "apt install curl"
check_cmd unzip   "apt install unzip"
check_cmd ss      "apt install iproute2"
check_cmd pgrep   "apt install procps"
check_cmd nohup   "apt install coreutils"

# Sliver 生成 implant 需要 Go 编译器
if ! command -v go &>/dev/null; then
    echo -e "  ${YELLOW}⚠${NC} go（生成 Payload 需要，建议: apt install golang-go）"
fi

if [ -n "$MISSING" ]; then
    echo ""
    echo -e "${RED}FATAL: 缺少必需工具:${MISSING}${NC}"
    echo ""
    echo "  Debian/Ubuntu: sudo apt install curl unzip iproute2 procps"
    echo "  CentOS/RHEL:   sudo yum install curl unzip iproute procps-ng"
    exit 1
fi
echo ""

# ── 检测平台 ──
case "$(uname -s)" in
    Linux)  PLATFORM="linux-amd64"; SLIVER_BIN_NAME="sliver-server_linux-amd64" ;;
    Darwin) PLATFORM="darwin-amd64"; SLIVER_BIN_NAME="sliver-server_darwin-amd64" ;;
    MINGW*|MSYS*)
        echo -e "${YELLOW}[!] Windows 不支持一键部署，请手动下载。${NC}"
        echo "    Vesper: https://github.com/Qiu-Sec/Vesper-Releases/releases/download/${VESPER_VER}/vesper-windows-amd64.zip"
        echo "    Sliver: https://github.com/BishopFox/sliver/releases/download/${SLIVER_VER}/sliver-server_windows-amd64.exe"
        exit 1
        ;;
    *) echo -e "${RED}未知平台: $(uname -s)${NC}"; exit 1 ;;
esac

echo "平台: ${PLATFORM}"
echo ""

# ── 创建目录 ──
mkdir -p "${INSTALL_DIR}"

# ── 下载 Vesper ──
VESPER_URL="https://github.com/Qiu-Sec/Vesper-Releases/releases/download/${VESPER_VER}/vesper-${PLATFORM}.zip"
VESPER_BIN="${INSTALL_DIR}/vesper"

echo "[1/4] 下载 Vesper..."
if [ -f "${VESPER_BIN}" ]; then
    echo "  ✓ 已存在，跳过"
else
    DL_OK=false
    if command -v curl &>/dev/null; then
        curl -fsSL --retry 2 --connect-timeout 10 "${VESPER_URL}" -o /tmp/vesper.zip 2>/dev/null && DL_OK=true
        # 直连失败，尝试 HTTP 代理
        if [ "$DL_OK" != true ] && [ -n "${https_proxy}" ]; then
            echo "  代理重试..."
            curl -fsSL --retry 2 --connect-timeout 10 -x "${https_proxy}" "${VESPER_URL}" -o /tmp/vesper.zip 2>/dev/null && DL_OK=true
        fi
    elif command -v wget &>/dev/null; then
        wget -q --tries=3 "${VESPER_URL}" -O /tmp/vesper.zip 2>/dev/null && DL_OK=true
    else
        echo -e "${RED}需要 curl 或 wget${NC}"; exit 1
    fi
    if [ "$DL_OK" != true ]; then
        echo -e "${RED}FATAL: 下载失败，检查网络或设置代理: export https_proxy=http://127.0.0.1:7897${NC}"
        exit 1
    fi
    unzip -o /tmp/vesper.zip -d "${INSTALL_DIR}" >/dev/null
    # 重命名为统一名称 vesper
    mv "${INSTALL_DIR}/vesper-${PLATFORM}" "${VESPER_BIN}" 2>/dev/null || true
    chmod +x "${VESPER_BIN}"
    rm -f /tmp/vesper.zip
    echo -e "  ${GREEN}✓${NC} $(du -h "${VESPER_BIN}" | cut -f1)"
fi

# ── 下载 Sliver ──
SLIVER_URL="https://github.com/BishopFox/sliver/releases/download/${SLIVER_VER}/${SLIVER_BIN_NAME}"
SLIVER_BIN="${INSTALL_DIR}/${SLIVER_BIN_NAME}"

echo "[2/4] 下载 Sliver ${SLIVER_VER}..."
if [ -f "${SLIVER_BIN}" ]; then
    echo "  ✓ 已存在，跳过"
else
    DL_OK=false
    if command -v curl &>/dev/null; then
        curl -fsSL --retry 2 --connect-timeout 10 "${SLIVER_URL}" -o "${SLIVER_BIN}" 2>/dev/null && DL_OK=true
        if [ "$DL_OK" != true ] && [ -n "${https_proxy}" ]; then
            echo "  代理重试..."
            curl -fsSL --retry 2 --connect-timeout 10 -x "${https_proxy}" "${SLIVER_URL}" -o "${SLIVER_BIN}" 2>/dev/null && DL_OK=true
        fi
    elif command -v wget &>/dev/null; then
        wget -q --tries=3 "${SLIVER_URL}" -O "${SLIVER_BIN}" 2>/dev/null && DL_OK=true
    fi
    if [ "$DL_OK" != true ]; then
        echo -e "${RED}FATAL: Sliver 下载失败${NC}"; exit 1
    fi
    chmod +x "${SLIVER_BIN}"
    echo -e "  ${GREEN}✓${NC} $(du -h "${SLIVER_BIN}" | cut -f1)"
fi

# ── 停止旧进程 ──
echo "[3/4] 启动 Sliver 守护..."
kill $(pgrep -f "${SLIVER_BIN_NAME}" 2>/dev/null) 2>/dev/null || true
sleep 1

export SLIVER_ROOT_DIR="${SLIVER_ROOT}"

# 用 setsid 彻底脱离终端，防止脚本退出时 daemon 被 kill
setsid "${SLIVER_BIN}" daemon > /dev/null 2>&1 < /dev/null &
SLIVER_PID=$!

# 等待 Sliver gRPC 端口就绪（最多 30 秒）
for i in $(seq 1 30); do
    if ss -tlnp 2>/dev/null | grep -q ":31337 "; then
        break
    fi
    sleep 1
done

if ! ss -tlnp 2>/dev/null | grep -q ":31337 "; then
    echo -e "${RED}FATAL: Sliver daemon 启动超时（30s），端口 31337 未监听${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Sliver daemon PID=${SLIVER_PID}"

# ── 初始化 Operator ──
OPERATOR_CFG="${SLIVER_ROOT}/configs/${OPERATOR_NAME}_${LHOST}.cfg"
mkdir -p "${SLIVER_ROOT}/configs"

echo "  创建 operator '${OPERATOR_NAME}'..."
# 每次都重建，确保证书与当前 daemon 一致
rm -f "${OPERATOR_CFG}"
"${SLIVER_BIN}" operator \
    --name "${OPERATOR_NAME}" \
    --lhost "${LHOST}" \
    --permissions all \
    --save "${OPERATOR_CFG}"
echo -e "  ${GREEN}✓${NC} Operator 就绪"

# ── 启动 Vesper ──
echo "[4/4] 启动 Vesper..."
kill $(pgrep -f "vesper" 2>/dev/null) 2>/dev/null || true
sleep 1

setsid env SLIVER_ROOT_DIR="${SLIVER_ROOT}" "${VESPER_BIN}" --public "${PUBLIC_ADDR}" \
    > "${INSTALL_DIR}/vesper.log" 2>&1 &
VESPER_PID=$!
sleep 2

if ! kill -0 $VESPER_PID 2>/dev/null; then
    echo -e "${RED}FATAL: Vesper 启动失败${NC}"
    cat "${INSTALL_DIR}/vesper.log"
    exit 1
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Vesper C2 部署完成！${NC}"
echo ""
echo "  Web:      http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'localhost'):8088"
echo "  登录:     admin / changeme"
echo "  Sliver:   ${LHOST}:31337"
echo ""
echo "  日志:     tail -f ${INSTALL_DIR}/vesper.log"
echo "  停止:     kill ${VESPER_PID}"
echo -e "${GREEN}============================================${NC}"
