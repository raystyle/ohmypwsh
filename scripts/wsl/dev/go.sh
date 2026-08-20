#!/bin/bash
# ===================================================
# go.sh — Go 工具链 + goproxy.cn 模块代理
# 以用户 ray 执行（sudo 免密，安装到 /usr/local）
# 用法:
#   bash go.sh install [版本]   # 默认最新 stable；可指定如 1.26.5
#   bash go.sh update  [版本]
#   bash go.sh remove
# 注：gopls 为官方 Go 语言服务器，随 go 一起安装；golangci-lint 等编辑器工具由目标机按需安装。
# ===================================================
set -eo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"
VERSION="${2:-}"   # 可选：指定版本（如 1.26.5），默认查最新 stable

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

GO_INSTALL_DIR="/usr/local/go"
GOPATH="$HOME/go"
GOBIN="$HOME/go/bin"
GOPROXY="https://goproxy.cn,direct"
GOSUMDB="sum.golang.google.cn"
GO_DL_BASE="https://golang.google.cn/dl"
FALLBACK_VERSION="go1.26.4"

ARCH="amd64"
[ "$(uname -m)" = "aarch64" ] && ARCH="arm64"

# 获取最新稳定版
get_latest_go_version() {
    local version
    version=$(curl -gsL --max-time 15 --retry 2 "${GO_DL_BASE}/?mode=json" 2>/dev/null | jq -r '.[0].version' 2>/dev/null)
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        echo "$FALLBACK_VERSION"
    else
        echo "$version"
    fi
}

# 下载并安装 Go 到 /usr/local/go（原子替换）
install_go() {
    local version="$1"
    if [ -x "$GO_INSTALL_DIR/bin/go" ]; then
        local current
        current=$("$GO_INSTALL_DIR/bin/go" version 2>/dev/null | awk '{print $3}')
        if [ "$current" = "$version" ]; then
            log_ok "go: $version（已是最新）"
            return 0
        fi
        log_info "升级 Go: $current → $version"
    fi

    local TARBALL_URL="${GO_DL_BASE}/${version}.linux-${ARCH}.tar.gz"
    local TMP_TARBALL="/tmp/go-install.tar.gz"
    if ! curl -gsfL --max-time 300 --retry 2 -o "$TMP_TARBALL" "$TARBALL_URL"; then
        log_warn "下载失败: $TARBALL_URL"
        rm -f "$TMP_TARBALL"
        exit 1
    fi

    local TMP_EXTRACT="/tmp/go-extract"
    sudo rm -rf "$TMP_EXTRACT"
    sudo mkdir -p "$TMP_EXTRACT"
    if ! sudo tar -C "$TMP_EXTRACT" -xzf "$TMP_TARBALL" 2>/dev/null || [ ! -x "$TMP_EXTRACT/go/bin/go" ]; then
        log_warn "tar 解压失败（tarball 可能损坏）"
        sudo rm -rf "$TMP_EXTRACT"
        rm -f "$TMP_TARBALL"
        exit 1
    fi
    sudo rm -rf "$GO_INSTALL_DIR"
    sudo mv "$TMP_EXTRACT/go" "$GO_INSTALL_DIR"
    sudo rm -rf "$TMP_EXTRACT"
    rm -f "$TMP_TARBALL"
    log_ok "go: $version 安装完成"
}

load_go_env() {
    export PATH="$GO_INSTALL_DIR/bin:$GOBIN:$PATH"
    export GOPATH="$GOPATH"
    export GOBIN="$GOBIN"
    export GOPROXY="$GOPROXY"
    export GOSUMDB="$GOSUMDB"
}

# 官方 Go 语言服务器（go install，装到 $GOBIN）
install_gopls() {
    if [ -x "$GOBIN/gopls" ]; then
        log_ok "gopls: $("$GOBIN/gopls" version 2>/dev/null | head -1)（已安装）"
        return 0
    fi
    log_info "gopls: 安装官方语言服务器（go install）..."
    if ! go install golang.org/x/tools/gopls@latest; then
        log_warn "gopls: go install 失败"
        exit 1
    fi
    log_ok "gopls: $("$GOBIN/gopls" version | head -1)"
}

# .bashrc.d 片段：Go 环境
config_bashrc() {
    mkdir -p "$HOME/.bashrc.d"
    cat > "$HOME/.bashrc.d/golang.sh" << 'EOF'
# --- Go 环境 (goproxy.cn) ---
export GOPATH="$HOME/go"
export GOBIN="$HOME/go/bin"
export GOPROXY="https://goproxy.cn,direct"
export GOSUMDB="sum.golang.google.cn"
export PATH="/usr/local/go/bin:$GOBIN:$PATH"
EOF
    log_ok ".bashrc.d/golang.sh: Go 环境 + PATH"
}

LATEST_VERSION=$(get_latest_go_version)

case "$ACTION" in
    install)
        mkdir -p "$GOPATH" "$GOBIN"
        target="$LATEST_VERSION"
        if [ -n "$VERSION" ]; then
            target="$VERSION"
            [[ "$target" != go* ]] && target="go$target"
        fi
        install_go "$target"
        load_go_env
        if ! command -v go &>/dev/null; then
            log_warn "go 安装异常，PATH 中找不到 go"
            exit 1
        fi
        log_ok "go: $(go version | awk '{print $3, $4}')"
        config_bashrc
        install_gopls
        ;;
    update)
        if ! command -v go &>/dev/null; then
            log_warn "go: 未安装，先执行 install"
            exit 1
        fi
        load_go_env
        target="$LATEST_VERSION"
        if [ -n "$VERSION" ]; then
            target="$VERSION"
            [[ "$target" != go* ]] && target="go$target"
        fi
        install_go "$target"
        load_go_env
        log_ok "go: $(go version | awk '{print $3, $4}')"
        install_gopls
        ;;
    remove)
        if [ -x "$GO_INSTALL_DIR/bin/go" ]; then
            sudo rm -rf "$GO_INSTALL_DIR"
            rm -rf "$GOPATH"
            rm -f "$HOME/.bashrc.d/golang.sh"
            log_ok "go: 已删除（/usr/local/go + ~/go + gopls + 片段）"
        else
            log_ok "go: 未安装，无需删除"
        fi
        ;;
    *)
        echo "用法: $0 {install|update|remove}" >&2
        exit 2
        ;;
esac
