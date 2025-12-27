# Skill: Add a New Module

Use this skill when creating a new PowerShell module or restructuring existing
module code. For documentation requirements, see
[documentation.md](documentation.md).

## Module Directory Structure

Create the following structure under `Modules/<ModuleName>/`:

```text
Modules/<ModuleName>/
├── <ModuleName>.psd1      # Module manifest
├── <ModuleName>.psm1      # Root module (dot-sources Private/ and Public/)
├── Private/
│   └── <ModuleName>.Internal.ps1  # Helper functions (not exported)
└── Public/
    └── <ModuleName>.Commands.ps1  # Exported cmdlets
```

## Step-by-Step Process

### 1. Create the Module Manifest (.psd1)

```powershell
@{
    RootModule = '<ModuleName>.psm1'
    ModuleVersion = '1.0.0'
    GUID = '<generate-new-guid>'
    Author = 'PowerShell Magic Contributors'
    Description = 'Brief description of module purpose'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Verb-Noun'  # List all public functions
    )
    PrivateData = @{ PSData = @{} }
}
```

### 2. Create the Root Module (.psm1)

```powershell
# Dot-source private helpers
Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }

# Dot-source public commands
Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }
```

### 3. Create Private Helper Functions

Place internal utilities in `Private/<ModuleName>.Internal.ps1`:

- Functions here are NOT exported
- Use for shared logic, validation, file I/O helpers
- Name with descriptive internal names (no Verb-Noun required)

### 4. Create Public Commands

Place exported cmdlets in `Public/<ModuleName>.Commands.ps1`:

- Use approved PowerShell verbs (`Get-Verb` to list)
- Include full comment-based help (Synopsis, Description, Parameters, Examples)
- Use `[CmdletBinding()]` for advanced function features
- Support pipeline input where appropriate

### 5. Update Module Manifest Exports

Keep `FunctionsToExport` in the `.psd1` accurate:

```powershell
FunctionsToExport = @(
    'Get-Thing',
    'Set-Thing',
    'New-Thing'
)
```

## Validation Checklist

- [ ] Module imports without errors: `Import-Module ./Modules/<Name> -Force`
- [ ] All public functions appear: `Get-Command -Module <Name>`
- [ ] Help is available: `Get-Help <Function-Name> -Full`
- [ ] Tests pass: `.\Tests\Test-PowerShellMagic.ps1 -TestName <Name>`
- [ ] **CHANGELOG.md updated** with module addition
- [ ] **New user guide created** in `docs/<module>-guide.md`
- [ ] **command-reference.md updated** with all new commands
- [ ] **README.md updated** with module overview

## Common Patterns

### Reusing Helpers Across Modules

If multiple modules need the same helper, consider:

1. Adding to `Modules/Common/Private/` for shared utilities
2. Dot-sourcing from the dependent module

### Configuration Storage

Follow existing patterns:

- QuickJump: `~/.quickjump/` for user data
- Templater: `~/.templater/` for templates
- Use `$env:LOCALAPPDATA` on Windows, `~/.config/` on Unix
