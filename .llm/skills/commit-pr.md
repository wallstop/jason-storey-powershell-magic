# Skill: Commits and Pull Requests

Use this skill when preparing commits or submitting pull requests.

> **Prerequisite:** Before using this skill, you MUST have completed all
> verification steps. See [verify-changes.md](verify-changes.md). All tests,
> formatters, and linters must pass before committing.

## Pre-Commit Checklist

Before committing, ensure:

```powershell
# 1. Run full test suite (ALL tests must pass)
.\Run-Tests.ps1

# 2. Check formatting
.\Format-PowerShell.ps1 -Check

# 3. Fix any formatting issues
.\Format-PowerShell.ps1 -Fix

# 4. Run in CI mode (strict)
.\Run-Tests.ps1 -CI
```

> **Zero-Flaky Test Policy:** If any tests fail, you must investigate and fix
> the root cause before committing. See [test-failures.md](test-failures.md).

## Commit Message Format

Use short, imperative subjects:

```text
Fix security scan for download validation
Add QuickJump category filtering
Update dependencies to latest versions
```

### Conventional Commits (Acceptable)

Conventional-style prefixes are acceptable when scoped clearly:

```text
feat: add fuzzy search to QuickJump
fix: resolve path normalization on Linux
docs: update installation instructions
chore: update PSScriptAnalyzer settings
test: add Templater token substitution tests
refactor: extract common config helpers
```

### Commit Subject Rules

- Start with capital letter (or lowercase after prefix)
- No period at the end
- 50 characters or less
- Imperative mood ("Add feature" not "Added feature")

### Commit Body (Optional)

For complex changes, add a body:

```text
feat: add category support to QuickJump

Categories allow organizing saved paths into groups like "projects",
"work", and "personal". The -Category parameter is available on
Add-QuickJumpPath and filters are available on Get-QuickJumpPath.

Closes #42
```

## Pull Request Guidelines

### PR Title

Follow the same format as commit messages:

```text
Add template variable validation to Templater
```

### PR Description Template

````markdown
## Summary

Brief description of what this PR does.

## Changes

- Added X to handle Y
- Modified Z for better performance
- Fixed bug where A caused B

## Affected Modules

- [ ] QuickJump
- [ ] Templater
- [ ] Unitea
- [ ] Common
- [ ] Setup scripts

## Testing

- [ ] `.\Run-Tests.ps1` passes
- [ ] `.\Run-Tests.ps1 -CI` passes
- [ ] Tested on Windows/macOS/Linux (as applicable)

## Documentation (Required)

**Documentation is mandatory for every user-facing change.** See
[documentation.md](documentation.md) for complete guidance.

### Documentation Checklist

- [ ] **CHANGELOG.md** updated with correct format
- [ ] **User docs** updated (guides in `docs/`)
- [ ] **Command help** updated (comment-based help in cmdlets)
- [ ] **Code samples** tested and working
- [ ] **README.md** updated (if needed)

### CHANGELOG Entry Format

```markdown
### Added

- New `qjsearch` command for fuzzy searching across all saved paths

### Fixed

- QuickJump no longer fails when alias contains special characters (#42)
```

Entries must be specific, action-oriented, and reference issue numbers.

### Related Issues

Closes #XX

### PR Best Practices

1. **Keep PRs focused** - One feature or fix per PR
2. **Include test coverage** - Add tests for new functionality
3. **Update documentation** - Reference new scripts in README/DEVELOPMENT.md
4. **Screenshots for UI changes** - Include terminal output examples
5. **Link related issues** - Use "Closes #XX" or "Fixes #XX"

## Hooks Setup

Install pre-commit hooks to catch issues early:

```powershell
# Auto-detect best method
.\Setup-Hooks.ps1

# Force specific method
.\Setup-Hooks.ps1 -Method precommit  # Python pre-commit framework
.\Setup-Hooks.ps1 -Method git        # Native Git hooks
```
````

## Common Issues

### Commit Blocked by Hooks

```powershell
# Check what's failing
.\Run-Tests.ps1 -Format

# Auto-fix formatting
.\Format-PowerShell.ps1 -Fix

# Re-stage fixed files
git add -u
git commit
```

### Tests Failing in CI

> **Important:** Never re-run CI hoping tests will pass, or skip/ignore failing
> tests. Every failure must be investigated. See
> [test-failures.md](test-failures.md) for the full investigation process.

```powershell
# Run in CI mode locally to reproduce
.\Run-Tests.ps1 -CI

# Check specific module
.\Tests\Test-PowerShellMagic.ps1 -TestName QuickJump -Verbose
```
