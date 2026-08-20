@{
    RootModule        = 'omp.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '1ffcf5b7-6c5f-4514-8d46-ff4ee4ff3bd2'
    Author            = 'ohmypwsh'
    CompanyName       = 'ohmypwsh'
    Copyright         = '(c) ohmypwsh'
    Description       = 'Agent 环境部署与管理模块 CLI（omp）'
    PowerShellVersion = '7.0'
    FunctionsToExport = 'Invoke-Omp'
    AliasesToExport   = 'omp'
    CmdletsToExport   = @()
    VariablesToExport = @()
    PrivateData       = @{
        PSData = @{
            Tags = @('ohmyenv', 'agent', 'environment', 'deployment')
        }
    }
}
