# Skill: Debug Module Issues

Use this skill when troubleshooting module loading problems, import errors, or
unexpected behavior.

## Common Module Issues

### Module Won't Import

```powershell
# Check for syntax errors
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    "Modules/YourModule/YourModule.psm1",
    [ref]$null,
    [ref]$errors
)
$errors | ForEach-Object { Write-Host $_.Message -ForegroundColor Red }

# Try importing with verbose output
Import-Module ./Modules/YourModule -Force -Verbose

# Check for missing dependencies
Get-Module -ListAvailable | Where-Object Name -like '*YourModule*'
```

### Functions Not Exported

```powershell
# List what's actually exported
Import-Module ./Modules/YourModule -Force
Get-Command -Module YourModule

# Check manifest exports match actual functions
$manifest = Import-PowerShellDataFile ./Modules/YourModule/YourModule.psd1
$manifest.FunctionsToExport

# Compare with defined functions
Get-Content ./Modules/YourModule/Public/*.ps1 |
    Select-String -Pattern '^function\s+(\w+-\w+)' |
    ForEach-Object { $_.Matches.Groups[1].Value }
```

### Dot-Sourcing Failures

Check that the `.psm1` correctly loads Private and Public scripts:

```powershell
# Verify file paths
Get-ChildItem -Path "./Modules/YourModule/Private/*.ps1"
Get-ChildItem -Path "./Modules/YourModule/Public/*.ps1"

# Check .psm1 has correct dot-source pattern
Get-Content ./Modules/YourModule/YourModule.psm1 |
    Select-String -Pattern '\. \$'
```

Expected pattern in `.psm1`:

```powershell
Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }

Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }
```

## Debugging Techniques

### Trace Function Execution

```powershell
# Enable verbose output
$VerbosePreference = 'Continue'
Your-Function -Verbose

# Enable debug output
$DebugPreference = 'Continue'
Your-Function -Debug
```

### Inspect Module State

```powershell
# Check loaded modules
Get-Module | Where-Object Name -like '*Magic*'

# Force reload after changes
Remove-Module YourModule -Force -ErrorAction SilentlyContinue
Import-Module ./Modules/YourModule -Force

# Check module path
(Get-Module YourModule).Path
```

### Test Individual Functions

```powershell
# Dot-source a single file for testing
. ./Modules/YourModule/Private/YourModule.Internal.ps1

# Test internal function directly
Internal-HelperFunction -Parameter "test"
```

## Cross-Platform Issues

### Path Separators

```powershell
# Wrong - Windows only
$path = "Modules\YourModule\file.ps1"

# Correct - Cross-platform
$path = Join-Path "Modules" "YourModule" "file.ps1"
$path = "Modules/YourModule/file.ps1"  # Forward slash works everywhere
```

### Home Directory

```powershell
# Wrong - Windows only
$configPath = "$env:USERPROFILE\.config"

# Correct - Cross-platform
$configPath = Join-Path $HOME ".config"
# Or use: [Environment]::GetFolderPath('UserProfile')
```

### Line Endings

If scripts fail on Linux/macOS with cryptic errors, check line endings:

```bash
# Check for Windows line endings
file Modules/YourModule/YourModule.psm1

# Convert to Unix line endings
sed -i 's/\r$//' Modules/YourModule/YourModule.psm1
```

## AST Validation

Run syntax validation without executing:

```powershell
# Validate all module scripts
Get-ChildItem -Path "./Modules" -Recurse -Filter "*.ps1" | ForEach-Object {
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $_.FullName, [ref]$null, [ref]$errors
    )
    if ($errors) {
        Write-Host "Errors in $($_.Name):" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "  $_" }
    }
}
```

## Test Isolation

```powershell
# Run tests in clean session
pwsh -NoProfile -Command {
    Import-Module ./Modules/YourModule -Force
    # Your test commands
}
```

## Checklist for Module Issues

- [ ] Syntax validates with AST parser
- [ ] `.psm1` dot-sources Private/ and Public/ folders
- [ ] `FunctionsToExport` matches actual public functions
- [ ] Module imports without errors
- [ ] Commands appear in `Get-Command -Module <Name>`
- [ ] Help is available for public functions
- [ ] Works on Windows, macOS, and Linux
