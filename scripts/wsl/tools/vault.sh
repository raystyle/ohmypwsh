#!/bin/bash
# ===================================================
# vault.sh — Vault（hashicorp/vault）单二进制 cp 到 ~/.local/bin
# 下载/校验由 Windows 侧 ohmywsl.ps1 完成（部署包统一缓存 EnvRoot\cache\wsl-tools\vault；
# 来源是 HashiCorp releases CDN，官方 SHA256SUMS 校验），本脚本只从已校验 asset（zip 单文件 vault）解包 cp（幂等）。
# 用法:
#   bash vault.sh version
#   bash vault.sh install <version> <asset-wsl-path>
#   bash vault.sh update  <version> <asset-wsl-path>
#   bash vault.sh remove
# ===================================================
set -eo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"
VERSION="${2:-}"
ASSET="${3:-}"

BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/vault"

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

installed_version() {
    if [ -x "$BIN" ]; then
        "$BIN" version 2>&1 | head -1 | sed -nE 's/^Vault[[:space:]]+v?([0-9][0-9.]+).*/\1/p'
    fi
}

install_vault() {
    local ver="$1" asset="$2"
    [ -n "$ver" ] || { log_warn "缺少版本号"; exit 1; }
    [ -f "$asset" ] || { log_warn "资产不存在: $asset"; exit 1; }

    local cur
    cur="$(installed_version)"
    if [ -n "$cur" ] && [ "$cur" = "$ver" ]; then
        log_ok "vault: $ver（已安装）"
        return 0
    fi

    local tmp
    tmp="$(mktemp -d)"
    unzip -oq "$asset" -d "$tmp"

    mkdir -p "$BIN_DIR"
    install -m 0755 "$tmp/vault" "$BIN"
    rm -rf "$tmp"
    log_ok "vault: $(installed_version) 已安装到 $BIN"
}

case "$ACTION" in
    version)
        installed_version
        ;;
    install)
        install_vault "$VERSION" "$ASSET"
        ;;
    update)
        install_vault "$VERSION" "$ASSET"
        ;;
    remove)
        rm -f "$BIN"
        log_ok "vault: 已删除"
        ;;
    *)
        echo "用法: $0 {version|install|update|remove}" >&2
        exit 2
        ;;
esac
