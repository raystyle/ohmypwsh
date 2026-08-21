# Node.js / npm 接管研究（fnm）

> 2026-08-20，来源：Schniz/fnm README + docs/configuration.md + docs/commands.md + GitHub Release 实测。

## 关键结论：nvm-sh/nvm 不支持 Windows，改用 fnm

用户给的 `nvm-sh/nvm` 是 Mac/Linux 专用（bash 脚本），Windows 不适用。早期临时落地的
`coreybutler/nvm-windows`（Go 编写）依赖管理员权限创建符号链接（`NVM_HOME` / `NVM_SYMLINK`），
与 ohmyenv「单二进制 + 绿色目录 + 幂等」的部署哲学不一致。最终 Windows 方案定为
**fnm**（`Schniz/fnm`，Rust 编写，单文件，跨平台）。

## fnm 现状

- 最新 `v1.39.0`，Windows 资产 `fnm-windows.zip`（单文件 `fnm.exe`，约 7.8 MB）。
- 单文件免安装，解压即用；支持 `.nvmrc` / `.node-version` / `package.json#engines#node`。
- 内置别名：`latest`、`lts-latest`（注意没有裸 `lts` 别名）。

## 目录与镜像配置（重点）

- `FNM_DIR`：node 各版本 + 别名（`aliases\`）的存储根。安装后生成 `node-versions\` 与
  `aliases\` 两个子目录。本机设为 `D:\ohmyenv\fnm-data`（与 fnm 本体 `D:\ohmyenv\fnm\fnm.exe`
  分离，避免 `ohmyenv update fnm` 清空 `fnm\` 时误删 node 版本）。
- `FNM_NODE_DIST_MIRROR`：node 下载镜像，默认 `https://nodejs.org/dist`，本机设为
  `https://npmmirror.com/mirrors/node`。
- npm registry：`~/.npmrc` 写 `registry=https://registry.npmmirror.com`。

## profile 初始化（PS5 + PS7 同款，对齐 fnm 官方文档）

```powershell
# BEGIN ohmypwsh: fnm
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}
# END ohmypwsh: fnm
```

- 官方推荐写法（docs/README ≥ v1.x Shell Setup）：PowerShell 用
  `fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression`。
- `--use-on-cd`：`cd` 进目录自动按 `.nvmrc` / `.node-version` 切换 node。
- **显式 `--shell powershell`**（官方建议）：避免运行时 shell 推断 / process tree 检测，更快。
- 移除自定义参数 `--version-file-strategy=recursive`，与官方标准保持一致
  （默认 `local` 策略；默认 node 即 lock `FNM_DIR` 内 default 版本 v24，子目录不命中 .nvmrc
  时回退 default 仍一致）。
- `Get-Command fnm` 守卫：fnm 尚未部署时 profile 静默跳过，不报错。
- profile 文件：PS5 `Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`、
  PS7 `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`。

## 部署与安装流程

1. `ohmyenv.ps1 pin fnm -Latest` → 锁定 `v1.39.0`。
2. `ohmyenv.ps1 deploy fnm` → 解压 `fnm.exe` 到 `D:\ohmyenv\fnm` + 前置注册 PATH。
3. `scripts\set-fnm-config.ps1` → 幂等配置 `FNM_DIR` / `FNM_NODE_DIST_MIRROR` / PATH /
   `.npmrc` / profile 块，并 `fnm install --lts`（缺省）+ 确保默认版本。
4. 新终端或 `. $PROFILE` 后 `node -v` / `npm -v` 可用。

## 踩坑沉淀

- `fnm install --lts` 会自动创建 `default` 与 `lts-latest` 两个别名（默认版本已就绪），
  **不要**再执行 `fnm default lts`（fnm 无 `lts` 别名，会报 `Can't find requested version: lts`；
  应使用 `lts-latest` 或具体版本号）。
- `fnm env` 输出的是多行 `$env:VAR = "..."`，必须 `| Out-String | Invoke-Expression` 整体求值。
- Windows 的 per-shell 激活符号链接在 `%LOCALAPPDATA%\fnm_multishells\...`（临时、随会话），
  真正的 node 数据在 `FNM_DIR`；打包迁移只关心 `FNM_DIR`。
- `fnm current` 需要在已执行过 `fnm env` 的 shell 中才有效，否则报
  `fnm env was not applied in this context`。

## 接管决策

- fnm 本体走 ohmyenv 部署包（`fnm-windows.zip` 单文件 + PATH）。
- node 版本由 fnm 管理（`fnm install` / `fnm use` / `--use-on-cd`），ohmyenv 只 pin fnm 本体。
- 项目根 `.nvmrc` 为唯一版本入口（`cd` 即切换），内容为具体 LTS 版本号。
- 镜像 / registry / profile 配置沉淀为 `scripts\set-fnm-config.ps1`（幂等）。
- **环境变量作用域（明确取舍）**：fnm 只在用户 PATH 放入本体 `fnm.exe`；用户级环境变量有
  `FNM_DIR` / `FNM_NODE_DIST_MIRROR`，但 **node/npm/npx 与 `FNM_MULTISHELL_PATH` 仅经
  profile 的 `fnm env` 在当前交互会话注入**，用户注册表和未加载 profile 的会话（`-NoProfile`、
  CI、agent 非交互 shell）里 node 命令不可用。这是「仅 profile / 动态注入」方案的既定取舍，
  node 命令的唯一可用来源是加载了 profile 的交互终端。
