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
- Claude Code 扩展配置：`scripts\set-claude-config.ps1`（uv 安装 claude-code 2.1.233 至 `D:\ohmyenv\uv-tools\bin` + 25 项优化环境变量 + settings.json `env` 块合并：GLM-5.3[1m] / glm-4.7 / 1M 压缩窗口，保留原权限配置，无插件/hook）
- Claude Code 密钥加密：`scripts\set-claude-key.ps1`（`-FromOmcProfile` 迁移 GLM token → `ANTHROPIC_API_KEY` 用户环境变量，不回显）+ `scripts\sops-encrypt-anthropic.ps1`（`.secrets\anthropic.env.enc`，加密/解密回读验证）
- 建立方案 `docs\plans\0008-claude-code-config.md`：Claude Code 扩展配置（GLM-5.3 1M 上下文）
- Claude Code 状态栏对齐 Codex：`scripts\claude-statusline.ps1`（纯 PowerShell，stdin JSON → 模型/ctx[1M]/tokens/成本/目录/分支+变更，纯 ASCII 输出防乱码）+ `scripts\set-claude-statusline.ps1`（幂等合并 settings.json `statusLine` 块）；研究文档 `docs\research\claude-code-statusline-api.md`
- Claude Code 完整 YOLO：settings.json permissions 只留 `defaultMode: bypassPermissions`（对齐 Codex danger-full-access + approval never）；修复 `disableBypassPermissionsMode` 非法布尔值导致整个 settings.json 被跳过、env 不生效回落内置模型的问题
- Claude Code 配置收敛：settings.json env 块 29 项（模型三档/1M 压缩窗口/遥测/超时/编码/PowerShell 工具/子代理模型），用户环境变量只留 `ANTHROPIC_API_KEY` + `ANTHROPIC_BASE_URL`
- `set-claude-key.ps1` 重写为 Codex 风格：交互输入 → 用户环境变量 → 自动 SOPS 加密备份（回读验证、明文即删）
- rmux 双端项目级 skill：`.claude\skills\rmux\SKILL.md`（Claude Code）与 `.agents\skills\rmux\SKILL.md`（Codex，仓库根向上扫描），经 skill-creator `quick_validate` 校验；研究文档 `docs\research\rmux-usage.md`（send-keys 目标/tiny CLI/备屏捕获等实测坑）
- 方案文档 `docs\plans\0009-claude-takeover.md`：Claude Code 完全接管（YOLO/状态栏/env 收敛/omc 清理/双端 rmux skill）
- 建立方案 `docs\plans\0010-portable-agent-env.md`：项目本质重定位为「可迁移 Agent 环境部署与管理模块 CLI」（原生 PS5.1 bootstrap → 升级 pwsh7 → 部署模块 CLI → 工具/agent/密钥管理 → 产物压缩包跨机还原）
- 产物分类定稿：安装包（pwsh7 / codex / claude / kimi / git / 7z，只归档原始 installer，二次部署直接安装配置，不进绿色 env）vs 部署包（age / sops / gh / aria2 / uv / python / rg / jq / yq / rmux / starship，单二进制 + PATH 进 EnvRoot）
- README / AGENTS.md「项目定位」/ ROADMAP 阶段 5 同步新定位与三条主链（bootstrap / 管理 / 迁移）
- pwsh7 纳入工具清单（安装包类）：`New-ToolDef` 新增 `pwsh`（`PowerShell/PowerShell`，MSI 资产 + `hashes.sha256` 校验，`Extract='msi'`，`Exe='%LOCALAPPDATA%\Programs\PowerShell\7\pwsh.exe'`）；`ToolNames` 置顶为 agent 层第一工具；pin `v7.6.5`
- ohmyenv 支持 `msi` 安装类型：下载 MSI 到缓存 → per-user 静默安装（`MSIINSTALLPERUSER=1`，不需管理员）→ 版本验证；msi 类 Bin 为空不注册 env PATH，`status` 对 msi 用 `ExpandEnvironmentVariables` 解析系统路径
- PowerShell 7 一键幂等安装/升级脚本 `scripts\set-pwsh.ps1`（PS5.1 兼容 + UTF-8 BOM）：检测系统已装 pwsh7（Program Files / LOCALAPPDATA）→ 决定新装 / 升级 / 跳过；非管理员自动提权重启；缓存复用 MSI；msiexec 静默安装（UpgradeCode 自动替换旧版）；重新检测验证版本。因 pwsh 不能安全自更新（替换正在运行的 exe/dll 破坏会话），由 `powershell.exe` 独立运行
- PowerShell 7 遥测关闭：`set-pwsh.ps1` 安装/升级加 `DISABLE_TELEMETRY=1`，安装后幂等写用户级 `POWERSHELL_TELEMETRY_OPTOUT=1` + `POWERSHELL_UPDATECHECK=Off`；研究文档 `docs\research\powershell-telemetry.md`（官方 about_Telemetry + GitHub Issue 实测）

### Changed

- Claude Code 状态栏微调：移除成本（`$0.14`）显示；目录显示完整路径（如 `D:\ohmypwsh`）而非叶子名
- Claude Code 安装与配置完全移交 ohmyenv：omc 侧 `.scripts\base\claude.ps1`（安装器/Profile 系统）、`.config\claude\`（GLM/DeepSeek/Zyun 明文 profile）、`~/.local\bin\claude.exe`（旧 2.1.187）删除；omc.ps1 `$BaseScripts` 清空、CLAUDE.md 与 `.claude\rules\claude-config.md` 同步标注接管
- `set-claude-config.ps1` 重构：用户级只写 `ANTHROPIC_BASE_URL`，其余配置收敛进 settings.json env；幂等删除 omc 遗留环境变量（`[NullString]::Value` 真删）；PATH/PSModulePath 清理
- 用户环境变量与 `~/.claude` 清理：CLAUDE_*/BUN_*/RUSTUP_*/CARGO_HOME/LANG/ANTHROPIC_DEFAULT_*/AUTH_TOKEN、PATH 的 `D:\Oh-My-Claude\*` 与 `.local\bin`、PSModulePath 死路径全删；`~/.claude` 旧 settings.local.json/插件（raystyle statusline/dev-fix + marketplace）/缓存/备份/history/daemon 残留清理
- Claude Code 完全从零重置（用户指示）：`~/.claude` 目录与 `~/.claude.json` 整体删除（含 12 个旧用户 skill：astgrep/browse/bunsh/github/google/grok/gx/md2pdf/mdcheck/nuevo/twitter/uvsh 与运行时状态），随后用 `set-claude-config.ps1` + `set-claude-statusline.ps1` 重建 settings.json（env 29 项 + YOLO + statusLine），`claude -p` 冒烟验证通过
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
- `ANTHROPIC_BASE_URL=https://open.bigmodel.cn/api/anthropic` + 遥测关闭等优化 env 就位；`claude --version` = 2.1.233（新装，支持 `[1m]`）

- Codex 状态栏移除 `used-tokens`（会话累计 token 如 `2.09M used` 的冗余显示）：保留 `context-remaining` 反映 1M 窗口实际占用；`scripts\set-codex-statusline.ps1` 默认状态栏组合同步去除该项
- Claude Code 状态栏移除 token 总量显示（`27.2k tok` / `2.09M tok` 等累计值）：保留 `ctx [1M] %` 反映窗口占用；`scripts\claude-statusline.ps1` 删除 token 段
- rmux 会话/窗格/布局三组原语实测定稿：上 2 下 1 = `new-session` + `split-window -h` + `split-window -f -v`（`-f` 全宽跨整窗是下排全宽的关键，实测 layout 字符串与 pane 坐标落盘）；恢复 attach = 新 wt 窗口 `attach-session -d -t NAME`（关 wt 仅 detach，daemon/会话保留，恢复不 new 不 kill-server）；`docs\research\rmux-usage.md` 与双端 SKILL.md 同步
- Kimi Code 接管配置：`scripts\set-kimi-config.ps1` 按官方默认位置 `~/.kimi-code` 安装/更新维护（不进 `D:\ohmyenv`，与 Claude Code 一致）；幂等合并 `config.toml`：`default_model=kimi-code/k3` + `default_permission_mode=yolo` + `telemetry=false`
- Kimi 工作区信任：`set-kimi-config.ps1` 按 `workspaces.json` 批量写 `workspace-trust\<workspace_id>` 信任标记（`{"root":"<路径>","trustedAt":<unix 毫秒>}`），跳过目录 trust 弹窗；实测 `D:\ohmypwsh` 已标记
- Claude Code 状态栏 context 显示统一为 `context: 已用% (已用/窗口)`（如 `context: 0% (0/1M)`）：`claude-statusline.ps1` 用 `used_percentage` + `context_window_size` 计算窗口内占用（`FmtTok` 格式化 0/k/M）；Codex 状态栏为内置组件无自定义 command，无法用该格式，仅能 `context-used`（`Context 3% used`）+ `context-window-size`（`1M window`）近似
- Codex 状态栏精简：移除 `run-state`（Ready 状态）与 `permissions`（Full Access 显示）；`context-remaining` 换成 `context-used` + `context-window-size`（显示 `Context 3% used · 1M window`），与 Claude 已用%语义对齐；`set-codex-statusline.ps1` 默认组合同步
- rmux send-keys 回车原语实测修正：回车键名只有 `Enter` 有效（`C-m` 被当字面量 `^M` 污染输入框）；TUI agent（codex/claude/kimi）提交判断改用进程 CPU 增长（capture 因 alternate screen 为空），发送前记 CPU、发送后增量 >0.5 判定已提交，不再盲目连发回车；`docs\research\rmux-usage.md` 踩坑第 8 条 + SKILL.md「Agent 状态判断原语」同步

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
- Claude Code 首次启动卡「Select login method」：第三方 API Key 场景 onboarding 登录验证不自动跳过 → `~/.claude.json` 设 `hasCompletedOnboarding=true` 并清空 `customApiKeyResponses.rejected`（曾因 send-keys Up+Enter 连发误选「No」），固化进 `scripts\set-claude-config.ps1`（幂等）
- Claude Code 工作区信任弹窗：`~/.claude.json` `projects` 批量标记 `hasTrustDialogAccepted` / `hasTrustDialogHooksAccepted`（主工作区 `D:/ohmypwsh` 兜底），跳过信任确认
- Claude Code `/status` 的 `.local\bin` 安装警告：settings.json env 加 `DISABLE_INSTALLATION_CHECKS=1` 关闭 config mismatch 3 行；剩余 1 行 PATH 警告为 native 二进制编译内检查（`doctorDiagnostic.ts` 不受该变量控制）的已知假阳性，文档化保留
- Claude Code `/status` 的 `.local\bin` PATH 警告（用户决定改为官方 native 布局）：`set-claude-config.ps1` 新增 2.5 段——claude 二进制幂等同步到 `%USERPROFILE%\.local\bin\claude.exe`（size+mtime 比对）+ 目录加入用户 PATH（4.3 清理规则同步移除 `.local\bin` 过滤），实测 `/status` 诊断区零警告；rmux 新窗格用 `split-window -e "Path=..."` 注入新 PATH
- 新建研究文档 `docs\research\claude-code-onboarding.md`：onboarding 登录验证 / 信任弹窗 / 安装警告 / rmux 中文输入坑（跨引用 `rmux-usage.md`）
- `docs\research\rmux-usage.md` 新增「关闭 / 退出 rmux」实测章节：进程模型（daemon = `libexec\rmux\rmux.exe --__internal-daemon` + attached client + tiny CLI）、三层退出方式（detach / kill-session / kill-server，前缀键 Ctrl+B）、`kill-session` 只影响目标会话实测、彻底关闭验证与兜底
- `docs\research\rmux-usage.md` 新增「独立终端窗口运行 claude」实测：`new-session -d` + `Start-Process wt -w new` 弹窗 attach（`-WindowStyle Minimized` 不抢 Codex 焦点）；两个关键坑——新 daemon 继承启动 shell 环境（先重建 PATH 避免 native 警告复发）、Codex 沙箱 `Start-Process` 会继承 `TERM=dumb` 导致客户端无色彩（启动前设 `TERM=xterm-256color`，`list-clients` 从 dumb 变 xterm-256color）
- `docs\research\rmux-usage.md` 独立窗口流程改为「wt → rmux → claude」：窗口直接跑 `rmux new-session -A -s claude -c D:\ohmypwsh claude`（会话存在则 attach）；**无色彩真正根因 = Codex 沙箱注入的 `NO_COLOR=1`**（一路传给 daemon→窗格→claude，置空无效必须 `Remove-Item Env:NO_COLOR`）+ `TERM=dumb`；wt 路径改用 `(Get-Command wt.exe).Source` 动态解析不再硬编码 WindowsApps；实测 daemon 在最后一个会话被杀后自动退出
- `docs\research\rmux-usage.md` 补充 Codex 环境注入研究结论：`NO_COLOR=1`/`TERM=dumb` 等是 unified exec 硬编码常量表（`UNIFIED_EXEC_ENV`，源码 `codex-rs/core/src/unified_exec/process_manager.rs`），在 `shell_environment_policy` 之后覆写，`sandbox_mode=danger-full-access` 只关隔离不改这套注入 → 只能工作流层清理
- 双端 rmux skill 定稿 + Claude Code review 回归：Codex 侧（`.agents\skills\rmux`）与 Claude 侧（`.claude\skills\rmux`）统一为「新开终端窗口 + rmux 同终端多窗格分别操作 codex/claude」；skill-creator `quick_validate` 通过（PYTHONUTF8=1 解决 GBK 读取，uv --with pyyaml 补依赖）；按 Claude Code review 修复 8 项（单 agent 变体 cwd、TUI capture 空、会话复用守卫、旧 daemon 污染守卫、list-clients 竞态、`--wait-text`、tiny CLI 说明、PATH 副作用注释）+ 新增 send-keys 提交原语（发送后验证已提交，未提交补 Enter）；双窗格（codex+claude）真机回归通过（新窗口 xterm-256color 彩色、两侧均可操作）

### Removed

- rmux skill 迁移至独立仓库 https://github.com/raystyle/win-rmux：删除 `.agents\skills\rmux` / `.claude\skills\rmux` 双端 skill 与 `docs\research\rmux-usage.md`（研究已迁入 win-rmux 的 `skills/win-rmux/references/rmux-usage.md`）；本项目只保留 rmux 的 ohmyenv 安装管理（pin / update / pack 部署包类）
