# 0003-tools-takeover — D:\Oh-My-Claude 工具批量接管（rg/jq/yq）

- 状态：已完成
- 日期：2026-08-19
- 关联：ROADMAP 阶段 4（工具分层与日常更新）

## 背景与问题

- `D:\Oh-My-Claude`（omc）仍托管 rg / jq / yq 三个常用 CLI：`.envs\tools\bin\rg.exe`（15.1.0）、`jq.exe`（1.8.1）、`yq.exe`（4.53.2），注册在 `omc.ps1` 的 `$ToolDefs`，工具定义在 `.scripts\tools\*.ps1`
- gh / git / 7z 已按同模式移交 ohmyenv；三个工具继续留在 omc 会导致 PATH 双源、版本锁定分散
- 另发现 codex 自带 `codex-path\rg.exe`（15.2.0）仅出现在进程 PATH（开发沙箱注入），注册表 PATH 无此目录，不构成权威来源

## 目标与非目标

- 目标：
  - 三个工具由 ohmyenv 统一管理（pin / update / status），部署到 `D:\ohmyenv`，新终端解析到新位置
  - omc 注册移除并改名保留（`*.removed-20260819`），与 gh/git/7z 接管同一模式
  - 顺带升级到最新版：rg 15.1.0 → 15.2.0、jq 1.8.1 → 1.8.2、yq 4.53.2 → 4.53.4
- 非目标：不动 omc 其他 `$ToolDefs` 工具（fzf / just / starship / bat / typst 等）；不删 `.config\<tool>\config.json`；不提交 `D:\Oh-My-Claude` 仓库（其工作区已有 gh/git/7z 未提交改动）

## 方案

### ohmyenv 接入

- `New-ToolDef` 新增三工具：rg（zip 展平单层目录）、jq / yq（copy 单文件 exe）
- `Get-InstalledVersion` 版本解析：rg `ripgrep (\d+\.\d+\.\d+)`、jq `jq-(\d+\.\d+\.\d+)`、yq `version v?(\d+\.\d+\.\d+)`
- `ohmyenv.ps1` ValidateSet 与帮助文本同步
- 流程：`ohmyenv pin <tool> -Latest` → `ohmyenv deploy <tool>`（aria2 多线程下载、sha256 回填、PATH 前置注册）

### omc 移交

- `omc.ps1` 的 `$ToolDefs` 移除 ripgrep / jq / yq
- 定义文件与二进制改名保留：`*.removed-20260819`
- `CLAUDE.md` 注册表块与工具一览同步标注「已移交 D:\ohmyenv 管理」

### 验证

- `scripts\verify-tools-handover.ps1`：重建 PATH（注册表为权威）后逐一检查解析路径与版本是否等于锁定

## 备选方案

- 保留 omc 托管、仅 ohmyenv pin：仍双源，无意义
- 直接删除旧二进制：不可回滚；沿用 `.removed-*` 改名保留（与 gh/git/7z 一致）

## 实施步骤

1. helpers.ps1 接入三工具（ToolNames / New-ToolDef / Get-InstalledVersion）✓
2. ohmyenv.ps1 ValidateSet + 帮助 ✓
3. `ohmyenv pin rg/jq/yq -Latest` ✓（15.2.0 / 1.8.2 / 4.53.4）
4. `ohmyenv deploy rg/jq/yq` ✓（aria2 下载 + sha256 回填 + PATH 前置）
5. omc.ps1 / CLAUDE.md 移除注册并标注 ✓
6. 定义文件与二进制改名保留 ✓
7. `verify-tools-handover.ps1` 一键验证 ✓（全部 PASS）
8. 文档：本方案 + CHANGELOG + 踩坑沉淀 ✓

## 风险与回滚

- 下载失败 → aria2 多线程 + curl / IWR 兜底 + sha256 校验（既有机制）
- 升级破坏兼容 → `ohmyenv pin <tool> -Version <旧版>` + `ohmyenv deploy <tool>`；旧二进制仍在 `*.removed-20260819`
- PATH 双源残留 → 新终端验证脚本兜底；codex-path 非注册表来源无需处理

## 验收标准

- `ohmyenv status` 三工具 locked = installed = path = True
- `verify-tools-handover.ps1` 全部 PASS（解析到 `D:\ohmyenv\<tool>`）
- `omc.ps1` 的 `$ToolDefs` 不再含三工具；`*.removed-20260819` 就位
- 新终端 `Get-Command rg/jq/yq` 只命中 `D:\ohmyenv`
