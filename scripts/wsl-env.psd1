# wsl-env.psd1 - WSL（Linux）软件部署锁定清单（由 ohmywsl.ps1 维护，勿手改）
# 与 env.psd1 同构：字段语义与 Windows 侧一致，但资产为 Linux 资产；唯一 pin 来源。
# 注意：含中文须 UTF-8 带 BOM（AGENTS 规则 4）。
@{
    Distro = 'ohmywsl'
    User   = 'ray'
    Tools  = @{
        'age' = @{
            Version      = '1.3.1'
            Tag          = 'v1.3.1'
            TagPrefix    = 'v'
            Repo         = 'FiloSottile/age'
            AssetPattern = '^age-v[0-9.]+-linux-amd64\.tar\.gz$'
            Asset        = 'age-v1.3.1-linux-amd64.tar.gz'
            SumsAsset    = ''
            SumsPattern  = ''
            Component    = 'age'
            Sha256       = 'BDC69C09CBDD6CF8B1F333D372A1F58247B3A33146406333E30C0F26E8F51377'
        }
        'sops' = @{
            Version      = '3.13.3'
            Tag          = 'v3.13.3'
            TagPrefix    = 'v'
            Repo         = 'getsops/sops'
            AssetPattern = '^sops-v[0-9.]+\.linux\.amd64$'
            Asset        = 'sops-v3.13.3.linux.amd64'
            SumsAsset    = 'sops-v{version}.checksums.txt'
            SumsPattern  = 'sops-v.*\.linux\.amd64'
            Component    = 'sops'
            Sha256       = 'E5BEC3346A873AE91D871550F3E698C1AAD962AFF462A080E40F25FDE17FEF6B'
        }
        'vault' = @{
            Version          = '2.0.4'
            Tag              = '2.0.4'
            TagPrefix        = ''
            CdnIndexUrl      = 'https://releases.hashicorp.com/vault/index.json'
            CdnAssetPattern  = '^vault_{version}_linux_amd64\.zip$'
            Asset            = 'vault_2.0.4_linux_amd64.zip'
            Component        = 'vault'
            Sha256           = '7429E7D85F8EF29DF063701C49420F7984A0AE2C8511C026CC75EDFBBB2DF387'
        }
        'codex' = @{
            Version      = '0.148.0'
            Tag          = 'rust-v0.148.0'
            TagPrefix    = 'rust-v'
            Repo         = 'openai/codex'
            AssetPattern = '^codex-package-x86_64-unknown-linux-musl\.tar\.gz$'
            Asset        = 'codex-package-x86_64-unknown-linux-musl.tar.gz'
            SumsAsset    = 'codex-package_SHA256SUMS'
            SumsPattern  = 'codex-package-x86_64-unknown-linux-musl\.tar\.gz'
            Component    = 'codex'
            Sha256       = '8C790500AF2BA6E74CE4948FE26C651AC1F77F6DBB005B47C8D26FF711146262'
        }
        'claude' = @{
            Version      = '2.1.238'
            Tag          = 'v2.1.238'
            TagPrefix    = 'v'
            Repo         = 'anthropics/claude-code'
            AssetPattern = '^claude-linux-x64\.tar\.gz$'
            Asset        = 'claude-linux-x64.tar.gz'
            SumsAsset    = 'SHASUMS256.txt'
            SumsPattern  = 'claude-linux-x64\.tar\.gz'
            Component    = 'claude'
            Sha256       = '1504400055A4427392CF27CCB3F93B4AA9566B6DADD1DFD98279CD25F79CE490'
        }
        'kimi' = @{
            Version      = '0.38.0'
            Tag          = '@moonshot-ai/kimi-code@0.38.0'
            TagPrefix    = '@moonshot-ai/kimi-code@'
            Repo         = 'MoonshotAI/kimi-code'
            AssetPattern = '^kimi-code-linux-x64\.zip$'
            Asset        = 'kimi-code-linux-x64.zip'
            SumsAsset    = ''
            SumsPattern  = ''
            AssetShaSuffix = '.sha256'
            Component    = 'kimi'
            Sha256       = '2278E0C90283985C4DF46B775BF0F163D07684A7B1BFC83EE3B42844F6FCCDFB'
        }
        'herdr' = @{
            Version      = '0.8.2'
            Tag          = 'v0.8.2'
            TagPrefix    = 'v'
            Repo         = 'herdrdev/herdr'
            AssetPattern = '^herdr-linux-x86_64$'
            Asset        = 'herdr-linux-x86_64'
            SumsAsset    = ''
            SumsPattern  = ''
            Component    = 'herdr'
            Sha256       = '976150A14D490C94B243EA2E1A7EB2DFB67F12E36B182DB90936F6728E6AECF4'
        }
        'ast-grep' = @{
            Version      = '0.45.1'
            Tag          = '0.45.1'
            TagPrefix    = ''
            Repo         = 'ast-grep/ast-grep'
            AssetPattern = '^app-x86_64-unknown-linux-gnu\.zip$'
            Asset        = 'app-x86_64-unknown-linux-gnu.zip'
            SumsAsset    = ''
            SumsPattern  = ''
            Component    = 'ast-grep'
            Sha256       = '76FB6555BE6734FB5057DBA8D2FB756430F374BB9E1AF694CF1CE00E13238D63'
        }
        'rg' = @{
            Version      = '15.2.0'
            Tag          = '15.2.0'
            TagPrefix    = ''
            Repo         = 'BurntSushi/ripgrep'
            AssetPattern = '^ripgrep-[0-9.]+-x86_64-unknown-linux-musl\.tar\.gz$'
            Asset        = 'ripgrep-15.2.0-x86_64-unknown-linux-musl.tar.gz'
            SumsAsset    = ''
            SumsPattern  = ''
            AssetShaSuffix = '.sha256'
            Component    = 'rg'
            Sha256       = '33E15BCF1624B25CDD2A55813A47A2F95DBE126268203E76AA6A585D1E7B149C'
        }
        'jq' = @{
            Version      = '1.8.2'
            Tag          = 'jq-1.8.2'
            TagPrefix    = 'jq-'
            Repo         = 'jqlang/jq'
            AssetPattern = '^jq-linux-amd64$'
            Asset        = 'jq-linux-amd64'
            SumsAsset    = 'sha256sum.txt'
            SumsPattern  = 'jq-linux-amd64'
            Component    = 'jq'
            Sha256       = 'B1C22172DD303F3BE49E935AA56AA48A8B7A46E0BC838B4997D3BB451495870F'
        }
        'yq' = @{
            Version      = '4.53.6'
            Tag          = 'v4.53.6'
            TagPrefix    = 'v'
            Repo         = 'mikefarah/yq'
            AssetPattern = '^yq_linux_amd64$'
            Asset        = 'yq_linux_amd64'
            SumsAsset    = ''
            SumsPattern  = ''
            Component    = 'yq'
            Sha256       = 'C5F056448F973AE7D39B5401949648A78F2DC1947D6A8EB65BE60D5C504B9385'
        }
        'shellcheck' = @{
            Version      = '0.11.0'
            Tag          = 'v0.11.0'
            TagPrefix    = 'v'
            Repo         = 'koalaman/shellcheck'
            AssetPattern = '^shellcheck-v[0-9.]+\.linux\.x86_64\.tar\.xz$'
            Asset        = 'shellcheck-v0.11.0.linux.x86_64.tar.xz'
            SumsAsset    = ''
            SumsPattern  = ''
            Component    = 'shellcheck'
            Sha256       = '8C3BE12B05D5C177A04C29E3C78CE89AC86F1595681CAB149B65B97C4E227198'
        }
        'just' = @{
            Version      = '1.58.0'
            Tag          = '1.58.0'
            TagPrefix    = ''
            Repo         = 'casey/just'
            AssetPattern = '^just-[0-9.]+-x86_64-unknown-linux-musl\.tar\.gz$'
            Asset        = 'just-1.58.0-x86_64-unknown-linux-musl.tar.gz'
            SumsAsset    = 'SHA256SUMS'
            SumsPattern  = 'just-.*-x86_64-unknown-linux-musl\.tar\.gz'
            Component    = 'just'
            Sha256       = '4A5CC2F53E6F0F8C59092A6CC38291EB729D46A7DD95D3AE582008881B84931D'
        }
    }
}
