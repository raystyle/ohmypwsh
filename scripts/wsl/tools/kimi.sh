#!/bin/bash
# ===================================================
# kimi.sh — Kimi Code（MoonshotAI/kimi-code）绿色二进制 cp 到 ~/.local/bin
# 下载/校验由 Windows 侧 ohmywsl.ps1 完成（部署包统一缓存 EnvRoot\cache\wsl-tools\kimi），
# 本脚本只负责从已校验 asset 解包出单二进制 kimi 并 cp 到 ~/.local/bin（幂等）。
# asset 为 kimi-code-linux-x64.zip，顶层就是单文件 kimi。
# 用法:
#   bash kimi.sh version
#   bash kimi.sh install <version> <asset-wsl-path>
#   bash kimi.sh update  <version> <asset-wsl-path>
#   bash kimi.sh remove
# ===================================================
set -eo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"
VERSION="${2:-}"
ASSET="${3:-}"

BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/kimi"

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

installed_version() {
    if [ -x "$BIN" ]; then
        "$BIN" --version 2>&1 | head -1 | sed -nE 's/^v?([0-9][0-9.]+).*/\1/p'
    fi
}

install_kimi() {
    local ver="$1" asset="$2"
    [ -n "$ver" ] || { log_warn "缺少版本号"; exit 1; }
    [ -f "$asset" ] || { log_warn "资产不存在: $asset"; exit 1; }

    local cur
    cur="$(installed_version)"
    if [ -n "$cur" ] && [ "$cur" = "$ver" ]; then
        log_ok "kimi: $ver（已安装）"
        return 0
    fi

    local tmp
    tmp="$(mktemp -d)"
    unzip -oq "$asset" -d "$tmp"

    mkdir -p "$BIN_DIR"
    install -m 0755 "$tmp/kimi" "$BIN"
    rm -rf "$tmp"
    log_ok "kimi: $(installed_version) 已安装到 $BIN"
}

case "$ACTION" in
    version)
        installed_version
        ;;
    install)
        install_kimi "$VERSION" "$ASSET"
        ;;
    update)
        install_kimi "$VERSION" "$ASSET"
        ;;
    remove)
        rm -f "$BIN"
        log_ok "kimi: 已删除"
        ;;
    *)
        echo "用法: $0 {version|install|update|remove}" >&2
        exit 2
        ;;
esac
