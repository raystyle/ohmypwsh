#Requires -Version 7.0
# set-agent-secret-guard.ps1 - Agent 密钥泄露防护 hook（Claude Code + Codex CLI，幂等合并）
# 用法: pwsh -NoProfile -File scripts\set-agent-secret-guard.ps1
# 说明: 部署 secret-guard.py 到 ~/.claude/hooks 与 ~/.codex/hooks，并合并 hooks 配置（保留已有 hooks）。

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers.ps1')

$envRoot = Get-DefaultEnvRoot
$python  = Join-Path $envRoot 'python\python.exe'
$srcHook = Join-Path $PSScriptRoot 'hooks\secret-guard.py'

if (-not (Test-Path -LiteralPath $python)) {
    throw "未找到 python: $python（先 ohmyenv deploy python）"
}

$claudeDir = Join-Path $env:USERPROFILE '.claude\hooks'
$codexDir  = Join-Path $env:USERPROFILE '.codex\hooks'
$claudeHook = Join-Path $claudeDir 'secret-guard.py'
$codexHook  = Join-Path $codexDir 'secret-guard.py'

foreach ($dir in @($claudeDir, $codexDir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
Copy-Item -LiteralPath $srcHook -Destination $claudeHook -Force
Copy-Item -LiteralPath $srcHook -Destination $codexHook -Force
Write-Host "[OK] secret-guard.py 已部署到 Claude/Codex hooks 目录" -ForegroundColor Green

function New-SecretGuardEntry {
    param([string]$Matcher, [string]$Status)
    @{
        matcher = $Matcher
        hooks = @(
            @{
                type = 'command'
                command = "`"$python`" `"$claudeHook`""
                timeout = 10
                statusMessage = $Status
            }
        )
    }
}

function New-SecretGuardEntryCodex {
    param([string]$Matcher, [string]$Status)
    @{
        matcher = $Matcher
        hooks = @(
            @{
                type = 'command'
                command = "`"$python`" `"$codexHook`""
                timeout = 10
                statusMessage = $Status
            }
        )
    }
}

# ── 1. Claude Code：合并 ~/.claude/settings.json hooks ──
$claudeSettings = Join-Path $env:USERPROFILE '.claude\settings.json'
$json = if (Test-Path -LiteralPath $claudeSettings) {
    Get-Content -LiteralPath $claudeSettings -Raw | ConvertFrom-Json -AsHashtable
} else { @{} }

if (-not $json.ContainsKey('hooks')) { $json['hooks'] = @{} }
$hooks = $json['hooks']

function Add-ClaudeEvent {
    param([string]$Event, [string]$Matcher, [string]$Status)
    if (-not $hooks.ContainsKey($Event)) { $hooks[$Event] = @() }
    $arr = [System.Collections.Generic.List[object]]::new()
    foreach ($e in @($hooks[$Event])) { $arr.Add($e) }
    $arr.Add((New-SecretGuardEntry -Matcher $Matcher -Status $Status))
    $hooks[$Event] = $arr.ToArray()
}

Add-ClaudeEvent -Event 'PreToolUse'      -Matcher 'Bash|Read|Write|Edit|Glob|Grep' -Status ' Scanning command for secrets...'
Add-ClaudeEvent -Event 'PostToolUse'     -Matcher 'Bash|Read|Glob|Grep' -Status ' Checking output for secrets...'
Add-ClaudeEvent -Event 'UserPromptSubmit' -Matcher '*' -Status ' Scanning prompt for secrets...'

$json['hooks'] = $hooks
$json | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $claudeSettings -Encoding utf8
Write-Host "[OK] Claude Code hooks 已合并: $claudeSettings" -ForegroundColor Green

# ── 2. Codex CLI：合并 ~/.codex/hooks.json ──
$codexHooksFile = Join-Path $env:USERPROFILE '.codex\hooks.json'
$codexJson = if (Test-Path -LiteralPath $codexHooksFile) {
    Get-Content -LiteralPath $codexHooksFile -Raw | ConvertFrom-Json -AsHashtable
} else { @{ hooks = @{} } }

if (-not $codexJson.ContainsKey('hooks')) { $codexJson['hooks'] = @{} }
$chooks = $codexJson['hooks']

function Add-CodexEvent {
    param([string]$Event, [string]$Matcher, [string]$Status)
    if (-not $chooks.ContainsKey($Event)) { $chooks[$Event] = @() }
    $arr = [System.Collections.Generic.List[object]]::new()
    foreach ($e in @($chooks[$Event])) { $arr.Add($e) }
    $entry = New-SecretGuardEntryCodex -Matcher $Matcher -Status $Status
    if ([string]::IsNullOrEmpty($Matcher)) { $entry.Remove('matcher') }
    $arr.Add($entry)
    $chooks[$Event] = $arr.ToArray()
}

Add-CodexEvent -Event 'PreToolUse'       -Matcher 'Bash' -Status ' Scanning command for secrets...'
Add-CodexEvent -Event 'PostToolUse'      -Matcher 'Bash' -Status ' Checking output for secrets...'
Add-CodexEvent -Event 'UserPromptSubmit' -Matcher '' -Status ' Scanning prompt for secrets...'

$codexJson['hooks'] = $chooks
$codexJson | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $codexHooksFile -Encoding utf8
Write-Host "[OK] Codex hooks 已合并: $codexHooksFile" -ForegroundColor Green

# ── 3. 确保 Codex hooks 特性开启（config.toml [features] hooks=true）──
$codexConfig = Join-Path $env:USERPROFILE '.codex\config.toml'
$t = if (Test-Path -LiteralPath $codexConfig) { Get-Content -LiteralPath $codexConfig -Raw } else { '' }
if ($t -notmatch '(?m)^\s*\[features\]\s*$') {
    Add-Content -LiteralPath $codexConfig -Value "`n[features]`nhooks = true`n" -Encoding utf8
    Write-Host '[OK] Codex config.toml 已启用 hooks' -ForegroundColor Green
} elseif ($t -notmatch '(?ms)\[features\].*?hooks\s*=\s*true') {
    $t = $t -replace '(?m)^\[features\]\s*$', "[features]`nhooks = true"
    Set-Content -LiteralPath $codexConfig -Value $t -Encoding utf8
    Write-Host '[OK] Codex config.toml 已启用 hooks' -ForegroundColor Green
} else {
    Write-Host '[INFO] Codex hooks 特性已启用' -ForegroundColor DarkGray
}

Write-Host '[完成] Agent 密钥泄露防护已就绪（Claude Code + Codex CLI）。' -ForegroundColor Cyan
