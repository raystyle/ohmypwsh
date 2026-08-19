# 0009-claude-takeover — Claude Code 完全接管（YOLO/状态栏/env 收敛/omc 清理）

- 状态：已完成
- 日期：2026-08-19
- 关联：ROADMAP 阶段 4；前置方案 0008-claude-code-config（GLM-5.3 1M 上下文）

## 背景与问题

0008 已实现 Claude Code 扩展配置（uv 安装 claude 2.1.233、GLM-5.3[1m] 1M 上下文、密钥 SOPS 加密）。但实机验证暴露三组问题：

1. settings.json 非法值：`permissions.disableBypassPermissionsMode: false`（claude 只接受字符串 `"disable"`）→ 整个 settings.json 被跳过 → env 块不生效 → 回落到内置 `claude-opus-5[1m]`，被 bigmodel 静默映射成 glm-4.7
2. 环境变量残留：omc 时代用户级 `ANTHROPIC_AUTH_TOKEN`（旧密钥→401）、`ANTHROPIC_DEFAULT_*`（glm-5.2[1m]）与 CLAUDE_*/BUN_*/RUSTUP_* 等大量变量未清；Codex 宿主进程还残留旧值污染子进程
3. omc 侧旧部署未删：`.scripts\base\claude.ps1`（安装器/Profile 系统）、`.config\claude\profiles\*`（明文密钥）、`~/.local\bin\claude.exe`（旧 2.1.187）、`omc.ps1`/`CLAUDE.md` 中的 claude 条目

## 目标与非目标

- 目标：
  - settings.json 合法化：permissions 只留 `defaultMode: bypassPermissions`（完整 YOLO，对齐 Codex danger-full-access + approval never）
  - 状态栏对齐 Codex：`statusLine` 块 + `scripts\claude-statusline.ps1`（纯 PowerShell，不走 bash）
  - 环境变量收敛：claude 全部配置进 settings.json env，用户级只留 `ANTHROPIC_API_KEY` + `ANTHROPIC_BASE_URL`；清 omc 残留（CLAUDE_*/BUN_*/RUSTUP_*/CARGO/LANG/PATH/PSModulePath）
  - `~/.claude` 完全重置：删 omc 时代 settings.local.json、plugins（raystyle statusline/dev-fix + marketplace）、backups、cache、history、daemon/session-env、12 个旧用户 skill（astgrep/browse/bunsh/github/google/grok/gx/md2pdf/mdcheck/nuevo/twitter/uvsh）与运行时状态；最终连 `.claude` 目录与 `~/.claude.json` 整体删除后用部署脚本重建（用户指示完全从零重置）
  - omc 完全接管：删 claude.ps1（留 `.removed-20260819` 标记）、`.config\claude\`、旧 exe；omc.ps1/CLAUDE.md/rules 同步
- 非目标：不动 omc 其余工具（aria2/fzf 等）；不迁移 claude 会话历史；不装插件/hook

## 方案

### 脚本

- `scripts\set-claude-config.ps1`（重构）：用户级只写 `ANTHROPIC_BASE_URL`；其余 25 项配置收敛进 settings.json `env`（模型/1M/遥测/超时/编码/PowerShell 工具/子代理模型）；幂等删除 omc 遗留环境变量（含 `[NullString]::Value` 真删）；permissions 只写 `defaultMode: bypassPermissions`；PATH/PSModulePath 清理
- `scripts\set-claude-key.ps1`（重写为 Codex 风格）：交互输入 → 用户环境变量 → 自动调用 `sops-encrypt-anthropic.ps1` 加密备份（回读验证、明文即删）
- `scripts\claude-statusline.ps1`：stdin JSON → 单行状态栏（模型/ctx[1M]/tokens/成本/目录/分支+变更），对齐 Codex 配色
- `scripts\set-claude-statusline.ps1`：幂等合并 `statusLine` 块（command 指向 pwsh）

### 双端 rmux skill

- `.claude\skills\rmux\SKILL.md`（Claude Code 项目级）与 `.agents\skills\rmux\SKILL.md`（Codex 项目级，仓库根 `.agents/skills` 向上扫描）内容同源：会话/窗格、send-keys 目标语法、等待语义、输出捕获、rmux claude 集成

## 实施步骤

1. 状态栏脚本 + settings.json statusLine 合并 ✓
2. settings.json 修复（非法 disableBypassPermissionsMode 删除）→ `jq empty` + claude -p debug 验证 model=glm-5.3[1m] ✓
3. 环境变量收敛 + omc 残留清理（User/Machine/PATH/PSModulePath/Profile 复核）✓
4. `~/.claude` 旧配置/hook/插件清理（保留 skills）✓
5. omc 侧删除（claude.ps1/.config/claude/旧 exe/omc.ps1/CLAUDE.md/rules）✓
6. 双端 rmux skill + 校验（skill-creator quick_validate）✓
7. 文档：research（statusline-api/rmux-usage/pitfalls）+ 本方案 + CHANGELOG/ROADMAP/README/AGENTS

## 关键坑（详见 research\ohmyenv-pitfalls.md）

- settings.json 任一非法值 → 整个文件被跳过（env 不生效、回落内置模型）
- 宿主进程残留旧环境变量污染子进程（注册表已清也不代表进程干净）
- `$null` 删环境变量留空串，须 `[NullString]::Value`
- bigmodel 对未知模型名静默映射到 glm-4.7（请求成功≠模型正确）
- rmux 0.10 Windows：TUI 备屏不可捕获、send-keys 目标偶发失败（RMUX_DISABLE_TINY_CLI=1 兜底）

## 验收

- `claude -p` 成功返回且 debug `dispatching ... model=glm-5.3[1m]`（[1m] 本地处理后实际发 glm-5.3）✓
- settings.json 合法（jq parse OK）、permissions 仅 defaultMode=bypassPermissions、env 29 项、statusLine 就位 ✓
- 用户环境变量仅 ANTHROPIC_API_KEY/ANTHROPIC_BASE_URL（+ 自有 UV/DeepSeek/SOPS），无 omc 残留 ✓
- `~/.claude` 无插件/hook/旧备份；`~/.local\bin\claude.exe` 与 omc claude 管理器已删除 ✓
- 双端 rmux skill 校验通过 ✓
