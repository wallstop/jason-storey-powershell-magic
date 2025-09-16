@{
    RootModule = 'Unitea.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-1190-1234-567a90abcdef'
    Author = 'Jason Storey'
    Description = 'Utility functions for Unity Projects'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Open-UnityProject',
        'Add-UnityProject',
        'Get-UnityProjects',
        'Remove-UnityProject',
        'Open-RecentUnityProject',
        'Get-UnityConfigPath'
    )
    AliasesToExport = @('unity', 'unity-add', 'unity-list', 'unity-remove', 'unity-recent', 'unity-config')
    PrivateData = @{
        PSData = @{
            Tags = @('Unity', 'ProjectManagement', 'FZF')
            ReleaseNotes = 'Added config path function and enhanced interactive remove'
        }
    }
}