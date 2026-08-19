# starship.toml 配置研究（PowerShell 专用）

## 主题

starship 提示符配置文件机制与 PowerShell（pwsh）专属配置。研究方式：gh api 拉取 `starship/starship` 官方配置文档（`docs/config/README.md`，v1.26.0）核实。

## 现状

- 接管前配置为 omc 符号预设（Nerd Font 符号映射 + `[shell] disabled = false`），无顶层 `format`，走默认 `$all` 提示行
- 配置位于 `~/.config/starship.toml`（starship 默认路径）；本机未设 `STARSHIP_CONFIG` / `XDG_CONFIG_HOME`，无 `%APPDATA%\starship.toml` 覆盖
- profile 已由接管保留 `Invoke-Expression (&starship init powershell)`

## 研究结论（官方文档核实）

### 顶层选项

| 选项 | 默认 | 说明 |
| --- | --- | --- |
| `format` | `$all` | 提示行结构；`$all` 等价于全部模块按默认顺序 |
| `scan_timeout` | `30`（ms） | 扫描文件超时 |
| `command_timeout` | `500`（ms） | 模块执行命令超时 |
| `add_newline` | `true` | 提示符前空行 |
| `right_format` | `''` | 右侧提示行 |
| `follow_symlinks` | `true` | 符号链接是否按目录处理 |

### 相关模块

- `[character]`：`success_symbol`（默认 `[❯](bold green)`）/ `error_symbol`（默认 `[❯](bold red)`），可改形状区分成败
- `[directory]`：`truncation_length = 3`、`truncate_to_repo = true`、`use_os_path_sep`（Windows 为 `\`）、`read_only` 符号、`truncation_symbol`
- `[cmd_duration]`：`min_time = 2_000`（ms）以上才显示耗时
- `[shell]`：默认 disabled；`pwsh_indicator` 默认镜像 `powershell_indicator`（`'psh'`），可分别标识 pwsh / powershell
- custom 命令执行：starship 检测到 PowerShell 时自动补 `-NoProfile -Command -`（避免递归加载 profile）；可显式 `shell = ['pwsh.exe', '-NoProfile', '-Command', '-']`

### 坑

- **TOML 1.0 不允许重复定义表**：分块合并配置时，若 PowerShell 块与符号预设都含 `[directory]` / `[shell]` 表 → `duplicate key` 解析失败 → 改为「全模板」单一源写入
- 解析失败时 starship 不渲染，profile 的 init 行报错、提示行退化为 shell 默认

## 落地（PowerShell 专用配置）

- `scripts\set-starship-config.ps1`：全模板幂等写入 `~/.config/starship.toml`（本脚本为唯一源；文件与模板不一致时需 `-Force` 覆盖，避免静默覆盖手动修改）
- 配置结构：
  - `format`：`$directory$git_branch$git_status$package$python$nodejs$rust$dotnet$cmd_duration$line_break$shell$character`
  - `scan_timeout = 30`、`command_timeout = 500`、`add_newline = true`
  - `[character]`：`❯`（绿）/ `✖`（红）
  - `[directory]`：truncation 3 / truncate_to_repo / Windows 路径分隔符 / read_only 符号
  - `[shell]`：`pwsh_indicator = 'pwsh'`、`powershell_indicator = 'psh'`、`disabled = false`
  - 保留原符号预设（aws/buf/bun/os.symbols/...）

## 验证

- `starship print-config` 解析通过；`format` 生效
- `starship prompt --status 0` 渲染：`ohmypwsh on main [?]`（目录/分支/状态）+ `pwsh ❯`（shell 标识 + 输入符）
- 新终端生效（registry PATH 重建后 `starship` 解析到 `D:\ohmyenv\starship\starship.exe`）
