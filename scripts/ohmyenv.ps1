#Requires -Version 7.0
# ohmyenv.ps1 - 环境依赖管理 CLI（gh / git）
# 用法: pwsh -File scripts\ohmyenv.ps1 <command> [gh|git|all] [options]

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('query', 'deploy', 'install', 'update', 'lock', 'status', 'help')]
    [string]$Command = 'help',

    [Parameter(Position = 1)]
    [ValidateSet('gh', 'git', 'all')]
    [string]$Tool = 'all',

    [switch]$Latest,
    [string]$Tag,
    [string]$Version,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers.ps1')

$lock  = Get-EnvLock
$tools = if ($Tool -eq 'all') { @('gh', 'git') } else { @($Tool) }

function Show-Help {
    @'
ohmyenv - 环境依赖管理 CLI（gh / git）

用法:
  ohmyenv.ps1 query   [gh|git|all] [-Latest | -Tag <tag> | -Version <ver>]
  ohmyenv.ps1 install [gh|git|all] [同上下载源选项]   # 仅装入环境目录，不改 PATH
  ohmyenv.ps1 deploy  [gh|git|all] [同上下载源选项]   # 安装 + 注册用户 PATH（默认锁定版本）
  ohmyenv.ps1 update  [gh|git|all]                   # 更新到最新版并锁定
  ohmyenv.ps1 lock    [gh|git|all] [-Latest | -Version <ver>]   # 查看 / 设置锁定版本
  ohmyenv.ps1 status                                 # 锁定 vs 已安装 vs PATH
  ohmyenv.ps1 help

示例:
  ohmyenv.ps1 query gh -Latest
  ohmyenv.ps1 install git
  ohmyenv.ps1 deploy gh -Version 2.92.0
  ohmyenv.ps1 update
  ohmyenv.ps1 lock git -Latest

说明:
  - 全部查询/下载走 api.github.com + 直连 URL（bootstrap 不依赖已装 gh）
  - 环境根目录与锁定版本见 scripts\env.psd1
'@
}

switch ($Command) {
    'query' {
        foreach ($t in $tools) {
            $r = Resolve-ToolVersion -Lock $lock -Tool $t -Latest:$Latest -Tag $Tag -Version $Version
            Write-Host "===== $($r.Tool) ($($r.Tag)) =====" -ForegroundColor Cyan
            "  asset : $($r.AssetName)"
            "  size  : {0:N0} B ({1:N1} MB)" -f $r.AssetSize, ($r.AssetSize / 1MB)
            "  url   : $($r.AssetUrl)"
        }
    }

    'install' {
        foreach ($t in $tools) {
            $r = Resolve-ToolVersion -Lock $lock -Tool $t -Latest:$Latest -Tag $Tag -Version $Version
            Install-ToolVersion -Lock $lock -Resolution $r -Force:$Force
        }
    }

    'deploy' {
        foreach ($t in $tools) {
            $r = Resolve-ToolVersion -Lock $lock -Tool $t -Latest:$Latest -Tag $Tag -Version $Version
            Install-ToolVersion -Lock $lock -Resolution $r -RegisterPath -Force:$Force
        }
        if (-not $Latest -and -not $Tag -and -not $Version) {
            Write-Host "[HINT] 已按锁定版本部署；如需升级到最新并锁定: ohmyenv update" -ForegroundColor DarkGray
        }
    }

    'update' {
        foreach ($t in $tools) {
            $r = Resolve-ToolVersion -Lock $lock -Tool $t -Latest
            if ($r.Tag -eq $lock.Tools[$t].Tag) {
                Write-Host "[INFO] $t 已是最新: $($lock.Tools[$t].Version)" -ForegroundColor DarkGray
                continue
            }
            Install-ToolVersion -Lock $lock -Resolution $r -RegisterPath -UpdateLock -Force:$Force
        }
    }

    'lock' {
        if (-not $Latest -and -not $Tag -and -not $Version) {
            Write-Host "当前锁定版本:" -ForegroundColor Cyan
            foreach ($t in $tools) {
                $d = $lock.Tools[$t]
                $sha = if ($d.Sha256) { $d.Sha256.Substring(0, [math]::Min(16, $d.Sha256.Length)) + '...' } else { '(未回填)' }
                "  $t : $($d.Version) ($($d.Tag))  sha256=$sha"
            }
        } else {
            foreach ($t in $tools) {
                $r = Resolve-ToolVersion -Lock $lock -Tool $t -Latest:$Latest -Tag $Tag -Version $Version
                $d = $lock.Tools[$t]
                $d.Tag     = $r.Tag
                $d.Version = $r.Version
                $d.Asset   = $r.AssetName
                $d.Sha256  = ''
                Save-EnvLock -Lock $lock
                Write-Host "[OK] $t 已锁定: $($d.Version)（sha256 将在下次 install/deploy 时回填）" -ForegroundColor Green
            }
        }
    }

    'status' {
        Write-Host "环境根目录: $($lock.EnvRoot)" -ForegroundColor Cyan
        foreach ($t in 'gh', 'git') {
            $d = $lock.Tools[$t]
            $exePath = Join-Path $lock.EnvRoot $d.Exe
            $bin     = Join-Path $lock.EnvRoot $d.Bin
            $installed = Get-InstalledVersion -ExePath $exePath -Tool $t
            $inPath = ([Environment]::GetEnvironmentVariable('Path', 'User') -split ';') -contains $bin
            "  $t : locked=$($d.Version)  installed=$(if ($installed) { $installed } else { '-' })  path=$inPath"
            "       exe = $exePath"
        }
    }

    default { Show-Help }
}
