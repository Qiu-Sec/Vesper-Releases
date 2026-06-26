#!/bin/bash
# Vesper C2 — 一键部署脚本
# curl -fsSL https://raw.githubusercontent.com/Qiu-Sec/Vesper-Releases/main/deploy.sh | bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VESPER_VER="${VESPER_VER:-v0.3.4}"
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

# ── 检测平台 ──
case "$(uname -s)" in
    Linux)  PLATFORM="linux-amd64"; SLIVER_BIN_NAME="sliver-server_linux" ;;
    Darwin) PLATFORM="darwin-amd64"; SLIVER_BIN_NAME="sliver-server_darwin" ;;
    MINGW*|MSYS*)
        echo -e "${YELLOW}[!] Windows 不支持一键部署，请手动下载。${NC}"
        echo "    Vesper: https://github.com/Qiu-Sec/Vesper/releases/download/${VESPER_VER}/vesper-windows-amd64.zip"
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
VESPER_URL="https://github.com/Qiu-Sec/Vesper/releases/download/${VESPER_VER}/vesper-${PLATFORM}.zip"
VESPER_BIN="${INSTALL_DIR}/vesper"

echo "[1/4] 下载 Vesper..."
if [ -f "${VESPER_BIN}" ]; then
    echo "  ✓ 已存在，跳过"
else
    if command -v curl &>/dev/null; then
        curl -fsSL "${VESPER_URL}" -o /tmp/vesper.zip
    elif command -v wget &>/dev/null; then
        wget -q "${VESPER_URL}" -O /tmp/vesper.zip
    else
        echo -e "${RED}需要 curl 或 wget${NC}"; exit 1
    fi
    unzip -o /tmp/vesper.zip -d "${INSTALL_DIR}" >/dev/null
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
    if command -v curl &>/dev/null; then
        curl -fsSL "${SLIVER_URL}" -o "${SLIVER_BIN}"
    else
        wget -q "${SLIVER_URL}" -O "${SLIVER_BIN}"
    fi
    chmod +x "${SLIVER_BIN}"
    echo -e "  ${GREEN}✓${NC} $(du -h "${SLIVER_BIN}" | cut -f1)"
fi

# ── 停止旧进程 ──
echo "[3/4] 启动 Sliver 守护..."
kill $(pgrep -f "${SLIVER_BIN_NAME}" 2>/dev/null) 2>/dev/null || true
sleep 1

export HOME="${SLIVER_ROOT}"
export SLIVER_ROOT_DIR="${SLIVER_ROOT}"

"${SLIVER_BIN}" daemon \
    --daemon-root "${SLIVER_ROOT}" \
    --daemon-log "${SLIVER_ROOT}/logs/sliver-daemon.log" &
SLIVER_PID=$!
sleep 3

if ! kill -0 $SLIVER_PID 2>/dev/null; then
    echo -e "${RED}FATAL: Sliver daemon 启动失败${NC}"
    cat "${SLIVER_ROOT}/logs/sliver-daemon.log" 2>/dev/null || true
    exit 1
fi
echo -e "  ${GREEN}✓${NC} PID=${SLIVER_PID}"

# ── 初始化 Operator ──
OPERATOR_CFG="${SLIVER_ROOT}/configs/${OPERATOR_NAME}_${LHOST}.cfg"
mkdir -p "${SLIVER_ROOT}/configs"

if [ ! -f "${OPERATOR_CFG}" ]; then
    echo "  创建 operator '${OPERATOR_NAME}'..."
    "${SLIVER_BIN}" operator \
        --name "${OPERATOR_NAME}" \
        --lhost "${LHOST}" \
        --permissions all \
        --save "${OPERATOR_CFG}"
fi
echo -e "  ${GREEN}✓${NC} Operator 就绪"

# ── 启动 Vesper ──
echo "[4/4] 启动 Vesper..."
kill $(pgrep -f "vesper" 2>/dev/null) 2>/dev/null || true
sleep 1

nohup env HOME="${SLIVER_ROOT}" "${VESPER_BIN}" --public "${PUBLIC_ADDR}" \
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
