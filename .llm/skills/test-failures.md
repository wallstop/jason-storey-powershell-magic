# Skill: Investigating Test Failures

Use this skill when tests fail. **Every test failure requires comprehensive
investigation and resolution.**

## Zero-Flaky Test Policy

This repository maintains a **strict zero-flaky test policy**:

- **Every test failure indicates a real bug**—either in production code or in
  the test itself
- **Flaky tests do not exist**—if a test sometimes passes and sometimes fails,
  that inconsistency is itself a bug requiring investigation
- **Never "make tests pass" superficially**—understand the root cause before
  making any changes
- **Never ignore or skip failing tests**—disabled tests hide real problems

## Investigation Process

When a test fails, follow this systematic approach:

### 1. Reproduce Consistently

```powershell
# Run the specific failing test multiple times
.\Tests\Test-PowerShellMagic.ps1 -TestName ModuleName -Verbose

# Run in CI mode to match pipeline behavior
.\Run-Tests.ps1 -CI

# Run with maximum verbosity
$VerbosePreference = 'Continue'
$DebugPreference = 'Continue'
.\Run-Tests.ps1
```

### 2. Categorize the Failure

Determine whether this is a **production bug** or a **test bug**:

| Symptom                                                                  | Likely Cause                                    |
| ------------------------------------------------------------------------ | ----------------------------------------------- |
| Test logic matches requirements, but production code behaves differently | **Production bug**                              |
| Test makes incorrect assumptions about expected behavior                 | **Test bug**                                    |
| Test depends on execution order or external state                        | **Test bug** (isolation issue)                  |
| Test passes locally but fails in CI                                      | **Environment bug** (investigate both)          |
| Test fails intermittently                                                | **Race condition or state leak** (critical bug) |

### 3. Investigate Root Cause

#### For Suspected Production Bugs

1. Read the test to understand the expected behavior
2. Read the production code being tested
3. Trace execution with debug output:

   ```powershell
   # Add temporary debug statements
   Write-Debug "Variable state: $($variable | ConvertTo-Json -Depth 3)"

   # Use breakpoints in VS Code
   Set-PSBreakpoint -Script ./Modules/Module/Public/Function.ps1 -Line 42
   ```

4. Verify the test's expectations match documented requirements
5. Fix the production code to match expected behavior

#### For Suspected Test Bugs

1. Verify the test accurately represents requirements
2. Check for test isolation issues:
   - Shared state between tests
   - Missing cleanup in `finally` blocks
   - Dependency on test execution order
3. Check for environmental assumptions:
   - Hardcoded paths
   - Platform-specific behavior
   - Missing mocks for external dependencies
4. Fix the test to correctly verify behavior

### 4. Verify the Fix

After making changes:

```powershell
# Run the specific test
.\Tests\Test-PowerShellMagic.ps1 -TestName ModuleName

# Run full suite to check for regressions
.\Run-Tests.ps1

# Run in CI mode
.\Run-Tests.ps1 -CI

# Run multiple times to catch intermittent issues
1..5 | ForEach-Object { .\Run-Tests.ps1 -CI }
```

## Common Root Causes

### State Leakage Between Tests

**Symptom**: Test passes in isolation but fails when run with other tests.

**Investigation**:

```powershell
# Run just the failing test
.\Tests\Test-PowerShellMagic.ps1 -TestName SpecificTest

# Run with a different test before it
# If results differ, there's state leakage
```

**Resolution**: Ensure proper cleanup in tests and avoid global state.

### Missing Mocks

**Symptom**: Test fails when external tool (fzf, 7-Zip, etc.) is unavailable.

**Investigation**: Check if test properly mocks external dependencies.

**Resolution**: Add appropriate mocks (see [add-tests.md](add-tests.md) for
patterns).

### Platform-Specific Behavior

**Symptom**: Test passes on Windows but fails on Linux/macOS (or vice versa).

**Investigation**:

```powershell
# Check for path separator issues
# Check for case sensitivity issues (Linux filesystems)
# Check for line ending issues
```

**Resolution**: Use cross-platform patterns:

```powershell
# Paths
$path = Join-Path "Modules" "Name" "file.ps1"

# Home directory
$home = [Environment]::GetFolderPath('UserProfile')

# Temp directory
$temp = [System.IO.Path]::GetTempPath()
```

### Timing/Race Conditions

**Symptom**: Test fails intermittently, especially under load.

**Investigation**: Look for:

- Async operations without proper awaiting
- File operations that assume immediate availability
- Tests that depend on execution speed

**Resolution**: Add proper synchronization or increase timeouts with clear
comments explaining why.

### Incorrect Test Expectations

**Symptom**: Test fails but production code behavior seems correct.

**Investigation**:

1. Review requirements/documentation
2. Check if test was written against outdated behavior
3. Verify with module maintainers if behavior is intentional

**Resolution**: Update test to match correct expected behavior (with
documentation reference).

## Forbidden Practices

**Never do these things:**

| ❌ Forbidden                                         | ✅ Do Instead                          |
| ---------------------------------------------------- | -------------------------------------- |
| Skip or disable the failing test                     | Investigate and fix the root cause     |
| Add `try/catch` to swallow errors                    | Let errors surface and fix them        |
| Add `-ErrorAction SilentlyContinue` to hide failures | Handle errors explicitly               |
| Change assertions to match wrong behavior            | Fix the code to match correct behavior |
| Mark test as "known flaky"                           | Fix the flakiness                      |
| Re-run CI until it passes                            | Fix the intermittent failure           |

## Documentation Requirements

When fixing a test failure, your commit should:

1. **Explain the root cause** in the commit message
2. **Categorize as production bug or test bug**
3. **Describe how the fix addresses the root cause**

Example commit message:

```text
fix: resolve QuickJump path caching race condition

Root cause: The path cache was being read before async write completed,
causing intermittent test failures when multiple tests ran in parallel.

This was a production bug—the same race condition could occur in real
usage when rapidly adding and querying paths.

Fix: Added proper synchronization using a mutex around cache operations.
```

## Escalation

If after thorough investigation you cannot determine the root cause:

1. Document everything you've tried
2. Include reproduction steps
3. Include environment details (OS, PowerShell version, etc.)
4. Request review from maintainers with full context

**Never close or ignore an unresolved test failure.**
