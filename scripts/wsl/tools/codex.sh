#!/bin/bash
# ===================================================
# codex.sh — Codex CLI（openai/codex）绿色二进制 cp 到 ~/.local/bin
# 下载/校验由 Windows 侧 ohmywsl.ps1 完成（部署包统一缓存 EnvRoot\cache\wsl-tools\codex），
# 本脚本只负责从已校验 asset 解包出单二进制 bin/codex 并 cp 到 ~/.local/bin（幂等）。
# asset 为 codex-package-x86_64-unknown-linux-musl.tar.gz，内含 bin/codex（主二进制）。
# 用法:
#   bash codex.sh version
#   bash codex.sh install <version> <asset-wsl-path>
#   bash codex.sh update  <version> <asset-wsl-path>
#   bash codex.sh remove
# ===================================================
set -eo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"
VERSION="${2:-}"
ASSET="${3:-}"

BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/codex"

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

installed_version() {
    if [ -x "$BIN" ]; then
        "$BIN" --version 2>&1 | head -1 | sed -nE 's/^codex-cli[[:space:]]+v?([0-9][0-9.]+).*/\1/p'
    fi
}

install_codex() {
    local ver="$1" asset="$2"
    [ -n "$ver" ] || { log_warn "缺少版本号"; exit 1; }
    [ -f "$asset" ] || { log_warn "资产不存在: $asset"; exit 1; }

    local cur
    cur="$(installed_version)"
    if [ -n "$cur" ] && [ "$cur" = "$ver" ]; then
        log_ok "codex: $ver（已安装）"
        return 0
    fi

    local tmp
    tmp="$(mktemp -d)"
    tar -xzf "$asset" -C "$tmp"

    mkdir -p "$BIN_DIR"
    install -m 0755 "$tmp/bin/codex" "$BIN"
    rm -rf "$tmp"
    log_ok "codex: $(installed_version) 已安装到 $BIN"
}

case "$ACTION" in
    version)
        installed_version
        ;;
    install)
        install_codex "$VERSION" "$ASSET"
        ;;
    update)
        install_codex "$VERSION" "$ASSET"
        ;;
    remove)
        rm -f "$BIN"
        log_ok "codex: 已删除"
        ;;
    *)
        echo "用法: $0 {version|install|update|remove}" >&2
        exit 2
        ;;
esac
