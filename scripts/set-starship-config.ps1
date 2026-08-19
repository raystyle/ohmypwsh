#Requires -Version 7.0
# set-starship-config.ps1 - starship.toml PowerShell 专用配置（全模板幂等写入）
# 用法: pwsh -NoProfile -File D:\ohmypwsh\scripts\set-starship-config.ps1 [-Force]
# 说明: 本脚本是 ~/.config/starship.toml 的唯一源（PowerShell 提示行 + 符号预设）；
#       已有文件与模板不一致时需 -Force 覆盖，避免静默覆盖手动修改。

param([switch]$Force)

$ErrorActionPreference = 'Stop'
$configPath = Join-Path $env:USERPROFILE '.config\starship.toml'

$template = @'
"$schema" = 'https://starship.rs/config-schema.json'

# ---- PowerShell 专用提示行（2026-08-19，ohmyenv 接管 starship 后配置）----
# 结构：目录 / git / 语言工具链 / 耗时 / shell 标识 / 输入符
format = """
$directory\
$git_branch\
$git_status\
$package\
$python\
$nodejs\
$rust\
$dotnet\
$cmd_duration\
$line_break\
$shell\
$character"""
scan_timeout = 30
command_timeout = 500
add_newline = true

[character]
success_symbol = '[❯](bold green)'
error_symbol = '[✖](bold red)'

[directory]
truncation_length = 3
truncate_to_repo = true
use_os_path_sep = true
read_only = " 󰌾"

[aws]
symbol = " "

[buf]
symbol = " "

[bun]
symbol = " "

[c]
symbol = " "

[cpp]
symbol = " "

[cmake]
symbol = " "

[conda]
symbol = " "

[crystal]
symbol = " "

[dart]
symbol = " "

[deno]
symbol = " "

[docker_context]
symbol = " "

[elixir]
symbol = " "

[elm]
symbol = " "

[fennel]
symbol = " "

[fortran]
symbol = " "

[fossil_branch]
symbol = " "

[gcloud]
symbol = " "

[git_branch]
symbol = " "

[git_commit]
tag_symbol = '  '

[golang]
symbol = " "

[gradle]
symbol = " "

[guix_shell]
symbol = " "

[haskell]
symbol = " "

[haxe]
symbol = " "

[hg_branch]
symbol = " "

[hostname]
ssh_symbol = " "

[java]
symbol = " "

[julia]
symbol = " "

[kotlin]
symbol = " "

[lua]
symbol = " "

[memory_usage]
symbol = "󰍛 "

[meson]
symbol = "󰔷 "

[nim]
symbol = "󰆥 "

[nix_shell]
symbol = " "

[nodejs]
symbol = " "

[ocaml]
symbol = " "

[os.symbols]
Alpaquita = " "
Alpine = " "
AlmaLinux = " "
Amazon = " "
Android = " "
AOSC = " "
Arch = " "
Artix = " "
CachyOS = " "
CentOS = " "
Debian = " "
DragonFly = " "
Elementary = " "
Emscripten = " "
EndeavourOS = " "
Fedora = " "
FreeBSD = " "
Garuda = "󰛓 "
Gentoo = " "
HardenedBSD = "󰞌 "
Illumos = "󰈸 "
Ios = "󰀷 "
Kali = " "
Linux = " "
Mabox = " "
Macos = " "
Manjaro = " "
Mariner = " "
MidnightBSD = " "
Mint = " "
NetBSD = " "
NixOS = " "
Nobara = " "
OpenBSD = "󰈺 "
openSUSE = " "
OracleLinux = "󰌷 "
Pop = " "
Raspbian = " "
Redhat = " "
RedHatEnterprise = " "
RockyLinux = " "
Redox = "󰀘 "
Solus = "󰠳 "
SUSE = " "
Ubuntu = " "
Unknown = " "
Void = " "
Windows = "󰍲 "
Zorin = " "

[package]
symbol = "󰏗 "

[perl]
symbol = " "

[php]
symbol = " "

[pijul_channel]
symbol = " "

[pixi]
symbol = "󰏗 "

[python]
symbol = " "

[rlang]
symbol = "󰟔 "

[ruby]
symbol = " "

[rust]
symbol = "󱘗 "

[scala]
symbol = " "

[status]
symbol = " "

[swift]
symbol = " "

[xmake]
symbol = " "

[zig]
symbol = " "

[shell]
disabled = false
pwsh_indicator = 'pwsh'
powershell_indicator = 'psh'
'@

$configDir = Split-Path $configPath -Parent
New-Item -ItemType Directory -Path $configDir -Force | Out-Null

if (-not (Test-Path -LiteralPath $configPath)) {
    Set-Content -LiteralPath $configPath -Value $template -Encoding utf8
    Write-Host "[OK] 已创建: $configPath" -ForegroundColor Green
    exit 0
}

$current = Get-Content -Raw -LiteralPath $configPath
if ($current.Trim() -eq $template.Trim()) {
    Write-Host '[INFO] 配置已是最新，跳过（-Force 重写）' -ForegroundColor DarkGray
    exit 0
}
if (-not $Force) {
    Write-Host '[WARN] 配置文件与模板不一致（可能有手动修改）；用 -Force 覆盖' -ForegroundColor Yellow
    exit 1
}

Set-Content -LiteralPath $configPath -Value $template -Encoding utf8
Write-Host "[OK] 已写入: $configPath" -ForegroundColor Green
