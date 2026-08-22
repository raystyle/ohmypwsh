#!/bin/bash
# ===================================================
# yq.sh — yq（mikefarah/yq）单裸二进制 cp 到 ~/.local/bin
# 下载/校验由 Windows 侧 ohmywsl.ps1 完成（部署包统一缓存 EnvRoot\cache\wsl-tools\yq），
# 本脚本只负责从已校验 asset（单裸二进制 yq_linux_amd64）cp（幂等）。
# 注：官方 checksums 是多哈希列格式（每行文件名+多列不同算法哈希），解析脆弱，故走实测回填 sha256。
# 用法:
#   bash yq.sh version
#   bash yq.sh install <version> <asset-wsl-path>
#   bash yq.sh update  <version> <asset-wsl-path>
#   bash yq.sh remove
# ===================================================
set -eo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"
VERSION="${2:-}"
ASSET="${3:-}"

BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/yq"

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

installed_version() {
    if [ -x "$BIN" ]; then
        "$BIN" --version 2>&1 | head -1 | sed -nE 's/.*version[[:space:]]+v?([0-9][0-9a-zA-Z.-]*).*/\1/p'
    fi
}

install_yq() {
    local ver="$1" asset="$2"
    [ -n "$ver" ] || { log_warn "缺少版本号"; exit 1; }
    [ -f "$asset" ] || { log_warn "资产不存在: $asset"; exit 1; }

    local cur
    cur="$(installed_version)"
    if [ -n "$cur" ] && [ "$cur" = "$ver" ]; then
        log_ok "yq: $ver（已安装）"
        return 0
    fi

    mkdir -p "$BIN_DIR"
    install -m 0755 "$asset" "$BIN"
    log_ok "yq: $(installed_version) 已安装到 $BIN"
}

case "$ACTION" in
    version)
        installed_version
        ;;
    install)
        install_yq "$VERSION" "$ASSET"
        ;;
    update)
        install_yq "$VERSION" "$ASSET"
        ;;
    remove)
        rm -f "$BIN"
        log_ok "yq: 已删除"
        ;;
    *)
        echo "用法: $0 {version|install|update|remove}" >&2
        exit 2
        ;;
esac
