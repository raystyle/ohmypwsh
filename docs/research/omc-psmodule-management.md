# omc 的 PowerShell 模块管理机制研究

## 主题

研究 `D:\Oh-My-Claude`（omc）如何安装/部署 PowerShell 模块：入口、机制与残留。基于源码（`omc.ps1` / `psanalyzer.ps1`（git 历史恢复）/ `psmodule.ps1` / `helpers.ps1`）+ 本机实测。模块已于 2026-08-19 清理，本文件记录「曾经如何管理」及「清理后的残留」。

## 架构

- **注册表**：`omc.ps1` 的 `$PsModules`（原 `psanalyzer=PSScriptAnalyzer` / `psfzf=PSFzf` / `pester=Pester`，现为空）→ `Invoke-PsModule` / `Invoke-Batch` 把 `omc check|install|update|uninstall <模块>` 调度到 `psanalyzer.ps1`
- **入口**：`.scripts\dev\psanalyzer.ps1`（2026-08-19 已删，git 历史可恢复）：`$ModuleDefs`（PSFzf 带 ProfileBlock）+ check / download / install / update / uninstall / register / unregister
- **核心库**：`.scripts\dev\psmodule.ps1`（仍在）：通用 PowerShell 模块管理器

## 安装/部署流程（psmodule.ps1）

1. **版本解析**：`helpers.ps1` 的 `Get-PSGalleryModuleInfo` 查 PSGallery v2 API 最新版；`Compare-SemanticVersion` 比较
2. **本地仓库**：`Register-OhMyClaudeLocalRepo` 注册名为 `OhMyClaude` 的本地 PSRepository（`.cache\dev\LocalRepo`，`InstallationPolicy=Trusted`），幂等
3. **下载**：`Save-ModuleNupkg` 直连 `https://www.powershellgallery.com/api/v2/package/<Module>/<Version>` 下载 `.nupkg` 到本地仓库（缓存复用；0 字节重下）
4. **安装**：`Install-Module -Repository OhMyClaude -RequiredVersion <ver> -Scope CurrentUser` → 装到当前 shell 的用户模块目录
5. **交叉部署**：`Get-PSModulePaths` 双路径（`$HOME\Documents\WindowsPowerShell\Modules` [PS5] + `$HOME\Documents\PowerShell\Modules` [PS7]），把已装版本目录 `Copy-Item` 到另一个 shell 的目录，保证 5.1 与 7 各有一份
6. **版本锁定**：`.config\<ModuleName>\config.json` 写 `{"lock":"<version>"}`（与 ohmyenv 的 pin 思路一致）
7. **Profile 集成**：PSFzf 定义 `ProfileBlock` → 经 `profile-line.ps1` 写 `BEGIN/END ohmywinclaude: PSFzf` 块（Ctrl+t / Ctrl+r 绑定，即本次清理删掉的块）
8. **卸载**：当前 shell `Uninstall-Module` + 调另一个 shell（`powershell.exe`/`pwsh.exe`）交叉卸载 + 删锁 + 删 profile 块

## 关键设计

- 走「本地仓库 + 直连下载 nupkg」而非直接对 PSGallery `Install-Module`：规避 PSGallery 直连不稳定问题，同时保留 `Install-Module` 的安装语义
- 先 lock 后 install：无锁装最新并写锁，有锁按锁安装（`omc install <模块>` 幂等）
- PS5 / PS7 双份部署：两 shell 用户目录分离，模块需各自落一份

## 残留（2026-08-19 模块清理后）

- `OhMyClaude` PSRepository **仍注册于 5.1 与 pwsh7**（Trusted，指向 `.cache\dev\LocalRepo`）→ 建议注销：`Unregister-PSRepository -Name OhMyClaude`（两个 shell 各一次）
- `.cache\dev\LocalRepo` 残留 2 个 nupkg：`Pester.5.7.1.nupkg`、`PSScriptAnalyzer.1.25.0.nupkg`
- `.config\{Pester,PSFzf,PSScriptAnalyzer}\config.json` 锁文件残留（lock 5.7.1 / 2.7.10 / 1.25.0）
- `psmodule.ps1` 已成孤儿库（唯一调用方 `psanalyzer.ps1` 已删）

## 与 pses 的区别

- pses（PowerShellEditorServices，调试组件）不走 PSGallery：`pses.ps1` 从 GitHub Releases 下载 `PowerShellEditorServices.zip` 解压到 `.envs\dev\pses` 并加入用户 `PSModulePath`（已删，PSModulePath 残留已清）

## 结论

- omc 模块管理 = PowerShellGet 语义 + 本地 nupkg 仓库 + PS5/PS7 双路径交叉部署 + 锁文件（`.config\<模块>\config.json`）+ 可选 profile 块
- 现状已停用（`$PsModules` 空、模块全删）；残留的仓库注册 / nupkg / 锁文件可按需清理
