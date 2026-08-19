# ohmyenv 运维踩坑记录（规则 1 沉淀）

## 下载与 API

- **api.github.com 匿名限流（60/h）与 5xx 网关错误**：统一由 `Invoke-GitHubApi` 处理，命中 403/rate-limit/502/503/504 时自动改用 `gh api` 认证通道（5000/h）；gh 装好后即生效（全局兜底，见 AGENTS.md 设计原则）
- **aria2 部分连接报 SSL/TLS handshake 失败**：GitHub CDN 瞬态，多线程 + SHA256SUMS 校验兜底，重试即成功
- **中断的下载会残留进程并锁住缓存文件**：先 `taskkill /PID` 终止孤儿进程，脚本对缓存做 sha256 校验，不匹配自动重下
- **aria2 报 OK 但文件可能残缺**：SSL/TLS 断连后进度停在 96% 仍回 OK（实测 git 56MB 包缺约 2MB）；新版本升级时缓存无 sha 基准会直接复用 → 安装后版本校验兜底，版本不符时删缓存重下

## 解压

- **7-Zip 的 `7zXXX-x64.exe` 是 7z 归档**：直接运行需提权且不支持 `-y`；用 Windows 自带 tar（bsdtar）`tar -xf <file> -C <dir>` 解包（`7z-archive` 类型），无需预装 7z
- **PowerShell `@versionArgs` 数组展开调用原生命令会解析异常**（gh 收到 `v`）→ 直接传 `$versionArgs` 变量
- **7z --help 首行为空行** → 版本解析先跳过空行再取首行
- **7zsfx 解包后立即读版本可能瞬态失败**：文件刚落地/杀软扫描未就绪时 `git.exe --version` 读空 → 版本读取加重试（5 次 × 500ms 退避）

## 锁文件

- **PowerShell Data File 键名不能以数字开头**：`7z = @{...}` 解析失败，必须写 `'7z' = @{...}`
- **静态元数据与锁文件不同步**：`New-ToolDef` 修改（如 Extract 类型）不会自动进入已存在的 `env.psd1` → `Get-EnvLock` 每次把 `New-ToolDef` 的静态字段合并进锁，pin 字段（Version/Tag/Asset/Sha256）保留
- **升级时 sha256 误用旧锁定值**：`$d.Sha256` 非空且目标版本 ≠ 锁定版本时，旧代码拿旧 sha 比新文件必失败 → 仅同版本比对，新版本直接回填
- **安装中断后「已装新版本但锁定滞后」**：`update` 的已安装跳过分支原不回写锁定 → 补齐锁定（Tag/Version/Asset/Sha256）

## 版本管理

- 版本不硬编码在代码：`env.psd1` 是唯一 pin 来源；新工具先 `ohmyenv pin <tool> [-Latest | -Version X]`，之后 `ohmyenv update <tool>`（见 AGENTS.md 设计原则）
- **rmux 用 tmux 风格版本参数**：`rmux --version` 打印 usage 且退出非零，版本读取必须 `rmux -V`（输出 `rmux 0.10.0`）→ `Get-InstalledVersion` 按工具定制 versionArgs

## 工具接入与移交

- **新增工具接入 ohmyenv 需同步四处**：`$script:ToolNames`、`New-ToolDef`（静态元数据）、`Get-InstalledVersion`（版本解析）、`ohmyenv.ps1` 的 ValidateSet（+ 帮助文本）；漏一处则 pin/status/install 报「未知工具」或版本读不到
- **omc 工具移交要动五处并改名保留**：`omc.ps1` 的 `$ToolDefs` 注册表、`.scripts\tools\<tool>.ps1` 定义文件、`.envs\tools\bin\<tool>.exe` 二进制（三者改名 `*.removed-YYYYMMDD` 保留）、`CLAUDE.md` 文档同步；`.config\<tool>\config.json` 沿用 gh/git/7z 先例保留不动
- **进程 PATH 与注册表 PATH 不一致**：开发沙箱/继承环境可能把额外目录（如 codex 自带 `codex-path`）注入进程 PATH 且排前；验证必须重建 PATH（Machine + User 合并，等价全新终端），否则 `Get-Command` 会命中非权威目录
- **release tag 无 v 前缀也兼容**：`Resolve-ToolVersion` 的 TagPrefix 缺省为 `v`，tag 不匹配前缀时直接用 tag 名作版本（ripgrep 15.2.0 无 v 前缀，正常解析）
- **单文件 exe 工具用 `copy` 解压类型**：jq / yq / sops 都是 release 单文件（如 `jq-windows-amd64.exe` / `yq_windows_amd64.exe`），`Extract='copy'` 直接拷入工具目录
- **starship 只有逐资产 `.sha256`、无统一 SHA256SUMS**：`SumsAsset` 机制不适用（那是给单文件 SUMS 清单用的），走「下载后回填 sha + 安装后版本校验」即可
- **PS 模块是双份安装 + 额外副本**：Pester/PSScriptAnalyzer/PSFzf 同时存在于 `WindowsPowerShell\Modules`（5.1）与 `PowerShell\Modules`（pwsh7），且 pses 目录内还有副本 → 清理要三处齐清；直接删除时注意进程占用（PSFzf.dll 曾被占用，重试后成功）
- **profile 块由 profile-line.ps1 的 BEGIN/END 标记管理**：清理用块标记正则删除最稳（本例删除 PSFzf 块、仅留 Starship 块）
- **starship 在非交互环境报 `TERM=dumb` 错误**：Codex CLI / 脚本管道常注入 `TERM=dumb`（starship 跨平台检测），profile 里裸 `Invoke-Expression (&starship init powershell)` 会打印 `[ERROR] - (starship::print): Under a 'dumb' terminal (TERM=dumb).` 噪音；修复为加守卫 `if ($env:TERM -ne "dumb" -and $Host.Name -eq "ConsoleHost") { Invoke-Expression (&starship init powershell) }`（pwsh7 与 5.1 profile 均已应用，交互终端渲染不受影响）
