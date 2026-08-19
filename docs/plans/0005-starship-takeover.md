# 0005-starship-takeover — starship 接管与 PowerShell 清理

- 状态：已完成
- 日期：2026-08-19
- 关联：ROADMAP 阶段 4

## 背景与问题

- starship 由 omc 托管（1.25.0），`PostInstall` 负责两件事：profile 注入 `Invoke-Expression (&starship init powershell)`、把 `starship.toml` 拷贝到 `~\.config\starship.toml`
- 用户要求：接管 starship（**配置文件必须保留**）；清理 PowerShell 模块（Pester / PSScriptAnalyzer / PSFzf）、调试组件 pses（PowerShellEditorServices）与 fzf profile，profile 只留 Starship；**不留备份，直接清理**

## 目标与非目标

- 目标：
  - starship 1.26.0 由 ohmyenv 管理；`~\.config\starship.toml` 与 profile 的 Starship init 块保留
  - PowerShell 用户级模块与调试组件直接删除；两个 profile（pwsh7 / 5.1）仅保留 Starship 块
- 非目标：不动 fzf.exe 本体；不动系统级模块（`Program Files` 下的 Pester 3.4.0 属 Windows 内置）；不动 omc 其他工具

## 方案

### starship 接管

- `New-ToolDef`：zip 展平单目录；starship 发布只有逐资产 `.sha256`（无统一 SHA256SUMS），不走 `SumsAsset`，下载后回填 sha
- 配置保留：`~\.config\starship.toml` 即 starship 默认配置路径（无 `STARSHIP_CONFIG` 环境变量），与 omc 源配置 sha 完全一致，零迁移
- profile Starship 块保留：新终端 `starship` 解析到 `D:\ohmyenv\starship\starship.exe`

### PowerShell 清理（直接删除，不留备份）

- profile（pwsh7 + 5.1）：删除 PSFzf 块，仅留 Starship
- 用户级模块删除：Pester 5.7.1 / PSScriptAnalyzer 1.25.0 / PSFzf 2.7.10（`WindowsPowerShell\Modules` 与 `PowerShell\Modules` 双份）+ PowerShellEditorServices + `.envs\dev\pses` 目录
- omc 注册移除：`$DevTools` 移除 pses、`$PsModules` 清空；`pses.ps1` / `psanalyzer.ps1` 删除

## 实施步骤

1. ohmyenv 接入 starship（ToolNames / New-ToolDef / 版本解析 / ValidateSet / verify 脚本）✓
2. `pin starship -Latest`（1.26.0）+ `deploy`（aria2 SSL 瞬断 → curl 兜底成功）✓
3. omc 移除 starship 注册，定义与二进制删除 ✓
4. profile 清理：先备份 → 按用户指示删除备份，PSFzf 块移除，仅留 Starship ✓
5. 模块与调试组件直接删除（含 pses 目录；PSFzf.dll 曾短暂被进程占用，重试后删除成功）✓
6. 验证：verify-tools-handover 5/5 PASS、模块清单干净、profile 仅 Starship ✓
7. 文档：本方案 + CHANGELOG + ROADMAP + 踩坑沉淀 ✓

## 风险与回滚

- starship 版本行为差异 → `ohmyenv pin starship -Version <旧>` + deploy；配置本就标准路径，无迁移风险
- profile 无备份 → Starship 块即标准 init 一行，可手工恢复
- 已删除模块可重装（`Install-Module`）或从 D:\Oh-My-Claude git 历史恢复脚本

## 验收标准

- verify-tools-handover 全部 PASS（starship 解析 `D:\ohmyenv\starship\starship.exe`、配置就位）
- `Get-Module -ListAvailable` 仅剩系统内置模块
- 两个 profile 仅含 Starship 块
