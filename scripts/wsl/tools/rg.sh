#!/bin/bash
# ===================================================
# rg.sh — ripgrep（BurntSushi/ripgrep）单二进制 cp 到 ~/.local/bin
# 下载/校验由 Windows 侧 ohmywsl.ps1 完成（部署包统一缓存 EnvRoot\cache\wsl-tools\rg），
# 本脚本只负责从已校验 asset（tar.gz 单目录包裹 ripgrep-<ver>-.../rg）解出单二进制 cp（幂等）。
# 用法:
#   bash rg.sh version
#   bash rg.sh install <version> <asset-wsl-path>
#   bash rg.sh update  <version> <asset-wsl-path>
#   bash rg.sh remove
# ===================================================
set -eo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"
VERSION="${2:-}"
ASSET="${3:-}"

BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/rg"

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

installed_version() {
    if [ -x "$BIN" ]; then
        "$BIN" --version 2>&1 | head -1 | sed -nE 's/.*ripgrep[[:space:]]+([0-9][0-9.]+).*/\1/p'
    fi
}

install_rg() {
    local ver="$1" asset="$2"
    [ -n "$ver" ] || { log_warn "缺少版本号"; exit 1; }
    [ -f "$asset" ] || { log_warn "资产不存在: $asset"; exit 1; }

    local cur
    cur="$(installed_version)"
    if [ -n "$cur" ] && [ "$cur" = "$ver" ]; then
        log_ok "rg: $ver（已安装）"
        return 0
    fi

    local tmp
    tmp="$(mktemp -d)"
    tar -xzf "$asset" -C "$tmp"
    local src
    src="$(find "$tmp" -type f -name rg | head -1)"
    [ -n "$src" ] || { log_warn "tarball 内未找到 rg"; exit 1; }

    mkdir -p "$BIN_DIR"
    install -m 0755 "$src" "$BIN"
    rm -rf "$tmp"
    log_ok "rg: $(installed_version) 已安装到 $BIN"
}

case "$ACTION" in
    version)
        installed_version
        ;;
    install)
        install_rg "$VERSION" "$ASSET"
        ;;
    update)
        install_rg "$VERSION" "$ASSET"
        ;;
    remove)
        rm -f "$BIN"
        log_ok "rg: 已删除"
        ;;
    *)
        echo "用法: $0 {version|install|update|remove}" >&2
        exit 2
        ;;
esac
