# ohmyenv 运维踩坑记录（规则 1 沉淀）

## 下载与 API

- **api.github.com 匿名限流（60/h）与 5xx 网关错误**：统一由 `Invoke-GitHubApi` 处理，命中 403/rate-limit/502/503/504 时自动改用 `gh api` 认证通道（5000/h）；gh 装好后即生效（全局兜底，见 AGENTS.md 设计原则）
- **api.github.com 直连可能 SSL/连接/超时失败而 `gh api` 正常**：`Invoke-GitHubApi` 兜底已从仅 403/5xx 扩展为 SSL/TLS/连接/超时也切 `gh api`（本机实测 direct `Invoke-RestMethod` 报 SSL 失败、`gh api` 返回正常）
- **aria2 部分连接报 SSL/TLS handshake 失败**：GitHub CDN 瞬态，多线程 + SHA256SUMS 校验兜底，重试即成功
- **中断的下载会残留进程并锁住缓存文件**：先 `taskkill /PID` 终止孤儿进程，脚本对缓存做 sha256 校验，不匹配自动重下
- **aria2 报 OK 但文件可能残缺**：SSL/TLS 断连后进度停在 96% 仍回 OK（实测 git 56MB 包缺约 2MB）；新版本升级时缓存无 sha 基准会直接复用 → 安装后版本校验兜底，版本不符时删缓存重下
- **aria2 对 GitHub CDN 偶发 SSL/TLS handshake 失败且会长时间 0B 卡住**：加 `--connect-timeout=20 --timeout=60 --max-tries=3 --retry-wait=5` 快速失败并回落 curl（本机 yq 下载实测）
- **版本无关资产名（如 `yq_windows_amd64.exe`）升级会复用旧缓存**：缓存文件名不含版本，无 sha 基准时 `Save-ReleaseAsset` 直接复用 → 安装后「版本不符」；升级（Tag 变化）必须强制重下（`-Force`）

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
- **TagPrefix 空串与 null 不能混用**：`New-ToolDef` 未显式声明 `TagPrefix` 时，`Save-EnvLock` 会把 `$null` 写成 `''`，重载后 `Resolve-ToolVersion` 把空串当「无前缀」而不再按默认 `v` 剥前缀，导致 `daily -DryRun` 对 v 前缀 tag 工具误判「跨主版本」；凡 tag 带 `v` 的工具必须在 `New-ToolDef` 显式 `TagPrefix='v'`（pwsh/age/sops/git/gh/yq/rmux/starship 已补）
- **单文件 exe 工具用 `copy` 解压类型**：jq / yq / sops 都是 release 单文件（如 `jq-windows-amd64.exe` / `yq_windows_amd64.exe`），`Extract='copy'` 直接拷入工具目录
- **python-build-standalone 的 tag 是日期而非版本**：`Resolve-ToolVersion` 新增静态 `VersionPattern`，命中资产名时用捕获组作版本（python 3.12.14 从 `cpython-3.12.14+20260814-...-install_only.tar.gz` 提取）
- **install_only tarball 顶层套单目录**（`python/` 包裹层）：`targz` 解压已加与 zip 相同的单目录展平（python-build-standalone 实测触发）
- **uv 默认 python 由 `UV_PYTHON_INSTALL_DIR` 决定**：接管后指向 `D:\ohmyenv\python`，`uv python list` 同时仍会发现 PATH 上的 omc 残留 python（先不管 jupyter 时保留）
- **PyPI 的 `claude-code` 是占位包**（0.0.1 无入口点，`uv tool install` 报 No executables）→ Claude Code 安装改用 `uv pip download claude-agent-sdk`（wheel 内捆绑 `claude.exe`，aliyun 源约 100MB）解出
- **OrderedDictionary 的 PSObject 成员不被 ConvertTo-Json 序列化**：settings.json env 块合并须用字典式赋值（`$envTarget[$key]=$value`），`Add-Member` 会写出 `"env": {}`
- **starship 只有逐资产 `.sha256`、无统一 SHA256SUMS**：`SumsAsset` 机制不适用（那是给单文件 SUMS 清单用的），走「下载后回填 sha + 安装后版本校验」即可
- **PS 模块是双份安装 + 额外副本**：Pester/PSScriptAnalyzer/PSFzf 同时存在于 `WindowsPowerShell\Modules`（5.1）与 `PowerShell\Modules`（pwsh7），且 pses 目录内还有副本 → 清理要三处齐清；直接删除时注意进程占用（PSFzf.dll 曾被占用，重试后成功）
- **profile 块由 profile-line.ps1 的 BEGIN/END 标记管理**：清理用块标记正则删除最稳（本例删除 PSFzf 块、仅留 Starship 块）
- **starship 在非交互环境报 `TERM=dumb` 错误**：Codex CLI / 脚本管道常注入 `TERM=dumb`（starship 跨平台检测），profile 里裸 `Invoke-Expression (&starship init powershell)` 会打印 `[ERROR] - (starship::print): Under a 'dumb' terminal (TERM=dumb).` 噪音；修复为加守卫 `if ($env:TERM -ne "dumb" -and $Host.Name -eq "ConsoleHost") { Invoke-Expression (&starship init powershell) }`（pwsh7 与 5.1 profile 均已应用，交互终端渲染不受影响）
- **settings.json 任一非法值会导致整个文件被跳过**：Claude Code 对 `permissions.disableBypassPermissionsMode` 只接受字符串 `"disable"`（不是布尔 false），写 `false` 时 claude 报错并「Files with errors are skipped entirely」→ env 块（模型/1M 上下文）全部不生效、回落到内置默认模型。排查口径：启动 claude 若出现 settings 错误弹窗，先 `jq empty settings.json` 只是语法校验不够，还要看 claude 自身 schema 报错
- **Codex/宿主进程残留环境变量会污染子进程**：exec 沙箱继承宿主进程环境（宿主在清理前启动），即使注册表已删 `ANTHROPIC_AUTH_TOKEN`/`ANTHROPIC_DEFAULT_*`，进程环境里仍是旧值（旧密钥导致 401、旧模型 glm-5.2[1m] 被 claude 使用）。验证环境变量必须同时看注册表（`[Environment]::GetEnvironmentVariable($n,'User')`）与当前进程（`$env:$n`）；测试脚本开头先清 `Get-ChildItem Env: | Where-Object Name -match '^(ANTHROPIC|CLAUDE_)' | Remove-Item`
- **PowerShell 删环境变量 `$null` 会留空串**：`[Environment]::SetEnvironmentVariable($n, $null, 'User')` 被 PS 转成空串（变量“清空但仍在”，GetEnvironmentVariable 返回空串非 $null）；必须用 `[NullString]::Value` 才真正删除
- **bigmodel 对未知模型名静默映射**：open.bigmodel.cn 的 anthropic 端点对 `claude-opus-5[1m]` 等未知模型返回 200 并把响应 `model` 置为 `glm-4.7`（默认映射），不报错——所以「请求成功」不等于「用了想要的模型」，验证必须看 claude debug 日志的 `dispatching ... model=` 行或直连指定模型名确认
- **rmux 0.10 Windows：TUI 备屏不可捕获、send-keys 目标偶发失败**：全屏 TUI（claude）走 alternate screen，`capture-pane`/`pane-snapshot` 为空（`-a` 报 no alternate screen）；send-keys 对部分目标在 tiny CLI 下报 can't find pane（设 `RMUX_DISABLE_TINY_CLI=1` 走 full helper 可解）；调试 claude 优先 `claude -p`（纯文本可捕获）或用会话转录 `~/.claude\projects\<encoded-cwd>\*.jsonl` 验证
