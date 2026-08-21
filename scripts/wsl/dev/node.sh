#!/bin/bash
# ===================================================
# node.sh — fnm + Node.js LTS + npmmirror（与主项目 Windows fnm 对齐）
# 以用户 ray 执行
# 用法:
#   bash node.sh install [版本]   # 默认最新 LTS；可指定如 20.18.0 / 22
#   bash node.sh update  [版本]
#   bash node.sh remove
# ===================================================
set -eo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"
VERSION="${2:-}"

FNM_DIR="$HOME/.local/share/fnm"
FNM_BIN="$FNM_DIR/fnm"
FNM_VERSION="1.39.0"
FNM_URL="https://github.com/Schniz/fnm/releases/download/v${FNM_VERSION}/fnm-linux.zip"

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

fnm_env() {
    export FNM_NODE_DIST_MIRROR="https://npmmirror.com/mirrors/node"
    eval "$("$FNM_BIN" env --shell bash)"
}

install_fnm() {
    if [ -x "$FNM_BIN" ]; then
        log_ok "fnm: $($FNM_BIN --version)（已安装）"
        return 0
    fi
    log_info "安装 fnm ${FNM_VERSION} ..."
    mkdir -p "$FNM_DIR"
    local tmp
    tmp=$(mktemp -d)
    curl -fsSL --retry 3 --connect-timeout 15 -o "$tmp/fnm-linux.zip" "$FNM_URL"
    unzip -oq "$tmp/fnm-linux.zip" -d "$tmp"
    local bin
    bin=$(find "$tmp" -type f -name fnm | head -1)
    [ -n "$bin" ] || { log_warn "fnm-linux.zip 缺少 fnm 二进制"; exit 1; }
    install -m 0755 "$bin" "$FNM_BIN"
    rm -rf "$tmp"
    log_ok "fnm: $($FNM_BIN --version) 已安装"
}

install_node() {
    local ver="${1:-}"
    fnm_env
    local cur
    cur=$("$FNM_BIN" current 2>/dev/null || true)
    if [ -z "$ver" ] && [ -n "$cur" ] && [ "$cur" != "none" ] && [ "$cur" != "system" ]; then
        log_ok "node: $cur（已安装）"
    else
        local target="${ver:---lts}"
        "$FNM_BIN" install "$target"
        local resolved
        resolved=$("$FNM_BIN" ls 2>/dev/null | awk '/lts/{print $2}' | head -1)
        if [ -z "$resolved" ]; then
            resolved=$("$FNM_BIN" ls 2>/dev/null | awk '/v[0-9]/{print $2}' | head -1)
        fi
        if [ -n "$resolved" ]; then
            "$FNM_BIN" default "$resolved"
        fi
        fnm_env
        log_ok "node: $($FNM_BIN current) 已安装"
    fi
    if command -v npm >/dev/null 2>&1; then
        log_ok "npm: $(npm --version)"
    else
        log_warn "node: 安装失败"
        exit 1
    fi
}

config_npm_mirror() {
    npm config set registry https://registry.npmmirror.com 2>/dev/null
    log_ok "npm registry: npmmirror"
}

config_bashrc() {
    mkdir -p "$HOME/.bashrc.d"
    cat > "$HOME/.bashrc.d/node.sh" << 'EOF'
# --- fnm (Node 版本管理) + 国内镜像 ---
export FNM_DIR="$HOME/.local/share/fnm"
export FNM_NODE_DIST_MIRROR="https://npmmirror.com/mirrors/node"
[ -x "$FNM_DIR/fnm" ] && eval "$("$FNM_DIR/fnm" env --use-on-cd --shell bash)"
EOF
    log_ok ".bashrc.d/node.sh: fnm env + npmmirror"
}

case "$ACTION" in
    install)
        install_fnm
        install_node "$VERSION"
        config_npm_mirror
        config_bashrc
        ;;
    update)
        install_fnm
        fnm_env
        if [ -n "$VERSION" ]; then
            "$FNM_BIN" install "$VERSION"
            "$FNM_BIN" default "$VERSION"
        else
            "$FNM_BIN" install --lts
            resolved=$("$FNM_BIN" ls 2>/dev/null | awk '/lts/{print $2}' | head -1)
            [ -n "$resolved" ] && "$FNM_BIN" default "$resolved"
        fi
        fnm_env
        config_npm_mirror
        ;;
    remove)
        if [ -x "$FNM_BIN" ]; then
            "$FNM_BIN" uninstall --all 2>/dev/null || true
        fi
        rm -f "$HOME/.bashrc.d/node.sh"
        log_ok "node: 已删除（fnm 节点 + .bashrc.d/node.sh）"
        ;;
    *)
        echo "用法: $0 {install|update|remove}" >&2
        exit 2
        ;;
esac
