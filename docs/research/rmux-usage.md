# RMUX 正确用法研究（gh 调研 + 本机实测）

> 2026-08-19，来源：Helvesec/rmux v0.10.0（README、docs/integrations/claude-code.md、docs/man/rmux.1、resources/claude/skills/rmux/SKILL.md）+ 本机 Windows 10 实测。

## 结论

- RMUX 是 Rust 写的 tmux 兼容终端复用器（105 个命令），Windows 原生 ConPTY，无需 WSL
- 本机部署：`D:\ohmyenv\rmux`（ohmyenv 管理，已前置 PATH）。Windows 包 = `rmux.exe`（tiny CLI 分发器）+ `libexec\rmux\rmux.exe`（full helper），两者必须同目录保留
- 配置读取顺序：`%XDG_CONFIG_HOME%\rmux\rmux.conf` → `~/.rmux.conf` → `%APPDATA%\rmux\rmux.conf` → `%RMUX_CONFIG_FILE%`；无配置时按 best-effort 解析 `tmux.conf`（`RMUX_DISABLE_TMUX_FALLBACK=1` 关闭）
- 官方提供 Claude Code skill（`rmux claude install-skill` 装到 `%USERPROFILE%\.claude\skills\rmux`），项目级双端 skill 已在本仓库落地（`.claude/skills/rmux` + `.agents/skills/rmux`）

## 常用命令（实测可用）

```powershell
rmux new-session -d -s NAME -c D:\path
rmux split-window -h -t 1:0 -c D:\path 'cmd'   # 右分屏；-v 上下
rmux list-sessions / rmux find-panes
rmux capture-pane -t NAME -p
rmux pane-snapshot -t NAME
rmux kill-pane -t %N / kill-session -t NAME
```

## 踩坑（实测沉淀）

1. **send-keys 目标**：`-t` 接受会话名 / `session:window.pane` / pane id（`%N`），payload 必须放在 `--` 之后，键名 `Enter`/`Down`/`Up`/`C-c`。
2. **tiny CLI 误报「can't find pane」**：默认 `rmux.exe`（tiny 分发器）对部分目标解析失败；设 `RMUX_DISABLE_TINY_CLI=1` 走 full helper 可解（本次实测 `-t 1` 在 tiny 下报错、full helper 下 exit 0）。
3. **`--wait` 本版本只支持 `quiet`**（`--wait-next-text`/`--wait-visible-text` 是独立参数，不是 `--wait` 的值）；等待必须配 `--timeout`，避免盲 sleep。
4. **Windows ConPTY 备屏捕获限制**：Claude Code 等全屏 TUI 走 alternate screen，rmux 0.10 `capture-pane`/`pane-snapshot` 返回空（`capture-pane -a` 报 no alternate screen），无法从外部读取 TUI 渲染内容；键可发（`broadcast-keys`/`send-keys`），但输入通道对 TUI 窗格不稳定（偶发 `server closed connection before a complete response frame arrived`）。
5. **`rmux claude`（teammate 模式）**：自动传 `--teammate-mode tmux` 并注入私有 tmux shim；内层会话 socket 每实例随机（`-L` 无法预知），外层命令看不到内层会话；TUI 内容同样不可捕获。调试建议改用 `claude -p`（纯文本可捕获）或让用户目视窗格。
6. **发送键到未知窗格有副作用**：`send-keys` 目标错误会把键注入错误的 pane（实测曾把 echo 打进其他 agent 会话输入框）。发送前先 `find-panes` 确认目标。
7. **中文输入经 send-keys 丢失/乱码**：对 Claude Code 窗格发中文 payload（如 `-- '只回复"连接正常"' Enter`）时输入框不显示内容，且产生 `server closed connection before a complete response frame arrived`（乱码字节打到 API）；同一窗格英文 payload 立即正常。驱动 claude 的 prompt 先用 ASCII/英文，或先 `claude -p` 走管道传中文。

## 与本项目的关系

- 双端 skill：`.claude/skills/rmux/SKILL.md`（Claude Code 项目级）与 `.agents/skills/rmux/SKILL.md`（Codex 项目级，仓库根向上扫描）内容同源
- Claude Code 的 statusline 命令经 `pwsh` 运行，与 rmux 无直接依赖；rmux 用于分屏调试
