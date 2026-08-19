# AGENTS.md

## 规则

1. **踩坑必须当场沉淀**

   踩过的坑、错误、反复试出来的可行命令，必须当场沉淀为脚本（`scripts\`）或文档命令，禁止反复手写、反复试错。

2. **环境感知，默认使用 pwsh**

   执行命令前先感知系统环境；默认使用 PowerShell 7（`pwsh`），不要使用 Windows PowerShell 5.1（`powershell.exe`）。

   - 运行环境：Windows 10 Enterprise LTSC 2024（Build 26100，64 位）
   - `pwsh`：`C:\Program Files\PowerShell\7\pwsh.exe`，版本 7.6.4
   - `gh`：GitHub CLI，版本 2.91.0
   - `git`：Git for Windows，版本 2.54.0.windows.1

3. **文档规范**

   项目文档由 `CHANGELOG.md`、`ROADMAP.md`、`docs\plans\` 三块组成；任何可交付变更必须同步更新文档，禁止只改代码不落文档。

   - `CHANGELOG.md`：每次可交付变更追加记录（Added / Changed / Fixed / Removed + 日期），先维护在 `[Unreleased]` 下
   - `ROADMAP.md`：阶段与里程碑状态（未开始 / 进行中 / 已完成 / 挂起），随进展翻转
   - `docs\plans\NNNN-短名.md`：重要方案/决策必须落成方案文档，模板见 `docs\plans\0000-template.md`，禁止只在对话中拍板
   - 文档总览与命名约定见 `docs\README.md`

## 设计原则

- **引导安装不依赖 gh（bootstrap 自举）**：首次安装或恢复环境时，不得把已装好的 gh 当作先决条件；通过 `api.github.com` REST API 查询 gh/git 发布资产并直连下载（带 User-Agent、按 tag 查询、失败重试）。gh 仅在已安装后可作为加速下载通道。
- **版本不硬编码，先 pin 后 update**：工具定义（`New-ToolDef`）只含静态元数据，版本/Tag/资产名只存在于 `scripts\env.psd1`（唯一 pin 来源）；新工具先 `ohmyenv pin <tool> [-Latest | -Version X]`，之后用 `ohmyenv update <tool>` 升级并重新 pin。
