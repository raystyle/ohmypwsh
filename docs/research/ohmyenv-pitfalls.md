# ohmyenv 运维踩坑记录（规则 1 沉淀）

## 下载与 API

- **api.github.com 匿名限流（60/h）与 5xx 网关错误**：统一由 `Invoke-GitHubApi` 处理，命中 403/rate-limit/502/503/504 时自动改用 `gh api` 认证通道（5000/h）；gh 装好后即生效（全局兜底，见 AGENTS.md 设计原则）
- **aria2 部分连接报 SSL/TLS handshake 失败**：GitHub CDN 瞬态，多线程 + SHA256SUMS 校验兜底，重试即成功
- **中断的下载会残留进程并锁住缓存文件**：先 `taskkill /PID` 终止孤儿进程，脚本对缓存做 sha256 校验，不匹配自动重下

## 解压

- **7-Zip 的 `7zXXX-x64.exe` 是 7z 归档**：直接运行需提权且不支持 `-y`；用 Windows 自带 tar（bsdtar）`tar -xf <file> -C <dir>` 解包（`7z-archive` 类型），无需预装 7z
- **PowerShell `@versionArgs` 数组展开调用原生命令会解析异常**（gh 收到 `v`）→ 直接传 `$versionArgs` 变量
- **7z --help 首行为空行** → 版本解析先跳过空行再取首行

## 锁文件

- **PowerShell Data File 键名不能以数字开头**：`7z = @{...}` 解析失败，必须写 `'7z' = @{...}`
- **静态元数据与锁文件不同步**：`New-ToolDef` 修改（如 Extract 类型）不会自动进入已存在的 `env.psd1` → `Get-EnvLock` 每次把 `New-ToolDef` 的静态字段合并进锁，pin 字段（Version/Tag/Asset/Sha256）保留

## 版本管理

- 版本不硬编码在代码：`env.psd1` 是唯一 pin 来源；新工具先 `ohmyenv pin <tool> [-Latest | -Version X]`，之后 `ohmyenv update <tool>`（见 AGENTS.md 设计原则）
