#!/bin/bash
# ===================================================
# clean.sh — 打包前深度清理（只清理，保持工具链完整）
# 以用户 ray 执行（sudo 免密）
# 用法: bash clean.sh run
#
# 清理项：
#   apt 缓存 + 索引（导入后 apt update 自动重建）
#   pip 缓存 / 用户缓存目录 / bash history
#   日志 + 临时文件
#   机器身份：machine-id 清空（目标机首次启动重新生成）
#   SSH host keys 删除（首次启动 sshd 重新生成）
# ===================================================
set -euo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-run}"
log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

if [ "$ACTION" != "run" ]; then
    echo "用法: $0 run" >&2
    exit 2
fi

# ─── apt 缓存 + 索引 ───
sudo apt-get clean >/dev/null 2>&1 || true
sudo rm -rf /var/lib/apt/lists/*
log_ok "apt: 缓存 + 索引已清理"

# ─── pip 缓存 ───
if command -v pip3 &>/dev/null; then
    pip3 cache purge >/dev/null 2>&1 || true
fi

# ─── 用户缓存 / history ───
for u in /root /home/*; do
    [ -d "$u" ] || continue
    rm -rf "$u/.cache"/* 2>/dev/null || true
    rm -f "$u/.bash_history" 2>/dev/null || true
done
log_ok "缓存 + bash history 已清理"

# ─── 日志 + 临时文件 ───
sudo find /var/log -type f -name '*.log' -delete 2>/dev/null || true
sudo rm -rf /var/log/journal/* 2>/dev/null || true
sudo rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
log_ok "日志 + 临时文件已清理"

# ─── 机器身份：machine-id 清空（首次启动重新生成） ───
if [ -f /etc/machine-id ]; then
    sudo rm -f /etc/machine-id
    sudo touch /etc/machine-id
    log_ok "machine-id 已清空（目标机首次启动重新生成）"
fi

# ─── SSH host keys（首次启动重新生成） ───
if ls /etc/ssh/ssh_host_* >/dev/null 2>&1; then
    sudo rm -f /etc/ssh/ssh_host_*
    log_ok "SSH host keys 已删除（首次启动重新生成）"
fi

# ─── 清理结果断言（失败即构建失败，防止带身份/缓存/凭证打包） ───
verify_clean() {
    local ok=0
    if [ -f /etc/machine-id ] && [ -s /etc/machine-id ]; then
        echo "[ERROR] machine-id 未清空（/etc/machine-id 非空）"
        ok=1
    fi
    if ls /etc/ssh/ssh_host_* >/dev/null 2>&1; then
        echo "[ERROR] SSH host keys 仍存在（/etc/ssh/ssh_host_*）"
        ok=1
    fi
    if [ -n "$(sudo find /var/lib/apt/lists -type f 2>/dev/null)" ]; then
        echo "[ERROR] apt 索引未清理（/var/lib/apt/lists 仍有文件）"
        ok=1
    fi
    if [ -n "$(sudo find /var/log -type f -name '*.log' 2>/dev/null)" ]; then
        echo "[ERROR] 日志未清理（/var/log 仍有 *.log）"
        ok=1
    fi
    for u in /root /home/*; do
        [ -d "$u" ] || continue
        if [ -e "$u/.bash_history" ]; then
            echo "[ERROR] $u/.bash_history 仍存在"
            ok=1
        fi
        if [ -n "$(find "$u/.cache" -mindepth 1 2>/dev/null)" ]; then
            echo "[ERROR] $u/.cache 未清空"
            ok=1
        fi
    done
    return $ok
}

if ! verify_clean; then
    log_warn "深度清理断言失败，禁止打包"
    exit 1
fi
log_ok "深度清理断言通过（machine-id / SSH keys / 缓存 / 日志均干净）"

# ─── 敏感文件扫描（凭证/密钥/.env 禁止进镜像） ───
sensitive=$(sudo find /root /home -type f \( \
        -name '*.env' -o -name '.env' \
        -o -name 'id_rsa' -o -name 'id_dsa' -o -name 'id_ecdsa' -o -name 'id_ed25519' \
        -o -name '*.key' -o -name '*.pem' -o -name '*.pgp' \
        -o -name '.git-credentials' -o -name '.netrc' -o -name '.bash_history' \
    \) 2>/dev/null)
if [ -n "$sensitive" ]; then
    log_warn "敏感文件扫描发现: $(echo "$sensitive" | tr '\n' ' ')"
    exit 1
fi
log_ok "敏感文件扫描: 无（凭证/密钥/.env）"

log_ok "深度清理完成"
