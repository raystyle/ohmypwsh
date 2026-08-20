#!/bin/bash
# ===================================================
# apt-sources.sh — 清华镜像源 + 系统基础包（编译环境底座）
# 以用户 ray 执行（sudo 免密）
# 用法: bash apt-sources.sh {install|update|remove}（默认 install）
# ===================================================
set -euo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

SOURCE_FILE="/etc/apt/sources.list.d/ubuntu.sources"
BACKUP_FILE="/etc/apt/sources.list.d/ubuntu.sources.bak"

# 基础包 = 下载/脚本工具 + 编译环境（gcc/g++/make + cmake/ninja/pkg-config +
# openssl 开发头 + mingw 交叉工具链）+ ssh/file
BASE_PKGS="curl wget ca-certificates gnupg unzip zip jq python3 python3-pip \
    build-essential cmake ninja-build pkg-config libssl-dev \
    openssh-client file gcc-mingw-w64"

# --- 写入清华镜像源 ---
write_tsinghua_sources() {
    sudo tee "$SOURCE_FILE" > /dev/null << 'EOF'
Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
    log_ok "apt 源: 清华镜像（security 保持官方）"
}

# --- 安装基础包 ---
install_base_packages() {
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $BASE_PKGS >/dev/null 2>&1
    log_ok "基础包已安装（含 build-essential/cmake/ninja/pkg-config/openssl/mingw）"
}

# --- 版本验证 ---
verify() {
    for c in curl jq gcc g++ make cmake ninja pkg-config ssh; do
        if command -v "$c" >/dev/null 2>&1; then
            local v
            v=$($c --version 2>/dev/null | head -1 || true)
            log_ok "$c   $v"
        else
            log_warn "$c   MISSING"
        fi
    done
}

case "$ACTION" in
    install)
        if [ ! -f "$BACKUP_FILE" ]; then
            sudo cp "$SOURCE_FILE" "$BACKUP_FILE"
            log_ok "原始 ubuntu.sources 已备份 → .bak"
        else
            log_ok "备份已存在，跳过"
        fi
        write_tsinghua_sources
        log_info "apt update ..."
        sudo apt-get update -qq >/dev/null 2>&1
        install_base_packages
        verify
        ;;
    update)
        log_info "apt update + upgrade 基础包 ..."
        sudo apt-get update -qq >/dev/null 2>&1
        sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq $BASE_PKGS >/dev/null 2>&1 || true
        verify
        ;;
    remove)
        if [ -f "$BACKUP_FILE" ]; then
            sudo cp "$BACKUP_FILE" "$SOURCE_FILE"
            sudo rm -f "$BACKUP_FILE"
            log_ok "ubuntu.sources 已从 .bak 恢复"
            sudo apt-get update -qq >/dev/null 2>&1
        else
            log_warn "备份文件不存在，无法恢复"
        fi
        log_warn "基础包保留不删（系统编译依赖过多）"
        ;;
    *)
        echo "用法: $0 {install|update|remove}" >&2
        exit 2
        ;;
esac
