# Codex TUI 状态栏研究（status_line）

> 2026-08-19 对照 codex 0.148.0 源码核实（`codex-rs/tui/src/bottom_pane/status_line_setup.rs`、`status_line_style.rs`、`codex-rs/config/src/types.rs`）。

## 结论

- `[tui].status_line` 是唯一配置入口（`array<string>`，`null` 禁用状态栏；未设置时默认 `model-with-reasoning` + `current-dir`）
- `status_line_use_colors` 真实存在，默认 `true`：按主题色分 accent 着色（源码确认）
- 分隔符固定为 ` · `，样式由活动主题派生（饱和度 85% / 亮度 100%），fallback 配色：模型/状态/元数据/模式 → 青，路径/用量/进度 → 绿，分支/额度/线程 → 品红
- 配置仅在新会话启动时读取；已有会话不会自动刷新

## 可用项清单（0.148.0 全量）

| 配置 ID | 显示内容 | 说明 |
| --- | --- | --- |
| `model-name` | 当前模型名 | |
| `model-with-reasoning` | 模型名 + 推理级别 | 默认项，如 `deepseek-v4-flash high` |
| `reasoning` | 当前推理级别 | |
| `current-dir` | 当前工作目录 | 默认项 |
| `project-root` | 项目名 | 不可用时省略；别名 `project` / `project-name` |
| `git-branch` | 当前 Git 分支 | 非 git 仓库时省略，如 `main` |
| `pull-request-number` | PR 编号 | 如 `PR #123` |
| `branch-changes` | Git 变更摘要 | 如 `+12 -3`（解决“不知道 git 状态”） |
| `run-state` | 会话状态 | `Ready` / `Working` / `Thinking`；别名 `status` |
| `permissions` | 权限档案 / 沙箱模式 | 本机显示 `danger-full-access` |
| `approval-mode` | 命令审批模式 | 别名 `approval`；本机 `never` |
| `context-remaining` | 上下文剩余 % | 如 `Context 95% left` |
| `context-used` | 上下文已用 % | |
| `context-window-size` | 上下文窗口大小 | |
| `used-tokens` | 会话 token 总量 | 为 0 时省略 |
| `total-input-tokens` / `total-output-tokens` | 输入 / 输出 token | |
| `five-hour-limit` / `weekly-limit` | 5 小时 / 周额度 | OpenAI 官方额度才有意义；DeepSeek 下不显示 |
| `codex-version` | Codex 版本 | |
| `thread-credits` / `estimated-thread-cost` | 线程额度 / 预估成本 | |
| `session-id` | 会话标识 | 线程开始前省略；别名 `thread-id` |
| `fast-mode` | 是否 Fast mode | |
| `raw-output` | 是否原始滚动模式 | |
| `thread-title` | 线程标题 | 未命名时显示 ID |
| `workspace-headline` | 工作区通知头条 | 仅企业工作区 |
| `task-progress` | `update_plan` 任务进度 | 不可用前省略 |

完整/最新清单以 TUI 内 `/statusline` 选择器为准（`/statusline` 或 `/statusbar` 打开，支持勾选、排序、实时预览，确认后写回 `[tui]`）。

## 当前推荐配置（已应用）

```toml
[tui]
status_line = [
  "run-state",
  "model-with-reasoning",
  "git-branch",
  "branch-changes",
  "context-remaining",
  "used-tokens",
  "permissions",
]
status_line_use_colors = true
```

设计理由：

- `run-state` 放最前：一眼看到会话在 Ready / Working / Thinking
- `model-with-reasoning`：模型 + 推理级别
- `git-branch` + `branch-changes`：分支与工作区变更一目了然（`main · +12 -3`）
- `context-remaining` + `used-tokens`：上下文余量与 token 消耗
- `permissions`：信任边界（`danger-full-access`）常驻可见

应用脚本：`scripts\set-codex-statusline.ps1`（幂等合并，不覆盖 DeepSeek / 沙箱 / 信任项目等既有配置；`-StatusLine @(...)` 自定义，`-NoColors` 关彩色）。

## 注意事项

- 重启 codex 新会话生效；已有会话不刷新
- git 相关项在非 git 仓库目录自动省略
- `five-hour-limit` / `weekly-limit` 在 DeepSeek（非 OpenAI 官方额度）下无意义，不推荐加
- 已由 `codex doctor` 确认 `config.toml parse ok`
