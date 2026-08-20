#!/bin/bash
# ===================================================
# uv.sh — uv (astral-sh/uv) + 清华 PyPI 镜像
# 以用户 ray 执行
# 用法:
#   bash uv.sh install [版本]   # 默认最新；可指定 release tag（如 0.11.28）
#   bash uv.sh update  [版本]
#   bash uv.sh remove
# ===================================================
set -eo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"
VERSION="${2:-}"   # 可选：指定 release tag（如 0.11.28），默认查最新

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

export PATH="$HOME/.local/bin:$PATH"

# 获取 uv 最新 tag（GitHub API；失败回退已知版本）
get_uv_tag() {
    local tag
    tag=$(curl -gs --max-time 15 "https://api.github.com/repos/astral-sh/uv/releases/latest" 2>/dev/null | jq -r '.tag_name // empty' 2>/dev/null)
    [ -n "$tag" ] || tag="0.8.12"
    echo "$tag"
}

# 下载 + 原子安装 uv 二进制
install_uv() {
    local UV_TAG="${VERSION:-$(get_uv_tag)}"
    local ARCH="x86_64"
    [ "$(uname -m)" = "aarch64" ] && ARCH="aarch64"
    local UV_ASSET="uv-$ARCH-unknown-linux-gnu.tar.gz"
    local UV_TMP="/tmp/uv-install"
    rm -rf "$UV_TMP" && mkdir -p "$UV_TMP"

    if ! curl -gsfL --connect-timeout 10 --max-time 180 --retry 2 \
        -o "$UV_TMP/$UV_ASSET" \
        "https://github.com/astral-sh/uv/releases/download/$UV_TAG/$UV_ASSET"; then
        log_warn "uv: 下载失败（$UV_TAG，检查网络）"
        rm -rf "$UV_TMP"
        exit 1
    fi

    if ! tar -xzf "$UV_TMP/$UV_ASSET" -C "$UV_TMP" 2>/dev/null; then
        log_warn "uv: 解压失败（tarball 可能损坏）"
        rm -rf "$UV_TMP"
        exit 1
    fi

    mkdir -p "$HOME/.local/bin"
    cp "$UV_TMP/uv-$ARCH-unknown-linux-gnu/uv"  "$HOME/.local/bin/uv"
    cp "$UV_TMP/uv-$ARCH-unknown-linux-gnu/uvx" "$HOME/.local/bin/uvx"
    chmod +x "$HOME/.local/bin/uv" "$HOME/.local/bin/uvx"
    rm -rf "$UV_TMP"
    log_ok "uv: $UV_TAG 已安装"
}

# PyPI 清华镜像
config_mirror() {
    mkdir -p "$HOME/.config/uv"
    cat > "$HOME/.config/uv/uv.toml" << 'EOF'
[[index]]
url = "https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple/"
default = true
EOF
    log_ok "uv PyPI: 清华镜像"
}

# .bashrc.d 片段：~/.local/bin PATH
config_path() {
    mkdir -p "$HOME/.bashrc.d"
    cat > "$HOME/.bashrc.d/local-bin.sh" << 'EOF'
# --- ~/.local/bin（uv 等用户级工具） ---
export PATH="$HOME/.local/bin:$PATH"
EOF
    log_ok ".bashrc.d/local-bin.sh: ~/.local/bin PATH"
}

case "$ACTION" in
    install)
        if [ -n "$VERSION" ]; then
            install_uv
        elif ! command -v uv &>/dev/null; then
            install_uv
        else
            log_ok "uv: $(uv --version | awk '{print $2}')（已安装）"
        fi
        config_mirror
        config_path
        ;;
    update)
        if command -v uv &>/dev/null; then
            install_uv
        else
            log_warn "uv: 未安装，先执行 install"
            exit 1
        fi
        config_mirror
        ;;
    remove)
        if command -v uv &>/dev/null; then
            rm -f "$HOME/.local/bin/uv" "$HOME/.local/bin/uvx"
            rm -rf "$HOME/.config/uv"
            log_ok "uv: 已删除（uv/uvx + ~/.config/uv）"
        else
            log_ok "uv: 未安装，无需删除"
        fi
        ;;
    *)
        echo "用法: $0 {install|update|remove}" >&2
        exit 2
        ;;
esac
