#!/bin/bash
# ===================================================
# bun.sh — bun + npmmirror（最新稳定版，GitHub API 获取 tag）
# 以用户 ray 执行
# 用法: bash bun.sh {install|update|remove}（默认 install）
# ===================================================
set -eo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

export PATH="$HOME/.bun/bin:$PATH"

# 架构
ARCH="x64"
[ "$(uname -m)" = "aarch64" ] && ARCH="aarch64"

# 获取 bun 最新 tag（GitHub API；失败回退已知版本）
get_bun_tag() {
    local tag
    tag=$(curl -gs --max-time 15 "https://api.github.com/repos/oven-sh/bun/releases/latest" 2>/dev/null | jq -r '.tag_name // empty' 2>/dev/null)
    [ -n "$tag" ] || tag="bun-v1.2.20"
    echo "$tag"
}

# 下载 + 原子安装（优先 npmmirror 镜像，回退 GitHub 直连）
install_bun() {
    local TAG
    TAG=$(get_bun_tag)
    local ASSET="bun-linux-$ARCH.zip"
    local TMP_DIR="/tmp/bun-install"
    rm -rf "$TMP_DIR" && mkdir -p "$TMP_DIR"

    local url="https://npmmirror.com/mirrors/bun/$TAG/$ASSET"
    if ! curl -gsfL --connect-timeout 10 --max-time 120 --retry 2 -o "$TMP_DIR/$ASSET" "$url"; then
        log_warn "npmmirror 下载失败，回退 GitHub: $TAG"
        url="https://github.com/oven-sh/bun/releases/download/$TAG/$ASSET"
        curl -gsfL --connect-timeout 10 --max-time 120 --retry 2 -o "$TMP_DIR/$ASSET" "$url" \
            || { log_warn "bun: 下载失败（$TAG）"; rm -rf "$TMP_DIR"; exit 1; }
    fi

    if ! unzip -qo "$TMP_DIR/$ASSET" -d "$TMP_DIR" 2>/dev/null; then
        log_warn "bun: 解压失败（zip 可能损坏）"
        rm -rf "$TMP_DIR"
        exit 1
    fi

    mkdir -p "$HOME/.bun/bin"
    cp "$TMP_DIR/bun-linux-$ARCH/bun" "$HOME/.bun/bin/bun"
    chmod +x "$HOME/.bun/bin/bun"
    rm -rf "$TMP_DIR"
    log_ok "bun: $TAG 已安装"
}

# npmmirror 配置
config_mirror() {
    mkdir -p "$HOME"
    cat > "$HOME/.bunfig.toml" << 'EOF'
[install]
registry = "https://registry.npmmirror.com/"
EOF
    log_ok "bun registry: npmmirror"
}

# .bashrc.d 片段：~/.bun/bin PATH
config_path() {
    mkdir -p "$HOME/.bashrc.d"
    cat > "$HOME/.bashrc.d/bun.sh" << 'EOF'
# --- bun ---
export PATH="$HOME/.bun/bin:$PATH"
EOF
    log_ok ".bashrc.d/bun.sh: ~/.bun/bin PATH"
}

case "$ACTION" in
    install)
        if ! command -v bun &>/dev/null; then
            install_bun
        else
            log_ok "bun: $(bun --version)（已安装）"
        fi
        config_mirror
        config_path
        ;;
    update)
        if command -v bun &>/dev/null; then
            install_bun
        else
            log_warn "bun: 未安装，先执行 install"
            exit 1
        fi
        config_mirror
        ;;
    remove)
        if [ -d "$HOME/.bun" ]; then
            rm -rf "$HOME/.bun"
            rm -f "$HOME/.bashrc.d/bun.sh" "$HOME/.bunfig.toml"
            log_ok "bun: 已删除（~/.bun + 片段 + bunfig）"
        else
            log_ok "bun: 未安装，无需删除"
        fi
        ;;
    *)
        echo "用法: $0 {install|update|remove}" >&2
        exit 2
        ;;
esac
