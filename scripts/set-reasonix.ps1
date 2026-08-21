#Requires -Version 7.0
# set-reasonix.ps1 - Reasonix Desktop 接管（esengine/DeepSeek-Reasonix，DeepSeek 密钥复用，幂等）
# 用法: pwsh -NoProfile -File scripts\set-reasonix.ps1
# 说明: 下载官方 Reasonix-windows-amd64.zip（sha256 校验）→ 解压到 EnvRoot\reasonix →
#       写入 %APPDATA%\reasonix\config.toml（DeepSeek preset）与 .env（复用 DEEPSEEK_API_KEY）。

param([string]$Version = 'desktop-v1.31.0')

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'helpers.ps1')

$envRoot   = Get-DefaultEnvRoot
$reasonixDir = Join-Path $envRoot 'reasonix'
$zipPath   = Join-Path $envRoot 'cache\Reasonix-windows-amd64.zip'
$zipUrl    = "https://github.com/esengine/DeepSeek-Reasonix/releases/download/$Version/Reasonix-windows-amd64.zip"
$zipSha    = 'c7bc883956e22ce18980ac8ab6a306742ed96dc6bbdb34917d27f266e645d4ee'
$reasonixHome = Join-Path $env:APPDATA 'reasonix'
$config    = Join-Path $reasonixHome 'config.toml'
$envFile   = Join-Path $reasonixHome '.env'

# ── 1. 下载 + sha256 校验 ──
if (-not (Test-Path -LiteralPath (Join-Path $reasonixDir 'Reasonix.exe'))) {
    if (-not (Test-Path -LiteralPath $zipPath)) {
        Write-Host "[INFO] 下载 $zipUrl" -ForegroundColor Cyan
        Save-ReleaseAsset -Url $zipUrl -OutFile $zipPath -ExpectedSha256 $zipSha
    }
    $actual = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $zipSha) { throw "Reasonix zip sha256 校验失败: $actual" }
    New-Item -ItemType Directory -Path $reasonixDir -Force | Out-Null
    Expand-Archive -LiteralPath $zipPath -DestinationPath $reasonixDir -Force
    Write-Host "[OK] Reasonix 已解压到 $reasonixDir" -ForegroundColor Green
} else {
    Write-Host '[INFO] Reasonix 已就绪，跳过解压' -ForegroundColor DarkGray
}

# ── 2. Reasonix home + config.toml（DeepSeek preset，密钥不落 config）──
New-Item -ItemType Directory -Path $reasonixHome -Force | Out-Null
$configContent = @'
config_version = 1
default_model = "deepseek/deepseek-v4-flash"
language = "zh"

[desktop]
provider_access = ["deepseek"]

[[providers]]
name        = "deepseek"
kind        = "anthropic"
base_url    = "https://api.deepseek.com/anthropic"
models      = ["deepseek-v4-flash", "deepseek-v4-pro"]
default     = "deepseek-v4-flash"
api_key_env = "DEEPSEEK_API_KEY"
web_search  = true
'@
$existingConfig = if (Test-Path -LiteralPath $config) { [System.IO.File]::ReadAllText($config) } else { '' }
if (-not $existingConfig) {
    [System.IO.File]::WriteAllText($config, $configContent, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "[OK] config.toml 已写入: $config" -ForegroundColor Green
} else {
    Write-Host '[INFO] config.toml 已存在，保留 Reasonix 生成的完整配置' -ForegroundColor DarkGray
}

# ── 2.5 优化配置（幂等字符串替换）──
$text = [System.IO.File]::ReadAllText($config)
$repl = @(
    @('default_tool_approval_mode = "auto"', 'default_tool_approval_mode = "yolo"'),
    @('check_updates = true', 'check_updates = false'),
    @('telemetry = true', 'telemetry = false'),
    @('metrics = true', 'metrics = false'),
    @('# display_currency = "auto"', 'display_currency = "CNY"'),
    @('# prefer = "auto"', 'prefer = "pwsh"'),
    @('mode  = "ask"', 'mode  = "yolo"'),
    @('# deny = ["Bash(rm -rf*)", "Bash(git push*)"]', 'deny = ["Bash(rm -rf*)", "Bash(git push*)"]'),
    @('# forbid_read = []', 'forbid_read = ["${USERPROFILE}\\.ssh", "${USERPROFILE}\\.aws"]')
)
$changed = $false
foreach ($r in $repl) {
    if ($text.Contains($r[0])) { $text = $text.Replace($r[0], $r[1]); $changed = $true }
}
# 关闭 pro planner：仅注释未注释的 planner_model 行（正则，幂等不叠加 #）
if ($text -match '(?m)^[ \t]*planner_model\s*=\s*"deepseek-pro"') {
    $text = [regex]::Replace($text, '(?m)^([ \t]*)planner_model\s*=\s*"deepseek-pro"', '$1# planner_model = "deepseek-pro"')
    $changed = $true
}
if ($changed) {
    [System.IO.File]::WriteAllText($config, $text, (New-Object System.Text.UTF8Encoding $false))
    Write-Host '[OK] Reasonix 优化配置已应用（yolo/telemetry off/deny/forbid_read/planner off/pwsh/CNY）' -ForegroundColor Green
} else {
    Write-Host '[INFO] Reasonix 优化配置已是最新' -ForegroundColor DarkGray
}

# ── 3. .env：复用用户环境变量 DEEPSEEK_API_KEY（不回显）──
$key = [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY', 'User')
if (-not $key) { $key = $env:DEEPSEEK_API_KEY }
if (-not $key) { throw '未找到 DEEPSEEK_API_KEY（先运行 set-deepseek-key.ps1）' }
$envContent = "DEEPSEEK_API_KEY=$key`n"
if ((Test-Path $envFile) -and ([System.IO.File]::ReadAllText($envFile) -eq $envContent)) {
    Write-Host '[INFO] .env 已是最新' -ForegroundColor DarkGray
} else {
    [System.IO.File]::WriteAllText($envFile, $envContent, (New-Object System.Text.UTF8Encoding $false))
    Write-Host '[OK] .env 已写入（密钥不回显）' -ForegroundColor Green
}

# ── 4. PATH（用户级前置 reasonix）──
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$parts = $userPath -split ';' | Where-Object { $_ }
if ($parts -notcontains $reasonixDir) {
    [Environment]::SetEnvironmentVariable('Path', (@($reasonixDir) + $parts) -join ';', 'User')
    $env:Path = "$reasonixDir;$env:Path"
    Write-Host '[OK] PATH 已前置 reasonix' -ForegroundColor Green
} else {
    Write-Host '[INFO] reasonix 已在 PATH' -ForegroundColor DarkGray
}

# ── 5. 校验 ──
$cli = Join-Path $reasonixDir 'reasonix-cli.exe'
if (Test-Path $cli) {
    $ver = (& $cli --version 2>&1 | Select-Object -First 1)
    Write-Host "[OK] reasonix-cli: $ver" -ForegroundColor Green
}

# ── 6. 桌面快捷方式（幂等）──
$desktop = [Environment]::GetFolderPath('Desktop')
$lnkPath = Join-Path $desktop 'Reasonix.lnk'
$wsh = New-Object -ComObject WScript.Shell
$lnk = $wsh.CreateShortcut($lnkPath)
$lnk.TargetPath = (Join-Path $reasonixDir 'Reasonix.exe')
$lnk.WorkingDirectory = $reasonixDir
$lnk.Description = 'Reasonix Desktop'
$lnk.Save()
Write-Host "[OK] 桌面快捷方式已创建: $lnkPath" -ForegroundColor Green

Write-Host '[完成] Reasonix Desktop 接管就绪。桌面入口: reasonix\Reasonix.exe' -ForegroundColor Cyan
