# Claude Code 首次启动 onboarding 与安装警告（登录验证 / 信任 / .local PATH）

> 2026-08-19，完全接管重置（删除 `~/.claude` 与 `~/.claude.json`）后，经 rmux 右侧窗格驱动 claude 实测沉淀。

## 结论

- 第三方 API Key（`ANTHROPIC_API_KEY` + `ANTHROPIC_BASE_URL`）场景，claude 首次启动仍会卡「Select login method」；`~/.claude.json` 设 `hasCompletedOnboarding: true` 即可永久跳过（已固化进 `scripts\set-claude-config.ps1`）。
- 工作区信任弹窗（"Is this a project you created or one you trust?"）由 `~/.claude.json` 的 `projects.<path>` 记录；`hasTrustDialogAccepted` / `hasTrustDialogHooksAccepted` 置 true 即永久跳过（脚本批量处理所有已记录项目 + 主工作区 `D:/ohmypwsh`）。
- 自定义 API Key 确认弹窗（"Do you want to use this API key?"）务必单独按键确认：rmux `send-keys` 把 `Up`+`Enter` 连发会落在「2. No」，被记入 `customApiKeyResponses.rejected`，导致后续一直不信任该密钥；脚本已幂等清空 rejected。
- `/status` 的 `.local\bin` 安装警告分两类：
  - config mismatch 类（install method / claude.exe missing）→ `DISABLE_INSTALLATION_CHECKS=1`（settings.json env）可关；
  - PATH 检查类（"Native installation exists but ... is not in your PATH"）→ **编译进 native 二进制**，环境变量与配置都无法关闭；唯一消除方式是按官方 native 布局部署（二进制在 `%USERPROFILE%\.local\bin\claude.exe` 且该目录在 PATH）。已按用户决定改为官方布局（见踩坑 4 更新），`/status` 诊断区零警告。

## 背景

完全接管 Claude Code：删除 omc 时代 `~/.claude` 全部目录（含 12 个旧 skill）与 `~/.claude.json`，由 `set-claude-config.ps1` 重建。首次在 rmux 右窗格启动 claude 时逐屏撞出 onboarding 问题。

## 踩坑明细

### 1. 首次启动卡「Select login method」

即使当前环境已有 `ANTHROPIC_API_KEY` 与 `ANTHROPIC_BASE_URL`（rmux 窗格 env 实测均存在），claude 仍先弹「Detected a custom API key ... Do you want to use this API key?」，再进「Select login method」且 Esc 无法跳过。

根因：onboarding 的登录验证步骤不会因环境 Key 存在而自动跳过（官方与阿里云 Model Studio 文档一致结论：第三方 Key 场景必须显式标记 onboarding 已完成）。

修复（已固化脚本）：

```jsonc
// C:\Users\<user>\.claude.json
{
  "hasCompletedOnboarding": true,
  "customApiKeyResponses": { "approved": [], "rejected": [] }
}
```

### 2. 自定义 API Key 被误记 rejected

rmux `send-keys -t 0:0.1 -- Up Enter` 连发时，光标从「2. No」移到「1. Yes」的动作未被 claude 识别，回车落在「No」→ `customApiKeyResponses.rejected` 写入密钥后缀。正确做法：`Up` 单独发 → `capture-pane` 确认光标到「1. Yes」→ 再单独 `Enter`。

### 3. 工作区信任弹窗

onboarding 通过后仍会问 "Accessing workspace: D:\ohmypwsh ... Quick safety check"。信任状态持久化在 `~/.claude.json` 的 `projects` 字段（路径用正斜杠：`D:/ohmypwsh`）：

```jsonc
"projects": {
  "D:/ohmypwsh": {
    "hasTrustDialogAccepted": true,
    "hasTrustDialogHooksAccepted": true
  }
}
```

### 4. `/status` 的 `.local\bin` 安装警告（4 行 → 1 行）

本机 claude 为 `D:\ohmyenv\uv-tools\bin\claude.exe`（320 MB native 二进制，由 set-claude-config 从 claude-agent-sdk wheel 解出）。源码 `src/utils/doctorDiagnostic.ts` 判定：

- `getCurrentInstallationType()`：`isInBundledMode()`（原生二进制）且未识别为包管理器 → `type = 'native'`；
- PATH 检查（`if (type === 'native')`）无条件执行，不在 `DISABLE_INSTALLATION_CHECKS` 门内 → `~/.local\bin` 不在 PATH 必报；
- config mismatch 检查（installMethod !== 'native'、claude.exe missing）在 `DISABLE_INSTALLATION_CHECKS` 门内 → 加 `"DISABLE_INSTALLATION_CHECKS": "1"`（settings.json env）后 3 行消失。

**更新（2026-08-19，用户决定改为官方 native 布局）**：不再保留该警告——`set-claude-config.ps1` 新增 2.5 段：

- 把 ohmyenv 托管的 `D:\ohmyenv\uv-tools\bin\claude.exe` 幂等同步到 `%USERPROFILE%\.local\bin\claude.exe`（比较 size + LastWriteTimeUtc，变更才重拷）；
- 把 `%USERPROFILE%\.local\bin` 加入用户 PATH（4.3 段清理规则同步移除 `.local\bin` 过滤，避免自相矛盾）；
- 实测 `/status` 的 System diagnostics 段完全消失（零警告）。

注意：rmux 守护进程 env 是启动时快照，已开窗格/新开窗格不会自动带上新 PATH——重启 claude 窗格时用 `split-window -e "Path=..."` 注入（本次实测有效），或重启终端/daemon 全局生效。二进制本体仍由 ohmyenv 托管，native 位只是同步副本。

### 5. 关联：rmux send-keys 中文输入丢失

冒烟测试用中文 prompt（"只回复…"）经 `send-keys` 发送时输入框无内容，且产生 `server closed connection before a complete response frame arrived`（乱码字节打到 API）；改英文 prompt 立即正常。详见 win-rmux skill 的 `references/rmux-usage.md`（https://github.com/raystyle/win-rmux）踩坑 7。

## 待办

- 无：onboarding 两坑（登录验证 + 信任弹窗）与安装警告处理均已固化进 `scripts\set-claude-config.ps1`（幂等合并，`[INFO]` 提示已最新）；native 布局已按用户决定落地。
