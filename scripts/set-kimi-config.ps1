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
# 2026-08-21 改造：上/升级改为「GitHub 直下 win32-x64.zip + 官方 sha256 校验 + 替换 kimi.exe」，
# 替代 fragil 的 `kimi upgrade`（联网查更新无重试、网络抖动即失败）。与 WSL 侧 kimi 同源同校验。
function Install-KimiBinary {
    param([string]$TargetVersion)
    Write-Host '[INFO] 下载 kimi-code win32-x64 并替换 kimi.exe ...' -ForegroundColor Cyan
    # 复用 helpers.ps1 的 GitHub 查询与下载/校验
    $repo = 'MoonshotAI/kimi-code'
    $release = if ($TargetVersion) {
        Get-GitHubRelease -Repo $repo -Tag "@moonshot-ai/kimi-code@$TargetVersion"
    } else {
        Get-GitHubRelease -Repo $repo -Latest
    }
    $asset = Find-ReleaseAsset -Release $release -Pattern '^kimi-code-win32-x64\.zip$'
    $tag = $release.tag_name
    $ver = $tag -replace '^@moonshot-ai/kimi-code@', ''
    $cachePath = Join-Path (Join-Path (Get-DefaultEnvRoot) 'cache') $asset.name
    # 官方 sha256：逐资产 .sha256
    $shaUrl = ($asset.browser_download_url + '.sha256')
    $shaText = (Invoke-RestMethod -Uri $shaUrl -TimeoutSec 30 -UseBasicParsing).Trim()
    $expectedSha = $null
    if ($shaText -match '([0-9a-fA-F]{64})') { $expectedSha = $Matches[1].ToUpperInvariant() }
    Save-ReleaseAsset -Url $asset.browser_download_url -OutFile $cachePath -ExpectedSha256 $expectedSha -Force
    if ($expectedSha) { Assert-Sha256 -File $cachePath -Expected $expectedSha }

    # 解出 kimi.exe 替换（保留用户数据：config.toml / fd.exe / workspaces 等均不动）
    $tmpZip = Join-Path $env:TEMP ("kimi-win32-" + [guid]::NewGuid().ToString('N').Substring(0,8) + '.zip')
    Copy-Item -LiteralPath $cachePath -Destination $tmpZip -Force
    $tmpDir = Join-Path $env:TEMP ("kimi-extract-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    try {
        Expand-Archive -LiteralPath $tmpZip -DestinationPath $tmpDir -Force
        $newExe = Join-Path $tmpDir 'kimi.exe'
        if (-not (Test-Path -LiteralPath $newExe)) { throw '解压后未找到 kimi.exe' }
        # kimi.exe 可能被运行中会话占用：先尝试停掉本用户 kimi 进程（无感无痛）
        Get-Process -Name kimi -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        $kimiBinDir = Split-Path $kimiBin -Parent
        New-Item -ItemType Directory -Path $kimiBinDir -Force | Out-Null
        Copy-Item -LiteralPath $newExe -Destination $kimiBin -Force
        Write-Host "[OK] kimi 已更新: $((& $kimiBin --version 2>&1 | Select-Object -First 1))" -ForegroundColor Green
    } finally {
        Remove-Item -LiteralPath $tmpZip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($Update -and (Test-Path -LiteralPath $kimiBin)) {
    Install-KimiBinary -TargetVersion $Version
} elseif (-not (Test-Path -LiteralPath $kimiBin)) {
    # 全新安装也走 GitHub 直下（比官方 install.ps1 更可控：有 sha256 校验 + 重试）
    Write-Host '[INFO] 全新安装 kimi-code（GitHub 直下 0.38.0）...' -ForegroundColor Cyan
    Install-KimiBinary -TargetVersion $Version
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
