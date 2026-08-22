#Requires -Version 7.0
# set-wsl-keys.ps1 - 把 Windows 的 age 私钥 + SOPS 加密密钥平移到 WSL（ohmywsl）
# 1) 复制 age 私钥（%APPDATA%\sops\age\keys.txt）→ WSL ~/.config/sops/age/keys.txt（chmod 600）
# 2) 在 WSL ~/.bashrc.d/ohmywsl-secrets.sh 注入惰性解密：每次 shell 启动用 WSL sops 现场解密
#    .secrets\deepseek.env.enc / anthropic.env.enc 导出 DEEPSEEK_API_KEY / ANTHROPIC_API_KEY；
#    明文只进环境变量，不落盘。
# 用法: pwsh -NoProfile -File scripts\set-wsl-keys.ps1 [-Distro ohmywsl] [-User ray] [-SkipPrivateKey]
# 前置: ohmywsl distro 已导入、age/sops 已 install（ohmywsl.ps1 install age sops）

param(
    [string]$Distro = 'ohmywsl',
    [string]$User = 'ray',
    [switch]$SkipPrivateKey
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'helpers.ps1')

$envRoot    = Get-DefaultEnvRoot
$projectRoot = Split-Path -Parent $PSScriptRoot
$secretsDir  = Join-Path $projectRoot '.secrets'
$winKeys     = Join-Path $env:APPDATA 'sops\age\keys.txt'

function ConvertTo-WslPath {
    param([Parameter(Mandatory)][string]$WinPath)
    $drive = $WinPath.Substring(0, 1).ToLower()
    return '/mnt/' + $drive + $WinPath.Substring(2).Replace('\', '/')
}

function Invoke-WslBash {
    param(
        [Parameter(Mandatory)][string]$Command,
        [switch]$Root
    )
    $prev = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
    try {
        $u = if ($Root) { 'root' } else { $User }
        & wsl -d $Distro -u $u -e bash -lc $Command
        return $LASTEXITCODE
    } finally {
        [Console]::OutputEncoding = $prev
    }
}

# distro 检查
$prevEnc = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::Unicode
$hasDistro = [bool]((wsl -l -q 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq $Distro }))
[Console]::OutputEncoding = $prevEnc
if (-not $hasDistro) { throw "WSL distro $Distro 不存在，先导入: scripts\set-wsl-distro.ps1" }

# 前置：WSL 内有 sops
$null = Invoke-WslBash -Command "command -v sops >/dev/null 2>&1 || { echo 'sops missing'; exit 1; }"
if ($LASTEXITCODE -ne 0) { throw "WSL 内未安装 sops，先执行: ohmywsl.ps1 install sops" }

# ── 1. age 私钥平移 ──
if (-not $SkipPrivateKey) {
    if (-not (Test-Path -LiteralPath $winKeys)) { throw "未找到 Windows age 私钥: $winKeys" }
    $keysWsl = ConvertTo-WslPath (Join-Path $envRoot 'cache\wsl-tools\age\age-keys.txt')
    # 先落到 EnvRoot cache（不直接跨盘写 WSL 家目录），再在 WSL 内拷贝到 ~/.config/sops/age/
    Copy-Item -LiteralPath $winKeys -Destination (Join-Path $envRoot 'cache\wsl-tools\age\age-keys.txt') -Force
    $cmd = "mkdir -p `$HOME/.config/sops/age && cp '$keysWsl' `$HOME/.config/sops/age/keys.txt && chmod 600 `$HOME/.config/sops/age/keys.txt && echo age-key-ok"
    $out = Invoke-WslBash -Command $cmd
    Write-Host "[OK] age 私钥已平移到 WSL ~/.config/sops/age/keys.txt（chmod 600）" -ForegroundColor Green
    # 解密自检：用 WSL sops 直接解 deepseek.enc，验证私钥可用
    $deepseekEnc = ConvertTo-WslPath (Join-Path $secretsDir 'deepseek.env.enc')
    $null = Invoke-WslBash -Command "export SOPS_AGE_KEY_FILE=`$HOME/.config/sops/age/keys.txt; sops --input-type dotenv --output-type dotenv -d '$deepseekEnc' 2>&1 | grep -q DEEPSEEK_API_KEY && echo sops-decrypt-ok"
    if ($LASTEXITCODE -ne 0) { throw 'WSL 内 sops 用平移私钥解密失败' }
    Write-Host '[OK] WSL sops 解密自检通过（私钥与 .sops.yaml 公钥自洽）' -ForegroundColor Green
}

# ── 2. 惰性解密注入 .bashrc.d/ohmywsl-secrets.sh ──
# 明文绝不落盘：脚本只记录 SOPS_AGE_KEY_FILE 与两条「现场解密 -> export」指令；
# 每次交互/非交互 shell 启动时用 sops -d 解出 key（管道，不进文件）。
$deepseekWsl = ConvertTo-WslPath (Join-Path $secretsDir 'deepseek.env.enc')
$anthropicWsl = ConvertTo-WslPath (Join-Path $secretsDir 'anthropic.env.enc')
$block = @"
# --- ohmywsl secrets（由 set-wsl-keys.ps1 生成，勿手改）---
# 惰性解密：sops 字段解密 dotenv，结果 export；明文仅进环境变量，不落盘。
export SOPS_AGE_KEY_FILE="`$HOME/.config/sops/age/keys.txt"
export ANTHROPIC_BASE_URL="https://open.bigmodel.cn/api/anthropic"
if command -v sops >/dev/null 2>&1; then
  [ -f '$deepseekWsl' ] && eval `"`$(sops --input-type dotenv --output-type dotenv -d '$deepseekWsl' 2>/dev/null | sed 's/^/export /')`"
  [ -f '$anthropicWsl' ] && eval `"`$(sops --input-type dotenv --output-type dotenv -d '$anthropicWsl' 2>/dev/null | sed 's/^/export /')`"
fi
unset -v __sops_out
# --- end ohmywsl secrets ---
"@

# 通过 heredoc 安全写进 WSL（避免 PowerShell 引号地狱）
$blockPath = Join-Path $envRoot 'cache\wsl-tools\ohmywsl-secrets.sh'
[System.IO.File]::WriteAllText($blockPath, $block, (New-Object System.Text.UTF8Encoding $false))
$blockWsl = ConvertTo-WslPath $blockPath
$null = Invoke-WslBash -Command "mkdir -p `$HOME/.bashrc.d && cp '$blockWsl' `$HOME/.bashrc.d/ohmywsl-secrets.sh && chmod 644 `$HOME/.bashrc.d/ohmywsl-secrets.sh && echo secrets-installed"
if ($LASTEXITCODE -ne 0) { throw '写入 ~/.bashrc.d/ohmywsl-secrets.sh 失败' }

# ── 3. 校验：新 shell 里解出的 key 形如 sk- / xxxx.yyyy，且不落盘（只在 WSL 内断言，不回显 key） ──
$null = Invoke-WslBash -Command "unset DEEPSEEK_API_KEY ANTHROPIC_API_KEY; . `$HOME/.bashrc.d/ohmywsl-secrets.sh 2>/dev/null; printf '%s' `"`$DEEPSEEK_API_KEY`" | grep -q '^sk-' || exit 1; printf '%s' `"`$ANTHROPIC_API_KEY`" | grep -qE '^[A-Za-z0-9]+\.[A-Za-z0-9]+`$' || exit 2"
if ($LASTEXITCODE -ne 0) {
    throw "被平移密钥校验失败（exit=$LASTEXITCODE）"
}
Write-Host '[OK] WSL 内密钥断言通过（DS 形如 sk- / AK 形如 x.y，明文不回显）' -ForegroundColor Green

# 明文不落盘校验：WSL 家目录内不应出现 key 明文命中文件
$keyLoose = Invoke-WslBash -Command "grep -rlE 'sk-[A-Za-z0-9]{8,}' `$HOME/.bashrc.d `$HOME/.config/sops 2>/dev/null || true"
if ($keyLoose) { throw "检测到明文密钥落盘: $($keyLoose -join ' ')" }

Write-Host "[OK] 密钥平移完成：WSL 内新 shell 可拿到 DEEPSEEK_API_KEY / ANTHROPIC_API_KEY（惰性解密，明文不落盘）" -ForegroundColor Green
