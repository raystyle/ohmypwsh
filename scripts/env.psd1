# env.psd1 - 环境依赖锁定清单（由 ohmyenv CLI 维护，勿手改）
@{
    EnvRoot = 'D:\ohmyenv'
    Tools   = @{
        gh = @{
            Version      = '2.91.0'
            Tag          = 'v2.91.0'
            Repo         = 'cli/cli'
            AssetPattern = '^gh_[0-9.]+_windows_amd64\.zip$'
            Asset        = 'gh_2.91.0_windows_amd64.zip'
            Dir          = 'gh'
            Bin          = 'gh\bin'
            Exe          = 'gh\bin\gh.exe'
            Extract      = 'zip'
            Sha256       = 'CED3E6F4BB5A9865056B594B7AD0CF42137DC92C494346F1CA705B5DBF14C88E'
        }
        git = @{
            Version      = '2.54.0.windows.1'
            Tag          = 'v2.54.0.windows.1'
            Repo         = 'git-for-windows/git'
            AssetPattern = '^PortableGit-[0-9.]+-64-bit\.7z\.exe$'
            Asset        = 'PortableGit-2.54.0-64-bit.7z.exe'
            Dir          = 'git'
            Bin          = 'git\cmd'
            Exe          = 'git\cmd\git.exe'
            Extract      = '7zsfx'
            Sha256       = 'BEA006A6CC69673F27B1647E84AB3A68E912FBC175AB6320C5987E012897F311'
        }
    }
}
