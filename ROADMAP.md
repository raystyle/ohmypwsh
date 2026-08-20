# ROADMAP

项目阶段与里程碑。状态：`未开始` / `进行中` / `已完成` / `挂起`。

## 阶段总览

| 阶段 | 目标 | 状态 |
| --- | --- | --- |
| 0 | 项目基础设施：AGENTS 规则、文档规范 | 已完成 |
| 1 | 环境依赖管理：独立 D 盘环境目录，自建 gh/git 安装管理 | 已完成 |
| 2 | 密钥管理：age + SOPS 接入 ohmyenv，.sops.yaml 与冒烟测试 | 已完成 |
| 3 | Codex 接管：原生二进制 + 沙箱 + DeepSeek 密钥迁移到 env_key | 已完成 |
| 4 | 软件工具扩展：核心基础工具先装齐，扩展工具稳定扩展，pwsh7/7z 等部署方式完善，日常无影响更新 | 进行中 |
| 5 | 项目重定位：可迁移 Agent 环境部署与管理模块 CLI（EnvRoot 重定位、bootstrap、omp 模块、pack/unpack） | 未开始 |

## 阶段 0：项目基础设施（已完成）

- 建立 AGENTS.md 规则 1（踩坑当场沉淀）、规则 2（环境感知，默认 pwsh）、规则 3（文档规范）
- 建立 CHANGELOG / ROADMAP / `docs\plans\` 文档骨架

## 阶段 1：环境依赖管理（已完成）

目标：参考 D:\Oh-My-Claude 的 omc 机制，在 D 盘独立系统环境目录（`D:\ohmyenv`）安装 gh 与 git，并在项目内沉淀安装管理脚本（`scripts\`），随后清理旧安装。

方案：`docs\plans\0001-env-deps.md`（bootstrap 不依赖 gh，通过 api.github.com 查询二进制包）。

完成项：

- `scripts\ohmyenv.ps1` CLI（query / deploy / install / update / lock / status）+ `scripts\env.psd1` 锁定清单
- gh 2.91.0、git 2.54.0.windows.1 安装于 `D:\ohmyenv`，版本与 sha256 已锁定
- omc 注册表移除 gh/git；旧文件改名保留（`*.removed-20260819`），确认无误后可删除
- 用户 PATH 前置新目录、移除旧 git 路径；gh 登录状态正常（keyring）

## 阶段 2：密钥管理（已完成）

- age 1.3.1、sops 3.13.3 接入 `ohmyenv`（查询/下载/锁定/sha256/PATH 统一管理）
- 生成 age 私钥 `%APPDATA%\sops\age\keys.txt`，设置 `SOPS_AGE_KEY_FILE` 用户环境变量
- 建立 `.sops.yaml`（公钥）与 `scripts\sops-test.ps1` 冒烟测试（已通过）

## 阶段 3：Codex 接管（已完成）

- 方案：`docs\plans\0002-codex-takeover.md`
- 二进制：npm 包（0.147.0）→ ohmyenv 原生（0.148.0，`D:\ohmyenv\codex`）
- 沙箱：`sandbox_mode=danger-full-access` + `approval_policy=never`（合并写入，已生效）
- 密钥：`experimental_bearer_token` 明文 → `DEEPSEEK_API_KEY` 用户环境变量 + `env_key`（已生效，SOPS 加密副本见下）
- 已完成：原生部署、doctor 验证、aria2 下载通道（7.1MiB/s）
- 已完成：npm 交接清理（`@openai/codex` 卸载、shim 清除、doctor 确认单一原生来源）
- 已完成：7zip 接管（`D:\ohmyenv\7z` 26.02，omc 已移除，`7z-archive` 用 tar 解包）
- 已完成：DeepSeek key SOPS 加密副本（`.secrets\deepseek.env.enc`，换机/轮换可恢复）
- 已完成：状态栏增强配置（`[tui] status_line` 独立脚本 `scripts\set-codex-statusline.ps1` 幂等合并，`codex doctor` 验证 parse ok）

## 阶段 4：软件工具扩展（进行中）

目标：核心基础工具先装齐（密钥 age/sops、智能体环境 codex、项目管理 git/gh、基础工具 aria2/7z），环境稳定后再扩展（rg/jq/yq 及后续工具）；日常更新走「无影响」策略（同主版本自动、跨主版本人工确认）。

- 已完成：工具四层分类与引导顺序（`ToolNames` 重排为 age → sops → codex → git → gh → aria2 → 7z → rg → jq → yq，`status` 按核心/扩展分组）
- 已完成：首批扩展工具接管 rg/jq/yq（15.2.0 / 1.8.2 / 4.53.4，omc 注册移除，交接验证 PASS）
- 已完成：`ohmyenv daily` 日常无影响更新（同主版本自动、跨主版本待确认，`-DryRun` / `-IncludeBreaking`，日志 `D:\ohmyenv\logs\update-daily.log`）
- 已完成：升级链加固（sha 旧值误用修复、7zsfx 版本读取重试、滞后锁定补齐）
- 已完成：日常实测升级 git 2.54.0 → 2.55.0.windows.4、gh 2.91.0 → 2.97.0
- 已完成：扩展工具 rmux 接入（0.10.0，SHA256SUMS 校验）
- 已完成：扩展工具 starship 接管（1.26.0，配置 `~\.config\starship.toml` 与 profile init 保留）
- 已完成：starship PowerShell 专用配置（gh 研究文档 + `set-starship-config.ps1` 幂等模板）
- 已完成：PowerShell 清理（Pester/PSScriptAnalyzer/PSFzf/pses 直接删除，profile 仅留 Starship）
- 已完成：PowerShell 模块管理器（`psmodule.ps1`：在线/离线安装、自研模块打包、PS5/PS7 共享部署；`modules.psd1` 唯一锁源）
- 已完成：Windows PowerShell 5.1 PowerShellGet 1.0.0.1 → 2.2.5；omc 模块管理残留清理（OhMyClaude 仓库/nupkg/锁/孤儿库）
- 已完成：PS5/PS7 编码兼容优先规则（AGENTS 规则 4 + 研究文档）
- 已完成：uv/Python 接管（uv 0.12.5 最新 + Python 3.12.14 为准，`UV_*` 全部迁入 `D:\ohmyenv`，源确认为 aliyun/nju，omc 注册移除）
- 已完成：Claude Code 扩展配置（2.1.233 + GLM-5.3[1m] 1M 上下文 + bigmodel 端点 + 遥测关闭；密钥 SOPS 加密保存）
- 已完成：Claude Code 完全接管（YOLO 对齐 Codex + 状态栏纯 PowerShell + 配置收敛 settings.json env + 用户环境变量/`~/.claude` omc 残留清理 + omc 侧 claude 安装器/Profile/旧 exe 删除；`claude -p` 实测 model=glm-5.3[1m]）
- 已完成：rmux 双端项目级 skill（已迁移至独立仓库 https://github.com/raystyle/win-rmux；本项目只维护 rmux 的安装管理）
- 已完成：pwsh7 v7.6.5 纳入工具清单（安装包类，MSI + `hashes.sha256` 校验，`Extract='msi'`）
- 已完成：`scripts\set-pwsh.ps1` 一键幂等安装/升级（PS5.1 兼容 + UTF-8 BOM，检测 → 新装/升级
  /跳过 → 提权 → msiexec → 验证）；实测关闭所有 pwsh 后 cmd 启动升级 7.6.4 → 7.6.5 成功
- 已完成：PowerShell 7 遥测关闭（`DISABLE_TELEMETRY=1` + `POWERSHELL_TELEMETRY_OPTOUT=1` +
  `POWERSHELL_UPDATECHECK=Off`）
- 已完成：7z 绿色部署收敛（`7z-extra`：7zr.exe 解压 `7zXXXX-extra.7z` → x64/7za.exe shim 成
  `7z.exe` 单文件 1.3MB，替换旧的 tar 解压多文件部署；实测解压功能正常）
- 已决定：不挂自动升级任务（2026-08-19 用户指示，`ohmyenv daily` 保持手动执行）
- 待办（可选）：按需继续接管更多扩展工具
- 已完成：PowerShell 模块 / .NET 库 / VS Build Tools 研究（`docs\research\powershell-dotnet-vsbuild.md`）
  —— 结论：模块按需 `Install-PSResource`（已有 `psmodule.ps1`）；.NET SDK 可接管但需扩展 CDN
  直链下载源（最新 10.0.400，官方 CDN 非 GitHub）；VS Build Tools 体积数 GB 维持 omc
- 已完成：.NET SDK 接管（10.0.400，`CdnUrl` CDN 直链下载源扩展 + 部署到 `D:\ohmyenv\dotnet` +
  PATH 前置，实测 `dotnet --list-sdks` 10.0.400）
- 已完成：Node.js/npm 接管（fnm 1.39.0 部署到 `D:\ohmyenv\fnm` + `set-fnm-config.ps1` 幂等配置
  `FNM_DIR=D:\ohmyenv\fnm-data`/镜像 npmmirror/profile 块/`.npmrc` registry；`fnm install --lts`
  安装 node v24.19.0 并设默认；项目根 `.nvmrc` 无缝切换）
- 已完成：Bun 接管（oven-sh/bun 1.3.14 部署到 `D:\ohmyenv\bun` + `set-bun-config.ps1` 幂等配置
  全局 `~/.bunfig.toml` / 局部 `bunfig.toml` 镜像 npmmirror）
- 已完成：gsudo 接管（gerardog/gsudo 2.6.1 部署到 `D:\ohmyenv\gsudo`，专用 x64 展平解压 +
  命令统一叫 `gsudo`，不建 `sudo` 别名，避免 Windows 内置 sudo 冲突）

## 阶段 5：项目重定位（未开始，远期）

目标：把项目本质收敛为「可迁移 Agent 环境部署与管理模块 CLI」——从原生 PS5.1 一键初始化，升级
pwsh7，部署模块 CLI，产物分安装包/部署包两类，支持压缩包跨机还原已 pin 工具环境。

方案：`docs\plans\0010-portable-agent-env.md`。

预研（阶段 4 期间已提前摸清，正式推进待本阶段启动）：

- 项目本质定位落盘（README / AGENTS.md「项目定位」/ 方案 0010）
- 产物分类定稿：安装包（pwsh7 / codex / claude / kimi / git / 7z，只归档 installer，二次安装）
  vs 部署包（age / sops / gh / aria2 / uv / python / rg / jq / yq / rmux / starship，单二进制
  + PATH，进 EnvRoot）
- EnvRoot 可重定位起步：`Get-DefaultEnvRoot`（环境变量 `OHMYENV_ROOT` > D 盘存在 > C 盘回退）
  + `-EnvRoot` 参数覆盖
- omp 模块起步：`scripts\omp.psm1`（`Invoke-Omp` + `omp` 别名，复用 ohmyenv 全部命令）
- `ohmyenv pack` 实测成功：产出 `D:\ohmyenv\deploy\ohmyenv-deploy-<时间戳>.zip`（426 MB，含
  密钥 + agent 配置 + 部署包 + 安装包 + manifest）；`unpack` 已实现幂等（>= pin 跳过 / < pin
  升级 / 未装部署）

正式待办（本阶段启动后推进）：

- 扫清残留硬编码：`set-claude-config.ps1`（`D:\ohmyenv`）、`set-claude-statusline.ps1`
  （`D:\ohmypwsh`）、`verify-codex-handover.ps1`（`D:\ohmyenv`）
- `omp.psd1` 模块清单（omp.psm1 已有，补清单 + 安装到 PSModulePath）
- PS5.1 兼容 `bootstrap.ps1`（装 pwsh7 + 部署 omp 模块 + 注册 PATH，人类初始部署入口）
- `ohmyenv unpack` 换机/换路径还原实测（验收标准 2）
