#Requires -Version 7.0
# set-agent-secret-guard.ps1 - 统一密钥泄露防护 hook（Claude Code / Codex CLI / Kimi Code CLI / Reasonix，幂等）
# 用法: pwsh -NoProfile -File scripts\set-agent-secret-guard.ps1
# 说明: 部署统一 secret-guard.py 到四个 CLI 的 hooks 目录，并按各自格式幂等合并 hooks 配置
#       （保留已有 hooks，不重复追加 secret-guard）。
#       hook 命令统一使用 python3（Windows 由 set-python-config.ps1 建立别名；WSL/Linux 原生 python3）。
#
# 各 CLI hook 格式差异（已按官方文档核实）:
#   Claude Code : ~/.claude/settings.json         JSON, matcher, timeout 秒
#   Codex CLI   : ~/.codex/hooks.json + [features] hooks=true, matcher, timeout 秒
#   Kimi Code   : ~/.kimi-code/config.toml        TOML [[hooks]], matcher(可选), timeout 秒
#   Reasonix    : %APPDATA%\reasonix\settings.json JSON, match, timeout 毫秒

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers.ps1')

$envRoot = Get-DefaultEnvRoot
$srcHook = Join-Path $PSScriptRoot 'hooks\secret-guard.py'

$python3Exe = Join-Path $envRoot 'python\python3.exe'
if (-not (Test-Path -LiteralPath $python3Exe)) {
    throw "未找到 python3 别名: $python3Exe（先 ohmyenv deploy python + set-python-config.ps1）"
}
if (-not (Test-Path -LiteralPath $srcHook)) {
    throw "未找到统一 hook 脚本: $srcHook"
}

$claudeHome   = Join-Path $env:USERPROFILE '.claude'
$codexHome    = Join-Path $env:USERPROFILE '.codex'
$kimiHome     = Join-Path $env:USERPROFILE '.kimi-code'
$reasonixHome = Join-Path $env:APPDATA 'reasonix'

$claudeHook   = Join-Path $claudeHome   'hooks\secret-guard.py'
$codexHook    = Join-Path $codexHome    'hooks\secret-guard.py'
$kimiHook     = Join-Path $kimiHome     'hooks\secret-guard.py'
$reasonixHook = Join-Path $reasonixHome 'hooks\secret-guard.py'

# ── 0. 部署统一 hook 脚本副本 ──
foreach ($h in @($claudeHook, $codexHook, $kimiHook, $reasonixHook)) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $h) -Force | Out-Null
    Copy-Item -LiteralPath $srcHook -Destination $h -Force
}
Write-Host '[OK] secret-guard.py 已部署到 Claude / Codex / Kimi / Reasonix hooks 目录' -ForegroundColor Green

$claudeCmd   = "python3 `"$claudeHook`""
$codexCmd    = "python3 `"$codexHook`""
$reasonixCmd = "python3 `"$reasonixHook`""

# ── 通用: JSON hooks 幂等 upsert（Claude/Codex 嵌套结构；按 secret-guard.py 定位并更新命令）──
function Add-NestedJsonHook {
    param(
        [hashtable]$Hooks,
        [string]$Event,
        [string]$Matcher,
        [string]$Command,
        [string]$Status
    )
    if (-not $Hooks.ContainsKey($Event)) { $Hooks[$Event] = @() }
    $found = $false
    foreach ($entry in @($Hooks[$Event])) {
        if ($entry -is [hashtable] -and $entry.ContainsKey('hooks')) {
            foreach ($h in @($entry['hooks'])) {
                if ($h -is [hashtable] -and ($h['command'] -like '*secret-guard.py*')) {
                    $h['command'] = $Command
                    $h['timeout'] = 10
                    $h['statusMessage'] = $Status
                    # 同步 matcher 到外部 entry（若本调用带 matcher），使存量安装重跑也能应用扩充
                    if (-not [string]::IsNullOrEmpty($Matcher)) { $entry['matcher'] = $Matcher }
                    $found = $true
                }
            }
        }
    }
    if ($found) { return $false }
    $newEntry = @{
        hooks = @(
            @{ type = 'command'; command = $Command; timeout = 10; statusMessage = $Status }
        )
    }
    if (-not [string]::IsNullOrEmpty($Matcher)) { $newEntry['matcher'] = $Matcher }
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($e in @($Hooks[$Event])) { $list.Add($e) }
    $list.Add($newEntry)
    $Hooks[$Event] = $list.ToArray()
    return $true
}

# ── 通用: JSON hooks 幂等 upsert（Reasonix 扁平结构，match + timeout 毫秒）──
function Add-FlatJsonHook {
    param(
        [hashtable]$Hooks,
        [string]$Event,
        [string]$Match,
        [string]$Command,
        [int]$Timeout
    )
    if (-not $Hooks.ContainsKey($Event)) { $Hooks[$Event] = @() }
    $found = $false
    foreach ($entry in @($Hooks[$Event])) {
        if ($entry -is [hashtable] -and ($entry['command'] -like '*secret-guard.py*')) {
            $entry['command'] = $Command
            $entry['timeout'] = $Timeout
            $found = $true
        }
    }
    if ($found) { return $false }
    $newEntry = @{ command = $Command; timeout = $Timeout }
    if (-not [string]::IsNullOrEmpty($Match)) { $newEntry['match'] = $Match }
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($e in @($Hooks[$Event])) { $list.Add($e) }
    $list.Add($newEntry)
    $Hooks[$Event] = $list.ToArray()
    return $true
}

# ── 1. Claude Code: ~/.claude/settings.json ──
$claudeSettings = Join-Path $claudeHome 'settings.json'
$json = if (Test-Path -LiteralPath $claudeSettings) {
    Get-Content -LiteralPath $claudeSettings -Raw | ConvertFrom-Json -AsHashtable
} else { @{} }
if (-not $json.ContainsKey('hooks')) { $json['hooks'] = @{} }
$claudeHooks = $json['hooks']

$null = Add-NestedJsonHook -Hooks $claudeHooks -Event 'PreToolUse'       -Matcher 'Bash|Read|Write|Edit|MultiEdit|Glob|Grep|WebFetch|WebSearch|NotebookEdit|Task|mcp__' -Command $claudeCmd -Status ' Scanning command for secrets...'
$null = Add-NestedJsonHook -Hooks $claudeHooks -Event 'PostToolUse'      -Matcher 'Bash|Read|Write|Edit|MultiEdit|Glob|Grep|WebFetch|WebSearch|NotebookEdit|Task|mcp__' -Command $claudeCmd -Status ' Checking output for secrets...'
$null = Add-NestedJsonHook -Hooks $claudeHooks -Event 'UserPromptSubmit' -Matcher ''                               -Command $claudeCmd -Status ' Scanning prompt for secrets...'

$json['hooks'] = $claudeHooks
$json | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $claudeSettings -Encoding utf8
Write-Host "[OK] Claude Code hooks 已合并: $claudeSettings" -ForegroundColor Green

# ── 2. Codex CLI: ~/.codex/hooks.json + [features] hooks=true ──
$codexHooksFile = Join-Path $codexHome 'hooks.json'
$codexJson = if (Test-Path -LiteralPath $codexHooksFile) {
    Get-Content -LiteralPath $codexHooksFile -Raw | ConvertFrom-Json -AsHashtable
} else { @{ hooks = @{} } }
if (-not $codexJson.ContainsKey('hooks')) { $codexJson['hooks'] = @{} }
$codexHooks = $codexJson['hooks']

$null = Add-NestedJsonHook -Hooks $codexHooks -Event 'PreToolUse'       -Matcher 'Bash' -Command $codexCmd -Status ' Scanning command for secrets...'
$null = Add-NestedJsonHook -Hooks $codexHooks -Event 'PostToolUse'      -Matcher 'Bash' -Command $codexCmd -Status ' Checking output for secrets...'
$null = Add-NestedJsonHook -Hooks $codexHooks -Event 'UserPromptSubmit' -Matcher ''     -Command $codexCmd -Status ' Scanning prompt for secrets...'

$codexJson['hooks'] = $codexHooks
$codexJson | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $codexHooksFile -Encoding utf8
Write-Host "[OK] Codex hooks 已合并: $codexHooksFile" -ForegroundColor Green

$codexConfig = Join-Path $codexHome 'config.toml'
$t = if (Test-Path -LiteralPath $codexConfig) { Get-Content -LiteralPath $codexConfig -Raw } else { '' }
# 按「块」处理 [features]：从 [features] 到下一个 [表头] 或文末之间的内容才归它管，
# 避免跨 table 误匹配、避免在已有 hooks=false 时追加重复 hooks=true 键（非法 TOML）。
$featuresBlockRegex = '(?m)^\s*\[features\]\s*$(\r?\n)([\s\S]*?)(?=^\s*\[[^\[\r\n]+\]\s*$|\z)'
if ($t -notmatch '(?m)^\s*\[features\]\s*$') {
    # 无 [features] 表：整体追加
    $nl = if ($t.TrimEnd()) { "`n`n" } else { '' }
    Add-Content -LiteralPath $codexConfig -Value "$nl[features]`nhooks = true`n" -Encoding utf8
    Write-Host '[OK] Codex config.toml 已启用 hooks' -ForegroundColor Green
} elseif ($t -match $featuresBlockRegex) {
    # 捕获整个 [features] 块（含表头到下一表头前的全部内容）做锚定替换，避免 .Replace('',..) 空块崩溃
    # 和全文误替换。
    $wholeBlock = $Matches[0]          # 含 [features] 表头 + 内容（截至下一表头或文末）
    $block      = $Matches[2]          # 表头之后、下一个表头之前的内容
    # 块内是否有 hooks 键（探测用，须以 hooks 起始 + 行尾语义，容空格与 =）
    $hasHook    = [bool]($block -match '(?mi)^[ \t]*hooks[ \t]*=')
    $hookFalse  = [bool]($block -match '(?mi)^[ \t]*hooks[ \t]*=\s*false(?:[ \t]*(?:#.*)?)?\r?$')
    if (-not $hasHook) {
        # 块内无 hooks 键：在块尾追加 hooks=true（空块也安全：追加到表头行后）
        $insert = if ([string]::IsNullOrWhiteSpace($block)) { "hooks = true`n" } else { ($block.TrimEnd()) + "`nhooks = true`n" }
        $updatedBlock = ($wholeBlock -replace "(?m)^(\[features\]\s*$)", "`$1`n$insert")
        $t = $t.Replace($wholeBlock, $updatedBlock)
        Set-Content -LiteralPath $codexConfig -Value $t -Encoding utf8
        Write-Host '[OK] Codex config.toml 已启用 hooks' -ForegroundColor Green
    } elseif ($hookFalse) {
        # 块内 hooks=false（含带行尾注释的 false）：限定在块内翻 true
        $updatedBlock = $wholeBlock -replace '(?m)^([ \t]*hooks[ \t]*=[ \t]*)false([ \t]*(?:#.*)?)?[ \t]*\r?$', '$1true'
        $t = $t.Replace($wholeBlock, $updatedBlock)
        Set-Content -LiteralPath $codexConfig -Value $t -Encoding utf8
        Write-Host '[OK] Codex config.toml hooks 已改为 true' -ForegroundColor Green
    } else {
        Write-Host '[INFO] Codex hooks 特性已启用' -ForegroundColor DarkGray
    }
} else {
    # 理论上不会到这：有 [features] 表但块正则失败（罕见），保守提示
    Write-Host '[INFO] Codex hooks 特性检测跳过（无法解析块）' -ForegroundColor DarkGray
}

# ── 3. Kimi Code CLI: ~/.kimi-code/config.toml（[[hooks]]，timeout 秒）──
$kimiConfig = Join-Path $kimiHome 'config.toml'
New-Item -ItemType Directory -Path $kimiHome -Force | Out-Null
if (-not (Test-Path -LiteralPath $kimiConfig)) {
    [System.IO.File]::WriteAllText($kimiConfig, '', (New-Object System.Text.UTF8Encoding $false))
}
$kimiRaw = [System.IO.File]::ReadAllText($kimiConfig, [System.Text.Encoding]::UTF8)

if ($kimiRaw.Contains('secret-guard.py')) {
    $kimiOld = $kimiRaw
    $kimiRaw = [regex]::Replace($kimiRaw, '(?m)^command\s*=\s*.*secret-guard\.py.*$', "command = 'python3 `"$kimiHook`"'")
    if ($kimiRaw -ne $kimiOld) {
        [System.IO.File]::WriteAllText($kimiConfig, $kimiRaw, (New-Object System.Text.UTF8Encoding $false))
        Write-Host '[OK] Kimi secret-guard 命令已更新为 python3' -ForegroundColor Green
    } else {
        Write-Host '[INFO] Kimi secret-guard 命令已是 python3' -ForegroundColor DarkGray
    }
} else {
    if ($kimiRaw.Length -gt 0 -and -not $kimiRaw.EndsWith("`n")) { $kimiRaw += "`n" }
    $kimiBlock = @"

[[hooks]]
event = "PreToolUse"
command = 'python3 "$kimiHook"'
timeout = 10

[[hooks]]
event = "PostToolUse"
command = 'python3 "$kimiHook"'
timeout = 10

[[hooks]]
event = "UserPromptSubmit"
command = 'python3 "$kimiHook"'
timeout = 10
"@
    $kimiRaw += $kimiBlock
    [System.IO.File]::WriteAllText($kimiConfig, $kimiRaw, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "[OK] Kimi hooks 已追加（PreToolUse / PostToolUse / UserPromptSubmit）" -ForegroundColor Green
}

# ── 4. Reasonix: %APPDATA%\reasonix\settings.json（match + timeout 毫秒）──
$reasonixSettings = Join-Path $reasonixHome 'settings.json'
$rxJson = if (Test-Path -LiteralPath $reasonixSettings) {
    Get-Content -LiteralPath $reasonixSettings -Raw | ConvertFrom-Json -AsHashtable
} else { @{} }
if (-not $rxJson.ContainsKey('hooks')) { $rxJson['hooks'] = @{} }
$rxHooks = $rxJson['hooks']

$null = Add-FlatJsonHook -Hooks $rxHooks -Event 'PreToolUse'       -Match '*' -Command $reasonixCmd -Timeout 5000
$null = Add-FlatJsonHook -Hooks $rxHooks -Event 'PostToolUse'      -Match '*' -Command $reasonixCmd -Timeout 10000
$null = Add-FlatJsonHook -Hooks $rxHooks -Event 'UserPromptSubmit' -Match ''  -Command $reasonixCmd -Timeout 5000

$rxJson['hooks'] = $rxHooks
$rxJson | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $reasonixSettings -Encoding utf8
Write-Host "[OK] Reasonix hooks 已合并: $reasonixSettings" -ForegroundColor Green

Write-Host '[完成] 统一密钥泄露防护已就绪（Claude Code + Codex CLI + Kimi Code CLI + Reasonix）。' -ForegroundColor Cyan
