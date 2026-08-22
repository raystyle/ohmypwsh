#!/bin/bash
# ===================================================
# age.sh — age（FiloSottile/age）+ age-keygen 安装到 ~/.local/bin
# 下载/校验由 Windows 侧 ohmywsl.ps1 完成，本脚本只负责从已校验 asset 安装（幂等）。
# 用法:
#   bash age.sh version
#   bash age.sh install <version> <asset-wsl-path>   # tar.gz 内含 age/age、age/age-keygen
#   bash age.sh update  <version> <asset-wsl-path>
#   bash age.sh remove
# ===================================================
set -eo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"
VERSION="${2:-}"
ASSET="${3:-}"

BIN_DIR="$HOME/.local/bin"

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

installed_version() {
    if [ -x "$BIN_DIR/age" ]; then
        "$BIN_DIR/age" --version 2>&1 | head -1 | sed -E 's/^v?([0-9][0-9.]+).*/\1/'
    fi
}

install_age() {
    local ver="$1" asset="$2"
    [ -n "$ver" ] || { log_warn "缺少版本号"; exit 1; }
    [ -f "$asset" ] || { log_warn "资产不存在: $asset"; exit 1; }

    local cur
    cur="$(installed_version)"
    if [ -n "$cur" ] && [ "$cur" = "$ver" ]; then
        log_ok "age: $ver（已安装）"
        return 0
    fi

    mkdir -p "$BIN_DIR"
    local tmp
    tmp="$(mktemp -d)"
    tar -xzf "$asset" -C "$tmp"
    install -m 0755 "$tmp/age/age"         "$BIN_DIR/age"
    install -m 0755 "$tmp/age/age-keygen"  "$BIN_DIR/age-keygen"
    rm -rf "$tmp"
    log_ok "age: $(installed_version) 已安装"
    log_ok "age-keygen: $("$BIN_DIR/age-keygen" --version 2>&1 | head -1)"
}

case "$ACTION" in
    version)
        installed_version
        ;;
    install)
        install_age "$VERSION" "$ASSET"
        ;;
    update)
        install_age "$VERSION" "$ASSET"
        ;;
    remove)
        rm -f "$BIN_DIR/age" "$BIN_DIR/age-keygen"
        log_ok "age: 已删除"
        ;;
    *)
        echo "用法: $0 {version|install|update|remove}" >&2
        exit 2
        ;;
esac
