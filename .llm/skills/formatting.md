# Skill: Code Formatting and Style

Use this skill when writing new PowerShell code or fixing formatting issues. For
architecture and design principles, see
[code-architecture.md](code-architecture.md). For error handling patterns, see
[defensive-powershell.md](defensive-powershell.md).

## Quick Commands

```powershell
# Check formatting (reports issues)
.\Format-PowerShell.ps1 -Check

# Auto-fix formatting issues
.\Format-PowerShell.ps1 -Fix

# Format specific directory
.\Format-PowerShell.ps1 -Path "Modules/QuickJump" -Fix
```

## PSScriptAnalyzer Rules

The project uses `PSScriptAnalyzerSettings.psd1` for consistent formatting.

### Indentation

- **4 spaces** (no tabs)
- Consistent throughout nested blocks

```powershell
# Correct
function Get-Thing {
    if ($condition) {
        Do-Something
    }
}

# Wrong (2 spaces or tabs)
function Get-Thing {
  if ($condition) {
    Do-Something
  }
}
```

### Bracing Style (One True Brace Style - OTBS)

- Opening brace on **same line** as statement
- Closing brace on its own line
- Small scriptblocks allowed on single line

```powershell
# Correct
if ($condition) {
    Do-Something
} else {
    Do-Other
}

# Correct - small scriptblock on one line
Get-ChildItem | Where-Object { $_.Length -gt 10mb }

# Wrong (brace on new line - Allman style)
if ($condition)
{
    Do-Something
}
```

### Line Length

- **Limit lines to 115 characters** (fits console and GitHub diffs)
- Use **splatting** for long cmdlet calls (never backticks)

```powershell
# ❌ WRONG: Backticks for continuation
Get-WmiObject -Class Win32_LogicalDisk `
              -Filter "DriveType=3" `
              -ComputerName SERVER2

# ✅ CORRECT: Splatting
$params = @{
    Class        = 'Win32_LogicalDisk'
    Filter       = 'DriveType=3'
    ComputerName = 'SERVER2'
}
Get-WmiObject @params
```

### Naming Conventions

| Element                | Convention                | Example              |
| ---------------------- | ------------------------- | -------------------- |
| Functions              | PascalCase with Verb-Noun | `Get-QuickJumpPath`  |
| Parameters             | PascalCase                | `$FilePath`          |
| Private variables      | camelCase                 | `$configPath`        |
| Script-scope variables | `$Script:` prefix         | `$Script:CachedData` |

### Approved Verbs

Use PowerShell approved verbs for cmdlets:

```powershell
Get-Verb  # Lists all approved verbs
```

Common verbs: `Get`, `Set`, `New`, `Remove`, `Add`, `Clear`, `Export`, `Import`,
`Invoke`, `Test`

### Aliases

**Avoid aliases in scripts**—use full cmdlet names for clarity and
cross-platform compatibility:

```powershell
# ✅ CORRECT: Full cmdlet names
Get-ChildItem -Path $folder | Where-Object { $_.Extension -eq '.ps1' }
ForEach-Object { $_.Name }
Select-Object -First 10

# ❌ AVOID: Aliases (less readable, may not exist cross-platform)
gci $folder | ? { $_.Extension -eq '.ps1' }
% { $_.Name }
select -First 10
```

**Exception**: Interactive shell use is fine with aliases.

### Parameters

- Use explicit types where applicable
- Include `[CmdletBinding()]` for advanced functions
- Define parameter attributes clearly

```powershell
function Get-Thing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Path,

        [Parameter()]
        [ValidateSet('Option1', 'Option2')]
        [string]$Mode = 'Option1',

        [switch]$Force
    )

    process {
        # Implementation
    }
}
```

### Security Rules

- **No plain text passwords** in scripts
- Use `[SecureString]` for sensitive data
- Validate file paths before operations

## Comment-Based Help

Public functions **require** comment-based help (this is documentation, not
inline comments):

```powershell
function Get-Thing {
    <#
    .SYNOPSIS
    Brief one-line description.

    .DESCRIPTION
    Detailed description of what the function does.

    .PARAMETER Path
    Description of the Path parameter.

    .EXAMPLE
    Get-Thing -Path "C:\folder"
    Description of what this example does.

    .EXAMPLE
    "C:\folder" | Get-Thing
    Pipeline example.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string]$Path
    )
    # ...
}
```

### Inline Comments

**Minimize inline comments.** Code should be self-documenting through
descriptive names.

```powershell
# BAD: Comment describes what the code does
# Get the config path from environment
$configPath = $env:CONFIG_PATH

# GOOD: No comment needed - code is obvious
$configPath = $env:CONFIG_PATH

# GOOD: Comment explains WHY (non-obvious reasoning)
# Retry needed because Unity Hub can lock files briefly after launch
Start-Sleep -Seconds 2
```

## Pre-Commit Validation

Formatting is checked automatically on commit if hooks are installed:

```powershell
# Install hooks
.\Setup-Hooks.ps1

# Manual pre-commit check
.\Run-Tests.ps1 -Format
```

## Common Formatting Issues

| Issue                       | Fix                                         |
| --------------------------- | ------------------------------------------- |
| Trailing whitespace         | Remove spaces at end of lines               |
| Missing newline at EOF      | Add blank line at end of file               |
| Inconsistent indentation    | Use 4 spaces everywhere                     |
| Alias usage                 | Replace with full cmdlet names              |
| Missing `[CmdletBinding()]` | Add to all public functions                 |
| Backtick line continuation  | Use splatting instead                       |
| Lines over 115 chars        | Break with splatting or multiple statements |

## PSScriptAnalyzer Configuration Reference

Key rules enforced in this repository (see `PSScriptAnalyzerSettings.psd1`):

```powershell
@{
    Rules = @{
        # Style
        PSPlaceOpenBrace = @{
            Enable             = $true
            OnSameLine         = $true       # OTBS style
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }
        PSUseConsistentIndentation = @{
            Enable          = $true
            IndentationSize = 4
            Kind            = 'space'
        }

        # Cmdlet Design
        PSUseApprovedVerbs = @{ Enable = $true }
        PSUseSingularNouns = @{ Enable = $true }
        PSAvoidUsingCmdletAliases = @{ Enable = $true }
        PSAvoidUsingPositionalParameters = @{ Enable = $true }

        # Security
        PSAvoidUsingPlainTextForPassword = @{ Enable = $true }
        PSUsePSCredentialType = @{ Enable = $true }
        PSAvoidUsingInvokeExpression = @{ Enable = $true }

        # Best Practices
        PSAvoidGlobalVars = @{ Enable = $true }
        PSAvoidUsingEmptyCatchBlock = @{ Enable = $true }
        PSUseShouldProcessForStateChangingFunctions = @{ Enable = $true }
        PSProvideCommentHelp = @{ Enable = $true }
    }
}
```
