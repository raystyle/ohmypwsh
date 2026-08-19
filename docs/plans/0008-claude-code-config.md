# 0008-claude-code-config — Claude Code 扩展配置（GLM-5.3 1M 上下文）

- 状态：已完成
- 日期：2026-08-19
- 关联：ROADMAP 阶段 4

## 背景与问题

- Claude Code 现由 omc 管理（`base\claude.ps1`，`~/.local/bin/claude.exe` 2.1.187，GLM profile），key 明文存在 `.config\claude\profiles\GLM.json`（`ANTHROPIC_AUTH_TOKEN`）
- 需求：由 ohmyenv 扩展配置——端点 `https://open.bigmodel.cn/api/anthropic`、GLM-5.3 + 1M 上下文（`[1m]` 后缀 + `CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000`）、密钥加密保存（用户环境变量 + SOPS 加密副本）；其余优化配置参考 omc（关遥测等），不装插件和 hook

## 目标与非目标

- 目标：
  - `uv tool install claude-code` 由 ohmyenv 的 uv 管理（装到 `D:\ohmyenv\uv-tools\bin`）
  - `~/.claude/settings.json` 幂等合并 `env` 块（HAIKU=glm-4.7 / SONNET=glm-5.3[1m] / OPUS=glm-5.3[1m] / AUTO_COMPACT_WINDOW=1000000），保留现有权限等配置
  - 用户环境变量：`ANTHROPIC_BASE_URL` + omc 优化集（遥测/超时/1M 上下文等），**不装插件/hook**
  - 密钥：`ANTHROPIC_API_KEY`（迁移自 GLM profile，不回显）→ 用户环境变量 + `.secrets\anthropic.env.enc` SOPS 加密
- 非目标：不动 omc 的 claude profile 体系；不迁移 claude 会话/历史；不添加 MCP/插件/hook

## 方案

### 脚本

- `scripts\set-claude-key.ps1`：`-FromOmcProfile` 迁移 GLM token 或交互式设置 `ANTHROPIC_API_KEY`
- `scripts\sops-encrypt-anthropic.ps1`：加密为 `.secrets\anthropic.env.enc`（加密/解密回读验证，明文即删）
- `scripts\set-claude-config.ps1`：uv 安装 claude-code（缺省）+ 用户环境变量幂等设置 + settings.json `env` 块合并

### settings.json env 块（用户指定）

```json
{ "env": {
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "1000000",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.7",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5.3[1m]",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-5.3[1m]"
} }
```

### 用户环境变量（参考 omc 优化集，无插件/hook）

`ANTHROPIC_BASE_URL`、`DISABLE_TELEMETRY=1`、`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`、`DISABLE_FEEDBACK_SURVEY=1`、`DISABLE_AUTOUPDATER=1`、`CLAUDE_CODE_DISABLE_1M_CONTEXT=0`、`CLAUDE_CODE_AUTO...` 超时/编码/子代理模型等（见脚本）

## 实施步骤

1. 方案文档（本文件）✓
2. `set-claude-key.ps1` / `sops-encrypt-anthropic.ps1` / `set-claude-config.ps1` ✓
3. 运行：uv 安装 claude-code → 环境变量 → settings.json 合并 ✓
4. 密钥迁移（GLM profile → `ANTHROPIC_API_KEY`）→ SOPS 加密 ✓
5. 验证：`claude --version`、settings.json 内容、env、`.secrets\anthropic.env.enc` 解密回读 ✓
6. 文档：CHANGELOG / ROADMAP / docs/README / AGENTS 常用命令

实测补充：

- PyPI 的 `claude-code` 是占位包（0.0.1 无入口点）→ 改用「uv pip download `claude-agent-sdk` wheel（aliyun，~100MB）→ 解出 `claude.exe` → `D:\ohmyenv\uv-tools\bin`」
- claude 版本 2.1.233（最新，支持 `[1m]` 模型后缀）
- settings.json `env` 块合并用 OrderedDictionary 字典式赋值（`Add-Member` 对字典不生效、ConvertTo-Json 不序列化）
- 密钥从 omc GLM profile 的 `ANTHROPIC_AUTH_TOKEN` 迁移为 `ANTHROPIC_API_KEY`（不回显）+ `.secrets\anthropic.env.enc`

## 风险与回滚

- claude 已装（2.1.187）与 uv tool 新装并存 → PATH 前置 `D:\ohmyenv\uv-tools\bin`，新 claude 生效；旧 `~/.local/bin/claude.exe` 保留
- `[1m]` 模型不被识别 → 需升级 claude-code（`uv tool upgrade claude-code`）重试
- settings.json 合并 → 备份在首次写入时生成 `.bak-YYYYMMDDHHmmss`

## 验收标准

- `claude --version` 正常（D:\ohmyenv\uv-tools\bin 解析）
- settings.json 含 env 块（GLM-5.3[1m] / 4 项），原有 permissions 等保留
- `ANTHROPIC_BASE_URL` 与优化 env 就位；无 plugins/hooks 键
- `.secrets\anthropic.env.enc` 可解密回读 `ANTHROPIC_API_KEY`
