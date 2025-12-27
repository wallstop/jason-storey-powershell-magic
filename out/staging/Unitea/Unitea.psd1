@{
    RootModule = 'Unitea.psm1'
    ModuleVersion = '2.2.0'
    GUID = 'a1b2c3d4-e5f6-1190-1234-567a90abcdef'
    Author = 'Jason Storey'
    Description = 'Utility functions for Unity Projects'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Open-UnityProject',
        'Add-UnityProject',
        'Update-UnityProject',
        'Get-UnityProjectSyncStatus',
        'Invoke-UniteaStartupSyncCheck',
        'Get-UnityProjects',
        'Remove-UnityProject',
        'Open-RecentUnityProject',
        'Get-UnityConfigPath'
    )
    AliasesToExport = @('unity', 'unity-add', 'unity-update', 'unity-check', 'unity-list', 'unity-remove', 'unity-recent', 'unity-config')
    PrivateData = @{
        PSData = @{
            Tags = @('Unity', 'ProjectManagement', 'FZF')
            ProjectUri = 'https://github.com/wallstop/jason-storey-powershell-magic'
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ReleaseNotes = 'Modularization, optimizations, and better path handling.'
        }
    }
}

