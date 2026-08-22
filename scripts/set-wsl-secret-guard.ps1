#Requires -Version 7.0
# set-wsl-secret-guard.ps1 - 统一密钥泄露防护 hook 同步进 WSL（Codex / Claude Code / Kimi Code，幂等）
# 用法: pwsh -NoProfile -File scripts\set-wsl-secret-guard.ps1 [-Distro ohmywsl] [-User ray]
# 说明: 把 scripts\hooks\secret-guard.py cp 进 WSL 三个 agent 的 hooks 目录，并按各 CLI 格式
#       （Linux 路径、原生 python3）幂等合并 hooks 配置。与 Windows 侧 set-agent-secret-guard.ps1
#       同源（同一 secret-guard.py），不含 Reasonix（WSL 未装）。
#       hook 命令统一用 Linux 原生 python3（基础镜像自带 Python 3.12）。

param(
    [string]$Distro = 'ohmywsl',
    [string]$User = 'ray'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'helpers.ps1')

$envRoot    = Get-DefaultEnvRoot
$srcHook    = Join-Path $PSScriptRoot 'hooks\secret-guard.py'
$stageDir   = Join-Path $envRoot 'cache\wsl-secret-guard'
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null

if (-not (Test-Path -LiteralPath $srcHook)) { throw "未找到统一 hook 脚本: $srcHook" }

function ConvertTo-WslPath {
    param([Parameter(Mandatory)][string]$WinPath)
    $drive = $WinPath.Substring(0, 1).ToLower()
    return '/mnt/' + $drive + $WinPath.Substring(2).Replace('\', '/')
}

function Invoke-WslBash {
    param([Parameter(Mandatory)][string]$Command, [switch]$Root)
    $prev = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
    try {
        $u = if ($Root) { 'root' } else { $User }
        & wsl -d $Distro -u $u -e bash -lc $Command
        return $LASTEXITCODE
    } finally {
        [Console]::OutputEncoding = $prev
    }
}

# distro / python3 前置检查
$prevEnc = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::Unicode
$hasDistro = [bool]((wsl -l -q 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq $Distro }))
[Console]::OutputEncoding = $prevEnc
if (-not $hasDistro) { throw "WSL distro $Distro 不存在，先导入: scripts\set-wsl-distro.ps1" }
$null = Invoke-WslBash -Command "command -v python3 >/dev/null 2>&1 || exit 1"
if ($LASTEXITCODE -ne 0) { throw 'WSL 内无 python3（基础镜像应自带 Python 3.12）' }

# ── 0. 部署统一 hook 脚本副本到 WSL 三个 agent 的 hooks 目录 ──
# 先落盘到 EnvRoot stage（不跨盘直接写 WSL），再在 WSL 内复制到各 hooks 目录
Copy-Item -LiteralPath $srcHook -Destination (Join-Path $stageDir 'secret-guard.py') -Force
$stageWsl = ConvertTo-WslPath (Join-Path $stageDir 'secret-guard.py')
$deploy = @(
    '$HOME/.codex/hooks',
    '$HOME/.claude/hooks',
    '$HOME/.kimi-code/hooks'
) -join ' '
$null = Invoke-WslBash -Command "for d in $deploy; do mkdir -p `"`$d`"; cp '$stageWsl' `"`$d/secret-guard.py`"; chmod 755 `"`$d/secret-guard.py`"; done; echo hook-copied"
if ($LASTEXITCODE -ne 0) { throw 'secret-guard.py 复制到 WSL hooks 目录失败' }
Write-Host '[OK] secret-guard.py 已同步到 WSL Codex / Claude / Kimi hooks 目录' -ForegroundColor Green

# ── 通用: 配置模板。Claude 用 settings.json（JSON nested hooks）；Codex 用 hooks.json；
#          Kimi 用 config.toml（[[hooks]]）。命令一律 Linux 原生 python3 + WSL 家目录绝对路径。──
$claudeCmd = 'python3 "$HOME/.claude/hooks/secret-guard.py"'
$codexCmd  = 'python3 "$HOME/.codex/hooks/secret-guard.py"'
$kimiCmd   = 'python3 "$HOME/.kimi-code/hooks/secret-guard.py"'

# ── 1. Claude Code: ~/.claude/settings.json（JSON，嵌套 hooks）──
# 直接生成 Linux settings.json 模板（与 set-wsl-agent-config.ps1 保持同一个 env/permissions 基线，
# 再叠加 hooks 块），避免在 WSL 内做 JSON round-trip 的引号地狱。
$claudeSettings = [ordered]@{
    env = [ordered]@{
        'CLAUDE_CODE_AUTO_COMPACT_WINDOW'        = '1000000'
        'ANTHROPIC_DEFAULT_HAIKU_MODEL'          = 'glm-4.7'
        'ANTHROPIC_DEFAULT_SONNET_MODEL'         = 'glm-5.3[1m]'
        'ANTHROPIC_DEFAULT_OPUS_MODEL'           = 'glm-5.3[1m]'
        'DISABLE_TELEMETRY'                      = '1'
        'DISABLE_FEEDBACK_SURVEY'                = '1'
        'DISABLE_AUTOUPDATER'                    = '1'
        'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC' = '1'
        'CLAUDE_CODE_DISABLE_1M_CONTEXT'         = '0'
        'CLAUDE_CODE_ATTRIBUTION_HEADER'         = '0'
        'CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING'  = '1'
        'CLAUDE_CODE_DISABLE_INTERLEAVED_THINKING' = '1'
        'CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY' = '1'
        'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'   = '1'
        'CLAUDE_CODE_SUBAGENT_MODEL'             = 'glm-5-turbo'
        'ENABLE_LSP_TOOL'                        = '1'
        'BASH_MAX_TIMEOUT_MS'                    = '600000'
        'BASH_DEFAULT_TIMEOUT_MS'                = '300000'
        'BASH_MAX_OUTPUT_LENGTH'                 = '20000'
        'API_TIMEOUT_MS'                         = '3000000'
        'MCP_TIMEOUT'                            = '60000'
        'DISABLE_AUTO_COMPACT'                   = '0'
        'CLAUDE_AUTOCOMPACT_PCT_OVERRIDE'        = '80'
        'LC_ALL'                                 = 'en_US.UTF-8'
        'LANG'                                   = 'en_US.UTF-8'
        'PYTHONIOENCODING'                       = 'utf-8'
        'PYTHONUTF8'                             = '1'
    }
    permissions = [ordered]@{ defaultMode = 'bypassPermissions' }
    hooks = [ordered]@{
        PreToolUse = @(
            [ordered]@{
                matcher = 'Bash|Read|Write|Edit|MultiEdit|Glob|Grep|WebFetch|WebSearch|NotebookEdit|Task|mcp__'
                hooks = @(
                    [ordered]@{ type = 'command'; command = $claudeCmd; timeout = 10; statusMessage = ' Scanning command for secrets...' }
                )
            }
        )
        PostToolUse = @(
            [ordered]@{
                matcher = 'Bash|Read|Write|Edit|MultiEdit|Glob|Grep|WebFetch|WebSearch|NotebookEdit|Task|mcp__'
                hooks = @(
                    [ordered]@{ type = 'command'; command = $claudeCmd; timeout = 10; statusMessage = ' Checking output for secrets...' }
                )
            }
        )
        UserPromptSubmit = @(
            [ordered]@{
                hooks = @(
                    [ordered]@{ type = 'command'; command = $claudeCmd; timeout = 10; statusMessage = ' Scanning prompt for secrets...' }
                )
            }
        )
    }
}
$claudeStage = Join-Path $stageDir 'claude-settings.json'
[System.IO.File]::WriteAllText($claudeStage, ($claudeSettings | ConvertTo-Json -Depth 12), (New-Object System.Text.UTF8Encoding $false))
$null = Invoke-WslBash -Command "mkdir -p `$HOME/.claude && cp '$(ConvertTo-WslPath $claudeStage)' `$HOME/.claude/settings.json && echo claude-guard-ok"
if ($LASTEXITCODE -ne 0) { throw '写入 ~/.claude/settings.json 失败' }
Write-Host '[OK] Claude Code hooks 已合并: ~/.claude/settings.json' -ForegroundColor Green

# ── 2. Codex CLI: ~/.codex/hooks.json ──
$codexHooksJson = [ordered]@{
    hooks = [ordered]@{
        PreToolUse = @(
            [ordered]@{
                matcher = 'Bash'
                hooks = @(
                    [ordered]@{ type = 'command'; command = $codexCmd; timeout = 10; statusMessage = ' Scanning command for secrets...' }
                )
            }
        )
        PostToolUse = @(
            [ordered]@{
                matcher = 'Bash'
                hooks = @(
                    [ordered]@{ type = 'command'; command = $codexCmd; timeout = 10; statusMessage = ' Checking output for secrets...' }
                )
            }
        )
        UserPromptSubmit = @(
            [ordered]@{
                hooks = @(
                    [ordered]@{ type = 'command'; command = $codexCmd; timeout = 10; statusMessage = ' Scanning prompt for secrets...' }
                )
            }
        )
    }
}
$codexStage = Join-Path $stageDir 'codex-hooks.json'
[System.IO.File]::WriteAllText($codexStage, ($codexHooksJson | ConvertTo-Json -Depth 12), (New-Object System.Text.UTF8Encoding $false))
$null = Invoke-WslBash -Command "mkdir -p `$HOME/.codex && cp '$(ConvertTo-WslPath $codexStage)' `$HOME/.codex/hooks.json && echo codex-guard-ok"
if ($LASTEXITCODE -ne 0) { throw '写入 ~/.codex/hooks.json 失败' }
# [features] hooks=true 由 set-wsl-agent-config.ps1 已写入 config.toml；此处兜底确保存在
$null = Invoke-WslBash -Command "grep -q '^hooks = true' `$HOME/.codex/config.toml || printf '\n[features]\nhooks = true\n' >> `$HOME/.codex/config.toml; echo codex-features-ok"
if ($LASTEXITCODE -ne 0) { throw 'Codex config.toml hooks=true 兜底失败' }
Write-Host '[OK] Codex hooks 已合并: ~/.codex/hooks.json（config.toml hooks=true 兜底）' -ForegroundColor Green

# ── 3. Kimi Code CLI: ~/.kimi-code/config.toml（[[hooks]]）──
$kimiStage = Join-Path $stageDir 'kimi-config.toml'
$kimiToml = @"
default_model = "kimi-code/k3"
default_permission_mode = "auto"
telemetry = false

[[hooks]]
event = "PreToolUse"
command = '$kimiCmd'
timeout = 10

[[hooks]]
event = "PostToolUse"
command = '$kimiCmd'
timeout = 10

[[hooks]]
event = "UserPromptSubmit"
command = '$kimiCmd'
timeout = 10
"@
[System.IO.File]::WriteAllText($kimiStage, $kimiToml, (New-Object System.Text.UTF8Encoding $false))
$null = Invoke-WslBash -Command "mkdir -p `$HOME/.kimi-code && cp '$(ConvertTo-WslPath $kimiStage)' `$HOME/.kimi-code/config.toml && echo kimi-guard-ok"
if ($LASTEXITCODE -ne 0) { throw '写入 ~/.kimi-code/config.toml 失败' }
Write-Host '[OK] Kimi hooks 已合并: ~/.kimi-code/config.toml' -ForegroundColor Green

# ── 4. 回读验证（JSON parse + secret-guard.py 冒烟自检）──
$null = Invoke-WslBash -Command "jq empty `$HOME/.claude/settings.json && jq empty `$HOME/.codex/hooks.json && echo JSON-PARSE-OK"
if ($LASTEXITCODE -ne 0) { throw 'JSON parse 校验失败' }
$null = Invoke-WslBash -Command "echo '{}' | python3 `$HOME/.codex/hooks/secret-guard.py >/dev/null 2>&1; echo PY-SMOKE-OK"
if ($LASTEXITCODE -ne 0) { throw 'secret-guard.py 冒烟自检失败' }
Write-Host '[完成] WSL 统一密钥泄露防护已就绪（Codex + Claude Code + Kimi Code）。' -ForegroundColor Cyan
