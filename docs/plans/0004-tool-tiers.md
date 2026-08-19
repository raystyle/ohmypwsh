# 0004-tool-tiers — 工具分层、引导安装顺序与日常无影响更新

- 状态：已完成
- 日期：2026-08-19
- 关联：ROADMAP 阶段 4（项目核心目标）

## 背景与问题

- ohmyenv 已管理 10 个工具，原为平铺清单（gh/git/age/sops/codex/aria2/7z/rg/jq/yq），status / update 无层级语义
- 用户定义核心目标：**核心基础工具先装齐（密钥 / 智能体 / 项目管理 / 下载归档），环境稳定后再扩展**
- 日常更新需要「无影响」策略：同主版本自动执行，跨主版本人工确认

## 目标与非目标

- 目标：
  - 四层核心基础工具：密钥（age/sops）、智能体环境（codex）、项目管理（git/gh）、基础工具（aria2/7z）——先装齐
  - 扩展工具：rg/jq/yq（首批），核心稳定后再扩展
  - `ToolNames` 顺序 = 引导安装 / 展示 / 日常更新顺序；`status` 按「核心基础工具 / 扩展工具」两层分组
  - `ohmyenv daily`：日常无影响更新（同主版本自动 pin+deploy，跨主版本保留待人工确认，`-DryRun` 预览，`-IncludeBreaking` 强制），日志 `D:\ohmyenv\logs\update-daily.log`
- 非目标：不引入包管理器；不自动创建计划任务（daily 已就绪，是否挂 Task Scheduler 由用户决定）

## 方案

### 分层与引导顺序

| 层 | 工具 | 说明 |
| --- | --- | --- |
| 核心基础工具·密钥 | age, sops | SOPS 加密/解密、`.secrets` 恢复、密钥轮换 |
| 核心基础工具·智能体环境 | codex | 原生 CLI、DeepSeek env_key、沙箱/状态栏 |
| 核心基础工具·项目管理 | git, gh | 版本控制、GitHub 交互、API 兜底 |
| 核心基础工具·基础工具 | aria2, 7z | 多线程下载通道（ohmyenv 自用）、归档解包 |
| 扩展工具 | rg, jq, yq | 搜索 / JSON / YAML（首批扩展） |

引导顺序：age → sops → codex → git → gh → aria2 → 7z → rg → jq → yq

### 日常无影响更新

- 规则：同主版本 = 无影响，自动更新并重新锁定；跨主版本 = 保留待人工确认
- 命令：`ohmyenv daily [-DryRun] [-IncludeBreaking]`；退出码 0 = 全部最新/已更新，2 = 存在跨主版本待确认
- 实测中修复的升级链问题：
  - 升级时 sha256 误用旧锁定值 → 仅同版本比对，新版本直接回填
  - 7zsfx 解包后立即读版本可能瞬态失败 → 版本读取加重试（5 次退避）
  - 安装中断导致「已装新版本但锁定滞后」→ `update` 跳过分支补齐锁定与 sha

## 实施步骤

1. helpers.ps1：`ToolNames` 重排 + Category 分层（key/agent/project/base/extras）✓
2. ohmyenv.ps1：`status` 两层分组 + 子分组 ✓；新增 `daily` 命令 ✓
3. 升级链加固（sha 旧值误用 / 7zsfx 瞬态 / 锁定滞后补齐）✓
4. 实测：`daily -DryRun` 预览 2 项；`daily` 实跑 git 2.54.0 → 2.55.0.windows.4、gh 2.91.0 → 2.97.0 ✓
5. 文档：本方案 + CHANGELOG + ROADMAP + 踩坑沉淀 ✓

## 风险与回滚

- 自动更新破坏 → `ohmyenv pin <tool> -Version <旧>` + deploy；缓存按版本命名可复用
- API 限流 → `Invoke-GitHubApi` 全局 gh 兜底
- aria2 报 OK 但文件残缺 → sha 回填 + 安装后版本校验兜底；残缺时删缓存重下

## 验收标准

- `status` 输出：核心基础工具（密钥/智能体/项目管理/基础工具）+ 扩展工具（rg/jq/yq），顺序为引导链
- `ohmyenv daily -DryRun` 正确报告；`ohmyenv daily` 同主版本自动升级并锁定
- 全部工具 locked = installed = path = True
