# modules.psd1 - PowerShell 模块锁定清单（由 psmodule.ps1 维护，勿手改）
@{
    ModuleRoot = 'D:\ohmyenv\modules'
    Modules    = @{
        'Pester' = @{
            Version = '5.7.1'
            Source  = 'PSGallery'
            Package = 'Pester.5.7.1.nupkg'
            Sha256  = '4A27904C6814A5FBE4758F8E49861F6A1994AEE77B71165A5C43C0371BA6C580'
            Target  = 'Shared'
        }
    }
}
