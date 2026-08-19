# Changelog

本项目变更记录，格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [Unreleased]

### Added

- 建立 `AGENTS.md` 规则 1：踩坑必须当场沉淀为脚本或文档命令
- 建立 `AGENTS.md` 规则 2：环境感知，默认使用 pwsh（PowerShell 7）
- 建立 `AGENTS.md` 规则 3：文档规范（CHANGELOG / ROADMAP / `docs\plans\` 方案文档）
- 建立 `docs\` 文档骨架：`docs\README.md` 总览与 `docs\plans\0000-template.md` 方案模板
- 建立 `AGENTS.md` 设计原则：引导安装不依赖 gh（bootstrap 自举，走 api.github.com 查询 gh/git 二进制包）
- 建立方案 `docs\plans\0001-env-deps.md`：环境依赖管理（gh/git 自举安装到 `D:\ohmyenv`）
- 实现 `scripts\ohmyenv.ps1` CLI：query / deploy / install / update / lock / status，全部通过 api.github.com 查询下载（不依赖已装 gh）
- 建立 `scripts\env.psd1` 锁定清单（版本 + sha256 回填）
- gh/git 正式移交本项目管理：安装在 `D:\ohmyenv\gh`、`D:\ohmyenv\git`，旧文件改名保留（`*.removed-20260819`）
- 建立研究文档 `docs\research\gh-git-https-ssh.md`：HTTPS / SSH 互相配置指南（含本机实测状态与待办）
- 初始化 git 仓库（`main` 分支，根提交 `077e6b4`，含 `.gitignore`）
- 密钥管理：age 1.3.1、sops 3.13.3 接入 `ohmyenv` CLI（新增 `zip` 单目录展平与单文件 `copy` 解压类型）
- 生成 age 密钥（`%APPDATA%\sops\age\keys.txt`），设置 `SOPS_AGE_KEY_FILE`，建立 `.sops.yaml` 与 `scripts\sops-test.ps1` 冒烟测试
- 建立方案 `docs\plans\0002-codex-takeover.md`：Codex 二进制与 DeepSeek 密钥管理接管（已完成）
- 工具接管 rg/jq/yq：ohmyenv 新增工具定义（rg zip 展平、jq/yq copy 单文件），pin 15.2.0 / 1.8.2 / 4.53.4，部署到 `D:\ohmyenv` 并前置注册 PATH（aria2 下载 + sha256 回填）
- 交接验证脚本 `scripts\verify-tools-handover.ps1`：新终端一键验证 rg/jq/yq/rmux 解析路径与版本（PASS/FAIL）
- 建立方案 `docs\plans\0003-tools-takeover.md`：D:\Oh-My-Claude 工具批量接管（rg/jq/yq）
- 工具分层：ohmyenv 工具按「核心基础工具（密钥 age/sops / 智能体环境 codex / 项目管理 git/gh / 基础工具 aria2/7z）+ 扩展工具（rg/jq/yq）」分层，`ToolNames` 重排为引导顺序（核心先装齐再扩展）
- `ohmyenv daily` 日常无影响更新：同主版本自动升级并重新锁定，跨主版本保留待人工确认（`-DryRun` 预览 / `-IncludeBreaking` 强制），日志 `D:\ohmyenv\logs\update-daily.log`，退出码 0/2
- 建立方案 `docs\plans\0004-tool-tiers.md`：工具分层、引导安装顺序与日常无影响更新
- AGENTS.md 常用命令新增 `ohmyenv daily`（预览 + 实跑）
- rmux 接入 ohmyenv：0.10.0（扩展工具），zip 展平 + SHA256SUMS 官方校验，部署到 `D:\ohmyenv\rmux` 并前置注册 PATH；版本识别用 `-V`（tmux 风格，`--version` 不支持）
- starship 接管：1.26.0（扩展工具），zip 展平 + sha 回填（无统一 SUMS，走下载后回填）；配置 `~\.config\starship.toml` 保留（默认路径零迁移），profile Starship init 块保留
- 建立方案 `docs\plans\0005-starship-takeover.md`：starship 接管（配置保留）与 PowerShell 模块/调试清理
- starship PowerShell 专用配置：研究文档 `docs\research\starship-config.md`（gh api 拉官方配置文档核实）+ `scripts\set-starship-config.ps1` 全模板幂等写入（唯一源，`-Force` 覆盖，保留原符号预设）
- 研究文档 `docs\research\powershell-dotnet-vsbuild.md`：PowerShell 模块 / .NET 库 / VS Build Tools 现状与接管建议（纯研究）
- PowerShell 模块清理完成（2026-08-19）：删除用户级 PSReadLine / WslInterop 副本与 PSFzf 残留，清空 `PSModulePath` 用户变量；pwsh 7 与 Windows PowerShell 5.1 均回到系统原生模块（pses 死路径一并移除）
- 残留目录清除（重启后锁释放）：`Documents\PowerShell\Modules` / `Documents\WindowsPowerShell\Modules` 用户模块目录整体删除，用户模块路径归零；Pester 3.4.0 / PSReadLine 2.0.0 为系统内置保留
- 研究文档 `docs\research\omc-psmodule-management.md`：omc 的 PowerShell 模块管理机制（本地 nupkg 仓库 + PS5/PS7 交叉部署 + 锁文件）与清理后残留盘点
- 研究文档补充「对 ohmyenv 的参考价值」：可借鉴（本地仓库/先 lock/双份部署认知/profile 标记）与应避免（仓库注册残留/WebClient/旧 PowerShellGet/锁散落/无校验拷贝），含接管建议方向
- PowerShell 模块管理器 `scripts\psmodule.ps1`：list / pin / install / update / uninstall / pack；在线（PSGallery → `D:\ohmyenv\cache\modules` → 部署）与离线（`-File` nupkg）同一部署路径；默认共享部署 `D:\ohmyenv\modules` + 用户 PSModulePath 追加（PS5/PS7 同见）；`modules.psd1` 唯一锁源（sha256 回填）
- 建立方案 `docs\plans\0006-psmodule-manager.md`：PowerShell 模块管理器（在线/离线、PS5/PS7、自研模块打包）
- 研究文档 `docs\research\powershell-encoding.md` + AGENTS 规则 4：PS5/PS7 编码兼容优先注意（PS5.1 无 BOM 按 ANSI 读取，自研 manifest 必须 UTF-8 带 BOM）
- uv/Python 接管：`uv` 0.12.5（最新）与 `python` 3.12.14（python-build-standalone 3.12 线 install_only）由 ohmyenv 管理，部署到 `D:\ohmyenv\uv` / `D:\ohmyenv\python`；新增静态 `VersionPattern`（python 版本从资产名提取）
- 建立方案 `docs\plans\0007-uv-python-takeover.md`：uv/Python 接管（uv 最新 + Python 3.12 为准）

### Changed

- 版本管理重构：`New-ToolDef` 不再硬编码版本；`env.psd1` 为唯一 pin 来源，新增 `pin` 命令（`lock` 为别名），流程改为“先 pin 后 update”
- 下载通道：aria2（`D:\ohmyenv\aria2` 1.37.0）多线程优先，curl / Invoke-WebRequest 兜底
- 按研究文档补齐本机配置：`gh auth setup-git`（HTTPS 走 gh 凭据助手）、ssh-agent 启用并加载密钥、`~/.ssh/config` 增加 github.com 条目、gh token 增加 `admin:public_key` scope
- 用户 PATH：移除 `D:\Oh-My-Claude\.envs\base\git\cmd`，前置注册 `D:\ohmyenv\gh\bin`、`D:\ohmyenv\git\cmd`
- omc 注册表移除 gh/git（`$BaseTools` 只保留 7z / aria2）
- GitForWindows 注册表与 `CLAUDE_CODE_GIT_BASH_PATH` 指向 `D:\ohmyenv` 的新安装
- Codex 接管落地：0.148.0 原生二进制（`D:\ohmyenv\codex`，SHA256SUMS 校验 + targz 解压），npm 版保留双轨共存
- 沙箱永久关闭：`sandbox_mode = "danger-full-access"` + `approval_policy = "never"` 合并写入（未覆盖原配置）
- DeepSeek 密钥迁移：交互式设置用户级 `DEEPSEEK_API_KEY`（`scripts\set-deepseek-key.ps1`），`config.toml` 改用 `env_key`，明文清除
- 7-Zip 接管：26.02 部署到 `D:\ohmyenv\7z`，新增 `7z-archive` 解压类型（Windows tar 直接解包，无需预装 7z），omc 注册表移除并改名保留旧文件
- 交接确认脚本 `scripts\verify-codex-handover.ps1`：新终端一键验证 codex 解析到原生版（PASS/FAIL）
- Codex 交接完成：npm `@openai/codex` 已卸载，shim 清除；doctor 确认 `managed by npm: no`、`update action: manual`（更新只走 ohmyenv）
- DeepSeek key 的 SOPS 加密副本：`.secrets\deepseek.env.enc`（可提交），新增 `scripts\sops-encrypt-deepseek.ps1` 一键加密/回读验证；明文不入库（`.gitignore` 保护）
- Codex 安装后增强配置功能：独立脚本 `scripts\set-codex-statusline.ps1` 幂等合并 `[tui]` 状态栏（`model-with-reasoning` / `git-branch` / `context-remaining`，彩色开关 `-NoColors`），不覆盖 DeepSeek/沙箱/信任项目等既有配置；`codex doctor` 确认 `config.toml parse ok`
- 建立研究文档 `docs\research\gh-cli.md`：gh 2.91.0 本机现状（认证/scopes/配置）、API 限流兜底通道、命令能力地图、与 ohmyenv 衔接及按需特性建议
- 文档规范扩展（AGENTS.md 规则 3）：`docs\research\` 研究文档纳入四块文档体系，`docs\README.md` 更新文档地图、命名约定与研究文档索引
- 状态栏升级为专业组合（对照 0.148.0 源码核实全量可选项）：`run-state` + `model-with-reasoning` + `git-branch` + `branch-changes` + `context-remaining` + `used-tokens` + `permissions`，主题色按类别区分（青/绿/品红）；`scripts\set-codex-statusline.ps1` 默认值同步更新
- 建立研究文档 `docs\research\codex-statusline.md`：状态栏可选项全量清单（官方描述 + 渲染示例）、样式机制（` · ` 分隔符、主题色 accent）、`/statusline` 交互行为、推荐配置与注意事项
- 状态栏补回项目目录显示：`current-dir`（当前工作目录完整路径）加入默认组合，与 `git-branch` / `branch-changes` 一并置于状态栏最后（`… · danger-full-access · D:\ohmypwsh · main · +12 -3`），`run-state` + `model-with-reasoning` + 用量/权限在前；`scripts\set-codex-statusline.ps1` 默认值与已应用配置同步更新
- 分隔符研究（gh 源码核实）：` · ` 为硬编码常量 `STATUS_LINE_SEPARATOR`，`[tui]` 无 separator 配置键，未知状态栏项被静默忽略，无法改用 `|`；结论已沉淀进 `docs\research\codex-statusline.md`
- 目录与分类规范（AGENTS.md 新增章节）：脚本 / 文档 / 配置 / 密钥数据 / 环境目录五类物理分离，新增文件必须归入对应目录（参考 `D:\hyper-v-lab` 的 AGENTS.md 风格），`docs\README.md` 增加指引
- 项目目录与文件索引：`docs\README.md` 新增完整目录树（根文件 / `.secrets` / `docs` / `scripts` 逐文件说明）与外部环境目录说明，AGENTS.md 分类要点指向该索引
- 建立对标研究 `docs\research\agents-docs-benchmark.md`：用 gh 调研 agentsmd 开放格式 / openai-agents-python / codex / zed 的 AGENTS.md 与文档结构，结论：本仓五要素齐全已属前列，建议补常用命令节、提交约定成文、根 README（待确认）
- 对标研究三项建议落地：AGENTS.md 新增「常用命令」（ohmyenv 全家 + PATH 重建 + 日常脚本）与「提交约定」（feat/docs/fix/chore 前缀）；根目录新增 `README.md` 项目入口；`docs\README.md` 目录索引同步
- omc 注册移除 ripgrep/jq/yq：`$ToolDefs` 清出，定义文件与二进制改名保留（`*.removed-20260819`），`CLAUDE.md` 同步标注已移交
- ohmyenv CLI 工具清单扩展为 10 个（gh/git/age/sops/codex/aria2/7z/rg/jq/yq），帮助文本同步
- 踩坑沉淀扩展（`docs\research\ohmyenv-pitfalls.md`）：新增工具接入四件套、omc 移交五步清单、进程 PATH 与注册表 PATH 差异、无 v 前缀 tag 兼容、单文件 copy 解压
- `ohmyenv status` 按「核心基础工具 / 扩展工具」两层 + 子分组展示，顺序 = 引导链
- 日常实测升级：git 2.54.0 → 2.55.0.windows.4、gh 2.91.0 → 2.97.0（同主版本，无影响）
- 自动升级任务方案取消：不注册 Task Scheduler，`ohmyenv daily` 保持手动执行（2026-08-19 用户指示）
- PowerShell 清理（2026-08-19 用户指示，直接删除不留备份）：profile（pwsh7/5.1）删除 PSFzf 块仅留 Starship；删除用户级 Pester 5.7.1 / PSScriptAnalyzer 1.25.0 / PSFzf 2.7.10（`WindowsPowerShell\Modules` 与 `PowerShell\Modules` 双份）+ PowerShellEditorServices + pses 调试组件；omc 注册清空 `$PsModules`、移除 pses
- 交接验证脚本扩展 starship（含配置文件就位检查）
- `~/.config/starship.toml` 应用 PowerShell 专用提示行（format 结构 / 性能选项 / `❯`-`✖` 输入符 / pwsh shell 标识），新终端生效
- Windows PowerShell 5.1 PowerShellGet 1.0.0.1 → 2.2.5（CurrentUser + TLS 1.2）；用户 PSModulePath 恢复标准 CurrentUser 路径
- omc 模块管理残留清理：注销 `OhMyClaude` PSRepository（双 shell）、删除 LocalRepo nupkg 与模块锁文件、删除孤儿 `psmodule.ps1`
- 实测：Pester 5.7.1 在线安装 + 自研 `OhMyDemo` 离线安装均通过 pwsh7 与 PS5.1 验证（测试模块已卸载）
- `UV_*` 用户环境变量全部迁入 `D:\ohmyenv`（uv-cache / python / uv-tools / uv-tools\bin / install dir），PATH 前置 `D:\ohmyenv\python\Scripts` 与 `D:\ohmyenv\uv-tools\bin`；源确认：pip/uv 走 aliyun、python 下载走 nju 镜像
- omc 移除 uv 注册（`$BaseScripts` 清出、`uv.ps1`/`uv.exe` 改名保留、CLAUDE.md 同步）；claude 2.1.187 验证仍可用

### Fixed

- `Get-InstalledVersion` 数组展开 bug（`@versionArgs` 解析异常导致所有工具显示未安装）
- 7z 版本解析（首行为空行）
- `Get-EnvLock` 静态元数据与锁文件同步（如 Extract 类型变更）
- `Invoke-GitHubApi` 全局兜底扩展到 5xx 网关错误（不限于 403 限流）
- 文档状态同步：ROADMAP 阶段 3 翻转为已完成（章节标题与旧待办清理）、方案 `0002-codex-takeover.md` 状态与实施步骤同步为已完成、CHANGELOG 末尾错位的「### Changed」区块并入主区块
- 升级时 sha256 误用旧锁定值：已有锁定 sha 的工具升级到新版本被旧 sha 拒绝 → 仅同版本比对，新版本接受并回填
- 7zsfx 解包后立即读版本可能瞬态失败 → 版本读取加重试（5 次退避）
- 安装中断导致「已装新版本但锁定滞后」→ `update` 跳过分支补齐锁定与 sha
- aria2 报 OK 但文件残缺（SSL 断连后 96% 停住）→ 升级链 sha 回填 + 安装后版本校验兜底，残缺缓存清除后重下
- starship 非交互噪音：profile（pwsh7 / 5.1）Starship 初始化加 `TERM`/`ConsoleHost` 守卫，`TERM=dumb`（Codex CLI / 脚本管道）不再打印 starship 错误，交互终端渲染不受影响
- `targz` 解压后未展平顶层单目录：python-build-standalone 的 `python/` 包裹层导致版本读取失败 → `targz` 与 zip 同样做单目录展平
