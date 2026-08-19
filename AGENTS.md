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

   项目文档由 `CHANGELOG.md`、`ROADMAP.md`、`docs\plans\`、`docs\research\` 四块组成；任何可交付变更必须同步更新文档，禁止只改代码不落文档。

   - `CHANGELOG.md`：每次可交付变更追加记录（Added / Changed / Fixed / Removed + 日期），先维护在 `[Unreleased]` 下
   - `ROADMAP.md`：阶段与里程碑状态（未开始 / 进行中 / 已完成 / 挂起），随进展翻转
   - `docs\plans\NNNN-短名.md`：重要方案/决策必须落成方案文档，模板见 `docs\plans\0000-template.md`，禁止只在对话中拍板
   - `docs\research\主题.md`：研究类成果（工具能力研究、踩坑沉淀、实测记录）落成研究文档，命名 `英文短名.md`，随研究/踩坑即时维护
   - 文档总览与命名约定见 `docs\README.md`

## 目录与分类规范

文件按类别物理分离，新增文件必须归入对应目录，禁止乱放：

| 类别 | 目录 | 说明 |
| --- | --- | --- |
| 脚本/代码 | `scripts\` | ohmyenv CLI（`ohmyenv.ps1`）、模块函数（`helpers.ps1`）、工具定义与锁定清单（`env.psd1`）、环境脚本（密钥/交接验证/状态栏等） |
| 文档 | `docs\`（`plans\` + `research\`）+ 根目录 AGENTS/CHANGELOG/ROADMAP.md | 见「文档规范」 |
| 配置 | `.sops.yaml`、`scripts\env.psd1` | SOPS 加密策略 / 工具版本锁定清单（唯一 pin 来源，代码不得硬编码版本） |
| 密钥数据 | `.secrets\` | SOPS 加密副本（可提交）；明文密钥/凭据绝不入库（`.gitignore` 兜底） |
| 环境目录 | `D:\ohmyenv` | 工具安装根（git 之外），由 ohmyenv 管理（query / deploy / install / update / pin） |

要点：

- 新文件按类别落位；排查期临时脚本仅作过渡，验证后必须收敛进 `scripts\` 或删除，不留孤儿脚本
- 明文密钥、token、凭据永不入库；加密副本只放 `.secrets\`
- 版本/Tag/资产名唯一来源是 `scripts\env.psd1`，先 `ohmyenv pin` 后 `ohmyenv update`
- 类别/目录变动时同步更新 `docs\README.md` 与本表

## 设计原则

- **引导安装不依赖 gh（bootstrap 自举）**：首次安装或恢复环境时，不得把已装好的 gh 当作先决条件；通过 `api.github.com` REST API 查询发布资产并直连下载（带 User-Agent、按 tag 查询、失败重试）。
- **API 限流全局 gh 兜底**：api.github.com 匿名限流（60 次/小时）时，所有查询统一走 `Invoke-GitHubApi`，自动切换到 `gh api` 认证通道（5000 次/小时）；gh 仅在已安装后作为加速/兜底通道。
- **版本不硬编码，先 pin 后 update**：工具定义（`New-ToolDef`）只含静态元数据，版本/Tag/资产名只存在于 `scripts\env.psd1`（唯一 pin 来源）；新工具先 `ohmyenv pin <tool> [-Latest | -Version X]`，之后用 `ohmyenv update <tool>` 升级并重新 pin。
