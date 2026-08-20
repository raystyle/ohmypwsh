#Requires -Version 7.0
# omp.psm1 - Agent 环境部署与管理模块 CLI（PowerShell 7 命令 omp）

. (Join-Path $PSScriptRoot 'helpers.ps1')

function Invoke-Omp {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('query', 'deploy', 'install', 'update', 'pin', 'lock', 'status', 'daily', 'pack', 'unpack', 'help')]
        [string]$Command = 'help',

        [Parameter(Position = 1)]
        [string]$Tool = 'all',

        [switch]$Latest,
        [string]$Tag,
        [string]$Version,
        [string]$Zip,
        [string]$EnvRoot,
        [switch]$Force,
        [switch]$DryRun,
        [switch]$IncludeBreaking
    )

    $ErrorActionPreference = 'Stop'
    $lock  = Get-EnvLock -EnvRoot $EnvRoot
    $tools = if ($Tool -eq 'all') { @($script:ToolNames) } else { @($Tool) }

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
                Write-Host '[HINT] 已按锁定版本部署；升级: omp update' -ForegroundColor DarkGray
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
        { $_ -in @('pin', 'lock') } {
            if (-not $Latest -and -not $Tag -and -not $Version) {
                Write-Host '当前 pin 版本:' -ForegroundColor Cyan
                foreach ($t in $tools) {
                    $d = $lock.Tools[$t]
                    if (-not $d.Tag) {
                        Write-Host "[INFO] $t 未 pin，自动 pin 最新版" -ForegroundColor Yellow
                        $r = Resolve-ToolVersion -Lock $lock -Tool $t -Latest
                        Set-ToolPin -Lock $lock -Resolution $r
                        continue
                    }
                    $sha = if ($d.Sha256) { $d.Sha256.Substring(0, [math]::Min(16, $d.Sha256.Length)) + '...' } else { '(未回填)' }
                    "  $t : $($d.Version) ($($d.Tag))  sha256=$sha"
                }
            } else {
                foreach ($t in $tools) {
                    $r = Resolve-ToolVersion -Lock $lock -Tool $t -Latest:$Latest -Tag $Tag -Version $Version
                    Set-ToolPin -Lock $lock -Resolution $r
                }
            }
        }
        'status' {
            Write-Host "环境根目录: $($lock.EnvRoot)" -ForegroundColor Cyan
            $lastTier = ''
            $lastCat = ''
            foreach ($t in $script:ToolNames) {
                $d = $lock.Tools[$t]
                $cat = $d.Category
                $tier = if ($cat -eq 'extras') { '扩展工具' } else { '核心基础工具' }
                if ($tier -ne $lastTier) {
                    Write-Host "[$tier]" -ForegroundColor Cyan
                    $lastTier = $tier
                    $lastCat = ''
                }
                if ($tier -eq '核心基础工具' -and $cat -ne $lastCat) {
                    Write-Host "  [$($script:ToolCategories[$cat])]" -ForegroundColor Yellow
                    $lastCat = $cat
                }
                $isMsi   = ($d.Extract -eq 'msi')
                $exePath = if ($isMsi) { [Environment]::ExpandEnvironmentVariables($d.Exe) } else { Join-Path $lock.EnvRoot $d.Exe }
                $bin     = if ($d.Bin) { Join-Path $lock.EnvRoot $d.Bin } else { '' }
                $installed = Get-InstalledVersion -ExePath $exePath -Tool $t
                $inPath = if ($d.Bin) { ([Environment]::GetEnvironmentVariable('Path', 'User') -split ';') -contains $bin } else { $false }
                "  $t : locked=$($d.Version)  installed=$(if ($installed) { $installed } else { '-' })  path=$inPath"
                "       exe = $exePath"
            }
        }
        'daily' {
            $envRoot = $lock.EnvRoot
            $logDir  = Join-Path $envRoot 'logs'
            $logFile = Join-Path $logDir 'update-daily.log'
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            $stamp  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $report = New-Object System.Collections.Generic.List[string]
            $report.Add("===== 日常更新检查 $stamp =====")
            $updated = 0; $held = 0; $fresh = 0
            foreach ($t in $script:ToolNames) {
                $d = $lock.Tools[$t]
                $r = Resolve-ToolVersion -Lock $lock -Tool $t -Latest
                if ($r.Version -eq $d.Version) {
                    Write-Host "[跳过] ${t}: $($d.Version) 已是最新" -ForegroundColor DarkGray
                    $report.Add("[跳过] ${t}: $($d.Version) 已是最新")
                    $fresh++
                    continue
                }
                $sameMajor = (($d.Version -split '\.')[0]) -eq (($r.Version -split '\.')[0])
                if ($IncludeBreaking -or $sameMajor) {
                    $action = if ($DryRun) { '预览' } else { '更新' }
                    $color  = if ($DryRun) { 'Cyan' } else { 'Green' }
                    Write-Host "[$action] ${t}: $($d.Version) -> $($r.Version)（同主版本，无影响）" -ForegroundColor $color
                    $report.Add("[$action] ${t}: $($d.Version) -> $($r.Version)（同主版本）")
                    if (-not $DryRun) { Install-ToolVersion -Lock $lock -Resolution $r -RegisterPath -UpdateLock }
                    $updated++
                } else {
                    Write-Host "[保留] ${t}: $($d.Version) -> $($r.Version)（跨主版本，需人工确认；-IncludeBreaking 强制更新）" -ForegroundColor Yellow
                    $report.Add("[保留] ${t}: $($d.Version) -> $($r.Version)（跨主版本，需人工确认）")
                    $held++
                }
            }
            $summary = "===== 汇总: $(if ($DryRun) { '预览' } else { '更新' }) $updated | 保留 $held | 已最新 $fresh ====="
            Write-Host $summary
            $report.Add($summary)
            $report | Add-Content -Path $logFile -Encoding utf8
            Write-Host "[LOG] $logFile" -ForegroundColor DarkGray
            if ($held -gt 0) { return 2 }
        }
        'pack' { Invoke-EnvPack -Lock $lock }
        'unpack' {
            $zip = $Zip
            if (-not $zip) {
                $deployDir = Join-Path $lock.EnvRoot 'deploy'
                $zip = Get-ChildItem -LiteralPath $deployDir -Filter 'ohmyenv-deploy-*.zip' -ErrorAction SilentlyContinue |
                       Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
                if (-not $zip) { throw '未找到部署包，先运行: omp pack' }
            }
            Invoke-EnvUnpack -Lock $lock -ZipPath $zip
        }
        'help' {
            @'
omp - Agent 环境部署与管理模块 CLI

用法:
  omp query   [tool|all] [-Latest | -Tag <tag> | -Version <ver>]
  omp install [tool|all] [同上下载源选项]
  omp deploy  [tool|all] [同上下载源选项]
  omp update  [tool|all]
  omp pin     [tool|all] [-Latest | -Version <ver>]
  omp status
  omp daily   [-DryRun] [-IncludeBreaking]
  omp pack
  omp unpack [-Zip <部署包.zip>]
  omp help

工具: pwsh / gh / git / age / sops / codex / aria2 / 7z / gsudo / dotnet / fnm / bun / uv / python / rg / jq / yq / rmux / starship（all = 全部）
'@
        }
        default {
            Write-Host "[WARN] 未知命令: $Command（omp help 查看用法）" -ForegroundColor Yellow
        }
    }
}

Set-Alias -Name omp -Value Invoke-Omp -Scope Global
Export-ModuleMember -Function Invoke-Omp -Alias omp
