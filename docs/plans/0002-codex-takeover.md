# 0002-codex-takeover — Codex 二进制与密钥管理接管

- 状态：已完成
- 日期：2026-08-19
- 关联：ROADMAP 阶段 3

## 背景与现状

- codex 当前为 npm 全局包 `@openai/codex@0.147.0`（`D:\Oh-My-Claude\.envs\dev\node\node_modules`），入口是 `codex.ps1` / `codex.cmd`（node 包装层）
- npm 包内原生二进制布局与官方 `codex-package` 一致：`bin\codex.exe`、`bin\codex-code-mode-host.exe`、`codex-path\rg.exe`、`codex-resources\codex-command-runner.exe`、`codex-resources\codex-windows-sandbox-setup.exe`
- 最新原生 release：`rust-v0.148.0`；官方 `install.ps1` 使用 `codex-package-x86_64-pc-windows-msvc.tar.gz`（约 125MB）+ `codex-package_SHA256SUMS` 校验，默认装到 `%LOCALAPPDATA%\Programs\OpenAI\Codex\bin`
- DeepSeek 密钥当前明文写在 `~/.codex/config.toml` 的 `experimental_bearer_token`；Codex 源码明确注释不鼓励该字段，优先 `env_key`
- `~/.codex/models.json`（DeepSeek 模型目录）与 `backup-deepseek/` 已存在

## 目标与非目标

- 目标：
  - codex 原生二进制由 ohmyenv 接管：`D:\ohmyenv\codex`，版本锁定 0.148.0，sha256 校验
  - 用户 PATH 前置 `D:\ohmyenv\codex\bin`，新 shell 中 `codex` 解析到原生 exe
  - 密钥迁移：`experimental_bearer_token` → 用户环境变量 `DEEPSEEK_API_KEY` + `config.toml` 的 `env_key`；密钥不再出现在任何配置文件中
  - 回滚路径保留：npm 包验证通过前不删除
- 非目标：不动 omc node 环境的其他部分；不迁移 codex 会话/历史数据

## 方案

### A. 二进制接管（ohmyenv 扩展）

- `New-ToolDef 'codex'`：`Repo = openai/codex`，`AssetPattern = '^codex-package-x86_64-pc-windows-msvc\.tar\.gz$'`，`Dir = codex`，`Bin = codex\bin`，`Exe = codex\bin\codex.exe`，`Extract = targz`
- `helpers.ps1` 新增 `targz` 解压类型：`tar -xzf <包> -C <目录>`（Windows 自带 bsdtar）
- 版本识别：`codex --version` 输出 `codex-cli 0.148.0`，pattern `codex-cli\s+v?(\d+\.\d+\.\d+)`
- sha256：下载 `codex-package_SHA256SUMS` 按资产名校验（官方方式），并回填锁定
- 部署：`ohmyenv deploy codex`
- PATH：前置 `D:\ohmyenv\codex\bin`（优先于 Oh-My-Claude dev\node，`codex.exe` 先于 npm shim 命中）

### B. 密钥接管

1. 备份 `~/.codex/config.toml` → `~/.codex/backup-takeover-20260819/`（独立于 DeepSeek 脚本的 backup）
2. 从 `config.toml` 提取 token → 设置用户级环境变量 `DEEPSEEK_API_KEY`（全程不回显）
3. `config.toml` 中 `experimental_bearer_token` 替换为 `env_key = "DEEPSEEK_API_KEY"`
4. 用 SOPS 加密一份密钥副本到项目 `.secrets\deepseek.env.enc`（加密文件可提交，明文不入库），用于换机/轮换恢复
5. 验证：新 shell 中 `codex doctor` / `codex --version` 正常
6. 清理含明文密钥的旧备份（`backup-deepseek`、迁移前的 config 备份）——需用户确认后处理

### C. 收尾

- 验证通过后可选：`npm rm -g @openai/codex`（保留 node 环境其他部分）—— 已执行 ✓
- 文档：`docs\research\codex-deepseek-config.md`（步骤与命令沉淀）、CHANGELOG、ROADMAP 阶段 3

## 实施步骤

1. ohmyenv 增加 codex 工具定义 + `targz` 解压 + 版本识别
2. `ohmyenv deploy codex`（下载 125MB 包 + SHA256SUMS 校验 + 解压 + PATH）✓
3. 验证原生 codex 运行（Get-Command、--version、doctor）✓
4. 密钥迁移（备份 → 交互式 env var → env_key）✓；SOPS 加密副本（`.secrets\deepseek.env.enc`）✓
5. `codex doctor` 最终验证 ✓（config ok、env_key present、sandbox unrestricted、approval Never）
6. 清理明文残留、npm 交接清理 ✓

## 风险与回滚

- 125MB 下载慢/失败 → curl 重试 + 缓存复用
- 原生二进制行为差异 → 保留 npm 入口；PATH 切换可逆（`Remove-EnvPath`）
- `env_key` 可用性 → 已由 Codex 源码确认支持（`model-provider-info` 注释）
- 密钥迁移中断 → 备份完整，config 未改前可重跑
- 回滚：删除 `D:\ohmyenv\codex` + 移除 PATH 条目 + 还原 config.toml 备份 + 删除 `DEEPSEEK_API_KEY`

## 验收标准

- `Get-Command codex` → `D:\ohmyenv\codex\bin\codex.exe`，`--version` = 0.148.0
- `config.toml` 无明文密钥，仅 `env_key`
- `DEEPSEEK_API_KEY` 仅存在于用户级环境变量
- `codex doctor` 无配置错误
- `.secrets\deepseek.env.enc` 可 `sops --decrypt` 恢复出密钥
