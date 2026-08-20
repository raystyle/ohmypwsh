# PowerShell 7 遥测关闭研究

> 2026-08-20，来源：官方 `about_Telemetry` + GitHub Issue #24865 / PowerShell/Announcements #67 实测。

## 结论

PowerShell 7 遥测关闭有三种方式（按推荐顺序）：

1. **MSI 安装参数 `DISABLE_TELEMETRY=1`**：静默安装时直接关闭，等效设置
   `POWERSHELL_TELEMETRY_OPTOUT=1`（GitHub Issue 实测确认）。
2. **环境变量 `POWERSHELL_TELEMETRY_OPTOUT`**：设为 `true` / `yes` / `1`（任一值），必须在启动
   PowerShell 前设置才生效。
3. **Windows 系统诊断设置**（7.6.2+）：`设置 → 隐私和安全性 → 诊断和反馈`，PowerShell 遥测会
   尊重系统级开关，不再只看环境变量。

另有更新检查通知开关：`POWERSHELL_UPDATECHECK=Off`（关闭启动时的版本更新检查/通知）。

## 官方命令

```powershell
[Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'User')
[Environment]::SetEnvironmentVariable('POWERSHELL_UPDATECHECK', 'Off', 'User')
```

## 本机集成

- `scripts\set-pwsh.ps1` 安装/升级时 `msiexec /i ... DISABLE_TELEMETRY=1`，并在安装后幂等写入
  用户级 `POWERSHELL_TELEMETRY_OPTOUT=1` 与 `POWERSHELL_UPDATECHECK=Off`。

