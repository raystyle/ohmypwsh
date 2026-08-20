#!/bin/bash
# ===================================================
# base-config.sh — 用户创建 / wsl.conf / 时区 / locale / .bashrc.d 骨架
# 以 root 执行：wsl -d <distro> -u root bash scripts/base/base-config.sh <user> <pass>
# 登录 shell 固定 bash（镜像不含 zsh）；启用 systemd linger（--user 服务可开机自启）
# ===================================================
set -eo pipefail
trap 'echo "[ERROR] $0:行 $LINENO 失败（命令: $BASH_COMMAND）" >&2' ERR

USERNAME="${1:?用法: $0 <username> <password>}"
PASSWORD="${2:?用法: $0 <username> <password>}"

log_ok()   { echo "[OK]    $1"; }
log_warn() { echo "[WARN]  $1"; }

LOGIN_SHELL="/bin/bash"

# --- 用户创建 ---
if id "$USERNAME" &>/dev/null; then
    log_ok "用户 $USERNAME 已存在，跳过"
    usermod -aG sudo "$USERNAME"
else
    GROUPS=""
    for g in sudo adm cdrom plugdev; do
        if getent group "$g" &>/dev/null; then
            GROUPS="${GROUPS:+$GROUPS,}$g"
        fi
    done
    if [ -z "$GROUPS" ]; then
        useradd -m -s "$LOGIN_SHELL" "$USERNAME"
    else
        useradd -m -s "$LOGIN_SHELL" -G "$GROUPS" "$USERNAME"
    fi
    echo "$USERNAME:$PASSWORD" | chpasswd
    log_ok "用户 $USERNAME 创建完成（shell: bash）"
fi

# --- sudoers: 免密 ---
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME"
chmod 440 "/etc/sudoers.d/$USERNAME"
log_ok "sudoers: $USERNAME 免密码"

# --- .bashrc.d 机制：守卫前注入 source 循环 ---
# Ubuntu 默认 .bashrc 顶部有非交互 return 守卫，非交互 shell（bash -lc）读不到守卫后的
# PATH 配置。在守卫前注入 source 循环，dev 工具（node/bun/rust/uv/go/zig）的 PATH 片段
# 对非交互 shell 也生效。
USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)
BASHRC_D="$USER_HOME/.bashrc.d"
MARKER="# >>> ohmywsl2 dev env >>>"

install -d -o "$USERNAME" -g "$USERNAME" -m 0755 "$BASHRC_D"

if ! sudo -u "$USERNAME" grep -q "$MARKER" "$USER_HOME/.bashrc" 2>/dev/null; then
    sudo -u "$USERNAME" bash -c '
        BASHRC="'"$USER_HOME"'/.bashrc"
        BLOCK=""
        BLOCK+="# >>> ohmywsl2 dev env >>>\n"
        BLOCK+="# 守卫前 source 所有片段：非交互 shell（bash -lc）也能拿到 dev PATH\n"
        BLOCK+="for __f in \"\$HOME/.bashrc.d\"/*.sh; do [ -r \"\$__f\" ] && . \"\$__f\"; done\n"
        BLOCK+="unset __f\n"
        BLOCK+="# <<< ohmywsl2 dev env <<<\n"
        if grep -q "^case \$- " "$BASHRC" 2>/dev/null; then
            sed -i "/^case \$- /i \\
$BLOCK" "$BASHRC"
        else
            sed -i "1i \\
$BLOCK" "$BASHRC"
        fi
    '
    log_ok ".bashrc.d 机制已注入 $USER_HOME/.bashrc（守卫前）"
else
    log_ok ".bashrc.d 机制已存在，跳过"
fi

# --- wsl.conf ---
cat > /etc/wsl.conf << EOF
[user]
default=$USERNAME

[boot]
systemd=true

[interop]
appendWindowsPath=false
EOF
log_ok "wsl.conf: user=$USERNAME, systemd=true, appendWindowsPath=false"

# --- 时区（预设，导入器会再次确认） ---
ln -sf /usr/share/zoneinfo/Asia/Singapore /etc/localtime
echo "Asia/Singapore" > /etc/timezone
log_ok "时区: 预设 Asia/Singapore"

# --- locale ---
locale-gen zh_CN.UTF-8 en_US.UTF-8 >/dev/null 2>&1 || true
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 2>/dev/null
log_ok "locale: en_US.UTF-8 + zh_CN.UTF-8"

# --- systemd linger：默认用户 --user 服务可开机自启 ---
# 构建期无 systemd-logind，直接写 linger 标记文件（等价 loginctl enable-linger）
install -d -m 0755 /var/lib/systemd/linger
touch "/var/lib/systemd/linger/$USERNAME"
log_ok "linger: 已为 $USERNAME 启用（--user 服务可开机自启）"
