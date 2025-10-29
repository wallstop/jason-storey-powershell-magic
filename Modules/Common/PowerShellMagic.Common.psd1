@{
    RootModule = 'PowerShellMagic.Common.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'f8a54d3c-4d9a-4e77-9bf5-1c5a948bb0f4'
    Author = 'PowerShell Magic Maintainers'
    Description = 'Shared helper functions used across PowerShell Magic modules.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Get-PSMagicConfigPath',
        'Copy-PSMagicHashtable',
        'Test-FzfAvailable',
        'Test-PSMagicNonInteractive'
    )
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Utilities', 'PowerShellMagic')
            ProjectUri = 'https://github.com/wallstop/jason-storey-powershell-magic'
        }
    }
}
