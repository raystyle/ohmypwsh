#!/bin/bash
# ===================================================
# zig.sh — Zig 编译器（官方预编译包，最新稳定版）
# 以用户 ray 执行
# 用法: bash zig.sh {install|update|remove}（默认 install）
# 说明:
#   - 从 ziglang.org/download/index.json 获取最新稳定版
#   - 解压到 ~/.local/zig/，软链 current → 版本目录，PATH 片段指向 current
#   - ZLS 官方语言服务器（GitHub 预编译）随 zig 一起安装到 ~/.local/bin
#   - 跨平台编译为 Zig 一等公民：zig build-exe -target x86_64-windows-gnu 等，
#     无需额外交叉工具链
# ===================================================
set -eo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

ACTION="${1:-install}"

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }
log_info() { echo "[INFO]  $1"; }

ZIG_ROOT="$HOME/.local/zig"
ZIG_BASE="https://ziglang.org/download"
ZLS_BIN="$HOME/.local/bin/zls"
ZLS_REPO="zigtools/zls"
ARCH="x86_64"
[ "$(uname -m)" = "aarch64" ] && ARCH="aarch64"

# 获取最新稳定版本号（index.json 中除 master 外的第一个 key）
get_zig_version() {
    local ver
    ver=$(curl -gsL --max-time 20 --retry 2 "$ZIG_BASE/index.json" 2>/dev/null \
        | jq -r 'to_entries[] | select(.key != "master") | .key' 2>/dev/null | head -1)
    [ -n "$ver" ] || { log_warn "zig: 无法获取版本列表（网络？）"; exit 1; }
    echo "$ver"
}

# 下载 + 原子安装
install_zig() {
    local VER
    VER=$(get_zig_version)
    local DIR_NAME="zig-${ARCH}-linux-$VER"
    local TARBALL="${DIR_NAME}.tar.xz"
    local TMP_DIR="/tmp/zig-install"
    rm -rf "$TMP_DIR" && mkdir -p "$TMP_DIR" "$ZIG_ROOT"

    log_info "zig: 下载 $TARBALL ..."
    if ! curl -gsfL --connect-timeout 10 --max-time 300 --retry 2 \
        -o "$TMP_DIR/$TARBALL" "$ZIG_BASE/$VER/$TARBALL"; then
        log_warn "zig: 下载失败（$TARBALL）"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    if ! tar -xJf "$TMP_DIR/$TARBALL" -C "$TMP_DIR" 2>/dev/null; then
        log_warn "zig: 解压失败（tarball 可能损坏）"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    if [ ! -x "$TMP_DIR/$DIR_NAME/zig" ]; then
        log_warn "zig: 解压后找不到 zig 二进制"
        rm -rf "$TMP_DIR"
        exit 1
    fi

    # 原子替换：新版本目录 + current 软链
    rm -rf "$ZIG_ROOT/$DIR_NAME"
    mv "$TMP_DIR/$DIR_NAME" "$ZIG_ROOT/"
    ln -sfn "$ZIG_ROOT/$DIR_NAME" "$ZIG_ROOT/current"
    rm -rf "$TMP_DIR"
    log_ok "zig: $VER 已安装（$ZIG_ROOT/current → $DIR_NAME）"
}

# 获取 ZLS 最新版本（GitHub 官方仓库 latest release）
get_zls_version() {
    local ver
    ver=$(curl -gsL --max-time 20 --retry 2 \
        "https://api.github.com/repos/${ZLS_REPO}/releases/latest" 2>/dev/null \
        | jq -r '.tag_name' 2>/dev/null)
    if [ -z "$ver" ] || [ "$ver" = "null" ]; then
        log_warn "zls: 无法获取版本（网络？）"
        exit 1
    fi
    echo "$ver"
}

# 下载官方预编译 + 原子安装到 ~/.local/bin
install_zls() {
    local VER
    VER=$(get_zls_version)
    local TARBALL="zls-${ARCH}-linux.tar.xz"
    local TMP_DIR="/tmp/zls-install"
    rm -rf "$TMP_DIR" && mkdir -p "$TMP_DIR" "$HOME/.local/bin"

    log_info "zls: 下载 $TARBALL ..."
    if ! curl -gsfL --connect-timeout 10 --max-time 300 --retry 2 \
        -o "$TMP_DIR/$TARBALL" "https://github.com/${ZLS_REPO}/releases/download/$VER/$TARBALL"; then
        log_warn "zls: 下载失败（$TARBALL）"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    if ! tar -xJf "$TMP_DIR/$TARBALL" -C "$TMP_DIR" 2>/dev/null; then
        log_warn "zls: 解压失败（tarball 可能损坏）"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    local BIN
    BIN=$(find "$TMP_DIR" -maxdepth 2 -type f -name zls | head -1)
    if [ -z "$BIN" ]; then
        log_warn "zls: 解压后找不到 zls 二进制"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    install -m 0755 "$BIN" "$ZLS_BIN"
    rm -rf "$TMP_DIR"
    log_ok "zls: $VER 已安装（$ZLS_BIN）"
}

# .bashrc.d 片段：PATH → current
config_path() {
    mkdir -p "$HOME/.bashrc.d"
    cat > "$HOME/.bashrc.d/zig.sh" << 'EOF'
# --- Zig（current 软链指向具体版本目录）+ ZLS ---
export PATH="$HOME/.local/bin:$HOME/.local/zig/current:$PATH"
EOF
    log_ok ".bashrc.d/zig.sh: ~/.local/bin + ~/.local/zig/current PATH"
}

case "$ACTION" in
    install)
        if [ -x "$ZIG_ROOT/current/zig" ]; then
            log_ok "zig: $("$ZIG_ROOT/current/zig" version)（已安装）"
        else
            install_zig
            log_ok "zig: $("$ZIG_ROOT/current/zig" version)"
        fi
        config_path
        if [ -x "$ZLS_BIN" ]; then
            log_ok "zls: $("$ZLS_BIN" --version 2>/dev/null | head -1)（已安装）"
        else
            install_zls
            log_ok "zls: $("$ZLS_BIN" --version | head -1)"
        fi
        ;;
    update)
        if [ ! -x "$ZIG_ROOT/current/zig" ]; then
            log_warn "zig: 未安装，先执行 install"
            exit 1
        fi
        install_zig
        log_ok "zig: $("$ZIG_ROOT/current/zig" version)"
        install_zls
        log_ok "zls: $("$ZLS_BIN" --version | head -1)"
        ;;
    remove)
        if [ -d "$ZIG_ROOT" ]; then
            rm -rf "$ZIG_ROOT"
            rm -f "$HOME/.bashrc.d/zig.sh"
            rm -f "$ZLS_BIN"
            log_ok "zig: 已删除（~/.local/zig + zls + 片段）"
        else
            log_ok "zig: 未安装，无需删除"
        fi
        ;;
    *)
        echo "用法: $0 {install|update|remove}" >&2
        exit 2
        ;;
esac
