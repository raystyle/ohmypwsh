#!/bin/bash
# ===================================================
# sops.sh — sops（getsops/sops）单二进制安装到 ~/.local/bin
# 下载/校验由 Windows 侧 ohmywsl.ps1 完成，本脚本只负责从已校验 asset 安装（幂等）。
# 用法:
#   bash sops.sh version
#   bash sops.sh install <version> <asset-wsl-path>   # 单二进制文件
#   bash sops.sh update  <version> <asset-wsl-path>
#   bash sops.sh remove
# ===================================================
set -eo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"
VERSION="${2:-}"
ASSET="${3:-}"

BIN="$HOME/.local/bin/sops"

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

installed_version() {
    if [ -x "$BIN" ]; then
        "$BIN" --version 2>&1 | head -1 | sed -E 's/^sops[ -]v?([0-9][0-9.]+).*/\1/'
    fi
}

install_sops() {
    local ver="$1" asset="$2"
    [ -n "$ver" ] || { log_warn "缺少版本号"; exit 1; }
    [ -f "$asset" ] || { log_warn "资产不存在: $asset"; exit 1; }

    local cur
    cur="$(installed_version)"
    if [ -n "$cur" ] && [ "$cur" = "$ver" ]; then
        log_ok "sops: $ver（已安装）"
        return 0
    fi

    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$asset" "$BIN"
    log_ok "sops: $(installed_version) 已安装"
}

case "$ACTION" in
    version)
        installed_version
        ;;
    install)
        install_sops "$VERSION" "$ASSET"
        ;;
    update)
        install_sops "$VERSION" "$ASSET"
        ;;
    remove)
        rm -f "$BIN"
        log_ok "sops: 已删除"
        ;;
    *)
        echo "用法: $0 {version|install|update|remove}" >&2
        exit 2
        ;;
esac
