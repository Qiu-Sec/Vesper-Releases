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
INSTALL_DIR="${INSTALL_DIR:-$(pwd)}"
PUBLIC_ADDR="${PUBLIC_ADDR:-0.0.0.0:8088}"
OPERATOR_NAME="${OPERATOR_NAME:-admin1}"
LHOST="${LHOST:-127.0.0.1}"
SLIVER_DIR="${INSTALL_DIR}/sliver"
SLIVER_DATA="${INSTALL_DIR}/.sliver"

echo -e "${GREEN}=== Vesper C2 一键部署 ${VESPER_VER} ===${NC}"
echo "安装目录: ${INSTALL_DIR}"
echo "Sliver 目录: ${SLIVER_DIR}"
echo "Sliver 数据: ${SLIVER_DATA}"
echo ""

# ── 环境检测 ──
echo -e "${YELLOW}[0/3] 环境检测...${NC}"
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
check_cmd pgrep   "apt install procps"

if ! command -v go &>/dev/null; then
    echo -e "  ${YELLOW}⚠${NC} go（生成 Payload 需要，建议: apt install golang-go）"
fi

if [ -n "$MISSING" ]; then
    echo ""
    echo -e "${RED}FATAL: 缺少必需工具:${MISSING}${NC}"
    echo ""
    echo "  Debian/Ubuntu: sudo apt install curl unzip procps"
    echo "  CentOS/RHEL:   sudo yum install curl unzip procps-ng"
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
mkdir -p "${INSTALL_DIR}" "${SLIVER_DIR}" "${SLIVER_DATA}"

# ── 下载 Vesper ──
VESPER_URL="https://github.com/Qiu-Sec/Vesper-Releases/releases/download/${VESPER_VER}/vesper-${PLATFORM}.zip"
VESPER_BIN="${INSTALL_DIR}/vesper"

echo "[1/3] 下载 Vesper..."
rm -f "${INSTALL_DIR}/vesper-${PLATFORM}"
DL_OK=false
if command -v curl &>/dev/null; then
    curl -fsSL --retry 2 --connect-timeout 10 "${VESPER_URL}" -o /tmp/vesper.zip 2>/dev/null && DL_OK=true
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
mv "${INSTALL_DIR}/vesper-${PLATFORM}" "${VESPER_BIN}" 2>/dev/null || true
chmod +x "${VESPER_BIN}"
rm -f /tmp/vesper.zip
echo -e "  ${GREEN}✓${NC} $(du -h "${VESPER_BIN}" | cut -f1)"

# ── 下载 Sliver ──
SLIVER_URL="https://github.com/BishopFox/sliver/releases/download/${SLIVER_VER}/${SLIVER_BIN_NAME}"
SLIVER_BIN="${SLIVER_DIR}/${SLIVER_BIN_NAME}"

echo "[2/3] 下载 Sliver ${SLIVER_VER}..."
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

# ── 启动 Vesper ──
echo "[3/3] 启动 Vesper..."
kill $(pgrep -f "vesper" 2>/dev/null) 2>/dev/null || true
sleep 1

# Sliver 需用户手动启动（v1.7.3 有启动竞态 bug，自动启不稳定）

setsid env SLIVER_ROOT_DIR="${SLIVER_DATA}" "${VESPER_BIN}" --public "${PUBLIC_ADDR}" \
    > "${INSTALL_DIR}/vesper.log" 2>&1 &
VESPER_PID=$!
disown "${VESPER_PID}" 2>/dev/null || true
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
echo ""
echo "  目录结构:"
echo "    ${INSTALL_DIR}/vesper                    ← Vesper 面板"
echo "    ${SLIVER_DIR}/${SLIVER_BIN_NAME}         ← Sliver 服务端"
echo "    ${SLIVER_DATA}/                          ← Sliver 数据"
echo ""
echo -e "  ${YELLOW}请手动启动 Sliver:${NC}"
echo "    cd ${SLIVER_DATA} && ${SLIVER_BIN} daemon &"
echo "    ${SLIVER_BIN} operator --name ${OPERATOR_NAME} --lhost ${LHOST} --permissions all \\"
echo "        --save ${SLIVER_DATA}/configs/${OPERATOR_NAME}_${LHOST}.cfg"
echo ""
echo "  日志:     tail -f ${INSTALL_DIR}/vesper.log"
echo "  停止:     kill ${VESPER_PID}"
echo -e "${GREEN}============================================${NC}"
