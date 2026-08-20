#Requires -Version 7.0
# claude-statusline.ps1 - Claude Code 状态栏（对齐 Codex 风格，纯 PowerShell，不走 bash）
# Claude Code 通过 settings.json 的 statusLine.command 调用本脚本，并把会话状态 JSON 从 stdin 传入；
# 脚本在 stdout 输出单行文本（支持 ANSI 颜色），exit 0。
#
# 用法（离线自测）:
#   echo '{"model":{"display_name":"GLM-5.3"},...}' | pwsh -NoProfile -File scripts\claude-statusline.ps1
# 配置（幂等合并 settings.json 的 statusLine 块）:
#   pwsh -NoProfile -File scripts\set-claude-statusline.ps1

$ErrorActionPreference = 'SilentlyContinue'

# ── 1. 读取 stdin JSON ──
$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
try { $d = $raw | ConvertFrom-Json } catch { exit 0 }

# ── ANSI 着色（对齐 Codex 状态栏配色：模型/元数据=青，路径/用量=绿，分支=品红） ──
function Seg([string]$text, [string]$code = '') {
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    if ($code) { return "$([char]27)[${code}m$text$([char]27)[0m" }
    return $text
}

# token 数格式化：0 / 31k / 1M
function FmtTok([double]$n) {
    if ($n -ge 1MB) { return '{0:N0}M' -f ($n / 1MB) }
    if ($n -ge 1KB) { return '{0:N0}k' -f ($n / 1KB) }
    return [string][long]$n
}

$parts = [System.Collections.Generic.List[string]]::new()

# ── 2. 模型（display_name 优先，回退 id） ──
$model = $null
if ($d.model) {
    $model = if ($d.model.display_name) { "$($d.model.display_name)" } else { "$($d.model.id)" }
}
$m = Seg $model '36'
if ($m) { $parts.Add($m) }

# ── 3. 上下文：context: 已用% (已用/窗口)，对齐 Codex 语义 ──
if ($d.context_window) {
    $cw = $d.context_window
    $win = [double]$cw.context_window_size
    $usedPct = $null
    if ($null -ne $cw.used_percentage) {
        $usedPct = [math]::Floor([double]$cw.used_percentage)
    } elseif ($null -ne $cw.remaining_percentage) {
        $usedPct = 100 - [math]::Floor([double]$cw.remaining_percentage)
    }
    if ($null -ne $usedPct -and $win -gt 0) {
        $usedTok = [math]::Round($win * $usedPct / 100)
        $c = Seg ("context: ${usedPct}% ($(FmtTok $usedTok)/$(FmtTok $win))") '32'
        if ($c) { $parts.Add($c) }
    }
}

# ── 5. 目录（完整路径） ──
$dir = $null
if ($d.workspace) { $dir = "$($d.workspace.current_dir)" }
if (-not $dir -or $dir -eq '.') { $dir = "$($d.cwd)" }
if (-not $dir -or $dir -eq '.') { $dir = "$($d.workspace.project_dir)" }
if ($dir) {
    $p = Seg $dir '32'
    if ($p) { $parts.Add($p) }
}

# ── 6. Git 分支 + 变更（JSON worktree 优先，git 命令兜底；非 git 目录自动省略） ──
$branch = $null
if ($d.worktree -and $d.worktree.branch) { $branch = "$($d.worktree.branch)" }
if (-not $branch -and $d.workspace -and $d.workspace.git_worktree -and $d.workspace.git_worktree.name) {
    $branch = "$($d.workspace.git_worktree.name)"
}
if (-not $branch) {
    $branch = (& git rev-parse --abbrev-ref HEAD 2>$null | Out-String).Trim()
}
if ($branch) {
    $add = 0L
    $del = 0L
    foreach ($line in (& git diff --numstat HEAD 2>$null)) {
        $f = $line -split "`t"
        if ($f.Count -ge 2 -and $f[0] -notmatch '-' -and $f[1] -notmatch '-') {
            $add += [long]$f[0]
            $del += [long]$f[1]
        }
    }
    $bs = $branch
    if ($add -gt 0 -or $del -gt 0) { $bs += " +$add -$del" }
    $g = Seg $bs '35'
    if ($g) { $parts.Add($g) }
}

if ($parts.Count -eq 0) { exit 0 }
Write-Output ($parts -join ' | ')
exit 0
