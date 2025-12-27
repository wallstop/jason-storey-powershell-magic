# Skill: Add or Modify Tests

Use this skill when writing new tests or updating existing test coverage.

> **Important:** This repository has a zero-flaky test policy. If tests fail,
> see [test-failures.md](test-failures.md) for investigation procedures. Never
> skip, ignore, or superficially fix failing tests.

## Core Testing Philosophy

**Every feature and bug fix requires extensive, exhaustive tests.** Tests are
not an afterthought—they are a core deliverable of every change. Incomplete test
coverage means incomplete work.

### What "Exhaustive" Means

Tests must cover ALL of the following:

| Scenario Type             | Description                    | Examples                                     |
| ------------------------- | ------------------------------ | -------------------------------------------- |
| **Happy path**            | Normal expected usage          | Valid inputs, typical workflows              |
| **Edge cases**            | Boundary conditions            | Empty strings, single items, maximum lengths |
| **Error cases**           | Invalid inputs                 | Wrong types, missing required params         |
| **Negative scenarios**    | What should NOT work           | Unauthorized access, invalid formats         |
| **Unexpected situations** | Defensive programming          | Null values, concurrent modifications        |
| **"The impossible"**      | States that "shouldn't happen" | Corrupted config, race conditions            |

### Test Coverage Checklist

Before considering a feature complete, verify tests exist for:

- [ ] Every public function/cmdlet
- [ ] Every parameter (valid values, invalid values, edge values)
- [ ] Every code path (if/else branches, switch cases)
- [ ] Every error condition (exceptions, validation failures)
- [ ] Pipeline input (if supported)
- [ ] Cross-platform behavior (path separators, line endings)

## Test Architecture Principles

- **No External Dependencies**: Tests run without fzf, 7-Zip, eza, or Unity Hub
- **Mocked Dependencies**: External tools are mocked for isolated testing
- **Syntax Validation**: PowerShell AST parsing validates all scripts
- **Offline Execution**: Mock network/filesystem effects
- **DRY Tests**: Extract repeated setup/teardown into shared helpers
- **Minimal Comments**: Test names should describe intent; avoid inline comments

## Test File Locations

| Test Type      | Location                           | Naming Pattern             |
| -------------- | ---------------------------------- | -------------------------- |
| Module tests   | `Tests/Test-PowerShellMagic.ps1`   | Functions inside main file |
| Download tests | `Tests/Test-PortableDownloads.ps1` | Separate focused file      |
| Hash tests     | `Tests/Test-Hash.ps1`              | Separate focused file      |
| Pester tests   | `Tests/Pester/*.Tests.ps1`         | Standard Pester naming     |

## Running Tests

```powershell
# Run all tests
.\Run-Tests.ps1

# Run specific module tests
.\Tests\Test-PowerShellMagic.ps1 -TestName QuickJump
.\Tests\Test-PowerShellMagic.ps1 -TestName Templater
.\Tests\Test-PowerShellMagic.ps1 -TestName Unitea

# Run with verbose output
.\Tests\Test-PowerShellMagic.ps1 -Verbose

# CI mode (strict, fails on any issue)
.\Run-Tests.ps1 -CI
```

## Writing New Tests

### Test Function Structure

```powershell
function Test-YourFeature {
    Write-TestInfo "Testing YourFeature..."

    $testData = "expected value"

    $result = Your-Function -Parameter $testData

    Assert-Equal -Expected "expected" -Actual $result -Message "Should return expected"
    Assert-True -Condition ($result -ne $null) -Message "Result should not be null"
    Assert-NotNull -Value $result -Message "Result exists"
}
```

**Note:** Avoid `# Arrange`, `# Act`, `# Assert` comments—structure should be
obvious from code flow.

### Available Assert Functions

```powershell
Assert-Equal -Expected $x -Actual $y -Message "Description"
Assert-True -Condition $bool -Message "Description"
Assert-False -Condition $bool -Message "Description"
Assert-NotNull -Value $obj -Message "Description"
Assert-FileExists -Path $path -Message "Description"
Assert-DirectoryExists -Path $path -Message "Description"
Assert-Contains -Collection $arr -Item $item -Message "Description"
Assert-Match -Pattern "regex" -Actual $string -Message "Description"
```

### Mocking External Dependencies

```powershell
# Mock fzf for interactive selection
function fzf { param($input) return $input | Select-Object -First 1 }

# Mock file system operations
$testDir = Join-Path $env:TEMP "TestDir_$(Get-Random)"
New-Item -ItemType Directory -Path $testDir -Force | Out-Null
try {
    # Your test code here
} finally {
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
}
```

### Testing Module Exports

```powershell
function Test-ModuleExports {
    Write-TestInfo "Testing module exports..."

    Import-Module "$PSScriptRoot/../Modules/YourModule" -Force

    $commands = Get-Command -Module YourModule
    Assert-True -Condition ($commands.Count -gt 0) -Message "Module exports commands"

    # Verify specific command exists
    $cmd = Get-Command -Name "Get-YourThing" -ErrorAction SilentlyContinue
    Assert-NotNull -Value $cmd -Message "Get-YourThing is exported"
}
```

## Adding Tests for a New Module

1. Add test function in `Tests/Test-PowerShellMagic.ps1`:

```powershell
function Test-YourModule {
    Write-Host "`n=== YourModule Tests ===" -ForegroundColor Cyan

    Test-YourModuleLoads
    Test-YourModuleCommands
    Test-YourModuleFeature
}
```

1. Register in the test dispatcher (near end of file):

   ```powershell
   switch ($TestName) {
       'YourModule' { Test-YourModule }
       'All' {
           # ... existing tests ...
           Test-YourModule
       }
   }
   ```

1. Update the `ValidateSet` in the param block:

```powershell
[ValidateSet('Setup', 'Common', 'QuickJump', 'Templater', 'Unitea', 'YourModule', 'All')]
```

## Test Validation Checklist

- [ ] Tests run without external dependencies
- [ ] Temporary files/directories are cleaned up
- [ ] No hardcoded paths (use `$PSScriptRoot`, `$env:TEMP`)
- [ ] Tests work on Windows, macOS, and Linux
- [ ] Repeated patterns extracted to shared helpers
- [ ] `.\Run-Tests.ps1 -CI` passes
- [ ] **All tests pass consistently** (run multiple times to verify)
- [ ] **Happy path covered**
- [ ] **Edge cases covered** (empty, null, whitespace, boundaries)
- [ ] **Error cases covered** (invalid inputs, missing params)
- [ ] **Negative scenarios covered** (what shouldn't work)
- [ ] **Data-driven tests used** where appropriate

## Handling Test Failures

If tests fail during development:

1. **Do not skip or ignore the failure**
2. **Investigate whether it's a production bug or test bug**
3. **Fix the root cause, not just the symptom**
4. See [test-failures.md](test-failures.md) for detailed investigation
   procedures

## DRY Test Patterns

### Shared Test Helpers

Extract common setup/teardown patterns:

```powershell
function New-TestDirectory {
    $testDir = Join-Path $env:TEMP "Test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null
    return $testDir
}

function Remove-TestDirectory {
    param([string]$Path)
    Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
}
```

### Reusable Mock Functions

Place frequently-used mocks in a shared location rather than duplicating:

```powershell
function New-MockFzf {
    return { param($input) $input | Select-Object -First 1 }
}
```

## Data-Driven Testing

Use data-driven tests to consolidate test code and cover many scenarios
efficiently. This is the preferred approach for testing multiple inputs.

### Basic Data-Driven Pattern

```powershell
function Test-InputValidation {
    Write-TestInfo "Testing input validation with multiple cases..."

    $testCases = @(
        @{ Input = 'valid-name'; Valid = $true; Reason = 'accepts alphanumeric with dash' }
        @{ Input = 'ValidName'; Valid = $true; Reason = 'accepts mixed case' }
        @{ Input = ''; Valid = $false; Reason = 'rejects empty string' }
        @{ Input = $null; Valid = $false; Reason = 'rejects null' }
        @{ Input = '   '; Valid = $false; Reason = 'rejects whitespace only' }
        @{ Input = 'name with spaces'; Valid = $false; Reason = 'rejects spaces' }
        @{ Input = 'a' * 256; Valid = $false; Reason = 'rejects exceeding max length' }
        @{ Input = '../path'; Valid = $false; Reason = 'rejects path traversal' }
        @{ Input = 'name<>|'; Valid = $false; Reason = 'rejects invalid characters' }
    )

    foreach ($case in $testCases) {
        $result = Test-ValidName -Name $case.Input
        Assert-Equal -Expected $case.Valid -Actual $result -Message $case.Reason
    }
}
```

### Comprehensive Edge Case Coverage

```powershell
function Test-PathHandling {
    Write-TestInfo "Testing path handling edge cases..."

    $testCases = @(
        # Normal cases
        @{ Path = 'C:\Users\Name'; Expected = $true; Desc = 'Windows absolute path' }
        @{ Path = '/home/user'; Expected = $true; Desc = 'Unix absolute path' }
        @{ Path = './relative'; Expected = $true; Desc = 'Relative path' }

        # Edge cases
        @{ Path = ''; Expected = $false; Desc = 'Empty path' }
        @{ Path = $null; Expected = $false; Desc = 'Null path' }
        @{ Path = ' '; Expected = $false; Desc = 'Whitespace path' }
        @{ Path = 'C:\'; Expected = $true; Desc = 'Root drive' }
        @{ Path = '/'; Expected = $true; Desc = 'Unix root' }

        # Extreme cases
        @{ Path = 'a' * 260; Expected = $false; Desc = 'Exceeds MAX_PATH' }
        @{ Path = "path`0with`0nulls"; Expected = $false; Desc = 'Embedded null chars' }

        # "Impossible" cases that code should still handle
        @{ Path = [char]0x0000; Expected = $false; Desc = 'Single null character' }
    )

    foreach ($case in $testCases) {
        $result = Test-PathValid -Path $case.Path
        Assert-Equal -Expected $case.Expected -Actual $result -Message $case.Desc
    }
}
```

### Testing Error Conditions

```powershell
function Test-ErrorHandling {
    Write-TestInfo "Testing error handling..."

    $errorCases = @(
        @{
            Action = { Get-Item -Path '/nonexistent/path' -ErrorAction Stop }
            ExpectedError = 'ItemNotFound'
            Desc = 'Non-existent path throws'
        }
        @{
            Action = { New-Item -Path 'invalid:<>path' -ErrorAction Stop }
            ExpectedError = 'InvalidArgument'
            Desc = 'Invalid characters throw'
        }
    )

    foreach ($case in $errorCases) {
        $threw = $false
        $errorCategory = $null
        try {
            & $case.Action
        } catch {
            $threw = $true
            $errorCategory = $_.CategoryInfo.Category
        }
        Assert-True -Condition $threw -Message "$($case.Desc) - should throw"
    }
}
```

## Test Categories to Always Include

### 1. Happy Path Tests

Test the normal, expected usage:

```powershell
function Test-NormalUsage {
    $result = Add-QuickJumpPath -Path '/valid/path' -Alias 'myalias'
    Assert-True -Condition $result.Success -Message "Normal add succeeds"
}
```

### 2. Boundary Value Tests

Test at the edges of valid input ranges:

```powershell
$boundaryTests = @(
    @{ Value = 0; Desc = 'Minimum value' }
    @{ Value = 1; Desc = 'Just above minimum' }
    @{ Value = 99; Desc = 'Just below maximum' }
    @{ Value = 100; Desc = 'Maximum value' }
)
```

### 3. Invalid Input Tests

Test that invalid inputs are properly rejected:

```powershell
function Test-RejectsInvalidInput {
    $invalidInputs = @($null, '', ' ', "`t", "`n", [char]0)

    foreach ($input in $invalidInputs) {
        $threw = $false
        try { Your-Function -Input $input } catch { $threw = $true }
        Assert-True -Condition $threw -Message "Rejects: '$input'"
    }
}
```

### 4. State Transition Tests

Test behavior when state changes:

```powershell
function Test-StateTransitions {
    # Initial state
    $initial = Get-State
    Assert-Equal -Expected 'Empty' -Actual $initial

    # After action
    Invoke-Action
    $after = Get-State
    Assert-Equal -Expected 'Modified' -Actual $after

    # After undo
    Undo-Action
    $final = Get-State
    Assert-Equal -Expected 'Empty' -Actual $final
}
```

### 5. Concurrency/Race Condition Tests

Test behavior under concurrent access (where applicable):

```powershell
function Test-ConcurrentAccess {
    $jobs = 1..10 | ForEach-Object {
        Start-Job -ScriptBlock {
            Add-QuickJumpPath -Path "/path/$_" -Alias "alias$_"
        }
    }
    $results = $jobs | Wait-Job | Receive-Job
    Assert-True -Condition ($results.Count -eq 10) -Message "All concurrent adds succeed"
}
```
