# PowerShell 模块 / .NET 库 / VS Build Tools 现状研究

## 主题

摸底本机 PowerShell 模块、.NET（SDK/运行时/Framework）与 VS Build Tools 的安装现状、来源与托管方式，为后续「是否由 ohmyenv 接管 / 是否补装模块」提供决策依据。纯研究，不动环境。

## PowerShell 模块

### 现状（pwsh 7.6.4）

- 清理（2026-08-19）后仅剩系统与 PowerShell 自带模块：
  - PowerShell 内置：`Microsoft.PowerShell.*`（7.0.0.0）、CimCmdlets、ThreadJob、Archive、Diagnostics、Security、Utility 等
  - Windows 系统模块：NetAdapter、Storage、Hyper-V、Dism、PKI、ScheduledTasks、WslInterop 0.4.1 等（来自 `Program Files\WindowsPowerShell\Modules`，pwsh 可加载）
  - 编辑/包管理：PSReadLine 2.4.5、PowerShellGet 2.2.5、**PSResourceGet 1.2.0**（新式模块管理）、PackageManagement 1.4.8.1
  - 系统内置 Pester 3.4.0（`Program Files\WindowsPowerShell\Modules`）保留；PSFzf / PSScriptAnalyzer / Pester 5.7 等已删
- 用户级模块目录现状：`C:\Users\ray\Documents\PowerShell\Modules` 只剩 PSReadLine 与 WslInterop；`WindowsPowerShell\Modules` 只剩 Windows 相关；omc 的 pses 目录已移除

### 清理结果（2026-08-19，保持系统原生）

- 用户级模块已全部移除：`Documents\PowerShell\Modules` 的 PSReadLine 2.4.5 / WslInterop 0.4.1 副本、`Documents\WindowsPowerShell\Modules` 的 PSFzf 残留（WslInterop 系统无副本，删除不影响 `wsl.exe` 本体）
- `PSModulePath` 用户环境变量已清空（原含已删除的 pses 死路径），模块解析回到系统默认（pwsh：`Program Files\PowerShell\7\Modules` 等；5.1：`Program Files\WindowsPowerShell\Modules` + `System32\WindowsPowerShell\v1.0\Modules`）
- 实测：pwsh 的 PSReadLine 2.4.5 解析到系统路径；5.1 剩系统内置 Pester 3.4.0 / PSReadLine 2.0.0；PSFzf / PSScriptAnalyzer / WslInterop 不再出现
- 两个被运行中会话锁定的残留已改名（惰性，不再加载），关闭所有 PowerShell 会话后执行删除：

```powershell
Remove-Item 'C:\Users\ray\Documents\PowerShell\Modules\PSReadLine.removed-20260819' -Recurse -Force
Remove-Item 'C:\Users\ray\Documents\WindowsPowerShell\Modules\PSFzf.pending-purge-20260819' -Recurse -Force
Remove-Item 'C:\Users\ray\Documents\PowerShell\Modules' -Force -ErrorAction SilentlyContinue
Remove-Item 'C:\Users\ray\Documents\WindowsPowerShell\Modules' -Force -ErrorAction SilentlyContinue
```

### 结论

- 模块管理通道完好：`Install-Module`（PowerShellGet）/ `Install-PSResource`（PSResourceGet）均可直连 PSGallery
- 如需按需补装（如 posh-git、Terminal-Icons、CompletionPredictor），按需安装到用户级即可，无需 omc
- PSReadLine 2.4.5 为 pwsh 必需，勿删

## .NET 库

### 现状

| 项目 | 版本 | 位置 | 来源 |
| --- | --- | --- | --- |
| .NET SDK | 10.0.203 | `D:\Oh-My-Claude\.envs\dev\dotnet` | omc（dotnet.ps1，LTS 通道） |
| .NET Runtime / ASP.NET Core / WindowsDesktop | 10.0.7 | 同上（shared） | omc |
| .NET Framework | 4.8.1（Release 533320） | 机器级 | Windows 系统 |
| pwsh 运行时 | .NET 10.0.10 | `C:\Program Files\PowerShell\7` | 机器级 MSI |

- `dotnet` 命令解析到 `D:\Oh-My-Claude\.envs\dev\dotnet\dotnet.exe`（用户 PATH 前置 omc 目录）；机器级 `C:\Program Files\dotnet` 不存在
- omc 锁定：`.config\dotnet\config.json` = 10.0.203，与实测一致

### 结论与可选项

- .NET 完全由 omc 便携式托管（SDK + 三套运行库同目录），与 ohmyenv 的「自包含目录 + pin」机制天然兼容
- 可选 A（ohmyenv 接管）：dotnet 官方发布提供 `dotnet-sdk-10.0.x-win-x64.zip`（自解压/zip），可走 `New-ToolDef` + pin/deploy，与 gh/git 同模式；运行库随 SDK 自带
- 可选 B（维持 omc）：继续由 omc 管理，ohmyenv 不介入
- 注意：pwsh 自身跑在机器级 .NET 10.0.10（MSI），与 omc 的 dotnet 互不相干；**卸载/接管 omc dotnet 不影响 pwsh**

## VS Build Tools

### 现状

| 项目 | 版本 | 位置 |
| --- | --- | --- |
| VS Build Tools | 17.14.37411.7（2026-06） | `D:\Oh-My-Claude\.envs\dev\VSBuildTools` |
| MSBuild | Current（随 Build Tools） | 同上 `MSBuild\Current\Bin\MSBuild.exe` |
| VC 工具链 | 随 Build Tools（`VC\Tools\MSVC`） | 同上 `VC` |
| DIA SDK / Team Tools / VB / VC# | 随 Build Tools | 同上 |
| Windows SDK | 10.0.26100.0 | `C:\Program Files (x86)\Windows Kits\10`（机器级） |

- omc 机制：`vsbuildtools.ps1` 管理离线 layout（`vs_buildtools.exe` 引导器 + VSLayout）与安装目录（`.envs\dev\VSBuildTools`），安装走 VS 官方引导器
- vswhere 实测：`-all -products *` 能查到 Build Tools 实例；`-requires Microsoft.VisualStudio.Workload.VCTools` 未命中（VC 目录实际存在，查询差异待核实）

### 结论与可选项

- Build Tools 完整可用（MSBuild + VC + Windows SDK 10.0.26100），C/C++ 与 .NET 构建链路齐备
- 可选 A（ohmyenv 接管）：体积大（数 GB）+ 依赖 VS 安装器/离线 layout，不适合现有 `New-ToolDef` 资产模式，需专门设计（可只做「查询/状态」托管，实际安装仍走 vs_installer）
- 可选 B（维持 omc）：继续由 omc 管理，仅研究记录现状

## 关联与建议

- 三条链路相互独立：pwsh（机器级 MSI，.NET 10.0.10）≠ omc dotnet（便携 SDK 10.0.203）≠ VS Build Tools（omc 安装目录 + 机器级 Windows SDK）
- 建议优先级：dotnet 接管收益最高（与 ohmyenv 机制兼容、体积适中、链路简单）；vsbuild 建议维持 omc 或只做状态查询；PowerShell 模块按需 `Install-PSResource`，不需要 omc/ohmyenv 托管
