# Codex 接管记录（原生二进制 + 沙箱 + 密钥）

> 2026-08-19 落地，配套方案：`docs\plans\0002-codex-takeover.md`

## 现状

- codex 0.148.0 原生二进制：`D:\ohmyenv\codex`（ohmyenv 管理，pin/update）
- npm 版 `@openai/codex@0.147.0` 已卸载（交接完成后清理）；当前唯一来源为原生版
- 下载通道：aria2 多线程优先（实测 7.1MiB/s），curl / Invoke-WebRequest 兜底

## 沙箱（永久关闭）

`~/.codex\config.toml` 合并写入（未覆盖原配置）：

```toml
sandbox_mode = "danger-full-access"
approval_policy = "never"

[windows]
sandbox = "unelevated"
```

`codex doctor` 确认：`sandbox unrestricted fs + enabled network · approval Never`。

## 密钥（env_key 方案）

- `DEEPSEEK_API_KEY`：用户级环境变量，由交互脚本 `scripts\set-deepseek-key.ps1` 设置（不在命令/日志中回显）
- `config.toml`：`experimental_bearer_token` 明文 → 已替换为 `env_key = "DEEPSEEK_API_KEY"`
- `codex doctor` 确认：`provider auth env var DEEPSEEK_API_KEY (present)`
- 备份：`~/.codex\backup-takeover-20260819\config.toml`（含旧明文 key，交接完成后清理）
- SOPS 加密副本：`.secrets\deepseek.env.enc`（可提交，用于换机/轮换恢复）；重加密用 `scripts\sops-encrypt-deepseek.ps1`

## 状态栏增强配置（[tui]）

独立脚本 `scripts\set-codex-statusline.ps1`（Codex 安装后增强配置功能），幂等合并，不覆盖既有配置：

```toml
[tui]
status_line = [
  "model-with-reasoning",
  "git-branch",
  "context-remaining",
]
status_line_use_colors = true
```

用法：`pwsh -NoProfile -File scripts\set-codex-statusline.ps1`（可 `-StatusLine @(...)` 自定义、`-NoColors` 关彩色）。
`codex doctor` 验证 `config.toml parse ok`；重启 codex 新会话生效，TUI 内 `/statusline` 可交互微调。
官方配置参考：`https://developers.openai.com/codex/config-reference`（`tui.status_line` 为 array<string> 或 null，`null` 禁用状态栏）。

## 踩过的坑（规则 1 沉淀）

- **不要用覆盖方式写 `config.toml`**：会冲掉模型提供方、项目信任、hooks 等已有配置 → 必须合并（正则替换单行 + 前置追加）
- **卸载 npm 包会中断当前会话**：必须先确认新会话跑在原生版（`scripts\verify-codex-handover.ps1` PASS）后，再在原生会话中卸载
- **版本不硬编码**：`New-ToolDef` 只含静态元数据；版本/Tag/资产名唯一来源是 `scripts\env.psd1`，先 `ohmyenv pin` 后 `ohmyenv update`
- **codex doctor 显示 managed by npm**：codex 会按 package root 检测；升级请用 `ohmyenv update codex`，不要用 `codex update`（会去动 npm 包）
- **aria2 部分连接报 SSL/TLS handshake 失败**：GitHub CDN 瞬态问题，多线程 + SHA256SUMS 校验兜底，重试即成功
- **孤儿下载进程**：中断的下载会残留进程并锁住缓存文件 → 先 `taskkill /PID` 再清理，脚本已对缓存做 sha256 校验重下
- `api.deepseek.com` 可达性探针偶发超时：本机网络问题，非配置错误
