# 0012 WSL 软件部署

- 状态：已批准（关键决策 2026-08-21 已与用户确认）
- 日期：2026-08-21
- 关联：ROADMAP 阶段 6（Windows 容器 + WSL 镜像平移）、`0011-windows-agent-env-oneclick.md`、
  `docs\research\wsl-image-build.md`、`scripts\build-wsl-image.ps1`、`scripts\set-wsl-distro.ps1`

## 背景与问题

阶段 6 已产出 ohmywsl 基础镜像（Ubuntu 24.04.4 dev 变体，1.65GB），把系统底座与
node/bun/rust/uv/go/zig 打进镜像；`docs\research\wsl-image-build.md` 明确
「gh（目标机增量部署）」等软件不进镜像。当前缺的是：在已导入的 ohmywsl distro 上，
像 Windows 侧 `ohmyenv.ps1` 一样按工具 **pin / query / install / update / status** 的
增量部署机制。ROADMAP 阶段 6 待办：「WSL 扩展增量安装部署（在基础镜像上按工具
pin/update/deploy，与主项目一致）」即指此事。

## 目标与非目标

- 目标：
  - 建立 WSL 侧软件部署 CLI `scripts\ohmywsl.ps1`（query / pin / install / update / status），
    语义与 Windows `ohmyenv.ps1` 对齐。
  - Linux 工具 pin 唯一来源收敛到 `scripts\wsl-env.psd1`（与 Windows `env.psd1` 分离）。
  - 每个工具一个 Linux 组件脚本（`scripts\wsl\tools\<tool>.sh`），Windows 编排、Linux 安装，
    全部走「GitHub 查询 → 下载 → sha256 校验 → WSL 内组件脚本安装」同一条链。
  - 把 distro 命名统一为 `ohmywsl`（`set-wsl-distro.ps1` 默认值、新 CLI 默认值一致）。
- 非目标：
  - 不重写/不替换已建好的基础镜像构建流程（`build-wsl-image.ps1` 继续负责镜像内 dev 工具链）。
  - 不在本轮把镜像内 dev 工具（node/bun/rust/uv/go/zig/git）全部回填 pin；这些按需逐个纳入。
  - 不做 WSL 内 AI agent（codex/claude/kimi）的密钥与配置接管（仍按需另行规划）。
  - 不做 distro 运行态 vhdx 的打包平移（继续走 `.wsl` 镜像导入/导出）。

## 方案

### 总体架构：Windows 编排 + Linux 组件脚本（已确认）

```text
scripts\ohmywsl.ps1                 # Windows 侧 CLI（pwsh7），语义对齐 ohmyenv.ps1
  ├─ dot-source helpers.ps1         # 复用 Invoke-GitHubApi / Get-GitHubRelease /
  │                                 #   Find-ReleaseAsset / Save-ReleaseAsset /
  │                                 #   Assert-Sha256 / Get-OfficialSha256
  ├─ Resolve-ToolVersion 复用       # wsl-env.psd1 字段与 env.psd1 同构，直接复用
  ├─ Save-WslLock / Get-WslLock     # 读/写 scripts\wsl-env.psd1（UTF-8 BOM）
  ├─ Invoke-WslTool                 # 下载校验 → 转 /mnt/<d>/... 路径 → wsl -d 执行组件脚本
  └─ ConvertTo-WslPath / Test-WslDistro   # 路径转换与 distro 检测（沿用 build-wsl-image 经验）

scripts\wsl-env.psd1                # Linux 工具 pin 唯一来源（独立于 env.psd1）
scripts\wsl\tools\<tool>.sh         # 每工具 Linux 安装组件（install/update/remove/version）
```

### 组件脚本接口约定

每个 `scripts\wsl\tools\<tool>.sh` 统一四种 action，脚本自身不负责下载/校验：

```bash
bash <tool>.sh version                # stdout 只输出已安装版本号；未安装输出空并 exit 1
bash <tool>.sh install <version> <asset-wsl-path>   # 从已校验 asset 安装（幂等）
bash <tool>.sh update  <version> <asset-wsl-path>   # 升级并清理旧版本
bash <tool>.sh remove                 # 卸载（含 .bashrc.d 片段清理）
```

约定：

- asset 路径为 WSL 内路径（如 `/mnt/d/ohmyenv/cache/wsl-tools/gh/gh_2.97.0_linux_amd64.tar.gz`），
  由 Windows 侧在下载并 sha256 校验后传入。
- 二进制统一安装到 `$HOME/.local/bin`；需要 root 的（如 `/usr/local`）用 sudo（基础镜像
  `ray` 已配免密 sudoers）。
- PATH 片段写入 `$HOME/.bashrc.d/ohmywsl-tools.sh`（幂等），保证非交互 `bash -lc` 也能拿到
  `$HOME/.local/bin`（基础镜像 base-config 已在 `.bashrc` 守卫前注入 source 循环）。
- 日志沿用 `[OK]` / `[WARN]` / `[INFO]` ASCII 前缀，避免 WSL/控制台编码坑。
- 同一版本重复 install 必须幂等（检测已装版本一致 → 直接 `[OK]` 跳过）。

### pin 清单 `scripts\wsl-env.psd1`（已确认独立）

结构与 `env.psd1` 同构，便于直接复用 `Resolve-ToolVersion`：

```powershell
@{
    Distro = 'ohmywsl'
    User   = 'ray'
    Tools  = @{
        'gh' = @{
            Version      = '2.97.0'
            Tag          = 'v2.97.0'
            TagPrefix    = 'v'
            Repo         = 'cli/cli'
            AssetPattern = '^gh_[0-9.]+_linux_amd64\.tar\.gz$'
            Asset        = 'gh_2.97.0_linux_amd64.tar.gz'
            SumsAsset    = 'gh_{version}_checksums.txt'
            SumsPattern  = 'gh_.*_linux_amd64\.tar\.gz'
            Component    = 'gh'
            Sha256       = '<install 时回填>'
        }
    }
}
```

字段说明：`Distro` / `User` 为部署目标默认值（可被 `-Distro` / `-User` 覆盖）；
`Component` 指向 `scripts\wsl\tools\<Component>.sh`（默认等于工具名）；其余字段与
`env.psd1` 同义（Linux 资产名与官方 checksums）。`Save-WslLock` 按 `env.psd1` 同样式
写回，UTF-8 带 BOM（AGENTS 规则 4）。

### CLI 命令语义

```powershell
pwsh -NoProfile -File scripts\ohmywsl.ps1 status                     # distro 状态 + pin vs installed
pwsh -NoProfile -File scripts\ohmywsl.ps1 query  [tool|all] [-Latest | -Tag <t> | -Version <v>]
pwsh -NoProfile -File scripts\ohmywsl.ps1 pin    [tool|all] [-Latest | -Version <v>]
pwsh -NoProfile -File scripts\ohmywsl.ps1 install [tool|all] [-Distro ohmywsl] [-User ray]   # 下载校验 + 组件安装 + 回填 sha256
pwsh -NoProfile -File scripts\ohmywsl.ps1 update  [tool|all]         # 最新版安装并重新 pin
pwsh -NoProfile -File scripts\ohmywsl.ps1 help
```

- `install`：解析 pin → 下载 asset 到 `EnvRoot\cache\wsl-tools\<tool>\` → 官方
  checksums / 锁定 sha256 校验 → 组件脚本安装 → 若 pin 的 `Sha256` 为空则回填。
- `update`：`-Latest` 解析 → 与 pin 比较（同版本跳过）→ install → `UpdateLock` 重写
  pin（Version/Tag/Asset/Sha256）。
- `status`：`Test-WslDistro` 检查 distro；对每个工具调用组件脚本 `version` 与 pin 比较；
  distro 缺失时输出引导（先 `set-wsl.ps1`，再 `set-wsl-distro.ps1`），不崩溃。
- Linux 侧安装即部署（二进制进 `$HOME/.local/bin`），不再单独区分 `install` / `deploy`。

### distro 命名统一（已确认）

- `scripts\set-wsl-distro.ps1` 默认 `$Distro = 'ohmywsl'`（原 `ohmywsl2` 为遗留默认，
  保留 `-Distro` 显式覆盖；旧 `ohmywsl2` distro 命名不迁移，按需手动 unregister）。
- `scripts\wsl-env.psd1` 默认 `Distro = 'ohmywsl'`，`ohmywsl.ps1` 默认一致。
- `scripts\wsl\base\base-config.sh` 中 `.bashrc` 标记 `ohmywsl2 dev env` 顺手改为
  `ohmywsl dev env`（仅影响下次 build，不迁移已导入镜像）。

### 已批准的首批接入范围（2026-08-21 用户定）

按用户需求顺序，首批两套（都不通过 GitHub 安装 agent 程序，而是「密钥接管 + 配置平移」）：

1. **WSL 密钥接管（age + sops）**：
   - Linux 侧部署 age/sops 二进制（`ohmywsl.ps1 install age/sops`，与 Windows 同一 pin 机制、
     GitHub 资产 + 官方 checksums + sha256 校验）。
   - 把 Windows 的 age 私钥（`%APPDATA%\sops\age\keys.txt`）复制进 WSL
     `~/.config/sops/age/keys.txt`（chmod 600），使 WSL 内 sops 与 `.sops.yaml` 公钥自洽。
   - 用 WSL 内 sops 现场解密 `.secrets\deepseek.env.enc` / `.secrets\anthropic.env.enc` 两个
     dotenv，生成 `DEEPSEEK_API_KEY` / `ANTHROPIC_API_KEY` 到 shell 环境（经 `.bashrc.d`
     幂等注入）；明文只进环境变量、不落盘。
2. **三 agent 配置平移（codex / claude / kimi）**：
   - 新建 Linux 专属幂等配置脚本（**不拷贝 Windows 文件**，Windows 值/路径与 Linux 不同）：
     - `~/.codex/config.toml`：状态栏（对齐 Windows 的 model-with-reasoning/context 等项，
       仅 Linux 可用的 widget）+ DeepSeek 模型/密钥引用（`env_key`）+ 信任项目。
     - `~/.claude/settings.json`：GLM-5.3[1m] 模型三档 + 1M 压缩窗口 + 权限 YOLO +
       遥测关闭 + 超时/编码项，**剔除 Windows 专属键**（`CLAUDE_CODE_GIT_BASH_PATH`、
       `CLAUDE_CODE_USE_POWERSHELL_TOOL`、`DISABLE_INSTALLATION_CHECKS` 按 Linux 语义处理）；
       `~/.claude.json` onboarding 修复同 Windows 语义。
     - `~/.kimi-code/config.toml`：`default_model = "kimi-code/k3"`、权限模式、`telemetry = false`。
   - Linux 侧 agent 二进制本身仍「不进基础镜像」、本轮不装（codex/claude/kimi 装什么、
     什么时候装，按需另行规划）。

## 工具纳入策略（按需，一次一个）

不一次性铺开。每个工具接入 = 3 个小改动，独立提交：

1. `scripts\wsl\tools\<tool>.sh` 组件脚本；
2. `scripts\wsl-env.psd1` 增加该工具 pin（先 `pin <tool> -Latest`）；
3. 实测 `install / status / update` 并在 `docs\research\wsl-image-build.md` 或新研究文档沉淀踩坑。

候选顺序（供用户点单，实际以需求为准）：

| 优先级 | 工具 | 说明 |
| --- | --- | --- |
| P0 | gh | 研究文档已点名「目标机增量部署」；Linux 侧 GitHub 认证与 API 兜底通道 |
| P1 | rg / jq / yq | 与 Windows 侧基础工具对齐，GitHub 单二进制/压缩包，最适合验证框架 |
| P1 | age / sops | Linux 侧密钥管理，需要时接入 |
| P2 | 镜像内 dev 工具回填 pin | node/bun/rust/uv/go/zig/git：先以当前镜像版本为基线 pin，再纳入 update |
| P3 | AI agent / 其他 | codex/claude/kimi 等按需单独规划 |

## 备选方案

| 方案 | 结论 |
| --- | --- |
| Linux 侧完整 `ohmyenv.sh` CLI（Windows 薄透传） | 弃：需在 Linux 重写下载/校验/锁逻辑，且 GitHub 匿名限流、aria2 主通道等 Windows 侧已沉淀的能力无法复用 |
| `ohmyenv.ps1` 扩展 `-Target wsl` 多平台统一 | 弃：主 CLI 与 `env.psd1` 结构改动大，Windows/Linux 资产字段互相污染，风险与收益不匹配 |
| 组件脚本自行下载安装（沿用 build 期 dev/*.sh 风格） | 弃：失去集中 pin/sha256 校验与 aria2/gh 兜底通道，与主项目「先 pin 后 update、官方哈希校验」原则不符 |

## 实施步骤

1. 本方案已批准（2026-08-21）。
2. 文档落位：更新 `ROADMAP.md` 阶段 6 待办引用本方案、`CHANGELOG.md [Unreleased]`、
   `docs\README.md` 方案索引。
3. 命名统一：`set-wsl-distro.ps1` 默认 Distro 改 `ohmywsl`；`base-config.sh` 标记去
   `ohmywsl2` 残留（下次 build 生效）。
4. 导入基础镜像：`set-wsl-distro.ps1` 导入 `ohmywsl-0.1.0-wsl-amd64.wsl` 为
   `ohmywsl` distro（先 `.wslconfig` 自适应 + 时区）。
5. 框架：新建 `scripts\ohmywsl.ps1`（Get-WslLock / Save-WslLock / Invoke-WslTool /
   ConvertTo-WslPath / Test-WslDistro，复用 helpers.ps1）+ 新建 `scripts\wsl-env.psd1`。
6. 首批接入（密钥接管）：`tools\age.sh` / `tools\sops.sh` 组件脚本 + `wsl-env.psd1` pin
   age/sops + Linux 私钥平移 + sops 现场解出两个 API Key 的 shell 环境注入脚本。
7. 首批接入（三 agent 配置平移）：`set-wsl-agent-config.ps1`（或等价 Linux 专属幂等脚本）
   生成 `~/.codex/config.toml` / `~/.claude/settings.json` + `~/.claude.json` /
   `~/.kimi-code/config.toml`。
8. 端到端实测：`wsl -d ohmywsl` 内验证 age/sops 版本、`sops -d` 回读、`echo $DEEPSEEK_API_KEY`
   形如 `sk-`、三个 agent 配置文件 parse 正常；并 `CHANGELOG` / `ROADMAP` / 研究文档沉淀。

## 风险与回滚

| 风险 | 缓解 | 回滚 |
| --- | --- | --- |
| `wsl` 输出 UTF-16LE 导致 distro 名误判（已有坑） | `Invoke-Wsl` 内统一临时切换 `[Console]::OutputEncoding = Unicode`，参考 `set-wsl-distro.ps1` | — |
| 非交互 `bash -lc` 拿不到 `$HOME/.local/bin` | 基础镜像已在 `.bashrc` 守卫前注入 `.bashrc.d` source 循环；组件脚本写 `ohmywsl-tools.sh` | 删除 `.bashrc.d/ohmywsl-tools.sh` |
| WSL 未安装 / distro 缺失 | `status` 与 `install` 前 `Test-WslDistro`，缺失时给 `set-wsl.ps1` / `set-wsl-distro.ps1` 指引 | — |
| Linux asset 名 / checksums 文件名与 Windows 不同 | 每个工具接入时单独验证（同 Windows 侧接入流程，先 pin 后 install 回填 sha） | `git checkout scripts\wsl-env.psd1` 回滚 pin |
| age 私钥进 WSL 的泄露面 | 私钥文件 chmod 600、不进镜像、不入库（`.gitignore`）；WSL 内同样受 `secret-guard` 语义约束 | 删除 `~/.config/sops/age/keys.txt` |
| API Key 明文误落盘 | 只在 sops 解密时进环境变量/管道，不写文件；复用 Windows 侧「解密回读不匹配即中止」校验 | 从 `.bashrc.d` 移除注入块、`unset` 变量 |
| 组件脚本安装失败留下半成品 | 组件脚本先解压到临时目录再原子替换；失败保留现场不删 distro | 删除 `$HOME/.local/bin/<bin>` 即可 |
| Windows 专属配置平移错配 | 三 agent 用 Linux 专属脚本重建配置，不拷贝 Windows 文件；剔除 `CLAUDE_CODE_GIT_BASH_PATH` / PowerShell 开关等 | 删除对应 `~/.codex` / `~/.claude` / `~/.kimi-code` 目录 |

## 验收标准

1. `pwsh -NoProfile -File scripts\ohmywsl.ps1 status` 在 distro 缺失时输出引导、退出不异常；
   distro 存在时正确显示 pin vs installed。
2. `set-wsl-distro.ps1` 默认导入后 `wsl -l -q` 出现 `ohmywsl`（无乱码误判）。
3. age/sops：`ohmywsl.ps1 pin age|sops -Latest` 写入 `scripts\wsl-env.psd1`；`install` 走
   下载 + sha256 校验 + 组件安装；`wsl -d ohmywsl age --version` / `sops --version` 与 pin
   一致；重复 `install` 幂等。
4. 密钥：`wsl -d ohmywsl` 内 `sops -d` 能解出两个 `.enc`；`echo $DEEPSEEK_API_KEY` 形如
   `sk-`、`echo $ANTHROPIC_API_KEY` 形如 `xxxx.yyyy`；明文不落盘（`grep` 密钥名命中文件即 FAIL）。
5. 三 agent 配置：`~/.codex/config.toml` / `~/.claude/settings.json` / `~/.kimi-code/config.toml`
   均存在且 parse 正常，无 Windows 专属残留键；重复执行幂等（无重复块/文件哈希稳定）。
6. 每个工具接入都有 `docs\research\` 踩坑沉淀或对既有研究文档的更新。
