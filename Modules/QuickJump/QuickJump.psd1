@{
    RootModule = 'QuickJump.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-1234-567890abcdef'
    Author = 'Your Name'
    Description = 'Quick directory jumping with categories and aliases, inspired by zoxide'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Add-QuickJumpPath',
        'Remove-QuickJumpPath',
        'Get-QuickJumpPaths',
        'Invoke-QuickJump',
        'Invoke-QuickJumpCategory',
        'Get-QuickJumpCategories',
        'Open-QuickJumpRecent',
        'Get-QuickJumpConfigPath'
    )
    AliasesToExport = @('qj', 'qja', 'qjr', 'qjl', 'qjc', 'qjrecent')
    PrivateData = @{
        PSData = @{
            Tags = @('Navigation', 'Directory', 'Jump', 'FZF', 'Productivity')
            ReleaseNotes = 'Enhanced with comprehensive documentation, tab completion, and standardized parameters'
        }
    }
}
