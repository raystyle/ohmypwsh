#!/bin/bash
# ===================================================
# git.sh — git + 全局默认配置（不装 gh）
# 以用户 ray 执行（sudo 免密）
# 用法: bash git.sh {install|update|remove}（默认 install）
# ===================================================
set -euo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

# --- git 全局默认（镜像分发场景不写用户身份，留给目标机配置） ---
config_git() {
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    log_ok "git 全局: init.defaultBranch=main, pull.rebase=false"
}

verify() {
    log_ok "git  $(git --version 2>/dev/null || echo MISSING)"
}

case "$ACTION" in
    install)
        if ! command -v git >/dev/null 2>&1; then
            sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git >/dev/null 2>&1
        fi
        log_ok "git: $(git --version)"
        config_git
        ;;
    update)
        sudo apt-get update -qq >/dev/null 2>&1
        sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq git >/dev/null 2>&1
        config_git
        verify
        ;;
    remove)
        log_warn "git 保留（系统基础，依赖过多）"
        ;;
    *)
        echo "用法: $0 {install|update|remove}" >&2
        exit 2
        ;;
esac
