---
name: rmux
description: 使用 RMUX 终端复用器（Windows/pwsh，D:\ohmyenv\rmux 0.10.0）管理会话/窗格、驱动并调试 Claude Code 与命令行程序：send-keys 目标语法、等待语义、capture-pane/stream-pane 输出捕获、rmux claude 集成。涉及 rmux/tmux、分屏或驱动调试 claude 时使用。
---

# RMUX

RMUX 是 Rust 写的 tmux 兼容终端复用器。本机由 ohmyenv 管理：`D:\ohmyenv\rmux`（已前置 PATH）。

## 自检

```powershell
rmux -V                          # 版本（0.10.0）
rmux list-commands               # 已实现命令
rmux list-commands send-keys     # 确认本版本 send-keys 的确切参数
rmux diagnose --human            # 安装/daemon 诊断
```

Windows 包结构：`rmux.exe`（tiny CLI 分发器）+ `libexec\rmux\rmux.exe`（full helper）。命令异常时设 `RMUX_DISABLE_TINY_CLI=1` 强制走 full helper 排障。

## 会话 / 窗格基础（tmux 兼容）

```powershell
rmux new-session -d -s NAME -c D:\path       # 后台新会话（-c 指定起始目录）
rmux list-sessions                           # 会话列表
rmux attach-session -t NAME                  # 附加
rmux split-window -h -t NAME -c D:\path 'cmd' # 右侧分割（-v 上下分割）
rmux list-panes -t NAME                      # 窗格列表
rmux kill-session -t NAME                    # 关闭会话
rmux find-sessions / rmux find-panes         # 查找（含 pane id）
```

## send-keys：目标、`--` 分隔与 tiny CLI 坑

实测结论（rmux 0.10.0 Windows）：

- `-t` 三种写法都接受：会话名（`-t work`）、`session:window.pane`（`-t 1:0.1`）、pane id（`-t %3`）
- 待发送内容放在 `--` 之后；键名用 `Enter` / `Down` / `Up` / `C-c`
- **tiny CLI 对部分目标会误报「can't find pane」**：遇此错误设 `RMUX_DISABLE_TINY_CLI=1`（走 full helper `libexec\rmux\rmux.exe`）重试
- `--wait` 本版本只支持 `quiet`；`--wait-next-text` / `--wait-visible-text` 是独立参数（不是 `--wait` 的值）

```powershell
rmux send-keys -t work -- 'echo hi' Enter
rmux send-keys -t work -- Down Enter          # 方向键选择 + 回车
rmux send-keys -t work --wait quiet --stable-for 500ms --timeout 2m -- 'cargo test' Enter
```

等待语义（**避免盲 sleep，必配 `--timeout`**）：

- `--wait quiet`：等输出静默，构建/测试/未知结束文本的默认选择
- `--wait-next-text TEXT`：只等**新**输出出现，避免匹配旧滚动
- `--wait-visible-text TEXT`：等渲染可见文本
- `--wait-pane-exit`：一次性进程（预期会退出）

## 读取输出

```powershell
rmux capture-pane -t work -p                 # 全量文本（tmux 兼容）
rmux pane-snapshot -t work                   # 快照
rmux stream-pane -t work --lines             # 增量输出
rmux wait-pane -t work --quiet --timeout 30s
rmux collect-pane-output -t work --until-pane-exit --max-bytes 1048576
```

## rmux claude 集成

`rmux claude [args]` 在 rmux 工作区启动 Claude Code，自动加 `--teammate-mode tmux` 并为 claude 进程注入私有 `tmux` shim（不影响系统 tmux）：

```powershell
rmux claude                                  # 交互会话
rmux claude --dangerously-skip-permissions   # 直入 YOLO（bypass）
rmux claude install-skill                    # 安装官方用户级 skill（%USERPROFILE%\.claude\skills\rmux）
```

首次 YOLO 启动会弹「Bypass Permissions mode」确认框：`rmux send-keys -t claude --wait quiet --timeout 10s -- Down Enter` 选择「Yes, I accept」（默认光标在 1. No, exit，按一次 Down 到 2 再回车；若 send-keys 报 can't find pane 先设 `RMUX_DISABLE_TINY_CLI=1`）。

Windows 上驱动/调试 claude 一律用 `rmux claude`（Unix 的 `setsid rmux new-session -d` 不适用）。

## 本项目调试 claude 的套路

```powershell
# 当前窗口右侧分割出 claude（左侧是 Codex）
rmux split-window -h -t 1:0 -c D:\ohmypwsh 'claude'
# 观察输出
rmux pane-snapshot -t 1:0.1
# 发命令验证模型
rmux send-keys -t 1 -- '/status' Enter
rmux send-keys -t 1 -- '/exit' Enter
```

claude 的调试日志在 `%USERPROFILE%\.claude\debug\`（`--debug` 时写入），可用 `Select-String -Pattern 'model=|API error'` 快速定位实际派发模型与错误。
