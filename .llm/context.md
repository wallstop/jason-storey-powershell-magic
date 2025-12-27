# AI Agent Guidelines

This document provides high-level context for AI assistants working with the
**PowerShell Magic** repository. For task-specific guidance, see the skill files
in `.llm/skills/`.

## Repository Essentials

PowerShell Magic provides three independent modules that work on Windows, macOS,
and Linux:

- **QuickJump** - Fast directory navigation with aliases and fuzzy finding
- **Templater** - Project template management with token substitution
- **Unitea** - Unity project management with version tracking

## Project Structure

```text
Modules/           # PowerShell modules (QuickJump, Templater, Unitea, Common)
  <Module>/
    <Module>.psd1  # Module manifest
    <Module>.psm1  # Root module
    Private/       # Internal helpers (not exported)
    Public/        # Exported cmdlets
Scripts/           # Maintenance utilities
Tests/             # Test suites
hooks/             # Git hook scripts
docs/              # User documentation
```

### Key Entry Points

| Script                      | Purpose                              |
| --------------------------- | ------------------------------------ |
| `Setup-PowerShellMagic.ps1` | Bootstrap installation               |
| `Run-Tests.ps1`             | Orchestrate all tests and formatting |
| `Format-PowerShell.ps1`     | PSScriptAnalyzer formatting          |
| `Setup-Hooks.ps1`           | Configure pre-commit hooks           |

## Code Quality Principles

These principles apply to **all code**: production, tests, CI/CD, and
documentation examples.

### Comments

- **Minimal comments**: rely on descriptive names and obvious call patterns
- **Explain why, not what**: only comment when the reasoning isn't self-evident
- Code should be self-documenting through clear naming and structure

### Architecture & Design

- **SOLID principles**: Single responsibility, Open/closed, Liskov substitution,
  Interface segregation, Dependency inversion
- **DRY (Don't Repeat Yourself)**: consolidate duplicate logic into shared
  abstractions
- **Clean Architecture**: separate concerns, maintain clear boundaries between
  layers
- **Design Patterns**: apply appropriate patterns (Factory, Strategy, Observer,
  etc.) where they add clarity

### Code Reuse

- **Build common abstractions**: when repetitive patterns emerge, extract
  lightweight shared utilities
- **Prefer function-based or value-typed abstractions**: minimize allocations
  and side effects
- **Consolidate to `Common` module**: shared helpers belong in `Modules/Common/`
- **Never duplicate code** unless absolutely necessary for isolation or
  performance

### Preprocessor Directives

- When `#Requires` or conditional compilation is needed, keep directives
  **within the appropriate scope**
- Maintain consistent placement across the codebase

### Consistency

- Follow existing patterns in the codebase before introducing new approaches
- Leverage existing tooling, utilities, and established conventions

## Mandatory Verification After All Changes

**CRITICAL:** After making ANY changes (code, tests, documentation, or
configuration), you MUST run all verification checks before considering the work
complete. Work is NOT finished until the diff is ready to commit without errors.

### Required Verification Steps

```powershell
# 1. Auto-fix formatting
.\Format-PowerShell.ps1 -Fix

# 2. Run full test suite in CI mode
.\Run-Tests.ps1 -CI

# 3. Check markdown links (if docs changed)
.\Scripts\Test-MarkdownLinks.ps1
```

### Verification Requirements

- **All tests must pass**—no exceptions, no "I'll fix it later"
- **All formatting must be clean**—run `-Fix` then verify with `-Check`
- **CI mode must pass**—it has stricter checks than local mode
- **No flaky behavior**—if a test fails intermittently, investigate and fix

**Never skip verification.** See [verify-changes.md](skills/verify-changes.md)
for detailed guidance.

## PowerShell-Specific Standards

These standards apply specifically to PowerShell code in this repository. See
[formatting.md](skills/formatting.md) for style rules and
[defensive-powershell.md](skills/defensive-powershell.md) for error handling.

### Naming Conventions

| Element           | Convention           | Example                      |
| ----------------- | -------------------- | ---------------------------- |
| Functions/Cmdlets | PascalCase Verb-Noun | `Get-QuickJumpPath`          |
| Parameters        | PascalCase           | `$FilePath`, `$ComputerName` |
| Local variables   | camelCase            | `$configPath`, `$itemCount`  |
| Script-scope      | `$Script:` prefix    | `$Script:CachedData`         |
| Module-scope      | `$Script:` in .psm1  | `$Script:ModuleConfig`       |

**Use approved verbs only**: Run `Get-Verb` for the full list. Common verbs:
`Get`, `Set`, `New`, `Remove`, `Add`, `Clear`, `Export`, `Import`, `Invoke`,
`Test`

### Function Structure

All exported functions must include:

1. **Comment-based help**: `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`
2. **`[CmdletBinding()]`**: Enables common parameters (`-Verbose`, `-Debug`,
   etc.)
3. **`[OutputType()]`**: Documents return type
4. **Parameter validation**: `[ValidateNotNullOrEmpty()]`, `[ValidateSet()]`,
   etc.
5. **Pipeline support**: Where appropriate, `ValueFromPipeline` or
   `ValueFromPipelineByPropertyName`

### Output Streams

Use the correct output stream for each purpose:

| Stream          | Command             | Use Case                           |
| --------------- | ------------------- | ---------------------------------- |
| Success (1)     | Return objects      | Function results (the actual data) |
| Error (2)       | `Write-Error`       | Recoverable errors                 |
| Warning (3)     | `Write-Warning`     | Potential issues user should know  |
| Verbose (4)     | `Write-Verbose`     | Detailed status messages           |
| Debug (5)       | `Write-Debug`       | Developer diagnostics              |
| Information (6) | `Write-Information` | Informational messages             |

**Never use `Write-Host`** in reusable functions—it cannot be captured or
redirected.

### Pipeline Design

- **Return objects, not formatted text**: Let the user decide formatting
- **Write objects immediately**: Don't buffer results; write as they're
  generated
- **Use process block**: For `ValueFromPipeline` parameters, process items in
  `process {}`
- **Single output type**: Don't mix strings and objects in output

### Avoid These Anti-Patterns

| Anti-Pattern                    | Better Approach                       |
| ------------------------------- | ------------------------------------- |
| `$array += $item`               | Use `[List[T]]` and `.Add()`          |
| Backticks for line continuation | Use splatting                         |
| `Write-Host` in functions       | Use `Write-Verbose` or `Write-Output` |
| Hardcoded paths with `\`        | Use `Join-Path`                       |
| Aliases in scripts              | Use full cmdlet names                 |
| `return $result`                | Just `$result` (implicit output)      |
| Positional parameters           | Use named parameters                  |

### Cross-Platform Considerations

This repository targets Windows, macOS, and Linux:

- **Use `Join-Path`**: Never hardcode path separators
- **Check `$IsWindows`, `$IsLinux`, `$IsMacOS`**: For platform-specific code
- **Use `$HOME`**: Instead of Windows-specific environment variables
- **Avoid Windows-only features**: WMI, Registry, COM objects
- **Test line endings**: Use `-Raw` for consistent file reading

## Mandatory Documentation

**Documentation is not optional.** Every feature addition, bug fix, or behavior
change requires documentation updates before the work is considered complete.
Incomplete documentation means incomplete work.

### What Must Be Updated

| Change Type       | Required Updates                                                                      |
| ----------------- | ------------------------------------------------------------------------------------- |
| New feature       | CHANGELOG, user guide, command help, code samples, inline comments (if complex logic) |
| Bug fix           | CHANGELOG, troubleshooting (if relevant), code samples showing correct behavior       |
| Changed behavior  | CHANGELOG, all affected docs, migration notes, version annotations                    |
| New config option | CHANGELOG, configuration.md, command help, examples                                   |
| Internal refactor | Update any affected code comments explaining "why"                                    |

### Documentation Artifacts

All of the following must be current and accurate:

- **Markdown docs** (`docs/`) – User guides, command reference, configuration
- **Comment-based help** – `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`
  in every public cmdlet
- **Code samples** – Every example must be **tested and working**
- **CHANGELOG.md** – Every user-facing change, in correct format
- **Inline comments** – Explain "why" for non-obvious logic (sparingly)

### Documentation Quality Standards

- **Extremely clear**: A new user should understand immediately
- **Succinct**: Avoid unnecessary words; get to the point
- **Correct code samples**: Test every example before committing—**broken
  samples are bugs**
- **Realistic examples**: Use actual scenarios, not "foo", "bar", or "test"
- **Version annotations**: Mark new features/changes with version introduced
- **Complete coverage**: Update ALL affected documentation—partial updates are
  incomplete work

### Indicating New Behavior

When behavior is new or changed, explicitly communicate this:

- **In CHANGELOG**: Use appropriate section (`Added`, `Changed`, `Fixed`)
- **In user docs**: Add "_(Added in vX.Y.Z)_" annotations
- **In command help**: Note version in `.NOTES` section
- **For breaking changes**: Add migration notes with before/after examples

### CHANGELOG Format

Follow [Keep a Changelog](https://keepachangelog.com/) format:

- **Added** – New features
- **Changed** – Changes to existing functionality
- **Fixed** – Bug fixes
- **Deprecated** / **Removed** / **Security** – As applicable

Entries must be specific, actionable, and reference issue numbers where
applicable. Vague entries like "improved performance" or "fixed a bug" are
unacceptable.

See [documentation.md](skills/documentation.md) for comprehensive guidance.

## Exhaustive Testing Requirements

**Every feature and bug fix requires extensive, exhaustive tests.** Tests are
not an afterthought—they are a core deliverable of every change.

### Test Coverage Requirements

For every new feature or bug fix, tests must cover:

| Scenario Type             | Description                                           | Required          |
| ------------------------- | ----------------------------------------------------- | ----------------- |
| **Happy path**            | Normal expected usage                                 | ✓ Always          |
| **Edge cases**            | Boundary conditions, empty inputs, maximum values     | ✓ Always          |
| **Error cases**           | Invalid inputs, missing parameters, permission errors | ✓ Always          |
| **Negative scenarios**    | What should NOT work                                  | ✓ Always          |
| **Unexpected situations** | Null values, wrong types, concurrent access           | ✓ Always          |
| **"The impossible"**      | States that "shouldn't happen" but might              | ✓ When applicable |

### Data-Driven Tests

Use data-driven tests to cover multiple scenarios efficiently:

```powershell
$testCases = @(
    @{ Input = 'valid'; Expected = $true; Name = 'accepts valid input' }
    @{ Input = ''; Expected = $false; Name = 'rejects empty string' }
    @{ Input = $null; Expected = $false; Name = 'rejects null' }
    @{ Input = '   '; Expected = $false; Name = 'rejects whitespace only' }
)

foreach ($case in $testCases) {
    $result = Test-YourFunction -Input $case.Input
    Assert-Equal -Expected $case.Expected -Actual $result -Message $case.Name
}
```

See [add-tests.md](skills/add-tests.md) for comprehensive testing guidance.

## Zero-Flaky Test Policy

This repository maintains a **strict zero-flaky test policy**. Any test failure
must be fully investigated and comprehensively fixed.

### Core Principles

- **Every test failure is a real bug**—either in production code or in the test
- **No flaky tests**—intermittent failures indicate real problems (race
  conditions, state leakage, environment issues)
- **Never "make tests pass" superficially**—understand the root cause first
- **Never ignore or skip failing tests**—disabled tests hide real problems

### When Tests Fail

1. **Investigate thoroughly**—determine if it's a production bug or test bug
2. **Fix the root cause**—not just the symptom
3. **Verify comprehensively**—run tests multiple times, in CI mode
4. **Document the fix**—explain root cause in commit message

See [test-failures.md](skills/test-failures.md) for detailed investigation
procedures.

## Available Skills

Use these focused guides for specific tasks:

| Skill                                                     | When to Use                                   |
| --------------------------------------------------------- | --------------------------------------------- |
| [add-module.md](skills/add-module.md)                     | Creating a new PowerShell module              |
| [add-cmdlet.md](skills/add-cmdlet.md)                     | Adding commands to existing modules           |
| [add-tests.md](skills/add-tests.md)                       | Writing or modifying tests                    |
| [test-failures.md](skills/test-failures.md)               | **Investigating any test failure**            |
| [formatting.md](skills/formatting.md)                     | Code style and PSScriptAnalyzer rules         |
| [code-architecture.md](skills/code-architecture.md)       | Design patterns and code reuse                |
| [defensive-powershell.md](skills/defensive-powershell.md) | **Error handling, validation, guard clauses** |
| [performance-security.md](skills/performance-security.md) | **Performance optimization and security**     |
| [documentation.md](skills/documentation.md)               | **Updating docs, CHANGELOG, code samples**    |
| [verify-changes.md](skills/verify-changes.md)             | **MANDATORY: Run after ALL changes**          |
| [commit-pr.md](skills/commit-pr.md)                       | Preparing commits and pull requests           |
| [debug-module.md](skills/debug-module.md)                 | Troubleshooting module issues                 |
| [release.md](skills/release.md)                           | Version bumping and releases                  |

## Quick Commands

```powershell
.\Run-Tests.ps1              # Run all tests
.\Run-Tests.ps1 -CI          # CI mode (strict)
.\Format-PowerShell.ps1 -Fix # Auto-fix formatting
.\Setup-Hooks.ps1            # Install pre-commit hooks
```

## Configuration & Security

- `Setup-PowerShellMagic.ps1` writes only to `%LOCALAPPDATA%\PowerShellMagic`
  after explicit YES confirmations
- Portable downloads are validated with SHA256 hashes
- Preserve the opt-in consent model for new installations

## Tool Requirements

### For Development

- **PowerShell 7.0+**: Core requirement
- **Git**: Version control
- **PSScriptAnalyzer**: Auto-installed by formatter script

### For Pre-commit (Optional)

- **Python 3.7+**: For pre-commit framework
- **pre-commit**: `pip install pre-commit`
- **Node.js 18+**: Required for markdownlint and Prettier hooks

### External Tools (Runtime)

- **fzf**: Interactive selection (auto-installed by setup)
- **7-Zip**: Archive extraction (auto-installed by setup)
- **eza**: Enhanced directory listing (optional)
