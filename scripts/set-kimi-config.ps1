#Requires -Version 7.0
# set-kimi-config.ps1 - Kimi Code 安装/更新 + 配置（默认位置 ~/.kimi-code，auto 权限 + 关遥测）
# 用法:
#   pwsh -NoProfile -File scripts\set-kimi-config.ps1                 # 缺省安装 + 配置
#   pwsh -NoProfile -File scripts\set-kimi-config.ps1 -Update         # 升级到最新
#   pwsh -NoProfile -File scripts\set-kimi-config.ps1 -PermissionMode yolo
# 说明: 与 claude 一致，kimi 按其官方默认位置 %USERPROFILE%\.kimi-code 安装/维护，不进入 D:\ohmyenv。

param(
    [switch]$Update,
    [ValidateSet('auto', 'yolo', 'manual')][string]$PermissionMode = 'auto',
    [string]$Version
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers.ps1')   # 重建 PATH（注册表权威）

$kimiHome = Join-Path $env:USERPROFILE '.kimi-code'
$kimiBin  = Join-Path $kimiHome 'bin\kimi.exe'

# ── 1. 安装 / 更新（官方 installer，装到默认 ~/.kimi-code） ──
if ($Update -and (Test-Path -LiteralPath $kimiBin)) {
    Write-Host '[INFO] 升级 kimi 到最新（kimi upgrade）...' -ForegroundColor Cyan
    & $kimiBin upgrade
    if ($LASTEXITCODE -ne 0) { throw 'kimi upgrade 失败' }
    Write-Host "[OK] kimi 已升级: $((& $kimiBin --version))" -ForegroundColor Green
} elseif (-not (Test-Path -LiteralPath $kimiBin)) {
    Write-Host '[INFO] 运行官方安装脚本（目标 %USERPROFILE%\.kimi-code）...' -ForegroundColor Cyan
    if ($Version) { $env:KIMI_VERSION = $Version } else { Remove-Item Env:KIMI_VERSION -ErrorAction SilentlyContinue }
    irm 'https://code.kimi.com/kimi-code/install.ps1' | iex
    if (-not (Test-Path -LiteralPath $kimiBin)) { throw 'kimi 安装失败：未找到 kimi.exe' }
    Write-Host "[OK] kimi 已安装: $kimiBin" -ForegroundColor Green
} else {
    Write-Host "[OK] kimi 已存在: $kimiBin（-Update 升级到最新）" -ForegroundColor Green
}

# ── 2. config.toml 幂等合并：模型 K3 / 权限模式 / 关遥测 ──
$configPath = Join-Path $kimiHome 'config.toml'
New-Item -ItemType Directory -Path $kimiHome -Force | Out-Null
if (-not (Test-Path -LiteralPath $configPath)) {
    [System.IO.File]::WriteAllText($configPath, '', (New-Object System.Text.UTF8Encoding $false))
}
$raw = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)

# default_model 确保
if ($raw -match '(?m)^default_model\s*=') {
    $raw = [regex]::Replace($raw, '(?m)^default_model\s*=.*$', 'default_model = "kimi-code/k3"')
} else {
    $raw = "default_model = `"kimi-code/k3`"" + [Environment]::NewLine + $raw
}

# 移除旧的 default_permission_mode / telemetry 行（避免重复），再统一插入
$raw = [regex]::Replace($raw, '(?m)^default_permission_mode\s*=.*\r?\n', '')
$raw = [regex]::Replace($raw, '(?m)^telemetry\s*=.*\r?\n', '')
$anchor = 'default_model = "kimi-code/k3"'
$extra  = [Environment]::NewLine + ('default_permission_mode = "' + $PermissionMode + '"') + [Environment]::NewLine + 'telemetry = false'
$raw = $raw.Replace($anchor, $anchor + $extra)

[System.IO.File]::WriteAllText($configPath, $raw, (New-Object System.Text.UTF8Encoding $false))
Write-Host "[OK] config.toml 已配置（default_model=kimi-code/k3, permission=$PermissionMode, telemetry=false）" -ForegroundColor Green

# ── 3. PATH 校验（官方 installer 会前置；这里幂等兜底） ──
$binDir = Join-Path $kimiHome 'bin'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -and ($userPath -split ';') -notcontains $binDir) {
    [Environment]::SetEnvironmentVariable('Path', ($binDir + ';' + $userPath), 'User')
    Write-Host "[OK] 已把 $binDir 前置到用户 PATH" -ForegroundColor Green
} else {
    Write-Host '[INFO] kimi bin 已在用户 PATH' -ForegroundColor DarkGray
}
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

# ── 4. 工作区信任：按 workspaces.json 批量写 workspace-trust 标记，跳过 trust 弹窗 ──
# 信任文件格式实测：%USERPROFILE%\.kimi-code\workspace-trust\<workspace_id>
# 内容 {"root":"<绝对路径>","trustedAt":<unix毫秒>}；workspace_id 从 workspaces.json 读，不硬编码
$workspacesPath = Join-Path $kimiHome 'workspaces.json'
$trustDir = Join-Path $kimiHome 'workspace-trust'
if (Test-Path -LiteralPath $workspacesPath) {
    $ws = Get-Content -Raw -LiteralPath $workspacesPath | ConvertFrom-Json
    New-Item -ItemType Directory -Path $trustDir -Force | Out-Null
    $nowMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    foreach ($wsProp in $ws.workspaces.PSObject.Properties) {
        $wsId = $wsProp.Name
        $wsRoot = $wsProp.Value.root
        $trustFile = Join-Path $trustDir $wsId
        $need = $false
        if (Test-Path -LiteralPath $trustFile) {
            $cur = Get-Content -Raw -LiteralPath $trustFile | ConvertFrom-Json
            if ($cur.root -ne $wsRoot) { $need = $true }
        } else {
            $need = $true
        }
        if ($need) {
            $trustObj = [ordered]@{ root = $wsRoot; trustedAt = $nowMs }
            [System.IO.File]::WriteAllText($trustFile, ($trustObj | ConvertTo-Json -Compress), (New-Object System.Text.UTF8Encoding $false))
            Write-Host "[OK] 已标记信任: $wsRoot" -ForegroundColor Green
        } else {
            Write-Host "[INFO] 已信任: $wsRoot" -ForegroundColor DarkGray
        }
    }
} else {
    Write-Host '[WARN] workspaces.json 不存在（kimi 首次启动后自动创建）' -ForegroundColor Yellow
}

# ── 5. 校验 ──
$ver = & $kimiBin --version 2>&1
Write-Host "[OK] kimi 版本: $ver" -ForegroundColor Green
