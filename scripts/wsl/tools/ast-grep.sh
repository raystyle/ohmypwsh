#!/bin/bash
# ===================================================
# ast-grep.sh — ast-grep（ast-grep/ast-grep）双二进制 cp 到 ~/.local/bin
# 下载/校验由 Windows 侧 ohmywsl.ps1 完成（部署包统一缓存 EnvRoot\cache\wsl-tools\ast-grep），
# 本脚本只负责从已校验 asset（zip 含 ast-grep 与 sg 两个二进制）解包 cp 到 ~/.local/bin（幂等）。
# 用法:
#   bash ast-grep.sh version
#   bash ast-grep.sh install <version> <asset-wsl-path>
#   bash ast-grep.sh update  <version> <asset-wsl-path>
#   bash ast-grep.sh remove
# ===================================================
set -eo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"
VERSION="${2:-}"
ASSET="${3:-}"

BIN_DIR="$HOME/.local/bin"
MAIN_BIN="$BIN_DIR/ast-grep"
LEGACY_BIN="$BIN_DIR/sg"

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

installed_version() {
    if [ -x "$MAIN_BIN" ]; then
        "$MAIN_BIN" --version 2>&1 | head -1 | sed -nE 's/^ast-grep[[:space:]]+v?([0-9][0-9.]+).*/\1/p'
    fi
}

install_astgrep() {
    local ver="$1" asset="$2"
    [ -n "$ver" ] || { log_warn "缺少版本号"; exit 1; }
    [ -f "$asset" ] || { log_warn "资产不存在: $asset"; exit 1; }

    local cur
    cur="$(installed_version)"
    if [ -n "$cur" ] && [ "$cur" = "$ver" ]; then
        log_ok "ast-grep: $ver（已安装）"
        return 0
    fi

    local tmp
    tmp="$(mktemp -d)"
    unzip -oq "$asset" -d "$tmp"

    mkdir -p "$BIN_DIR"
    install -m 0755 "$tmp/ast-grep" "$MAIN_BIN"
    install -m 0755 "$tmp/sg"       "$LEGACY_BIN"
    rm -rf "$tmp"
    log_ok "ast-grep: $(installed_version) 已安装到 $MAIN_BIN（legacy sg 别名同步）"
}

case "$ACTION" in
    version)
        installed_version
        ;;
    install)
        install_astgrep "$VERSION" "$ASSET"
        ;;
    update)
        install_astgrep "$VERSION" "$ASSET"
        ;;
    remove)
        rm -f "$MAIN_BIN" "$LEGACY_BIN"
        log_ok "ast-grep: 已删除"
        ;;
    *)
        echo "用法: $0 {version|install|update|remove}" >&2
        exit 2
        ;;
esac
