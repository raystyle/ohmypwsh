#Requires -Version 7.0
# set-vsbuild.ps1 - VS Build Tools 接管（VCTools + x86/x64 + Win11SDK + CMake，幂等）
# 参考 D:\hyper-v-lab 的 reverse-engineering-toolchain.md「3) VS Build Tools」。
# 用法: pwsh -NoProfile -File scripts\set-vsbuild.ps1
# 说明: VS Build Tools 需管理员安装；脚本会自动提权重启一次，日志写到 D:\ohmyenv\logs\vsbuild-install.log

param([string]$Layout = '')

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'helpers.ps1')

$envRoot     = Get-DefaultEnvRoot
$installPath = Join-Path $envRoot 'vsbuild'
$bsExe       = Join-Path $envRoot 'cache\vs_buildtools.exe'
$bsUrl       = 'https://aka.ms/vs/17/release/vs_buildtools.exe'
$setupExe    = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe"
$logFile     = Join-Path $envRoot 'logs\vsbuild-install.log'
New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null

function Write-Log([string]$m) {
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $m"
    Add-Content -LiteralPath $logFile -Value $line -Encoding utf8
    Write-Host $line
}

$components = @(
    '--add', 'Microsoft.VisualStudio.Workload.VCTools',
    '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
    '--add', 'Microsoft.VisualStudio.Component.Windows11SDK.26100',
    '--add', 'Microsoft.VisualStudio.Component.VC.CMake.Project',
    '--includeRecommended'
)

$layoutCandidates = @()
if ($Layout) { $layoutCandidates += $Layout }
$layoutCandidates += (Join-Path $envRoot 'cache\vsbuild\VSLayout')
$layoutDir = $layoutCandidates | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'vs_setup.exe')) } | Select-Object -First 1

# ── 1. 提权 ──
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host '[INFO] 需要管理员权限，正在提权重启本脚本...' -ForegroundColor Cyan
    $p = Start-Process (Get-Command pwsh).Source -Verb RunAs -Wait -PassThru -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath
    )
    if ($p.ExitCode -ne 0) {
        if (Test-Path -LiteralPath $logFile) { Get-Content -LiteralPath $logFile | Select-Object -Last 30 | ForEach-Object { Write-Host $_ } }
        throw "提权安装失败 exit=$($p.ExitCode)（详见 $logFile）"
    }
    if (Test-Path -LiteralPath $logFile) { Get-Content -LiteralPath $logFile | ForEach-Object { Write-Host $_ } }
    return
}

try {
    Write-Log '开始 VS Build Tools 接管检查'

    # ── 2. 已安装则跳过 ──
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $installedPath = if (Test-Path $vswhere) { (& $vswhere -products * -property installationPath 2>$null | Select-Object -First 1) } else { '' }
    $cl = Get-ChildItem (Join-Path $installPath 'VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe') -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($installedPath -and $cl -and $installedPath.TrimEnd('\') -eq $installPath.TrimEnd('\')) {
        Write-Log '[INFO] VS Build Tools 已安装到目标路径，跳过安装'
    } else {
        Write-Log "[INFO] 安装 VS Build Tools -> $installPath（组件 VCTools/x86.x64/Win11SDK/CMake）"
        if ($layoutDir) {
            Write-Log "[INFO] 使用离线布局: $layoutDir"
            Get-ChildItem (Join-Path $layoutDir 'certificates') -Filter '*.cer' -ErrorAction SilentlyContinue |
                ForEach-Object { Import-Certificate -FilePath $_.FullName -CertStoreLocation 'Cert:\LocalMachine\Root' | Out-Null }
            $layoutBs = Join-Path $layoutDir 'vs_buildtools.exe'
            $args = @('--noWeb', '--quiet', '--norestart', '--wait', '--installPath', $installPath) + $components
            $p = Start-Process -FilePath $layoutBs -ArgumentList $args -Wait -PassThru
        } else {
            Write-Log '[INFO] 未发现离线布局，走在线安装'
            if (-not (Test-Path -LiteralPath $bsExe)) {
                Write-Log '[INFO] 下载 VS Build Tools 引导器...'
                Invoke-WebRequest -Uri $bsUrl -OutFile $bsExe -UseBasicParsing -TimeoutSec 600
            }
            if (Test-Path -LiteralPath $setupExe) {
                Write-Log "[INFO] 使用现有 VS Installer: $setupExe"
                $args = @('install', '--productId', 'Microsoft.VisualStudio.Product.BuildTools', '--quiet', '--norestart', '--installPath', $installPath) + $components
                $p = Start-Process -FilePath $setupExe -ArgumentList $args -Wait -PassThru
            } else {
                $args = @('--quiet', '--norestart', '--wait', '--installPath', $installPath) + $components
                $p = Start-Process -FilePath $bsExe -ArgumentList $args -Wait -PassThru
            }
        }
        Write-Log "[INFO] 安装进程退出码: $($p.ExitCode)"
        if ($p.ExitCode -notin @(0, 3010)) { throw "VS Build Tools 安装失败 exit=$($p.ExitCode)" }
    }

    # ── 5. PATH（机器级：MSBuild + cl.exe）──
    $msbuild = Join-Path $installPath 'MSBuild\Current\Bin'
    $clDir = (Get-ChildItem (Join-Path $installPath 'VC\Tools\MSVC\*\bin\Hostx64\x64') -Directory -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1).FullName
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    foreach ($d in @($msbuild, $clDir)) {
        if ($d -and $machine -notlike "*$d*") { $machine += ";$d" }
    }
    [Environment]::SetEnvironmentVariable('Path', $machine, 'Machine')
    Write-Log '[INFO] MSBuild/cl 路径已合并到机器 PATH'

    # ── 6. 校验 ──
    $verifyPath = (& $vswhere -products * -property installationPath 2>$null | Select-Object -First 1)
    $verifyCl = Get-ChildItem (Join-Path $installPath 'VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe') -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($verifyPath -and $verifyCl) {
        Write-Log "[OK] VS Build Tools 已就绪: $verifyPath"
        Write-Log "[OK] cl.exe: $($verifyCl.FullName)"
    } else {
        throw 'VS Build Tools 校验失败（vswhere/cl.exe 未找到）'
    }
    Write-Log '[完成] VS Build Tools 接管就绪。新终端可用 MSBuild / cl.exe。'
}
catch {
    Write-Log "[ERROR] $($_.Exception.Message)"
    throw
}
