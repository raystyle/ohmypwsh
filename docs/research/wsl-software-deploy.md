# WSL 软件部署（ohmywsl 框架 / 密钥平移 / 三 agent 配置平移）

## 目标

在 ohmywsl WSL 基础镜像之上，按主项目 ohmyenv 同一套「先 pin 后 install/update、官方哈希校验、
幂等」机制增量部署 Linux 软件；首批落地「密钥接管（age/sops）」与「三 agent 配置平移」。

## 架构

- Windows 侧 `scripts\ohmywsl.ps1`（query / pin / install / update / status，pwsh7）复用
  `helpers.ps1` 的 `Invoke-GitHubApi` / `Get-GitHubRelease` / `Find-ReleaseAsset` /
  `Get-OfficialSha256` / `Save-ReleaseAsset`。
- Linux 侧 `scripts\wsl\tools\<tool>.sh` 组件脚本（四 action：`version` / `install` /
  `update` / `remove`），只负责从「已校验 asset」安装到 `$HOME/.local/bin`，不自己下载。
- pin 唯一来源 `scripts\wsl-env.psd1`（与 `env.psd1` 同构、UTF-8 BOM，含 `Distro` / `User`）。

## 关键决策（2026-08-21 已确认）

- distro 命名统一 `ohmywsl`（`set-wsl-distro.ps1` 默认值、`ohmywsl.ps1` 默认值一致；
  `base-config.sh` 的 `ohmywsl2 dev env` 标记已改为 `ohmywsl dev env`，下次 build 生效）。
- agent 二进制**不进基础镜像、基础镜像只留系统底座 + dev 工具链**；codex 等 agent 按
  `ohmywsl.ps1` 增量接入（codex 已接入，claude/kimi 按需）。
- API Key 落地方式：Windows age 私钥复制进 WSL `~/.config/sops/age/keys.txt`（chmod 600），
  `~/.bashrc.d/ohmywsl-secrets.sh` 每次 shell 启动用 WSL `sops` 现场解密 `.secrets\*.env.enc`
  并 `export`；**明文仅进环境变量，不落盘**。
- **部署链形态（关键约定）**：所有工具都是绿色文件/二进制——Windows 侧 ohmywsl.ps1 下载 +
  校验并把部署包统一缓存在 EnvRoot `cache\wsl-tools\<tool>\`；Linux 组件脚本只做「解包（若有）
  → cp 二进制到 `~/.local/bin` → chmod +x」，PATH 由基础镜像 `.bashrc.d/local-bin.sh`（
  `export PATH="$HOME/.local/bin:$PATH"`）保证，组件脚本不整目录落位、不自己下载、不写 PATH。

## 实测记录（2026-08-21）

| 项 | 结果 |
| --- | --- |
| `set-wsl-distro.ps1 -Force` | `ohmywsl-0.1.0-wsl-amd64.wsl`（1576.8MB）→ `ohmywsl` distro，vhdx 落 `D:\ohmyenv\wsl\ohmywsl`，.wslconfig 自适应 31GB/16 核 |
| `ohmywsl.ps1 install age` | aria2 15MiB/s 下载 + sha256 校验；WSL 内 `age --version` = v1.3.1 |
| `ohmywsl.ps1 install sops` | aria2 21MiB/s 下载 checksums.txt + 主资产 49MiB；WSL 内 `sops --version` = 3.13.3 |
| `set-wsl-keys.ps1` | 私钥平移 → sops 解密自检 → DS=sk- / AK=x.y 断言 → 明文落盘扫描通过；二次运行幂等 |
| `set-wsl-agent-config.ps1` | 四个配置文件落位、`jq empty` parse 通过；重复运行文件 sha256 稳定 |

## 踩坑沉淀（2026-08-22）

### WSL claude `API Error: 403 Request not allowed`

现象：WSL 内启动 `claude` 报 `Please run /login · API Error: 403 Request not allowed`。

根因：拿的是 bigmodel 的 `ANTHROPIC_API_KEY`，但 `ANTHROPIC_BASE_URL`（
`https://open.bigmodel.cn/api/anthropic`）缺失——请求打到了 Anthropic 官方 `api.anthropic.com`，
官方以 403 拒绝（密钥归属不匹配）。Windows 侧该变量作为**用户环境变量**存在且未随配置平移到
WSL，`set-wsl-agent-config.ps1` 生成的 `~/.claude/settings.json` env 与 `set-wsl-keys.ps1`
注入的 shell 环境也都未带它。

修复（两处皆改，形成双保险）：
1. `set-wsl-agent-config.ps1`：`~/.claude/settings.json` 的 `env` 补
   `ANTHROPIC_BASE_URL=https://open.bigmodel.cn/api/anthropic`（settings 级，所有 claude 进程生效）。
2. `set-wsl-keys.ps1`：secrets 注入脚本 `~/.bashrc.d/ohmywsl-secrets.sh` 加
   `export ANTHROPIC_BASE_URL=...`（shell 级兜底，覆盖强制走自定义端点/非 settings 的进程）。

验证：重跑两个脚本后，全新交互 shell（`--noprofile --norc`，仅加载 bashrc.d secrets）——
`ANTHROPIC_BASE_URL=https://open.bigmodel.cn/api/anthropic`，`claude -p` 实测返回 `PONG`，
403 消失。注意 CLI 输出曾有 `[claude-code:unrecognized_model] glm-5.3[1m]` 提示为无碍 noise。
`claude` 二进制实际在 `/home/ray/.local/bin/claude`，非登录 `bash` shell 的 PATH 不一定含它，
直接 `/home/ray/.local/bin/claude` 调用更稳。


## 踩坑沉淀

- **WSL 输出 UTF-16LE**：`wsl -l -q` / `wsl -e bash -lc` 的 stdout 是 UTF-16LE，直接
  `.Trim()` 比对或用 PowerShell 正则匹配会乱码失败。统一「临时切
  `[Console]::OutputEncoding = [System.Text.Encoding]::Unicode` → 执行 → 恢复」的
  `Invoke-Wsl` / `Test-WslDistro` 模式（同 `set-wsl-distro.ps1` 既有经验）。
- **跨 `wsl` 传 shell 变量的引号地狱**：PowerShell 里用 `\$c` 转义是错的（PowerShell 转义符
  是反引号 `` ` ``，不是 `\`）；`bash -lc "..."` 内再用双引号/`$VAR` 极易被两层解析打散。
  正确姿势：PowerShell 侧用 `` `$var `` 产生字面 `$var`；shell 内避免 `case ... in` / 嵌套
  双引号，改用 `grep -q` + 退出码断言；多行内容先写成临时文件（UTF-8 无 BOM）再 `cp` 进 WSL，
  不要拼命令字符串。
- **PowerShell 函数 `return $LASTEXITCODE` 陷阱**：`return $LASTEXITCODE` 会把退出码当作函数
  输出（污染调用方捕获的 stdout），不是设置调用方 `$LASTEXITCODE`。调用方要读 `$LASTEXITCODE`，
  必须让函数内的 `& wsl` **不**被 `return 值` 吞掉：函数直接执行原生命令（stdout 自然流给调用
  方），退出码由执行后全局 `$LASTEXITCODE` 读取。夹具脚本里用 `$null = Invoke-WslBash -Command "..."`，
  之后检查 `$LASTEXITCODE`（而不是函数返回值）。
- **sops 参数顺序严格**：`sops -d <file> --input-type dotenv` 会报
  "More than one positional argument"（`--output-type` 被当成第二个位置参数）。必须是
  `sops --input-type dotenv --output-type dotenv -d <file>`——flags 全部在首个位置参数之前。
- **sops 版本行为**：`sops --version` 会联网检查最新版本并打印弃用警告（`sops 3.13.3 (latest)`），
  组件脚本解析版本时只取行首 `sops[ -]v?数字`，不受该警告影响。
- **明文不落盘的验证姿势**：写密钥后跑 `grep -rlE 'sk-[A-Za-z0-9]{8,}' ~/.bashrc.d ~/.config/sops`
  应为空（输出 `PLAINTEXT-NOT-ON-DISK`）。不要在 WSL stdout 里 `echo` key 值（UTF-16 会让
  key 显示成 mojibake 但仍是泄露；校验只在 WSL 内断言，不回显）。
- **codex `--version` 版本提取要锚定前缀**：输出是 `codex-cli 0.148.0`（第一段是
  `codex-cli` 而不是版本号）。用 `.*(v?([0-9.]+))` 这类贪婪正则会因 `.*` 吞掉前面的数字导致
  误提成 `8.0`；正确写法 `sed -nE 's/^codex-cli[[:space:]]+v?([0-9][0-9.]+).*/\1/p'`。
- **claude/kimi 的 Linux 资产都是单文件**：`claude-linux-x64.tar.gz` 解出顶层单文件 `claude`；
  `kimi-code-linux-x64.zip` 解出单文件 `kimi`（Windows win32 zip 也是单 kimi.exe）。组件脚本
  只需解包取顶层单文件 cp 到 `~/.local/bin`，无目录、无资源依赖。
- **kimi tag 含 `@`**：`MoonshotAI/kimi-code` 的 tag 是 `@moonshot-ai/kimi-code@0.38.0`，
  `TagPrefix` 用 `@moonshot-ai/kimi-code@` 剥出 `0.38.0`；GitHub API 返回的
  `browser_download_url` 已把 `@` 编码为 `%40`，追加 `.sha256` 后缀（`AssetShaSuffix`）即可
  命中官方逐资产校验，需在 `ohmywsl.ps1` 的 `Save-WslLock` 显式输出 `AssetShaSuffix` 字段，
  否则回填 sha 时会丢弃该字段。
- **Windows 侧升级「无感无痛」两处加固**（2026-08-21）：
  - codex 升级前必须停掉运行中的 `codex.exe`（否则 `Remove-Item installDir` 被占用拒绝）。
  - `set-claude-config.ps1` 的 wheel 下载曾因 aliyun `IncompleteRead` 直接失败——现带
    `--retries 3 --timeout 60` 并按 aliyun → nju → tsinghua → 官方 PyPI 回退（实测 nju 无该包，
    tsinghua 成功）。
  - `set-kimi-config.ps1` 的 `kimi upgrade` 联网查更新无重试、抖动即失败——改为 GitHub 直下
    `kimi-code-win32-x64.zip` + 官方 `.sha256` 校验 + 替换 `kimi.exe`（保留 config.toml/fd.exe
    等用户数据，自动停 kimi 进程），与 WSL 侧同源同校验。
- **secret-guard 同步进 WSL**：`hooks\secret-guard.py` 是纯 Python 3（仅 `json/os/re/sys`），
  WSL 原生 python3 可直接跑，无需改造。`set-wsl-secret-guard.ps1` 把同一份 guard cp 进 WSL 三个
  agent 的 hooks 目录（`~/.codex/hooks` / `~/.claude/hooks` / `~/.kimi-code/hooks`，chmod 755），
  hook 命令用 Linux 原生 `python3`；配置格式与 Windows 一致（Claude settings.json 嵌套 hooks /
  Codex hooks.json + `[features] hooks=true` / Kimi config.toml `[[hooks]]`），但不用把 Reasonix
  算进去（WSL 未装）。验证用官方测试套件 `_test_secret_guard.py`（9 用例 PASS/FAIL），在 WSL
  部署位跑同样 9/9。
- **vault 走 HashiCorp releases CDN 而非 GitHub release**：`hashicorp/vault`（及 HashiCorp 系
  产品）的二进制**不挂 GitHub release assets**（连 v1.19.0 都是 0 资产），只发布在
  `releases.hashicorp.com/<product>/index.json`（`versions` → 每版本 `builds[]`（os/arch/url/
  filename）+ `shasums` 文件名）。接入要点：
  - 新增 `Get-HashiCorpIndex`：拉 index.json，latest 时过滤 `+`（排除 `+ent`/`+ent.hsm`/
    `+ent.fips1403` 企业变体）取最大版；指定版直接取。
  - `New-ToolDef` 用 `CdnIndexUrl` + `CdnAssetPattern`（`{version}` 占位，`[regex]::Escape` 替换）；
    注意 `$versions[$ver]` 对 `Invoke-RestMethod` 解析出的 PSCustomObject **无效**（哈希索引返回
    null），必须 `$versions.PSObject.Properties[$ver].Value`——这是本类踩坑的关键一行。
  - `Resolve-ToolVersion` 返回 `ShasumsUrl`（用主资产 URL 的 filename 换成 shasums 文件名），
    `Get-OfficialSha256` 下载官方 `vault_X_SHA256SUMS` 按资产名匹配取 sha。
  - 官方 SHA256SUMS 实测：windows_amd64 `5e6357e5...`、linux_amd64 `7429e7d8...`，与下载 zip
    实测 sha256 完全一致。
  - `vault version`（不是 `--version`）输出 `Vault v2.0.4 (...)`，版本识别用
    `^Vault\s+v?(\d+\.\d+\.\d+)`。

- **herdr 双端接入的形态差异**：`herdrdev/herdr` 是 Rust 单二进制 agent 运行时（后台 server +
  终端 pane，与 rmux 同类但更 agent-native）。
  - Windows 资产 `herdr-windows-x86_64.zip` 内含 `herdr.exe` + `conpty/`（ConPTY 依赖）+ 许可证，
  - Windows 资产 `herdr-windows-x86_64.zip` 内含 `herdr.exe` + `conpty/`（ConPTY 依赖）+ 许可证，
    **不是单二进制**，必须 `Extract='zip'` 整体落位（zip 展平逻辑只在「顶层单目录包裹无文件」时
    触发，herdr 顶层有 exe + 多目录，不会被误展平）；`Exe=herdr\herdr.exe`、`Bin=herdr`。
  - Linux 资产 `herdr-linux-x86_64` 是单裸二进制，组件脚本直接 cp 到 `~/.local/bin/herdr`。
  - 版本识别：`herdr --version` 输出 `herdr 0.8.2`，需 `^herdr\s+v?(\d+\.\d+\.\d+)`（Windows
    `Get-InstalledVersion`）与 `^herdr[[:space:]]+v?([0-9][0-9.]+)`（Linux 组件脚本）。
  - 官方 release 无 checksums 资产，走「下载后 sha256 回填」策略（同 age 等无校验源工具）。
- **ast-grep 的 Linux 资产是双二进制 zip**：`app-x86_64-unknown-linux-gnu.zip` 内含主力
  `ast-grep`（53MB）+ legacy 别名 `sg`（437KB，已 deprecated 但保留兼容），组件脚本两个都 cp。
  版本识别同样踩「贪婪正则误取」坑：`ast-grep --version` 首行 `ast-grep 0.45.1`，`.*([0-9.]+)`
  会误取 `5.1`，须锚定 `^ast-grep[[:space:]]+v?([0-9][0-9.]+)`。
- **yq 官方 `checksums` 是多哈希列格式**：每行 = 文件名 + crc32 + md5 + sha1 + sha256 + sha512
  等多列哈希（非标准「sha256 两个空格 文件名」），`Get-OfficialSha256` 的「整行取第一个 64 位
  hex」对列序变化很脆弱——Linux 侧 yq 改走「实测下载回填 sha256」，与 ast-grep（无 checksums）
  一致。rg 用逐资产 `.sha256`、jq 用 `sha256sum.txt`（标准格式）可正常走官方校验。
- **shellcheck 是 tar.xz 资产 + 版本输出两行**：官方资产 `shellcheck-*.linux.x86_64.tar.xz`，
  组件脚本必须 `tar -xJf`（不是 `-xzf`）；解出单目录 `shellcheck-<ver>/shellcheck`，`find … -name shellcheck`
  取二进制。`shellcheck --version` 输出前两行是「ShellCheck - shell script analysis tool」+
  「version: 0.11.0」，版本提取要针对 `^version:` 行（`sed -nE 's/^version:[[:space:]]*([0-9][0-9.]+).*/\1/p'`），
  不能锚定第一行。无官方 checksums 资产，走 sha 实测回填。
- **just 的 tar.gz 顶层直接是 `just`，且有官方 SHA256SUMS**：`just-*-x86_64-unknown-linux-musl.tar.gz`
  解包后顶层就是 `just` 可执行文件（无单目录包裹，直接 `install -m 0755 "$tmp/just"`）；校验用
  `SumsAsset='SHA256SUMS'` + `SumsPattern='just-.*-x86_64-unknown-linux-musl\.tar\.gz'`（标准
  sha256 两空格文件名格式，官方校验通道直接可用）。`just --version` 输出 `just 1.58.0` 首行即版本。

## 待办

- 增量工具继续接入（rg / jq / yq / gh 等，按需逐个 pin/install/update）。
- agent 二进制（codex / claude / kimi）在 WSL 的安装归属与时机另行规划。
