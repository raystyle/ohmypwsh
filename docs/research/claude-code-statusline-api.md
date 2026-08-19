# Claude Code 状态栏（statusLine）API 研究

> 2026-08-19，来源：code.claude.com/docs/en/statusline（SSRF 拦截后经 GitHub 镜像/社区文档核实：claude-code-best/claude-code docs/features/status-line.mdx、oakoss/linesmith docs/research/claude-code-statusline-api.md、danielmackay/claude-code-statusline）。

## 配置

`~/.claude/settings.json` 的 `statusLine` 块：

```json
{ "statusLine": { "type": "command", "command": "...", "padding": 0 } }
```

- `type`：仅支持 `command`
- `command`：shell 命令字符串，主进程每次 fork 新进程执行，会话状态 JSON 从 stdin 传入，stdout 输出状态栏文本
- `padding`：左右留白（Ink cell 数）
- `refreshInterval`（秒）：官方支持定时刷新；缺省/0 为事件驱动（新消息、模式切换、vim 模式变化时重算），300ms debounce + abort 单飞

## stdin JSON（脚本可读的全部字段）

| 字段 | 说明 |
| --- | --- |
| `model.id` / `model.display_name` | 运行时实际模型 |
| `session_id` / `session_name` | 会话标识/名称 |
| `cwd`、`workspace.current_dir` / `project_dir` / `added_dirs` | 工作目录（current_dir 随 cd 变化） |
| `workspace.git_worktree.name` | git worktree 名 |
| `worktree.name` / `branch` / `path` / `original_branch` | worktree 元信息 |
| `version` | Claude Code 版本 |
| `output_style.name` | 输出样式 |
| `cost.total_cost_usd` / `total_duration_ms` / `total_lines_added` / `total_lines_removed` | 会话累计成本/时长/行数 |
| `context_window.context_window_size` | 模型上下文上限 |
| `context_window.total_input_tokens` / `total_output_tokens` | 会话累计 token |
| `context_window.current_usage` | 最近一次 assistant 消息 usage（首次响应前为 null） |
| `context_window.used_percentage` / `remaining_percentage` | 0-100 浮点 |
| `context_window.exceeds_200k_tokens` | 是否超 200k |
| `rate_limits.five_hour` / `seven_day` | `{used_percentage, resets_at}`；**API key 用户无此字段** |
| `vim.mode` | vim 模式 |
| `agent.name` | 子 agent 时非空 |
| `remote.session_id` | Bridge/Remote 模式 |

## 输出契约

- stdout 单行文本（多行会挤占 REPL 高度，不推荐）；支持 ANSI 颜色、OSC8 超链接
- exit 0 + stdout → 显示；exit 0 + 空 → 清空；非 0/超时（默认 5000ms）→ 忽略保留上次
- 脚本必须无状态（每次调用新进程）；跨 tick 状态用 `~/.claude/statusline-state/<hash>` 持久化
- 热路径应 <100ms；`current_usage` 为 null 时要有 fallback

## 本机实现

- `scripts\claude-statusline.ps1`：纯 PowerShell 7，stdin JSON → 单行 `模型 · ctx [1M] N% · N.Nk tok · $cost · 目录 · 分支 +N -M`，配色对齐 Codex（模型青、用量绿、分支品红）
- `scripts\set-claude-statusline.ps1`：幂等合并 settings.json `statusLine` 块（command 指向 `pwsh -NoProfile -File D:/ohmypwsh/scripts/claude-statusline.ps1`，兼容 bash/pwsh 包装）
- 实测：样例 JSON 输出正常（含 `[1M]` 标注、`+N -M` 变更统计）
