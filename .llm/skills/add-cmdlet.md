# Skill: Add a New Cmdlet

Use this skill when adding a new command to an existing module. For architecture
and design principles, see [code-architecture.md](code-architecture.md). For
defensive coding patterns, see
[defensive-powershell.md](defensive-powershell.md). For documentation
requirements, see [documentation.md](documentation.md). For testing
requirements, see [add-tests.md](add-tests.md).

## Quick Reference

1. Add function to `Modules/<Module>/Public/<Module>.Commands.ps1`
2. Update `FunctionsToExport` in `Modules/<Module>/<Module>.psd1`
3. **Add exhaustive tests** in `Tests/Test-PowerShellMagic.ps1`
4. **Update ALL documentation** (CHANGELOG, user guide, command-reference)
5. Run `.\Run-Tests.ps1` to validate

> **Important:** A cmdlet is not complete without exhaustive tests AND
> comprehensive documentation. Both are required deliverables, not
> afterthoughts.

## Cmdlet Template

```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
    One-line description of what the cmdlet does.

    .DESCRIPTION
    Detailed description explaining the cmdlet's purpose and behavior.

    .PARAMETER ParameterName
    Description of this parameter.

    .EXAMPLE
    Verb-Noun -ParameterName "value"
    Description of what this example does.

    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ParameterName,

        [Parameter()]
        [ValidateSet('Option1', 'Option2', 'Option3')]
        [string]$AnotherParam = 'Option1',

        [switch]$Force
    )

    begin { }

    process { }

    end { }
}
```

**Note:** Comment-based help is documentation for users. Avoid inline comments
within the function body—rely on descriptive names instead.

## Advanced Cmdlet Template (State-Changing)

For cmdlets that modify system state, use `SupportsShouldProcess`:

```powershell
function Remove-ExpiredItem {
    <#
    .SYNOPSIS
    Removes items that have expired.

    .DESCRIPTION
    Removes items older than the specified age. Supports -WhatIf and -Confirm.

    .PARAMETER Path
    The path to check for expired items.

    .PARAMETER Age
    Maximum age in days. Items older than this are removed.

    .EXAMPLE
    Remove-ExpiredItem -Path "C:\Logs" -Age 30
    Removes log files older than 30 days.

    .EXAMPLE
    Remove-ExpiredItem -Path "C:\Logs" -Age 30 -WhatIf
    Shows what would be removed without actually deleting.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateScript({
            if (-not (Test-Path $_)) { throw "Path not found: $_" }
            $true
        })]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 365)]
        [int]$Age,

        [switch]$Force
    )

    process {
        $items = Get-ChildItem -Path $Path -File |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$Age) }

        foreach ($item in $items) {
            if ($Force -or $PSCmdlet.ShouldProcess($item.FullName, 'Delete')) {
                try {
                    Remove-Item -Path $item.FullName -ErrorAction Stop
                    Write-Verbose "Removed: $($item.FullName)"
                }
                catch {
                    Write-Error "Failed to remove $($item.FullName): $_"
                }
            }
        }
    }
}
```

## Naming Guidelines

### Approved Verbs

Use `Get-Verb` to see all approved verbs. Common ones:

| Category      | Verbs                                |
| ------------- | ------------------------------------ |
| Common        | `Get`, `Set`, `New`, `Remove`        |
| Data          | `Export`, `Import`, `Convert`        |
| Lifecycle     | `Start`, `Stop`, `Enable`, `Disable` |
| Diagnostic    | `Test`, `Debug`, `Measure`           |
| Communication | `Send`, `Receive`                    |

### Noun Patterns

Follow existing module conventions:

- **QuickJump**: `*-QuickJumpPath`, `*-QuickJumpAlias`
- **Templater**: `*-Template`, `*-TemplateToken`
- **Unitea**: `*-UnityProject`, `*-UnityVersion`

## Parameter Best Practices

### Common Parameter Patterns

```powershell
# Path parameter with pipeline support
[Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
[string]$Path = (Get-Location).Path

# Mandatory with validation
[Parameter(Mandatory = $true)]
[ValidateNotNullOrEmpty()]
[string]$Name

# Optional with default
[Parameter()]
[int]$Count = 10

# Switch for boolean flags
[switch]$Force
[switch]$PassThru
[switch]$WhatIf
```

### Validation Attributes

```powershell
[ValidateNotNullOrEmpty()]        # Not null or empty string
[ValidateSet('A', 'B', 'C')]      # Only these values allowed
[ValidateRange(1, 100)]           # Numeric range
[ValidatePattern('^[a-z]+$')]     # Regex pattern
[ValidateScript({ Test-Path $_ })] # Custom validation
[ValidateLength(1, 50)]           # String length constraints
[ValidateCount(1, 5)]             # Collection count limits
```

### Prefer ValidateScript for User-Friendly Errors

```powershell
# ❌ Cryptic regex error message
[ValidatePattern('^\d{3}$')]

# ✅ Clear custom message
[ValidateScript({
    if ($_ -match '^\d{3}$') { $true }
    else { throw "Value must be exactly 3 digits" }
})]
```

See [defensive-powershell.md](defensive-powershell.md) for comprehensive
validation guidance.

## Adding to Module Manifest

Update `FunctionsToExport` in the `.psd1`:

```powershell
# Before
FunctionsToExport = @(
    'Get-QuickJumpPath',
    'Add-QuickJumpPath'
)

# After
FunctionsToExport = @(
    'Get-QuickJumpPath',
    'Add-QuickJumpPath',
    'Remove-QuickJumpPath'  # New function
)
```

## Writing Tests

Add **exhaustive** test coverage in `Tests/Test-PowerShellMagic.ps1`:

```powershell
function Test-NewCmdlet {
    Write-TestInfo "Testing Verb-Noun..."

    # Happy path tests
    $result = Verb-Noun -ParameterName "valid-input"
    Assert-NotNull -Value $result -Message "Returns a result for valid input"

    # Test parameter validation - edge cases
    $edgeCases = @(
        @{ Input = ''; ShouldThrow = $true; Desc = 'Rejects empty string' }
        @{ Input = $null; ShouldThrow = $true; Desc = 'Rejects null' }
        @{ Input = '   '; ShouldThrow = $true; Desc = 'Rejects whitespace' }
        @{ Input = 'valid'; ShouldThrow = $false; Desc = 'Accepts valid input' }
    )

    foreach ($case in $edgeCases) {
        $threw = $false
        try { Verb-Noun -ParameterName $case.Input } catch { $threw = $true }
        Assert-Equal -Expected $case.ShouldThrow -Actual $threw -Message $case.Desc
    }

    # Test pipeline input
    $pipeResult = "input" | Verb-Noun
    Assert-NotNull -Value $pipeResult -Message "Accepts pipeline input"

    # Test error conditions
    $invalidInputs = @([char]0, '../path/traversal', 'name<>|')
    foreach ($invalid in $invalidInputs) {
        $threw = $false
        try { Verb-Noun -ParameterName $invalid } catch { $threw = $true }
        Assert-True -Condition $threw -Message "Rejects invalid: $invalid"
    }
}
```

See [add-tests.md](add-tests.md) for comprehensive testing guidance including
data-driven tests, edge cases, and error handling.

## Checklist

### Code Requirements

- [ ] Function uses approved verb (`Get-Verb`)
- [ ] Noun follows module naming pattern
- [ ] Full comment-based help included
- [ ] `[CmdletBinding()]` attribute present
- [ ] Parameters have appropriate validation
- [ ] Pipeline support where appropriate
- [ ] Added to `FunctionsToExport` in manifest

### Test Requirements (see [add-tests.md](add-tests.md))

- [ ] Happy path tests written
- [ ] Edge case tests (empty, null, whitespace, boundaries)
- [ ] Error condition tests (invalid inputs, missing params)
- [ ] Negative tests (what should NOT work)
- [ ] Pipeline tests (if pipeline supported)
- [ ] All tests passing (`.\Run-Tests.ps1`)
- [ ] Tests pass in CI mode (`.\Run-Tests.ps1 -CI`)

### Documentation Requirements (see [documentation.md](documentation.md))

- [ ] **CHANGELOG.md updated** with new command entry
- [ ] **User guide updated** (e.g., `docs/quickjump-guide.md`)
- [ ] **command-reference.md updated** with command details
- [ ] **ALL code samples tested** and working
- [ ] **Version annotation** added if appropriate

### Formatting

- [ ] Formatting passes (`.\Format-PowerShell.ps1 -Check`)

## Helper Functions

If your cmdlet needs internal helpers:

1. Add to `Modules/<Module>/Private/<Module>.Internal.ps1`
2. These are automatically available (dot-sourced by .psm1)
3. Do NOT add to `FunctionsToExport` (keeps them private)
4. **Check `Common` module first**—it may already have what you need

```powershell
# In Private/<Module>.Internal.ps1
function Get-InternalHelper {
    param([string]$Input)
    # Helper logic
}

# In Public/<Module>.Commands.ps1
function Get-PublicCommand {
    [CmdletBinding()]
    param([string]$Name)

    $result = Get-InternalHelper -Input $Name
    return $result
}
```

## Code Reuse

Before writing new helper functions:

1. Check `Modules/Common/` for existing utilities
2. If the helper could benefit other modules, add it to `Common`
3. Extract repeated patterns into shared abstractions
