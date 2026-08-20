#Requires -Version 7.0
# set-fnm-config.ps1 - Node.js/fnm 接管配置（FNM_DIR / 镜像 / PATH / profile / npm registry，幂等）
# 用法: pwsh -NoProfile -File scripts\set-fnm-config.ps1
# 前置: 先 `ohmyenv.ps1 deploy fnm`（fnm 本体 + 注册 PATH）

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers.ps1')   # 重建 PATH（注册表权威）+ Get-DefaultEnvRoot

$envRoot    = Get-DefaultEnvRoot
$fnmBin     = Join-Path $envRoot 'fnm'
$fnmExe     = Join-Path $fnmBin 'fnm.exe'
$fnmDataDir = Join-Path $envRoot 'fnm-data'
$nodeMirror = 'https://npmmirror.com/mirrors/node'
$registry   = 'https://registry.npmmirror.com'

if (-not (Test-Path -LiteralPath $fnmExe)) {
    throw "未找到 fnm: $fnmExe`n请先运行: pwsh -NoProfile -File scripts\ohmyenv.ps1 deploy fnm"
}

# ── 1. 用户环境变量：FNM_DIR / FNM_NODE_DIST_MIRROR（幂等）──
foreach ($pair in @(
    @('FNM_DIR', $fnmDataDir),
    @('FNM_NODE_DIST_MIRROR', $nodeMirror)
)) {
    $name = $pair[0]; $val = $pair[1]
    if ([Environment]::GetEnvironmentVariable($name, 'User') -ne $val) {
        [Environment]::SetEnvironmentVariable($name, $val, 'User')
        Set-Item "Env:$name" $val
        Write-Host "[OK] $name = $val" -ForegroundColor Green
    } else {
        Set-Item "Env:$name" $val
        Write-Host "[INFO] $name 已设置" -ForegroundColor DarkGray
    }
}

# ── 2. 用户 PATH 前置 fnm 本体目录（node/npm 由 fnm env 动态注入，不写死 symlink）──
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$parts = $userPath -split ';' | Where-Object { $_ }
if ($parts -notcontains $fnmBin) {
    [Environment]::SetEnvironmentVariable('Path', (@($fnmBin) + $parts) -join ';', 'User')
    $env:Path = "$fnmBin;$env:Path"
    Write-Host "[OK] PATH 已前置 $fnmBin" -ForegroundColor Green
} else {
    Write-Host "[INFO] fnm 已在 PATH" -ForegroundColor DarkGray
}

# ── 3. npm registry（幂等写用户 .npmrc）──
$npmrc = Join-Path $env:USERPROFILE '.npmrc'
$regLine = "registry=$registry"
$needWrite = $false
if (Test-Path -LiteralPath $npmrc) {
    $cur = [System.IO.File]::ReadAllText($npmrc)
    if ($cur -notmatch '(?m)^registry\s*=') { $needWrite = $true }
    elseif ($cur -notmatch [regex]::Escape($registry)) { $needWrite = $true }
} else {
    $needWrite = $true
}
if ($needWrite) {
    $out = if (Test-Path -LiteralPath $npmrc) {
        ([System.IO.File]::ReadAllLines($npmrc) | Where-Object { $_ -notmatch '^registry\s*=' }) -join "`r`n"
    } else { '' }
    $out = ($out.TrimEnd() + "`r`n$regLine`r`n")
    [System.IO.File]::WriteAllText($npmrc, $out, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "[OK] npm registry 已配置: $registry" -ForegroundColor Green
} else {
    Write-Host '[INFO] npm registry 已配置' -ForegroundColor DarkGray
}

# ── 4. profile 初始化（PS7 + PS5，幂等；只追加 fnm 块，保留 Starship）──
function Set-FnmProfileBlock {
    param([Parameter(Mandatory)][string]$Path)
    $mark  = 'ohmypwsh: fnm'
    $start = "# BEGIN $mark"
    $end   = "# END $mark"
    $line1 = 'if (Get-Command fnm -ErrorAction SilentlyContinue) {'
    $line2 = '    fnm env --use-on-cd --version-file-strategy=recursive --shell powershell | Out-String | Invoke-Expression'
    $line3 = '}'
    $block = "$start`r`n$line1`r`n$line2`r`n$line3`r`n$end"

    $dir = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $existing = if (Test-Path -LiteralPath $Path) { [System.IO.File]::ReadAllText($Path) } else { '' }

    # 去掉旧的 fnm 块（若存在）
    $pattern = '(?m)^[ \t]*' + [regex]::Escape($start) + '[\s\S]*?' + [regex]::Escape($end) + '[ \t]*(?:\r?\n)?'
    $without = [regex]::Replace($existing, $pattern, '')

    $sep = if ($without.Trim().Length -gt 0) { "`r`n`r`n" } else { '' }
    $result = $without.TrimEnd("`r", "`n") + $sep + $block + "`r`n"
    if ($result -ne $existing) {
        [System.IO.File]::WriteAllText($Path, $result, (New-Object System.Text.UTF8Encoding $false))
        Write-Host "[OK] profile 已更新: $Path" -ForegroundColor Green
    } else {
        Write-Host "[INFO] profile 已是最新: $Path" -ForegroundColor DarkGray
    }
}

Set-FnmProfileBlock -Path (Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1')
Set-FnmProfileBlock -Path (Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1')

# ── 5. 安装 node LTS（幂等）并确保默认版本 ──
$list = (& $fnmExe list 2>&1 | Out-String)
if ($list -notmatch 'v\d+\.\d+\.\d+') {
    Write-Host '[INFO] 未检测到已安装 node，执行 fnm install --lts ...' -ForegroundColor Cyan
    & $fnmExe install --lts
    if ($LASTEXITCODE -ne 0) { throw 'fnm install --lts 失败' }
    $list = (& $fnmExe list 2>&1 | Out-String)
    Write-Host "[OK] node LTS 已安装" -ForegroundColor Green
} else {
    Write-Host '[INFO] 已有 node 版本，跳过 install --lts' -ForegroundColor DarkGray
}

$defaultVer = (& $fnmExe default 2>&1 | Out-String).Trim()
if ((-not $defaultVer) -or ($defaultVer -match 'error|Can''t')) {
    if ($list -match 'v(\d+\.\d+\.\d+)') {
        & $fnmExe default $Matches[1]
        if ($LASTEXITCODE -ne 0) { throw "fnm default $($Matches[1]) 失败" }
        Write-Host "[OK] 默认 node 版本已设置: $($Matches[1])" -ForegroundColor Green
    }
} else {
    Write-Host "[INFO] 默认 node 版本: $defaultVer" -ForegroundColor DarkGray
}

Write-Host '[完成] fnm 接管就绪。新终端或 `. $PROFILE` 后可用 node / npm。' -ForegroundColor Cyan
