# oscdimg 接管研究

> 2026-08-20，来源：微软符号服务器下载实测 + `oscdimg` 无参运行实测。

## 现状

- oscdimg：Microsoft CD/DVD Premastering Utility（ISO 制作命令行工具，来自 Windows ADK）。
- 单文件 `oscdimg.exe`（约 140 KB），FileVersion/ProductVersion `2.56`，ProductName `OSCDIMG`。
- 下载源：微软符号服务器固定 URL（非 GitHub release）：
  `https://msdl.microsoft.com/download/symbols/oscdimg.exe/688CABB065000/oscdimg.exe`
- SHA256：`2000160b2c5044691b2f9a0ac308e5207f273d4880a572457af16d05886ba861`。

## 部署（ohmyenv 部署包，单二进制）

- `New-ToolDef`：`CdnUrl`（固定 URL，无 `{version}` 占位符）、`Extract='copy'`、
  `Dir='oscdimg'`、`Bin='oscdimg'`、`Exe='oscdimg\oscdimg.exe'`。
- pin `2.56`（取 FileVersion）→ deploy 到 `D:\ohmyenv\oscdimg` + 前置注册 PATH；sha256 校验。

## 版本识别（特殊）

- oscdimg **没有 `--version`**；`Get-InstalledVersion` 对 oscdimg 走文件版本：
  `(Get-Item $ExePath).VersionInfo.FileVersion`（返回 `2.56`）。

## 用途

- 制作 ISO（为后续 VS Build Tools 离线布局打包 ISO 准备，参考 `D:\hyper-v-lab` 的
  `oscdimg -m -u2 -udfver...` 用法）。
- 无参运行打印 `OSCDIMG 2.56 CD-ROM and DVD-ROM Premastering Utility` 用法。
