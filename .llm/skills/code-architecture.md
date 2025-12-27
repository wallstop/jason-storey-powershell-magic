# Skill: Code Architecture and Design

Use this skill when designing new features, refactoring existing code, or
deciding how to structure implementations.

## Core Principles

### Minimal Comments

Comments explain **why**, not **what**. Code should be self-documenting.

```powershell
# BAD: Comment describes what the code does
# Get the config path and check if it exists
$configPath = Get-ConfigPath
if (Test-Path $configPath) { ... }

# GOOD: No comment needed - names are descriptive
$configPath = Get-ConfigPath
if (Test-Path $configPath) { ... }

# GOOD: Comment explains non-obvious reasoning
# Skip validation for empty collections to avoid O(n²) on large datasets
if ($items.Count -eq 0) { return @() }
```

### SOLID Principles

| Principle                 | PowerShell Application                            |
| ------------------------- | ------------------------------------------------- |
| **Single Responsibility** | Each function does one thing well                 |
| **Open/Closed**           | Extend via parameters, not by modifying internals |
| **Liskov Substitution**   | Pipeline objects work interchangeably             |
| **Interface Segregation** | Small, focused parameter sets                     |
| **Dependency Inversion**  | Accept dependencies as parameters, not hardcoded  |

```powershell
# Single Responsibility - one function, one job
function Get-ProjectPath { ... }
function Test-ProjectExists { ... }
function New-ProjectStructure { ... }

# Dependency Inversion - injectable behavior
function Invoke-WithRetry {
    param(
        [scriptblock]$Action,
        [int]$MaxAttempts = 3
    )
    # Retry logic wraps any action
}
```

### DRY (Don't Repeat Yourself)

When you see the same pattern twice, extract it.

```powershell
# BAD: Duplicated validation logic
function Get-QuickJumpPath {
    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "Name cannot be empty"
    }
    # ...
}

function Add-QuickJumpPath {
    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "Name cannot be empty"
    }
    # ...
}

# GOOD: Shared validation in Common module
function Assert-NotNullOrWhiteSpace {
    param([string]$Value, [string]$ParameterName)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$ParameterName cannot be empty"
    }
}

function Get-QuickJumpPath {
    Assert-NotNullOrWhiteSpace -Value $Name -ParameterName 'Name'
    # ...
}
```

## Building Common Abstractions

### When to Abstract

Extract shared utilities when:

- Same pattern appears in **2+ places**
- Logic has **no module-specific dependencies**
- Abstraction is **simpler than duplication**

### Where to Put Shared Code

| Type              | Location                                   |
| ----------------- | ------------------------------------------ |
| Utility functions | `Modules/Common/Private/*.ps1`             |
| Exported helpers  | `Modules/Common/Public/*.ps1`              |
| Compiled patterns | `Modules/Common/Private/CompiledRegex.ps1` |
| Caching utilities | `Modules/Common/Private/ConfigCache.ps1`   |

### Lightweight Abstraction Patterns

Prefer value-based or function-based abstractions over complex objects:

```powershell
# GOOD: Simple hashtable for structured data
function New-PathEntry {
    param([string]$Name, [string]$Path)
    @{
        Name = $Name
        Path = $Path
        Created = [datetime]::UtcNow
    }
}

# GOOD: Function composition for behavior
function New-RetryPolicy {
    param([int]$MaxAttempts, [int]$DelayMs)
    return {
        param([scriptblock]$Action)
        for ($i = 0; $i -lt $MaxAttempts; $i++) {
            try { return & $Action }
            catch { Start-Sleep -Milliseconds $DelayMs }
        }
        throw "Max retries exceeded"
    }
}

# AVOID: Heavy class hierarchies for simple needs
class AbstractBaseHandler { ... }
class ConcreteHandler : AbstractBaseHandler { ... }
```

## Design Patterns in PowerShell

### Factory Pattern

```powershell
function New-ConfigProvider {
    param([ValidateSet('File', 'Environment', 'Registry')][string]$Type)

    switch ($Type) {
        'File'        { return { Get-Content $configPath | ConvertFrom-Json } }
        'Environment' { return { [System.Environment]::GetEnvironmentVariables() } }
        'Registry'    { return { Get-ItemProperty $regPath } }
    }
}
```

### Strategy Pattern

```powershell
function Invoke-Search {
    param(
        [string]$Query,
        [scriptblock]$SearchStrategy
    )
    & $SearchStrategy -Query $Query
}

$fuzzySearch = { param($Query) fzf --filter $Query }
$exactSearch = { param($Query) Select-String -Pattern $Query }

Invoke-Search -Query "test" -SearchStrategy $fuzzySearch
```

### Pipeline as Chain of Responsibility

```powershell
# Each function handles its concern and passes along
Get-ProjectFiles |
    Where-Object { $_.Extension -eq '.ps1' } |
    ForEach-Object { Test-ScriptSyntax $_ } |
    Where-Object { $_.IsValid }
```

## Tool vs Controller Pattern

A fundamental distinction in PowerShell design:

### Tools (Reusable Functions)

Functions designed for reuse across contexts:

- Accept input via **parameters only**
- Output raw **objects to pipeline** (not formatted text)
- **No direct screen output** (use `Write-Verbose`, `Write-Debug`)
- **Single responsibility** - do one thing well
- Designed for **pipeline integration**

```powershell
# ✅ TOOL: Reusable, pipeline-friendly
function Get-ExpiredFile {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path,

        [int]$DaysOld = 30
    )

    process {
        Get-ChildItem -Path $Path -File |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$DaysOld) }
    }
}
```

### Controllers (Automation Scripts)

Scripts for specific business processes:

- **Orchestrate** multiple tools
- May **format output** for display
- Handle **user interaction**
- **Specific** to business process
- **Not designed for reuse**

```powershell
# ✅ CONTROLLER: Orchestration script
# cleanup-old-logs.ps1

$logPaths = Get-Content -Path "$PSScriptRoot\log-paths.json" | ConvertFrom-Json

foreach ($logPath in $logPaths) {
    Write-Host "Checking $logPath..." -ForegroundColor Cyan

    $expired = Get-ExpiredFile -Path $logPath -DaysOld 90

    if ($expired) {
        Write-Host "Found $($expired.Count) files to remove" -ForegroundColor Yellow
        $expired | Remove-Item -WhatIf
    }
}
```

## Module Architecture

### Standard Module Structure

```text
MyModule/
├── MyModule.psd1              # Manifest (required for publishing)
├── MyModule.psm1              # Root module
├── Private/                   # Internal functions (not exported)
│   ├── Helper.ps1
│   └── Utility.ps1
├── Public/                    # Exported functions
│   ├── Get-Something.ps1
│   └── Set-Something.ps1
├── Classes/                   # PowerShell classes (if any)
└── en-US/                     # Help files
    └── about_MyModule.help.txt
```

### Module Manifest Best Practices

```powershell
@{
    RootModule        = 'MyModule.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    Author            = 'Your Name'
    Description       = 'Module description'
    PowerShellVersion = '7.0'

    # EXPLICITLY list exports - never use '*'
    FunctionsToExport = @('Get-Something', 'Set-Something')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # Dependencies
    RequiredModules   = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('Tag1', 'Tag2')
            ProjectUri = 'https://github.com/...'
            LicenseUri = 'https://...'
        }
    }
}
```

### Root Module Pattern

```powershell
# MyModule.psm1
$scriptRoot = $PSScriptRoot

# Dot-source private functions
Get-ChildItem -Path "$scriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }

# Dot-source public functions
Get-ChildItem -Path "$scriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }
```

## Code Consolidation Checklist

When adding new code, ask:

- [ ] Does similar logic already exist in `Common`?
- [ ] Can this be generalized for other modules?
- [ ] Is the abstraction simpler than the duplication?
- [ ] Does it minimize allocations (prefer hashtables over classes)?
- [ ] Are names descriptive enough to avoid comments?

## Existing Common Utilities

Check these before creating new helpers:

| File                | Purpose                                     |
| ------------------- | ------------------------------------------- |
| `CompiledRegex.ps1` | Pre-compiled regex patterns for performance |
| `ConfigCache.ps1`   | Cached configuration loading                |
| `HelpSupport.ps1`   | Help text generation utilities              |

## Anti-Patterns to Avoid

| Anti-Pattern                     | Better Approach                            |
| -------------------------------- | ------------------------------------------ |
| Copy-paste code                  | Extract to Common function                 |
| Comments explaining obvious code | Use descriptive names                      |
| Large monolithic functions       | Break into single-responsibility functions |
| Hardcoded dependencies           | Accept as parameters                       |
| Deep class hierarchies           | Use composition with functions             |
| Magic numbers/strings            | Named constants or configuration           |
| `$array += $item` in loops       | Use `[List[T]]` and `.Add()`               |
| `return $result`                 | Just `$result` (implicit output)           |
| `Write-Host` in tools            | Use `Write-Verbose` or return objects      |
| `*` in export fields             | Explicitly list exported functions         |
| Mixing output types              | Single consistent output type per function |

## Output Design

### Return Objects, Not Strings

```powershell
# ❌ WRONG: Returning formatted strings
function Get-ServerStatus {
    "Server $name is $status"
}

# ✅ CORRECT: Return objects, let user format
function Get-ServerStatus {
    [OutputType([PSCustomObject])]
    param([string]$Name)

    [PSCustomObject]@{
        Name      = $Name
        Status    = 'Online'
        CheckedAt = Get-Date
    }
}
```

### Single Output Type

Don't mix different types in output:

```powershell
# ❌ WRONG: Mixed output types break formatting
function Get-SystemInfo {
    "Starting check..."           # String
    Get-Process | Select-Object -First 5  # Process objects
    "Done!"                       # String again
}

# ✅ CORRECT: Use streams for messages, single type for output
function Get-SystemInfo {
    [CmdletBinding()]
    [OutputType([System.Diagnostics.Process])]
    param()

    Write-Verbose "Starting check..."
    Get-Process | Select-Object -First 5
    Write-Verbose "Done!"
}
```
