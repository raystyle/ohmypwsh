# AGENTS.md

## 项目定位

本仓本质是 **Agent 环境部署与管理模块 CLI**：从 Windows 原生 PowerShell 5.1 一键初始化，升级
PowerShell 7，部署完整 PowerShell 模块 CLI，再安装 / 管理工具与 agent 环境；所有已部署产物
（工具 + 配置 + 密钥）支持打包压缩，在另一台 Windows 通过产物压缩包一键还原已 pin 的软件工具
环境。定位方案见 `docs\plans\0010-portable-agent-env.md`。

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

4. **PS5/PS7 编码兼容（优先注意）**

   凡需兼容 Windows PowerShell 5.1 的 `.psd1` / `.ps1` 文件，含非 ASCII 内容时**必须 UTF-8 带 BOM**（PS5.1 无 BOM 按本地代码页 ANSI 读取，中文系统为 GBK，会解析报错/mojibake）；`pwsh7` 的 `Set-Content -Encoding utf8` 是无 BOM，应改用 `utf8BOM`。纯 ASCII 无风险；读取文件显式指定编码，不依赖探测。详见 `docs\research\powershell-encoding.md`。

## 目录与分类规范

文件按类别物理分离，新增文件必须归入对应目录，禁止乱放：

| 类别 | 目录 | 说明 |
| --- | --- | --- |
| 脚本/代码 | `scripts\` | ohmyenv CLI（`ohmyenv.ps1`）、模块函数（`helpers.ps1`）、工具定义与锁定清单（`env.psd1`）、环境脚本（密钥/交接验证/状态栏等） |
| 文档 | `docs\`（`plans\` + `research\`）+ 根目录 README/AGENTS/CHANGELOG/ROADMAP.md | 见「文档规范」 |
| 配置 | `.sops.yaml`、`scripts\env.psd1`、`scripts\modules.psd1` | SOPS 加密策略 / 工具版本锁定清单 / PowerShell 模块锁定清单（唯一 pin 来源，代码不得硬编码版本） |
| 密钥数据 | `.secrets\` | SOPS 加密副本（可提交）；明文密钥/凭据绝不入库（`.gitignore` 兜底） |
| 环境目录 | `D:\ohmyenv` | 工具安装根（git 之外），由 ohmyenv 管理（query / deploy / install / update / pin） |

要点：

- 新文件按类别落位；排查期临时脚本仅作过渡，验证后必须收敛进 `scripts\` 或删除，不留孤儿脚本
- 明文密钥、token、凭据永不入库；加密副本只放 `.secrets\`
- 版本/Tag/资产名唯一来源是 `scripts\env.psd1`，先 `ohmyenv pin` 后 `ohmyenv update`
- 类别/目录变动时同步更新 `docs\README.md`「项目目录索引」与本表

## 常用命令

所有脚本统一用 `pwsh -NoProfile` 运行；新终端先重建 PATH（注册表为权威，进程继承的 PATH 可能缺新目录）：

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
```

环境管理（工具安装根 `D:\ohmyenv`，bootstrap 不依赖 gh）：

```powershell
pwsh -NoProfile -File scripts\ohmyenv.ps1 status                # 锁定 vs 已安装 vs PATH
pwsh -NoProfile -File scripts\ohmyenv.ps1 pin   gh -Latest      # 先 pin 锁定版本
pwsh -NoProfile -File scripts\ohmyenv.ps1 update gh             # 升级到最新并重新 pin
pwsh -NoProfile -File scripts\ohmyenv.ps1 daily -DryRun         # 日常无影响更新预览（同主版本自动）
pwsh -NoProfile -File scripts\ohmyenv.ps1 daily                 # 日常无影响更新（跨主版本保留待确认）
```

PowerShell 7 安装 / 升级（pwsh 不能自更新，必须独立终端用 PS5.1 运行）：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\ohmypwsh\scripts\set-pwsh.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\ohmypwsh\scripts\bootstrap.ps1   # 人类初始部署入口（装 pwsh7 + 部署 omp + 注册 EnvRoot）
```

日常环境脚本：

```powershell
pwsh -NoProfile -File scripts\set-codex-statusline.ps1     # Codex 状态栏幂等合并（[tui]）
pwsh -NoProfile -File scripts\set-deepseek-key.ps1         # DeepSeek API Key 交互式设置
pwsh -NoProfile -File scripts\set-starship-config.ps1      # starship PowerShell 配置（全模板幂等，-Force 覆盖）
pwsh -NoProfile -File scripts\set-claude-key.ps1           # Claude Code (GLM) API Key 交互式设置（用户环境变量 + SOPS 加密备份）
pwsh -NoProfile -File scripts\set-claude-config.ps1        # Claude Code 配置（安装 + settings.json env 幂等合并 + omc 残留清理）
pwsh -NoProfile -File scripts\set-reasonix.ps1             # Reasonix Desktop 接管（DeepSeek 密钥复用，config.toml + .env + 桌面快捷方式，幂等）
pwsh -NoProfile -File scripts\set-agent-secret-guard.ps1   # Agent 密钥泄露防护 hook（Claude Code / Codex / Kimi / Reasonix，幂等合并，命令用 python3）
pwsh -NoProfile -File scripts\set-claude-statusline.ps1    # Claude Code 状态栏幂等合并（statusLine 块，纯 PowerShell）
pwsh -NoProfile -File scripts\set-fnm-config.ps1           # fnm/Node 接管（FNM_DIR/镜像/PATH/profile/.npmrc，幂等）
pwsh -NoProfile -File scripts\set-bun-config.ps1           # bun 镜像源（全局 ~/.bunfig.toml + 局部 bunfig.toml，幂等）
pwsh -NoProfile -File scripts\set-nushell-config.ps1       # 官方 nushell 插件注册（nu_plugin_* 逐个 plugin add，幂等）
pwsh -NoProfile -File scripts\set-rust.ps1                 # Rust 接管（rustup + stable + rsproxy.cn 镜像，幂等）
pwsh -NoProfile -File scripts\set-python-config.ps1        # Python3 命令别名（python.exe → python3.exe，与 Linux 对齐，幂等）
pwsh -NoProfile -File scripts\set-vsbuild.ps1              # VS Build Tools 接管（离线布局 --noWeb 安装，需提权，幂等）
pwsh -NoProfile -File scripts\set-docker.ps1               # Windows 容器 Docker Engine 接管（官方 static 二进制 + 服务注册，需提权）
pwsh -NoProfile -File scripts\set-wsl.ps1                  # WSL 安装/更新（microsoft/WSL 官方 x64 MSI，需提权）
pwsh -NoProfile -File scripts\set-wsl-distro.ps1           # WSL 镜像导入/部署（.wsl 产物 → distro，参考 ohmywsl2）
pwsh -NoProfile -File scripts\build-wsl-image.ps1          # 构建 ohmywsl WSL 镜像模板（官方 Ubuntu → EnvRoot\images\wsl，组件脚本 scripts\wsl\）
pwsh -NoProfile -File scripts\deploy-omp.ps1               # 部署 omp 模块到 EnvRoot\modules\omp（幂等）
pwsh -NoProfile -File scripts\sops-encrypt-anthropic.ps1   # ANTHROPIC_API_KEY SOPS 加密备份
pwsh -NoProfile -File scripts\sops-test.ps1                # SOPS 冒烟测试
pwsh -NoProfile -File scripts\verify-codex-handover.ps1    # codex 原生版交接验证（PASS/FAIL）
```

## 提交约定

- 前缀 `feat:`（功能/脚本）/ `docs:`（仅文档）/ `fix:`（修坑）/ `chore:`（杂项）+ 中文描述，如 `feat: Codex 状态栏升级专业组合`
- 一次提交只做一件事，先维护在本地 `main` 分支；远端推送按用户指示进行

## 设计原则

- **引导安装不依赖 gh（bootstrap 自举）**：首次安装或恢复环境时，不得把已装好的 gh 当作先决条件；通过 `api.github.com` REST API 查询发布资产并直连下载（带 User-Agent、按 tag 查询、失败重试）。
- **API 限流全局 gh 兜底**：api.github.com 匿名限流（60 次/小时）时，所有查询统一走 `Invoke-GitHubApi`，自动切换到 `gh api` 认证通道（5000 次/小时）；gh 仅在已安装后作为加速/兜底通道。
- **版本不硬编码，先 pin 后 update**：工具定义（`New-ToolDef`）只含静态元数据，版本/Tag/资产名只存在于 `scripts\env.psd1`（唯一 pin 来源）；新工具先 `ohmyenv pin <tool> [-Latest | -Version X]`，之后用 `ohmyenv update <tool>` 升级并重新 pin。
- **产物分类（安装包 vs 部署包）**：安装包类（pwsh7 / codex / claude / kimi / git / 7z）只归档原始 installer，二次部署直接安装 + 配置，不进入绿色 EnvRoot；部署包类（age / sops / gh / aria2 / uv / python / rg / jq / yq / rmux / starship / dotnet / fnm / bun / gsudo / oscdimg）单二进制/绿色 zip + PATH 部署，进入 EnvRoot。判据：官方单二进制/绿色 zip → 部署包；官方安装器装系统位置 → 安装包。
- **可重定位**：EnvRoot / 项目根不硬编码绝对路径（`D:\ohmyenv` / `D:\ohmypwsh` 等），由配置默认值 + 参数/环境变量覆盖，Bin/Exe/cache/tools 一律从 EnvRoot 推导；保证产物压缩包换机/换路径可还原。
