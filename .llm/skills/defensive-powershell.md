# Skill: Defensive PowerShell Coding

Use this skill when writing robust, production-ready PowerShell code that
handles edge cases, errors, and unexpected inputs gracefully.

## Core Principles

1. **Validate Early**: Use parameter validation attributes to catch bad input
   before execution
2. **Fail Fast**: Use guard clauses to exit early with clear error messages
3. **Be Explicit**: Use `-ErrorAction Stop` to convert non-terminating errors to
   terminating
4. **Catch Specific**: Handle specific exception types, not just generic
   exceptions
5. **Clean Up Always**: Use `finally` blocks for resource cleanup
6. **Handle Nulls**: Always check for null/empty before accessing properties or
   iterating
7. **Force Arrays**: Use `@()` when you need consistent array behavior

## Parameter Validation Attributes

Use validation attributes to reject bad input before your function body
executes:

```powershell
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]       # Rejects $null or empty string
    [string]$Name,

    [ValidateNotNull()]              # Rejects $null (allows empty)
    [object]$Config,

    [ValidateLength(1, 50)]          # String length constraints
    [string]$Description,

    [ValidateRange(1, 100)]          # Numeric range validation
    [int]$Percentage,

    [ValidateCount(1, 5)]            # Collection count limits
    [string[]]$Tags,

    [ValidateSet('Low', 'Medium', 'High')]  # Allowed values (enum-like)
    [string]$Priority = 'Medium',

    [ValidatePattern('^\d{3}-\d{4}$')]  # Regex pattern matching
    [string]$PhoneNumber,

    [ValidateScript({ Test-Path $_ })]  # Custom validation logic
    [string]$FilePath
)
```

### Prefer ValidateScript for Better Error Messages

`ValidatePattern` gives cryptic regex errors. Use `ValidateScript` for
user-friendly messages:

```powershell
# ❌ AVOID: Cryptic error message
[ValidatePattern('^\d{3}$')]
[string]$Code

# ✅ PREFER: Clear error message
[ValidateScript({
    if ($_ -match '^\d{3}$') { $true }
    else { throw "Code must be exactly 3 digits" }
})]
[string]$Code
```

### Common Validation Patterns

```powershell
# Path validation with detailed error
[ValidateScript({
    if (-not (Test-Path $_)) { throw "Path not found: $_" }
    if ((Get-Item $_).PSIsContainer) { throw "Expected file, got directory: $_" }
    $true
})]
[string]$FilePath

# Non-empty collection
[ValidateScript({
    if ($_.Count -eq 0) { throw "At least one item is required" }
    $true
})]
[string[]]$Items

# Alphanumeric with dashes only
[ValidateScript({
    if ($_ -notmatch '^[a-zA-Z0-9-]+$') {
        throw "Name must contain only letters, numbers, and dashes"
    }
    $true
})]
[string]$Name
```

## Guard Clauses and Early Returns

Fail fast with clear error messages at the start of functions:

```powershell
function Process-ConfigFile {
    [CmdletBinding()]
    param(
        [string]$FilePath,
        [hashtable]$Settings
    )

    # Guard clauses - validate preconditions immediately
    if (-not $FilePath) {
        throw [System.ArgumentNullException]::new('FilePath', 'File path is required')
    }

    if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new("File not found: $FilePath")
    }

    if (-not $Settings.ContainsKey('OutputPath')) {
        throw [System.ArgumentException]::new('Settings must contain OutputPath key')
    }

    # Main logic (only reached if all guards pass)
    $content = Get-Content -Path $FilePath -Raw
    # ...
}
```

## Error Handling Patterns

### Use -ErrorAction Stop for Trappable Errors

```powershell
try {
    # Use -ErrorAction Stop to make errors terminating
    Get-Content -Path $FilePath -ErrorAction Stop

    # Dependent operations stay in same try block
    Set-ItemProperty -Path $FilePath -Name IsReadOnly -Value $true -ErrorAction Stop
}
catch [System.IO.FileNotFoundException] {
    # Handle specific exception type
    Write-Error "File not found: $($_.Exception.Message)"
}
catch [System.IO.IOException] {
    # Handle broader IO exceptions
    Write-Error "IO error: $($_.Exception.Message)"
}
catch {
    # Catch-all for unexpected errors
    Write-Error "Unexpected error: $_"
}
finally {
    # Always runs - cleanup code
    if ($connection) { $connection.Close() }
}
```

### Copy Error Immediately

The `$_` variable can change. Copy it immediately:

```powershell
catch {
    $errorRecord = $_  # Copy immediately
    Write-Log "Error processing $item`: $($errorRecord.Exception.Message)"
    # Safe to use $errorRecord later in the catch block
}
```

### Wrap All Blocks in Try/Catch (Advanced Functions)

For consistent error handling across pipeline processing:

```powershell
function Process-Items {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)][object[]]$InputObject)

    begin {
        try {
            $processedCount = 0
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    process {
        try {
            foreach ($item in $InputObject) {
                # Process each item
                $processedCount++
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    end {
        try {
            Write-Verbose "Processed $processedCount items"
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
```

### User-Friendly Error Messages

Use `$PSCmdlet.ThrowTerminatingError()` for clean error display:

```powershell
$PSCmdlet.ThrowTerminatingError(
    [System.Management.Automation.ErrorRecord]::new(
        [System.IO.FileNotFoundException]::new("Could not find: $Path"),
        'ResourceNotFound',
        [System.Management.Automation.ErrorCategory]::ObjectNotFound,
        $Path
    )
)
```

## Handling Null and Empty Values

### Safe String Handling

```powershell
# Check for null, empty, or whitespace-only
if ([string]::IsNullOrWhiteSpace($value)) {
    Write-Warning "Value is empty or whitespace"
    return
}
```

### PowerShell 7+ Null Safety

```powershell
# Safe property access (null propagation)
$result = $object?.Property?.SubProperty

# Null coalescing
$value = $input ?? 'default'

# Null coalescing assignment
$config ??= @{}
```

### Pre-7.0 Null Handling

```powershell
# Safe property access
$value = if ($null -ne $object -and $null -ne $object.Property) {
    $object.Property.SubProperty
} else {
    $null
}

# Null coalescing
$value = if ($null -ne $input) { $input } else { 'default' }
```

### Force Array Results

PowerShell unwraps single-item arrays. Force array when needed:

```powershell
# ❌ RISKY: Single result becomes scalar
$results = Get-ChildItem -Filter "*.ps1"  # Might be 1 item (not array)

# ✅ SAFE: Always get array
$results = @(Get-ChildItem -Filter "*.ps1")

# Safe iteration with null check
foreach ($item in ($items ?? @())) {
    # Process item
}
```

## Safe Collection Access

### Hashtable Key Access

```powershell
# Check key existence before access
if ($config.ContainsKey('Setting')) {
    $value = $config['Setting']
}

# Validate required keys
$requiredKeys = @('Name', 'Path', 'Type')
$missingKeys = $requiredKeys | Where-Object { -not $config.ContainsKey($_) }
if ($missingKeys) {
    throw "Missing required configuration keys: $($missingKeys -join ', ')"
}

# Use TryGetValue for complex scenarios
$value = $null
if ($dict.TryGetValue('Key', [ref]$value)) {
    # Use $value
}
```

### Safe Collection Iteration

```powershell
# Check for empty or null collections
if (-not $items -or $items.Count -eq 0) {
    Write-Warning "No items to process"
    return
}

# Safe count check (handles $null)
if (($items | Measure-Object).Count -eq 0) {
    return
}
```

## ShouldProcess Support

For any function that modifies system state:

```powershell
function Remove-OldFiles {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$Force
    )

    $files = Get-ChildItem -Path $Path -File
    foreach ($file in $files) {
        if ($Force -or $PSCmdlet.ShouldProcess($file.FullName, 'Delete')) {
            Remove-Item -Path $file.FullName
        }
    }
}
```

## Idempotent Operations

Design functions that can be run multiple times safely:

```powershell
function Ensure-Directory {
    [CmdletBinding()]
    param([string]$Path)

    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }

    # Verify creation succeeded
    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw "Failed to create directory: $Path"
    }
}
```

## Anti-Patterns to Avoid

| Anti-Pattern                    | Why It's Bad                              | Better Approach                          |
| ------------------------------- | ----------------------------------------- | ---------------------------------------- |
| `$array += $item` in loops      | O(n²) memory, creates new array each time | Use `[List[T]]` and `.Add()`             |
| `if ($?) { ... }`               | Unreliable success detection              | Use `try/catch` with `-ErrorAction Stop` |
| `$result = Get-X; if ($result)` | Hides actual errors                       | Proper error handling                    |
| Empty catch blocks              | Silently hides errors                     | Log or rethrow                           |
| `catch { return $false }`       | Loses error context                       | Preserve error information               |
| Flag-based error tracking       | Complex and error-prone                   | Keep operations in try block             |

## Quick Reference: Defensive Checklist

- [ ] All parameters have appropriate validation attributes
- [ ] Guard clauses check preconditions at function start
- [ ] `-ErrorAction Stop` on cmdlets where errors should be caught
- [ ] Specific exception types caught before generic catch
- [ ] `finally` blocks clean up resources
- [ ] Null/empty checks before property access or iteration
- [ ] `@()` used when array behavior is required
- [ ] `ShouldProcess` supported for state-changing functions
- [ ] Operations are idempotent where possible
- [ ] Error messages are actionable and include context
