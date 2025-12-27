# Skill: Verify Changes Before Completion

**This is a mandatory final step for ALL work.** After making any code changes,
documentation updates, or configuration modifications, you MUST run all
verification checks and ensure everything passes. Work is NOT complete until the
code is ready to commit without errors.

## Critical Requirement

**Every change session must end with clean verification.** This means:

- All tests pass
- All formatting checks pass
- All linters pass
- No pre-commit hook failures
- The diff is ready to be committed without any errors

**Never consider work "done" if verification fails.** Fix all issues before
finishing.

## Mandatory Verification Workflow

After making ANY changes, run these commands in order:

```powershell
# Step 1: Auto-fix formatting issues first
.\Format-PowerShell.ps1 -Fix

# Step 2: Check for any remaining formatting issues
.\Format-PowerShell.ps1 -Check

# Step 3: Run the full test suite
.\Run-Tests.ps1

# Step 4: Run in CI mode (stricter checks)
.\Run-Tests.ps1 -CI

# Step 5: Check markdown links (if docs were modified)
.\Scripts\Test-MarkdownLinks.ps1
```

### Quick Single Command (Most Common)

For a comprehensive check after changes:

```powershell
# Fix formatting, then run all tests in CI mode
.\Format-PowerShell.ps1 -Fix; .\Run-Tests.ps1 -CI
```

## What Each Check Does

| Command                            | Purpose                                  |
| ---------------------------------- | ---------------------------------------- |
| `.\Format-PowerShell.ps1 -Fix`     | Auto-fixes PSScriptAnalyzer formatting   |
| `.\Format-PowerShell.ps1 -Check`   | Reports formatting issues without fixing |
| `.\Run-Tests.ps1`                  | Runs Pester tests and basic validation   |
| `.\Run-Tests.ps1 -CI`              | Strict CI mode—what GitHub Actions runs  |
| `.\Scripts\Test-MarkdownLinks.ps1` | Validates all markdown links work        |

## When Verification Fails

### Formatting Failures

```powershell
# Auto-fix should resolve most issues
.\Format-PowerShell.ps1 -Fix

# If issues persist, check specific file
.\Format-PowerShell.ps1 -Path "path/to/file.ps1" -Fix -Verbose
```

### Test Failures

**Never ignore test failures.** See [test-failures.md](test-failures.md) for the
full investigation process.

```powershell
# Run verbose to see details
.\Run-Tests.ps1 -Verbose

# Run specific test file
Invoke-Pester -Path "Tests/Pester/PowerShellMagic.Tests.ps1" -Output Detailed
```

### Markdown Link Failures

```powershell
# Check which links are broken
.\Scripts\Test-MarkdownLinks.ps1 -Verbose

# Fix broken links in documentation, then re-run
```

## Pre-Commit Hooks

If pre-commit hooks are installed, they will automatically run verification on
commit. However, **don't rely solely on hooks**—run verification proactively to
catch issues early.

```powershell
# Install hooks if not already set up
.\Setup-Hooks.ps1

# Manually run what hooks would check
.\Format-PowerShell.ps1 -Check
.\Run-Tests.ps1 -CI
```

## Checklist Before Declaring Work Complete

- [ ] `.\Format-PowerShell.ps1 -Fix` ran successfully
- [ ] `.\Format-PowerShell.ps1 -Check` reports no issues
- [ ] `.\Run-Tests.ps1` passes all tests
- [ ] `.\Run-Tests.ps1 -CI` passes (stricter mode)
- [ ] `.\Scripts\Test-MarkdownLinks.ps1` passes (if docs changed)
- [ ] All modified files are ready to stage and commit
- [ ] No errors, warnings, or failures in any output

## Common Pitfalls

### ❌ "I'll fix formatting later"

Never. Always fix formatting immediately with `.\Format-PowerShell.ps1 -Fix`.

### ❌ "Tests passed locally, CI will be fine"

Always run `.\Run-Tests.ps1 -CI` locally. CI mode has stricter checks.

### ❌ "It's just a documentation change"

Documentation changes can still break markdown links or formatting. Always
verify.

### ❌ "The test failure is unrelated to my change"

Investigate anyway. Your change may have exposed an existing issue, or there may
be an unexpected interaction. See [test-failures.md](test-failures.md).

## Integration with Other Skills

This skill is the **final step** that follows all other skills:

1. Make changes (using relevant skill: add-cmdlet, add-tests, etc.)
2. Update documentation (using [documentation.md](documentation.md))
3. **Verify changes (this skill)**
4. Commit (using [commit-pr.md](commit-pr.md))

The verification step is non-negotiable and cannot be skipped.
