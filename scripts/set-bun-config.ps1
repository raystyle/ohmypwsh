#Requires -Version 7.0
# set-bun-config.ps1 - bun 镜像源配置（全局 ~/.bunfig.toml + 局部项目 bunfig.toml，幂等）
# 用法: pwsh -NoProfile -File scripts\set-bun-config.ps1
# 前置: 先 `ohmyenv.ps1 deploy bun`

$ErrorActionPreference = 'Stop'

$registry = 'https://registry.npmmirror.com'
$template = "[install]`r`nregistry = `"$registry`"`r`n"

function Set-BunfigRegistry {
    param([Parameter(Mandatory)][string]$Path)

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $cur = if (Test-Path -LiteralPath $Path) { [System.IO.File]::ReadAllText($Path) } else { '' }
    $norm = $cur -replace "`r`n", "`n"

    if ($norm -match [regex]::Escape($registry)) {
        # 已包含目标 registry；仅当缺少 [install] 头时才补头，否则视为已就绪
        if ($norm -match '(?m)^\s*\[install\]\s*$') {
            Write-Host "[INFO] 已配置 registry: $Path" -ForegroundColor DarkGray
            return
        }
    }

    # 按行处理：去掉旧 registry 行，保证 [install] 头存在，并在其后插入 registry
    $lines = New-Object System.Collections.Generic.List[string]
    $installIndex = -1
    $rawLines = if ($norm.Trim()) { $norm -split "`n" } else { @() }
    for ($i = 0; $i -lt $rawLines.Count; $i++) {
        $raw = $rawLines[$i]
        if ($raw.Trim() -eq '[install]') { $installIndex = $lines.Count }
        if ($raw.Trim() -match '^registry\s*=') { continue }
        $lines.Add($raw)
    }

    if ($installIndex -lt 0) {
        $installIndex = $lines.Count
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim() -ne '') { $lines.Add('') }
        $lines.Add('[install]')
    }

    $lines.Insert($installIndex + 1, "registry = `"$registry`"")

    $result = ($lines -join "`r`n").TrimEnd("`r", "`n") + "`r`n"
    if ($result -ne $cur) {
        [System.IO.File]::WriteAllText($Path, $result, (New-Object System.Text.UTF8Encoding $false))
        Write-Host "[OK] registry 已写入: $Path" -ForegroundColor Green
    } else {
        Write-Host "[INFO] registry 已是最新: $Path" -ForegroundColor DarkGray
    }
}

# 1. 全局配置（对所有项目生效）
Set-BunfigRegistry -Path (Join-Path $env:USERPROFILE '.bunfig.toml')

# 2. 局部配置（当前项目根，与 package.json 同级）
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-BunfigRegistry -Path (Join-Path $projectRoot 'bunfig.toml')

Write-Host '[完成] bun 镜像源已配置（npmmirror）。' -ForegroundColor Cyan
