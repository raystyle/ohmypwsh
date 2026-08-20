#!/bin/bash
# ===================================================
# node.sh — nvm + Node.js LTS + npmmirror
# 以用户 ray 执行
# 用法:
#   bash node.sh install [版本]   # 默认最新 LTS；可指定如 20.18.0 / 22
#   bash node.sh update  [版本]
#   bash node.sh remove
# ===================================================
set -eo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"
VERSION="${2:-}"   # 可选：指定 Node 版本（如 20.18.0 / 22），默认最新 LTS

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

export NVM_DIR="$HOME/.nvm"

# 获取 nvm 最新 tag（GitHub API；失败回退固定版本）
get_nvm_tag() {
    local tag
    tag=$(curl -gs --max-time 15 "https://api.github.com/repos/nvm-sh/nvm/releases/latest" 2>/dev/null | jq -r '.tag_name // empty' 2>/dev/null)
    [ -n "$tag" ] || tag="v0.40.1"
    echo "$tag"
}

# 安装 nvm。已装且动作=install 则跳过。
install_nvm() {
    if [ -d "$NVM_DIR" ]; then
        log_ok "nvm: 已安装（$NVM_DIR）"
        return 0
    fi
    local NVM_TAG
    NVM_TAG=$(get_nvm_tag)
    curl -gsfL --connect-timeout 10 --max-time 60 --retry 2 "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_TAG/install.sh" | bash >/dev/null 2>&1
    log_ok "nvm: $NVM_TAG 已安装"
}

# 加载 nvm 到当前 shell
load_nvm() {
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
}

# 安装 Node.js（默认最新 LTS，可指定版本）。已装且未指定版本则跳过。
install_node() {
    local ver="${1:-}"
    if [ -z "$ver" ] && command -v node &>/dev/null; then
        log_ok "node: $(node --version)（已安装）"
    else
        local target="${ver:---lts}"
        NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node nvm install "$target" >/dev/null 2>&1
        nvm alias default node >/dev/null 2>&1
        log_ok "node: $(node --version) 已安装（$([ -n "$ver" ] && echo $ver || echo LTS)）"
    fi

    if command -v npm &>/dev/null; then
        log_ok "npm: $(npm --version)"
    else
        log_warn "node: 安装失败"
        exit 1
    fi
}

# npm 镜像配置
config_npm_mirror() {
    npm config set registry https://registry.npmmirror.com 2>/dev/null
    log_ok "npm registry: npmmirror"
}

# pip 镜像（python3 存在时）
config_pip_mirror() {
    if command -v python3 &>/dev/null; then
        python3 -m pip config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple 2>/dev/null || true
    fi
}

# .bashrc.d 片段：nvm 加载 + 镜像
config_bashrc() {
    mkdir -p "$HOME/.bashrc.d"
    cat > "$HOME/.bashrc.d/node.sh" << 'EOF'
# --- nvm (Node 版本管理) + 国内镜像 ---
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node/
EOF
    log_ok ".bashrc.d/node.sh: nvm 加载 + 镜像"
}

case "$ACTION" in
    install)
        install_nvm
        load_nvm
        install_node "$VERSION"
        config_npm_mirror
        config_pip_mirror
        config_bashrc
        ;;
    update)
        if [ ! -d "$NVM_DIR" ]; then
            log_warn "nvm: 未安装，先执行 install"
            exit 1
        fi
        load_nvm
        if [ -n "$VERSION" ]; then
            log_info "node: 更新到 $VERSION..."
            nvm install "$VERSION" >/dev/null 2>&1
            nvm alias default "$VERSION" >/dev/null 2>&1
        else
            log_info "node: 更新到最新 LTS..."
            NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node nvm install --lts >/dev/null 2>&1
            nvm alias default node >/dev/null 2>&1
        fi
        log_ok "node: $(node --version) 已更新"
        config_npm_mirror
        ;;
    remove)
        if [ -d "$NVM_DIR" ]; then
            rm -rf "$NVM_DIR"
            rm -f "$HOME/.bashrc.d/node.sh"
            log_ok "node: 已删除（~/.nvm + ~/.bashrc.d/node.sh）"
        else
            log_ok "node: 未安装，无需删除"
        fi
        ;;
    *)
        echo "用法: $0 {install|update|remove}" >&2
        exit 2
        ;;
esac
