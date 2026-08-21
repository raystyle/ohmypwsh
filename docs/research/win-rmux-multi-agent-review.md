# ohmyenv 全仓代码审查（win-rmux 三 agent review）

> 研究性质：代码审查结论沉淀（规则 3 文档规范）
> 日期：2026-08-22 · 方法：rmux 执行单元内 codex / kimi / claude 三 agent 并行只读 review（无改动）
> 范围：AGENTS.md / README / CHANGELOG / ROADMAP / docs\* + `scripts\*.ps1`、`*.psd1`、`*.psm1`、hooks
> 三端源文件：review-claude.md / review-codex.md / review-kimi.md（已清理，结论汇入本文）

## 结论速览

仓库定位清晰、设计纪律与文档文化良好（幂等、校验优先、CHANGELOG 记录详尽）。主要风险集中在
**部署包明文密钥、unpack 版本解析崩溃、PS5.1 锁清单无 BOM、无校验即执行** 四条；stage-5
「unpack 换机/换路径还原验收」当前会直接踩中 unpack 崩溃 bug，**应先行修复再验收**。

## 高风险（跨端交叉印证，优先修复）

1. **`Invoke-EnvUnpack` 版本解析崩溃 → 跨机还原功能断**（claude+codex+kimi）
   - `helpers.ps1:1060,1068` `[version]$m.Version`；git 锁定 `2.55.0.windows.4`（`Get-InstalledVersion`
     同样返回），`System.Version` 无法解析 → `InvalidCastException` 在 `$ErrorActionPreference='Stop'`
     下中止整个 `unpack`。
   - 修法：防御式解析（数字前缀比对 / try-parse 回退字符串相等），或清单存可比较的规范化版本。
2. **`pack` 把明文密钥打进未加密 zip**（claude+codex+kimi）
   - `helpers.ps1:986-1005`：age 私钥（`secrets/age-keys.txt`，SOPS 解密本体）+ `~/.claude.json`
     （可含 primaryApiKey，且代码注释却称已排除）+ 全部 SOPS 密文进 `ohmyenv-deploy-*.zip`；
     且包未过滤 `.secrets\*`，sops 崩溃残留的明文 `.env` 会一并入包。与「明文密钥永不入库/入包」直接冲突。
   - 修法：zip 加密 / ACL 保护 / 私钥带外处理；过滤 `.secrets\*.env`。
3. **`env.psd1` 无 BOM 却被 PS5.1 消费（规则 4 违规）**（claude+codex+kimi）
   - `bootstrap.ps1:32` 在 PS5.1 下 `Import-PowerShellDataFile` 读含中文头的 `env.psd1`，
     GBK 系统按 ANSI 解析会 mojibake / 报错。当前非 ASCII 仅在注释、尚能解析，属潜伏炸弹。
   - **根因是生成器**：`helpers.ps1:406`（`Save-EnvLock`）与 `psmodule.ps1:65` 用
     `Set-Content -Encoding utf8`（pwsh7 无 BOM）重写 → 手补 BOM 也会在下次 `pin/update` 丢失。
     应改 `utf8BOM` 并给现有 `env.psd1`/`modules.psd1` 补 BOM。
   - 同类点：`set-fnm-config.ps1:91,99` 重写 **PS5.1 profile** 也 utf8 无 BOM，profile 含非 ASCII 即触发。
4. **pwsh MSI 自更新无守卫**（claude）
   - unpack 对 msi 有「HINT+跳过」（`helpers.ps1:1093-1097`），但 `ohmyenv deploy all` / `update` / `daily`
     在 pwsh7 运行中会直接 `msiexec` pwsh MSI → 文件占用 → 3010（被当成功）→ 版本探测陈旧 → 混淆报错/重启挂起。
   - 修法：给 `Install-ToolVersion` msi 分支应用与 unpack 相同的守卫。
5. **无校验源工具零完整性校验 / 无校验即执行**（codex+kimi）
   - age/git/aria2/7z/dotnet/fnm/jq/ast-grep/oscdimg 首装 TOFU 仅 WARN（`helpers.ps1:764-785`）；
     更甚者 git PortableGit SFX 与 7z `7zr.exe` BootstrapAsset **未校验直接执行**（`helpers.ps1:771-775,823-852`）。
   - `set-kimi-config.ps1` 执行 `irm ... | iex` 且无哈希/签名/版本 pin —— 全仓最高危安装模式（codex）。
6. **`set-wsl-distro.ps1:49`  `wsl -l -q` UTF-16 未解码**（kimi+codex）
   - 输出含 NUL，`.Trim()` 去不掉 → 已存在 distro 判断恒失败；`-Force` 时跳过 `--unregister` 导致
     `--import` 重名报错。姊妹脚本 `build-wsl-image.ps1:56-62` 处理正确，属漏改。
   - 另：`set-wsl-distro.ps1:74` 写 `dnsTunneling=true`，而 CHANGELOG/ROADMAP/docs\research\wsl-image-build.md
     均记 `dnsTunneling=false` 为修 DNS 的结论 —— 疑似回归（codex 明确标出）。
7. **`helpers.ps1:570-583` 缓存不匹配「假重下」**（kimi）
   - catch 删缓存文件后控制流继续落「复用缓存」分支并 return → 文件已删、下载未发生，日志却谎称已重下，
     调用方随后对不存在文件 `Get-FileHash` 报错。确凿逻辑错误（一行控制流修复）。

## 中等

- **`psmodule.ps1 pin -Latest` 参数未声明**（claude+codex）：`[switch]$Latest` 不在 param 块，
  `pin <mod> -Latest` 是参数绑定错误，`$Latest` 只是碰巧工作的未定义变量。
- **双锁分歧 / 漂移**（claude）：`deploy-omp.ps1` 拷贝 helpers/env.psd1 进 `EnvRoot\modules\omp`；
  模块侧 `omp pin/update` 与仓库侧 `ohmyenv.ps1` 各改各的，无同步 → 下次 `deploy-omp` 静默回滚模块侧 pin。
- **secret-guard 正则误报 / 漏报**（claude+kimi）：
  - 误报：文件里含 secret 形状的示例/正则（guard 自身源码、docs/research）会被自身 `mysql://`/`redis://`
    模式拦下，PreToolUse Write/Edit 被拒；
  - 漏报：`secret-guard.py:47-51` 通用 key 字符类不含 `.`/`_`/`-`，GLM（`xxxx.yyyy`）漏报；无引号 `password = xxx` 漏报；
  - `set-agent-secret-guard.ps1:148-152` `[features]` 正则可跨 table 误匹配、不匹配注释行导致**重复 `[features]` 表（非法 TOML）**；`hooks=false` 已存在时头重写制造重复 `hooks` key。
- **guard fail-open × YOLO**（claude）：hook 依赖裸 `python3` 在 PATH；新机未注册时每次 hook 抛错 →
  fail-open（exit 0）→ 防护恰好消失于 `bypassPermissions` 撤掉其它护栏时。建议 `omp status` 加 hook 可解析性检查。
- **unpack 与「离线还原」定位矛盾**（kimi）：installer 类还原 `Install-ToolVersion` 无条件先联网取官方
  sums，离线直接 throw；zip 内 portable 产物从不与 manifest.Sha256 比对 → 篡改包被信任。
- **`SetEnvironmentVariable` 把 REG_EXPAND_SZ 落成 REG_SZ**（kimi）：`helpers.ps1:907`/`deploy-omp.ps1:39`/
  `psmodule.ps1:82` 重写 PATH/PSModulePath，`%USERPROFILE%` 类条目静默失效。
- **`set-claude-config.ps1:179-187`**：已有 `settings.json` 的 `env` 为 PSCustomObject 时被整体换成空表，
  用户自定义 env 键每次运行被静默删除；`:211-251` 重写 `~/.claude.json` 用 `-Depth 10` 可能截断深层状态。
- **提权重启丢参 / 路径未引号**（claude+codex+kimi）：`set-pwsh.ps1:61` 提权重启不转发 `-Version`；
  `set-vsbuild.ps1:45-47` 丢 `-Layout`；多处 `-File $PSCommandPath` 加引号（`set-docker.ps1:36-38`、`set-wsl.ps1:21-23`）。
- **`gh api` 兜底对多行 pretty JSON 失效**（kimi）：`helpers.ps1:424-427` 逐行 `ConvertFrom-Json`，应 `Out-String` 整体解析。
- **升级先删后解压无回滚**（kimi）：`helpers.ps1:788-791` 移除旧版本再解压，失败工具消失。
- **`2>&1` 混入 ErrorRecord 后 `.Trim()`**（kimi）：`helpers.ps1:673` 工具往 stderr 打警告即让 `status` 崩溃。
- **PS5.1 IWR 兜底未设 Tls12**（kimi）：`set-pwsh.ps1:93`/`bootstrap.ps1:52` 旧镜像握手可能失败——恰是 bootstrap 目标场景。
- **msiexec 参数插值注入面**（kimi）：`helpers.ps1:797-798`/`set-pwsh.ps1:61,108` ArgumentList 字符串插值，
  `OHMYENV_ROOT` 含 `"` 时在提权上下文构成注入面。
- **密钥输入回显**（kimi）：`set-claude-key.ps1:9`、`set-deepseek-key.ps1:7` 裸 `Read-Host`（pwsh7 有 `-MaskInput`）；
  `set-deepseek-key.ps1` 未如 claude 版自动触发 SOPS 加密备份。
- **`set-reasonix.ps1` 明文写 `DEEPSEEK_API_KEY` 到 `%APPDATA%\reasonix\.env`**（codex）：桌面应用可能必需，
  但属 `.secrets` 外明文；缓存 zip 损坏后无自愈（`set-reasonix.ps1:24-29`）。

## 低 / 文档同步

- `docs\README.md` 目录索引滞后（三端一致）：plans 目录树只列到 0007（`0008`–`0011` 缺，与上方「方案索引」
  自相矛盾）；research 树只列 7 篇（实际 20 篇，缺 agents-docs-benchmark.md、powershell-telemetry.md）；
  scripts 缺 `set-bun-config.ps1`/`set-fnm-config.ps1`/`set-kimi-config.ps1`/`claude-statusline.ps1`；
  `.secrets` 只列 deepseek.env.enc（缺 anthropic.env.enc）；`set-claude-key.ps1 -FromOmcProfile` 已不存在仍被描述。
- `AGENTS.md`：常用命令缺 `set-kimi-config.ps1`；环境快照（pwsh 7.6.4 / gh 2.91.0 / git 2.54.0）落后当前 pin。
- `ROADMAP.md` 落后：缺 just / ast-grep / nushell / Rust / VS Build Tools / python3 别名 / Kimi 接管完成项。
- 未跟踪文件无归宿：`.reasonix/`（运行时数据，宜入 .gitignore）、`reasonix.toml`、`bunfig.toml`、`.nvmrc` 分类表未涵盖。
- 其它零散：`omp.psm1:149 return 2` 写输出流而非退出码（`ohmyenv.ps1:193 exit 2` 不一致）；`Save-EnvLock`
  单引号不转义（资产名含 `'` 写坏 psd1）；`set-wsl-distro.ps1` 残留 `D:\ohmywsl2` 硬编码；WSL 镜像
  `ubuntu/ubuntu` 明文密码 + `NOPASSWD:ALL`（dev 可接受需文档明示）；`set-vsbuild.ps1` 把带版本 MSVC 目录
  钉进机器 PATH；`sops-encrypt-*.ps1` 逐字节重复易漂移；oscdimg `CdnUrl` 含符号服务器 GUID 可用性脆弱。

## 修复优先级（多端排序收敛）

1. `helpers.ps1:570-583` 缓存假重下（一行控制流修复）
2. unpack 版本解析（git `windows.N`）+ 离线化 + 包内哈希校验（stage-5 验收前置）
3. pack 排除/加密明文密钥（age keys、`~/.claude.json`、`.secrets/*.env`）
4. `Save-EnvLock`/`psmodule.ps1` 改 `utf8BOM` + 补 `env.psd1`/`modules.psd1` BOM（规则 4 自洽）
5. pwsh MSI 自更新守卫
6. `set-wsl-distro.ps1:49` UTF-16 解码 + 核对 `dnsTunneling`
7. git/7zr 等无校验即执行路径补哈希或文档明示 TOFU
8. 声明 `psmodule.ps1` `$Latest`；`docs\README.md` / AGENTS.md / ROADMAP 补齐

## 安全性正向确认（三端认可）

无明文密钥进仓库脚本（仅具名引用）；`.gitignore` 覆盖 keys.txt/*.agekey/.env/`.secrets/*.env`，`.enc` 可提交属设计；
`.sops.yaml` 仅暴露公钥；sops 脚本加密→泄露扫描（`Select-String -SimpleMatch`）→解密回读→删明文；
secret-guard 掩码（first4/last4）+ 匹配真实 env 值；`Test-SafeUnderRoot` 守卫破坏性目录删除；Reasonix `forbid_read` 保护 `.ssh/.aws`；
幂等合并（-AsHashtable + -Depth 20）与 hook 去重是真幂等。
