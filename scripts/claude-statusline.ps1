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

$parts = [System.Collections.Generic.List[string]]::new()

# ── 2. 模型（display_name 优先，回退 id） ──
$model = $null
if ($d.model) {
    $model = if ($d.model.display_name) { "$($d.model.display_name)" } else { "$($d.model.id)" }
}
$m = Seg $model '36'
if ($m) { $parts.Add($m) }

# ── 3. 上下文：剩余 %（回退已用 % 换算），1M 窗口标注 ──
if ($d.context_window) {
    $cw = $d.context_window
    $win = $cw.context_window_size
    $ctxPct = $null
    if ($null -ne $cw.remaining_percentage) {
        $ctxPct = [math]::Floor([double]$cw.remaining_percentage)
    } elseif ($null -ne $cw.used_percentage) {
        $ctxPct = 100 - [math]::Floor([double]$cw.used_percentage)
    }
    if ($null -ne $ctxPct) {
        $winTag = ''
        if ($win -and [double]$win -ge 1000000) { $winTag = '[1M] ' }
        $c = Seg ("ctx $winTag$ctxPct%") '32'
        if ($c) { $parts.Add($c) }
    }
}

# ── 4. 会话 token 总量 ──
if ($d.context_window -and $d.context_window.total_input_tokens) {
    $total = [long]$d.context_window.total_input_tokens + [long]$d.context_window.total_output_tokens
    if ($total -gt 0) {
        $tok = if ($total -ge 1MB) { '{0:N1}M' -f ($total / 1MB) }
               elseif ($total -ge 1KB) { '{0:N1}k' -f ($total / 1KB) }
               else { "$total" }
        $t = Seg ("$tok tok") '2'
        if ($t) { $parts.Add($t) }
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
