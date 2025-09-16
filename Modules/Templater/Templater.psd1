@{
    RootModule = 'Templater.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2d3d4-e55f-7890-1234-567890abcdef'
    Author = 'Jason Storey'
    Description = 'Register and Restore Templates'
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        'Add-Template',
        'Get-Templates',
        'Use-Template',
        'Remove-Template',
        'Update-Template',
        'Export-Templates',
        'Import-Templates',
        'Get-TemplateStats',
        'Get-TemplaterConfigPath'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @(
        'templates',
        'template',
        'tpl',
        'use-tpl',
        'add-tpl',
        'remove-tpl'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            Tags = @('template', '7zip', 'workflow', 'fzf', 'starter', 'project')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = 'https://github.com/yourname/Templater'
            ReleaseNotes = 'Initial public release - 2024-06'
        }
    }
}

