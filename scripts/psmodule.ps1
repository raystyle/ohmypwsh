#Requires -Version 7.0
# psmodule.ps1 - PowerShell 模块管理器（在线/离线、PS5/PS7）
# 用法: pwsh -NoProfile -File scripts\psmodule.ps1 <command> [<模块>] [options]

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('list', 'pin', 'install', 'update', 'uninstall', 'pack')]
    [string]$Command = 'list',

    [Parameter(Position = 1)]
    [string]$Name,

    [string]$Version,
    [switch]$Latest,         # pin 到最新版：psmodule.ps1 pin <模块> -Latest
    [string]$File,             # 离线 nupkg 路径（install）
    [string]$Out,              # pack 输出目录
    [switch]$Force,
    [switch]$IncludeBreaking
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers.ps1')

$script:ModuleLockPath = Join-Path $PSScriptRoot 'modules.psd1'
$script:EnvRoot        = Get-DefaultEnvRoot
$script:ModuleRoot     = Join-Path $script:EnvRoot 'modules'
$script:ModuleCache    = Join-Path $script:EnvRoot 'cache\modules'
$script:ModuleDocUser  = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules'
$script:ModuleDocUser5 = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Modules'

# ═══════════════════════════════════════════════════════════════════════════
# 锁定清单
# ═══════════════════════════════════════════════════════════════════════════

function Get-ModuleLock {
    if (Test-Path $script:ModuleLockPath) {
        $lock = Import-PowerShellDataFile -Path $script:ModuleLockPath
    } else {
        $lock = @{ ModuleRoot = $script:ModuleRoot; Modules = @{} }
        Save-ModuleLock -Lock $lock
    }
    if (-not $lock.ModuleRoot) { $lock.ModuleRoot = $script:ModuleRoot }
    $lock
}

function Save-ModuleLock {
    param([Parameter(Mandatory)][hashtable]$Lock)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# modules.psd1 - PowerShell 模块锁定清单（由 psmodule.ps1 维护，勿手改）')
    $lines.Add('@{')
    $lines.Add("    ModuleRoot = '$($Lock.ModuleRoot)'")
    $lines.Add('    Modules    = @{')
    foreach ($n in ($Lock.Modules.Keys | Sort-Object)) {
        $m = $Lock.Modules[$n]
        $lines.Add("        '$n' = @{")
        $lines.Add("            Version = '$($m.Version)'")
        $lines.Add("            Source  = '$($m.Source)'")
        $lines.Add("            Package = '$($m.Package)'")
        $lines.Add("            Sha256  = '$($m.Sha256)'")
        $lines.Add("            Target  = '$($m.Target)'")
        $lines.Add('        }')
    }
    $lines.Add('    }')
    $lines.Add('}')
    # 规则 4：modules.psd1 含中文说明，统一 UTF-8 带 BOM（与 env.psd1 一致，防 PS 非 pwsh7 读乱码）
    $lines | Set-Content -Path $script:ModuleLockPath -Encoding utf8BOM
    Write-Host "[OK] 模块锁定清单已写入: $script:ModuleLockPath" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════════════════
# PSModulePath
# ═══════════════════════════════════════════════════════════════════════════

function Add-PSModulePathEntry {
    param([Parameter(Mandatory)][string]$Dir)
    $reg = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
    $user = $reg.GetValue('PSModulePath', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $reg.Close()
    $parts = @(if ($null -ne $user) { $user -split ';' | Where-Object { $_ } })
    # 比较用展开后形式：$parts 存的是未展开（%USERPROFILE%），传入 $Dir 是展开后的字面路径
    $expandedDir = [Environment]::ExpandEnvironmentVariables($Dir)
    $partsExpanded = @($parts | ForEach-Object { [Environment]::ExpandEnvironmentVariables($_) })
    if ($partsExpanded -contains $expandedDir) {
        Write-Host "[INFO] PSModulePath 已存在: $Dir" -ForegroundColor DarkGray
        return
    }
    $new = (@($Dir) + $parts) -join ';'
    Set-UserEnvVar -Name 'PSModulePath' -Value $new
    $env:PSModulePath = "$Dir;$env:PSModulePath"
    Write-Host "[OK] PSModulePath 已注册（前置）: $Dir" -ForegroundColor Green
}

function Remove-PSModulePathEntry {
    param([Parameter(Mandatory)][string]$Dir)
    $reg = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
    $user = $reg.GetValue('PSModulePath', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $reg.Close()
    $expandedDir = [Environment]::ExpandEnvironmentVariables($Dir)
    $parts = @(if ($null -ne $user) { $user -split ';' | Where-Object { $_ } | Where-Object { [Environment]::ExpandEnvironmentVariables($_) -ne $expandedDir } })
    Set-UserEnvVar -Name 'PSModulePath' -Value ($parts -join ';')
    $env:PSModulePath = (($env:PSModulePath -split ';') | Where-Object { $_ -and [Environment]::ExpandEnvironmentVariables($_) -ne $expandedDir }) -join ';'
    Write-Host "[OK] PSModulePath 已移除: $Dir" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════════════════
# 工具函数
# ═══════════════════════════════════════════════════════════════════════════

function Get-TargetRoot {
    param([string]$Target)
    switch ($Target) {
        'PS5' { $script:ModuleDocUser5 }
        'PS7' { $script:ModuleDocUser }
        default { $script:ModuleRoot }
    }
}

function Get-InstalledModuleVersion {
    param([Parameter(Mandatory)][string]$ModuleName, [string]$Target = 'Shared')
    $root = Get-TargetRoot -Target $Target
    $dir = Join-Path $root $ModuleName
    if (-not (Test-Path -LiteralPath $dir)) { return }
    Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue |
        Sort-Object { try { [version]$_.Name } catch { [version]'0.0.0' } } -Descending |
        Select-Object -First 1 -ExpandProperty Name
}

function Resolve-OnlineModuleVersion {
    param([Parameter(Mandatory)][string]$ModuleName, [string]$Version)
    if ($Version) { return $Version }
    $r = Find-PSResource -Name $ModuleName -Repository PSGallery -ErrorAction Stop | Select-Object -First 1
    if (-not $r) { throw "PSGallery 未找到模块: $ModuleName" }
    $r.Version.ToString()
}

function Save-ModulePackage {
    param([Parameter(Mandatory)][string]$ModuleName, [Parameter(Mandatory)][string]$Version)
    New-Item -ItemType Directory -Path $script:ModuleCache -Force | Out-Null
    $pkg = Join-Path $script:ModuleCache "$ModuleName.$Version.nupkg"
    $url = "https://www.powershellgallery.com/api/v2/package/$ModuleName/$Version"
    Save-ReleaseAsset -Url $url -OutFile $pkg
    $sha = (Get-FileHash -LiteralPath $pkg -Algorithm SHA256).Hash
    [pscustomobject]@{ Package = Split-Path -Leaf $pkg; Sha256 = $sha }
}

function Get-NupkgModuleInfo {
    param([Parameter(Mandatory)][string]$Nupkg)
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('psmod-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        Expand-Archive -LiteralPath $Nupkg -DestinationPath $tmp -Force
        $psd1 = Get-ChildItem -LiteralPath $tmp -Filter *.psd1 -File -Depth 1 -ErrorAction SilentlyContinue |
            Where-Object { $_.DirectoryName -eq $tmp } | Select-Object -First 1
        if (-not $psd1) {
            $psd1 = Get-ChildItem -LiteralPath $tmp -Filter *.psd1 -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        }
        if (-not $psd1) { throw "nupkg 内未找到模块清单（*.psd1）: $Nupkg" }
        $data = Import-PowerShellDataFile -LiteralPath $psd1.FullName
        if (-not $data.ModuleVersion) { throw "模块清单缺少 ModuleVersion: $($psd1.FullName)" }
        [pscustomobject]@{
            Name    = $psd1.BaseName
            Version = $data.ModuleVersion.ToString()
        }
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Deploy-NupkgModule {
    param(
        [Parameter(Mandatory)][string]$Nupkg,
        [Parameter(Mandatory)][string]$ModuleName,
        [Parameter(Mandatory)][string]$ModuleVersion,
        [string]$Target = 'Shared'
    )
    $targetRoot = Get-TargetRoot -Target $Target
    $targetDir  = Join-Path $targetRoot "$ModuleName\$ModuleVersion"
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('psmod-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        Expand-Archive -LiteralPath $Nupkg -DestinationPath $tmp -Force
        $contentRoot = $tmp
        $rootPsd1 = Get-ChildItem -LiteralPath $tmp -Filter *.psd1 -File | Select-Object -First 1
        if (-not $rootPsd1) {
            $top = Get-ChildItem -LiteralPath $tmp -Directory | Where-Object { $_.Name -notin @('_rels', 'package') }
            if ($top.Count -eq 1) { $contentRoot = $top[0].FullName }
        }
        if (Test-Path -LiteralPath $targetDir) { Remove-Item -LiteralPath $targetDir -Recurse -Force }
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        Get-ChildItem -LiteralPath $contentRoot -Force | Where-Object {
            $_.Name -notin @('_rels', 'package', '[Content_Types].xml', 'PSGetModuleInfo.xml')
        } | Copy-Item -Destination $targetDir -Recurse -Force
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path -LiteralPath (Join-Path $targetDir "$ModuleName.psd1"))) {
        throw "部署后未找到 $ModuleName.psd1: $targetDir"
    }
    Write-Host "[OK] 已部署: $targetDir" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════════════════
# 命令
# ═══════════════════════════════════════════════════════════════════════════

switch ($Command) {
    'list' {
        $lock = Get-ModuleLock
        Write-Host "模块根: $($lock.ModuleRoot)" -ForegroundColor Cyan
        Write-Host "PSModulePath(user): $([Environment]::GetEnvironmentVariable('PSModulePath', 'User'))" -ForegroundColor DarkGray
        if ($lock.Modules.Count -eq 0) {
            Write-Host '(无托管模块)' -ForegroundColor DarkGray
            break
        }
        foreach ($n in ($lock.Modules.Keys | Sort-Object)) {
            $m = $lock.Modules[$n]
            $ver = Get-InstalledModuleVersion -ModuleName $n -Target $m.Target
            Write-Host "--- $n ---" -ForegroundColor Cyan
            Write-Host "  locked=$($m.Version)  installed=$(if ($ver) { $ver } else { '-' })  target=$($m.Target)  source=$($m.Source)"
            Write-Host "  location = $(Join-Path (Get-TargetRoot -Target $m.Target) $n)"
        }
    }

    'pin' {
        if (-not $Name) { throw 'pin 需要模块名: psmodule.ps1 pin <模块> [-Version X | -Latest]' }
        $lock = Get-ModuleLock
        $m = $lock.Modules[$Name]
        if (-not $Version -and -not $Latest -and -not $m) { throw "模块未锁定：先 -Latest 或 -Version" }
        if ($Latest) {
            $Version = Resolve-OnlineModuleVersion -ModuleName $Name
        } elseif (-not $Version -and $m) {
            Write-Host "当前锁定: $Name $($m.Version)" -ForegroundColor Cyan
            break
        }
        if (-not $lock.Modules.ContainsKey($Name)) { $lock.Modules[$Name] = @{} }
        $lock.Modules[$Name].Version = $Version
        if (-not $lock.Modules[$Name].Source)  { $lock.Modules[$Name].Source  = 'PSGallery' }
        if (-not $lock.Modules[$Name].Target)  { $lock.Modules[$Name].Target  = 'Shared' }
        Save-ModuleLock -Lock $lock
        Write-Host "[OK] $Name 已 pin: $Version" -ForegroundColor Green
    }

    'install' {
        if (-not $Name) { throw 'install 需要模块名: psmodule.ps1 install <模块> [-Version X] [-File <nupkg>]' }
        $lock = Get-ModuleLock
        $m = $lock.Modules[$Name]
        $target = if ($m.Target) { $m.Target } else { 'Shared' }

        if ($File) {
            if (-not (Test-Path -LiteralPath $File)) { throw "离线包不存在: $File" }
            $nupkg = (Resolve-Path -LiteralPath $File).Path
            $info  = Get-NupkgModuleInfo -Nupkg $nupkg
            if ($info.Name -ne $Name) { throw "包内模块名不符: $($info.Name) != $Name" }
            if ($Version -and $info.Version -ne $Version) { throw "包内版本不符: $($info.Version) != $Version" }
            $Version = $info.Version
            $pkgLeaf = Split-Path -Leaf $nupkg
            $sha = (Get-FileHash -LiteralPath $nupkg -Algorithm SHA256).Hash
        } else {
            if (-not $Version -and $m) { $Version = $m.Version }
            $Version = Resolve-OnlineModuleVersion -ModuleName $Name -Version $Version
            $down = Save-ModulePackage -ModuleName $Name -Version $Version
            $nupkg  = Join-Path $script:ModuleCache $down.Package
            $pkgLeaf = $down.Package
            $sha = $down.Sha256
            $info = Get-NupkgModuleInfo -Nupkg $nupkg
            if ($info.Name -ne $Name) { throw "PSGallery 包名不符: $($info.Name) != $Name" }
        }

        Deploy-NupkgModule -Nupkg $nupkg -ModuleName $Name -ModuleVersion $Version -Target $target
        if ($target -eq 'Shared') { Add-PSModulePathEntry -Dir $script:ModuleRoot }
        if (-not $lock.Modules.ContainsKey($Name)) { $lock.Modules[$Name] = @{} }
        $lock.Modules[$Name].Version = $Version
        $lock.Modules[$Name].Source  = if ($File) { 'Local' } else { 'PSGallery' }
        $lock.Modules[$Name].Package = $pkgLeaf
        $lock.Modules[$Name].Sha256  = $sha
        $lock.Modules[$Name].Target  = $target
        Save-ModuleLock -Lock $lock
        Write-Host "[OK] $Name $Version 安装完成（$($lock.Modules[$Name].Source)）" -ForegroundColor Green
    }

    'update' {
        $lock = Get-ModuleLock
        $names = if ($Name -and $Name -ne 'all') { @($Name) } else { @($lock.Modules.Keys | Sort-Object) }
        if ($names.Count -eq 0) { Write-Host '(无托管模块)' -ForegroundColor DarkGray; break }
        foreach ($n in $names) {
            if (-not $lock.Modules.ContainsKey($n)) { throw "未托管模块: $n" }
            $cur = $lock.Modules[$n].Version
            $latest = Resolve-OnlineModuleVersion -ModuleName $n
            if ($latest -eq $cur) { Write-Host "[跳过] ${n}: $cur 已是最新" -ForegroundColor DarkGray; continue }
            $sameMajor = (($cur -split '\.')[0]) -eq (($latest -split '\.')[0])
            if (-not $sameMajor -and -not $IncludeBreaking) {
                Write-Host "[保留] ${n}: $cur -> $latest（跨主版本，需 -IncludeBreaking）" -ForegroundColor Yellow
                continue
            }
            Write-Host "[更新] ${n}: $cur -> $latest" -ForegroundColor Green
            $down = Save-ModulePackage -ModuleName $n -Version $latest
            $nupkg = Join-Path $script:ModuleCache $down.Package
            $info  = Get-NupkgModuleInfo -Nupkg $nupkg
            $target = if ($lock.Modules[$n].Target) { $lock.Modules[$n].Target } else { 'Shared' }
            Deploy-NupkgModule -Nupkg $nupkg -ModuleName $n -ModuleVersion $latest -Target $target
            if ($target -eq 'Shared') { Add-PSModulePathEntry -Dir $script:ModuleRoot }
            $lock.Modules[$n].Version = $latest
            $lock.Modules[$n].Package = $down.Package
            $lock.Modules[$n].Sha256  = $down.Sha256
            Save-ModuleLock -Lock $lock
        }
    }

    'uninstall' {
        if (-not $Name) { throw 'uninstall 需要模块名' }
        $lock = Get-ModuleLock
        if (-not $lock.Modules.ContainsKey($Name)) { throw "未托管模块: $Name" }
        $m = $lock.Modules[$Name]
        $root = Get-TargetRoot -Target $m.Target
        $dir = Join-Path $root $Name
        if (Test-Path -LiteralPath $dir) {
            Remove-Item -LiteralPath $dir -Recurse -Force
            Write-Host "[OK] 已删除: $dir" -ForegroundColor Green
        }
        $lock.Modules.Remove($Name)
        Save-ModuleLock -Lock $lock
        if ($m.Target -eq 'Shared' -and $lock.Modules.Values.Target -notcontains 'Shared') {
            Remove-PSModulePathEntry -Dir $script:ModuleRoot
        }
        Write-Host "[OK] $Name 已卸载" -ForegroundColor Green
    }

    'pack' {
        if (-not $Name) { throw 'pack 需要源目录: psmodule.ps1 pack <模块目录> [-Version X] [-Out <目录>]' }
        if (-not (Test-Path -LiteralPath $Name)) { throw "源目录不存在: $Name" }
        $outDir = if ($Out) { $Out } else { $script:ModuleCache }
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        $srcDir = (Resolve-Path -LiteralPath $Name).Path
        if ($Version) {
            # Compress-PSResource 版本取自 manifest，-Version 仅做一致性校验
            $srcName = Split-Path $srcDir -Leaf
            $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $srcDir "$srcName.psd1")
            if ($manifest.ModuleVersion.ToString() -ne $Version) {
                throw "manifest ModuleVersion ($($manifest.ModuleVersion)) 与 -Version ($Version) 不一致"
            }
        }
        $pArgs = @{ Path = $srcDir; DestinationPath = $outDir }
        Compress-PSResource @pArgs -ErrorAction Stop
        $nupkg = Get-ChildItem -LiteralPath $outDir -Filter '*.nupkg' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $nupkg) { throw 'pack 未产出 nupkg' }
        Write-Host "[OK] 已打包: $($nupkg.FullName)" -ForegroundColor Green
    }

    default { throw "未知命令: $Command" }
}
