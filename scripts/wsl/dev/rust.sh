#!/bin/bash
# ===================================================
# rust.sh — Rust 工具链 + Linux/Windows 交叉编译 + rsproxy 镜像
# 以用户 ray 执行（sudo 免密）
# 用法:
#   bash rust.sh install [版本]   # 默认装 stable；可指定 1.96.0 / nightly 等
#   bash rust.sh update  [版本]
#   bash rust.sh remove
# ===================================================
set -eo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"
VERSION="${2:-}"   # 可选：stable(默认) / 1.96.0 / nightly 等 rustup toolchain 标识

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

# 镜像环境变量（rsproxy.cn）
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"

# 安装 rustup + stable toolchain
install_rustup() {
    if command -v rustup &>/dev/null; then
        log_ok "rust: $(rustc --version | awk '{print $2}')（已安装）"
        return 0
    fi
    curl --proto '=https' --tlsv1.2 -sSf --connect-timeout 10 --max-time 120 --retry 2 https://rsproxy.cn/rustup-init.sh | sh -s -- -y --default-toolchain stable >/dev/null 2>&1
    export PATH="$HOME/.cargo/bin:$PATH"
    if ! command -v rustc &>/dev/null; then
        log_warn "rustup 安装失败"
        exit 1
    fi
    log_ok "rust: $(rustc --version | awk '{print $2}') 已安装"
}

load_rust_env() {
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
    export PATH="$HOME/.cargo/bin:$PATH"
}

# cargo 镜像 + Windows mingw linker（已有用户配置则不覆盖）
config_cargo() {
    mkdir -p "$HOME/.cargo"
    if [ -f "$HOME/.cargo/config.toml" ]; then
        log_ok "cargo config.toml: 已存在，保留"
        return 0
    fi
    cat > "$HOME/.cargo/config.toml" << 'EOF'
[source.crates-io]
replace-with = "rsproxy-sparse"

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"

[net]
git-fetch-with-cli = true

[http]
check-revoke = false
multiplexing = true

# Linux 交叉编译 Windows x64（mingw-w64 linker）
[target.x86_64-pc-windows-gnu]
linker = "x86_64-w64-mingw32-gcc"
ar = "x86_64-w64-mingw32-ar"
EOF
    log_ok "cargo registry: rsproxy.cn (sparse) + windows-gnu mingw linker"
}

# 交叉编译 targets
install_targets() {
    rustup target add \
        x86_64-unknown-linux-gnu \
        x86_64-unknown-linux-musl \
        x86_64-pc-windows-gnu \
        >/dev/null 2>&1
    log_ok "targets: linux-gnu(x64) + linux-musl(x64 静态) + windows(x64)"
}

# rust-analyzer 组件（rustup 官方组件）
install_rust_analyzer() {
    rustup component add rust-analyzer >/dev/null 2>&1 || true
    log_ok "component: rust-analyzer"
}

# musl-tools（Linux 静态编译辅助；mingw/build-essential 已由 base 组装好）
ensure_musl() {
    if ! command -v musl-gcc &>/dev/null; then
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq musl-tools >/dev/null 2>&1
        log_ok "musl-tools: 已安装"
    else
        log_ok "musl-tools: 已安装"
    fi
}

# .bashrc.d 片段：Rust 环境
config_bashrc() {
    mkdir -p "$HOME/.bashrc.d"
    cat > "$HOME/.bashrc.d/rust.sh" << 'EOF'
# --- Rust 环境 (rsproxy.cn) ---
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
. "$HOME/.cargo/env" 2>/dev/null
export PATH="$HOME/.cargo/bin:$PATH"
EOF
    log_ok ".bashrc.d/rust.sh: Rust 环境 + cargo PATH"
}

case "$ACTION" in
    install)
        install_rustup
        load_rust_env
        if [ -n "$VERSION" ]; then
            if rustup toolchain list 2>/dev/null | grep -q "$VERSION"; then
                log_ok "rust: $VERSION 已安装"
            else
                rustup toolchain install "$VERSION" >/dev/null 2>&1
            fi
            rustup default "$VERSION" >/dev/null 2>&1
            log_ok "rust: 默认 toolchain 设为 $VERSION"
        fi
        config_cargo
        install_targets
        install_rust_analyzer
        ensure_musl
        config_bashrc
        ;;
    update)
        if ! command -v rustup &>/dev/null; then
            log_warn "rustup: 未安装，先执行 install"
            exit 1
        fi
        load_rust_env
        if [ -n "$VERSION" ]; then
            rustup update "$VERSION" >/dev/null 2>&1
            log_ok "rust: $VERSION 已更新"
        else
            rustup update >/dev/null 2>&1
            log_ok "rust: $(rustc --version | awk '{print $2}') 已更新"
        fi
        install_targets
        install_rust_analyzer
        ensure_musl
        ;;
    remove)
        if command -v rustup &>/dev/null; then
            rustup self uninstall -y >/dev/null 2>&1
            rm -rf "$HOME/.rustup"
            rm -f "$HOME/.bashrc.d/rust.sh"
            log_ok "rust: 已删除（rustup + ~/.rustup + 片段）"
        else
            log_ok "rust: 未安装，无需删除"
        fi
        ;;
    *)
        echo "用法: $0 {install|update|remove}" >&2
        exit 2
        ;;
esac
