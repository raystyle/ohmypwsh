#!/bin/bash
# ===================================================
# shellcheck.sh — ShellCheck（koalaman/shellcheck）单二进制 cp 到 ~/.local/bin
# 下载/校验由 Windows 侧 ohmywsl.ps1 完成（部署包统一缓存 EnvRoot\cache\wsl-tools\shellcheck），
# 本脚本只负责从已校验 asset（tar.xz 单目录包裹 shellcheck-<ver>/shellcheck）解出二进制 cp（幂等）。
# 注意：官方资产是 .tar.xz（非 tar.gz），须用 tar -xJf 解压。
# 用法:
#   bash shellcheck.sh version
#   bash shellcheck.sh install <version> <asset-wsl-path>
#   bash shellcheck.sh update  <version> <asset-wsl-path>
#   bash shellcheck.sh remove
# ===================================================
set -eo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"
VERSION="${2:-}"
ASSET="${3:-}"

BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/shellcheck"

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

installed_version() {
    if [ -x "$BIN" ]; then
        "$BIN" --version 2>&1 | sed -nE 's/^version:[[:space:]]*([0-9][0-9.]+).*/\1/p' | head -1
    fi
}

install_shellcheck() {
    local ver="$1" asset="$2"
    [ -n "$ver" ] || { log_warn "缺少版本号"; exit 1; }
    [ -f "$asset" ] || { log_warn "资产不存在: $asset"; exit 1; }

    local cur
    cur="$(installed_version)"
    if [ -n "$cur" ] && [ "$cur" = "$ver" ]; then
        log_ok "shellcheck: $ver（已安装）"
        return 0
    fi

    local tmp
    tmp="$(mktemp -d)"
    tar -xJf "$asset" -C "$tmp"
    local src
    src="$(find "$tmp" -type f -name shellcheck | head -1)"
    [ -n "$src" ] || { log_warn "tar.xz 内未找到 shellcheck 二进制"; exit 1; }

    mkdir -p "$BIN_DIR"
    install -m 0755 "$src" "$BIN"
    rm -rf "$tmp"
    log_ok "shellcheck: $(installed_version) 已安装到 $BIN"
}

case "$ACTION" in
    version)
        installed_version
        ;;
    install)
        install_shellcheck "$VERSION" "$ASSET"
        ;;
    update)
        install_shellcheck "$VERSION" "$ASSET"
        ;;
    remove)
        rm -f "$BIN"
        log_ok "shellcheck: 已删除"
        ;;
    *)
        echo "用法: $0 {version|install|update|remove}" >&2
        exit 2
        ;;
esac
