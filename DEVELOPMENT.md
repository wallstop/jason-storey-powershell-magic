# PowerShell Magic - Development Guide

This guide covers the development tools and workflow for PowerShell Magic contributors.

## 🚀 Quick Start

```powershell
# 1. Clone and enter repository
git clone https://github.com/wallstop/jason-storey-powershell-magic.git
cd powershell-magic

# 2. Set up development environment
.\Setup-Hooks.ps1

# 3. Run tests to verify everything works
.\Run-Tests.ps1
```

## 📋 Available Commands

### Main Test Runner

```powershell
.\Run-Tests.ps1              # Run all tests and formatting checks
.\Run-Tests.ps1 -Test        # Run only unit tests
.\Run-Tests.ps1 -Format      # Run only formatting checks
.\Run-Tests.ps1 -Format -Fix # Run formatting and auto-fix issues
.\Run-Tests.ps1 -CI          # CI mode (strict, no auto-fixes)
```

### PowerShell Formatter

```powershell
.\Format-PowerShell.ps1 -Check    # Check formatting only
.\Format-PowerShell.ps1 -Fix      # Auto-fix formatting issues
.\Format-PowerShell.ps1 -Path "Modules" -Fix  # Format specific directory
```

### Unit Tests

```powershell
.\Tests\Test-PowerShellMagic.ps1               # Run all tests
.\Tests\Test-PowerShellMagic.ps1 -TestName Setup     # Run setup tests only
.\Tests\Test-PowerShellMagic.ps1 -TestName Common    # Run shared utility tests only
.\Tests\Test-PowerShellMagic.ps1 -TestName QuickJump # Run QuickJump tests only
.\Tests\Test-PowerShellMagic.ps1 -Verbose            # Verbose output
```

### Pre-commit Hooks

```powershell
.\Setup-Hooks.ps1                    # Auto-detect and install best method
.\Setup-Hooks.ps1 -Method precommit  # Use Python pre-commit framework
.\Setup-Hooks.ps1 -Method git        # Use native Git hooks
.\Setup-Hooks.ps1 -Force             # Force reinstall hooks
```

## 🔧 Development Workflow

### Standard Workflow

1. **Setup**: `.\Setup-Hooks.ps1`
2. **Develop**: Make your changes
3. **Test**: `.\Run-Tests.ps1`
4. **Fix formatting**: `.\Format-PowerShell.ps1 -Fix` (if needed)
5. **Commit**: `git commit -m "Your message"` (hooks run automatically)

### Before Submitting PR

```powershell
# Run full test suite
.\Run-Tests.ps1

# Check that all files are properly formatted
.\Format-PowerShell.ps1 -Check

# Run tests in CI mode (strict)
.\Run-Tests.ps1 -CI
```

## 🧩 Module Layout

- Modules are adopting a `Private/` + `Public/` split so helpers stay isolated
  from exported cmdlets. QuickJump, Templater, and Unitea already follow this
  structure (`Modules/<Module>/Private/*.ps1`,
  `Modules/<Module>/Public/*.ps1`).
- Each module’s root `.psm1` dot-sources the scripts in those folders; follow
  the same pattern for new modules or when extracting additional helpers.
- Keep `FunctionsToExport` in each module manifest accurate when adding new
  public commands, and run the focused test suite (for example,
  `.\Tests\Test-PowerShellMagic.ps1 -TestName QuickJump`) after restructuring.
- Prefer one logical area per script file—group related helper functions
  together so future modules can reuse them by dot-sourcing the private file.

## 🧪 Test Architecture

### Test Coverage

- **Setup Script**: Syntax validation, function presence, dependencies
- **Module Loading**: All modules import without errors
- **Command Exports**: Expected commands are available
- **Dependency Handling**: Graceful failure without external tools
- **Configuration**: Config path functions work correctly
- **Common Utilities**: Shared helpers for config paths,
  non-interactive mode, and `fzf` probing
- **Code Quality**: Formatter and analyzer functionality

### Test Design

- **No External Dependencies**: Tests run without fzf, 7-Zip, eza, or Unity
  Hub
- **Mocked Dependencies**: Where external tools are needed
- **Syntax Validation**: PowerShell AST parsing for all scripts
- **Module Structure**: Validates proper module organization

## 📝 Code Style

### PSScriptAnalyzer Rules

- **Indentation**: 4 spaces (no tabs)
- **Bracing**: Opening brace on same line
- **Casing**: PascalCase for functions, camelCase for variables
- **Aliases**: Avoid in scripts (except `cd`, `ls`, `cat`, `rm`, `cp`, `mv`)
- **Parameters**: Explicit types where applicable
- **Security**: No plain text passwords, secure string handling

### Configuration Files

- **PSScriptAnalyzerSettings.psd1**: Main formatting rules
- **.pre-commit-config.yaml**: Pre-commit framework configuration
- **hooks/**: Native Git hook implementations

## 🔍 Pre-commit Hooks

### What They Check

1. **PowerShell Formatting**: Uses PSScriptAnalyzer rules
2. **Unit Tests**: Ensures all functionality works
3. **File Checks**: Trailing whitespace, merge conflicts, large files
4. **Markdown**: Linting and formatting

### Hook Behavior

- **Smart Execution**: Only runs on commits with PowerShell files
- **Merge Handling**: Skips hooks for merge commits
- **Graceful Degradation**: Falls back if tools unavailable
- **Clear Feedback**: Detailed error messages and fix suggestions

### Manual Hook Execution

```powershell
# Python pre-commit framework
pre-commit run --all-files    # Run all hooks
pre-commit run powershell-format  # Run specific hook

# Native Git hooks
.\hooks\pre-commit.ps1        # Run PowerShell hook directly
```

## 🏗️ CI/CD Integration

### GitHub Actions Example

```yaml
name: PowerShell Magic CI
on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@v4
    - name: Run Tests
      run: |
        powershell -ExecutionPolicy Bypass -File "./Run-Tests.ps1" -CI
```

### Azure DevOps Example

```yaml
steps:
- task: PowerShell@2
  displayName: 'Run PowerShell Magic Tests'
  inputs:
    filePath: './Run-Tests.ps1'
    arguments: '-CI'
    errorActionPreference: 'stop'
```

## 🔧 Tool Requirements

### For Development

- **PowerShell 5.1+**: Core requirement
- **Git**: Version control
- **PSScriptAnalyzer**: Auto-installed by formatter script

### For Pre-commit (Optional)

- **Python 3.7+**: For pre-commit framework
- **pre-commit**: `pip install pre-commit`

### External Tools (Runtime)

- **fzf**: Interactive selection (auto-installed by setup)
- **7-Zip**: Archive extraction (auto-installed by setup)
- **eza**: Enhanced directory listing (optional)

## 🐛 Troubleshooting

### Common Issues

### "PSScriptAnalyzer not found"

```powershell
# Auto-install via formatter
.\Format-PowerShell.ps1 -Check

# Manual install
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

### "Pre-commit hooks not working"

```powershell
# Reinstall hooks
.\Setup-Hooks.ps1 -Force

# Check Git hooks directory
ls .git\hooks\
```

### "Tests failing in CI"

```powershell
# Run locally in CI mode
.\Run-Tests.ps1 -CI

# Check specific test
.\Tests\Test-PowerShellMagic.ps1 -Verbose
```

### "Formatting issues"

```powershell
# Auto-fix most issues
.\Format-PowerShell.ps1 -Fix

# Check what needs fixing
.\Format-PowerShell.ps1 -Check
```

## 📚 Additional Resources

- **PSScriptAnalyzer Documentation**: <https://github.com/PowerShell/PSScriptAnalyzer>
- **Pre-commit Framework**: <https://pre-commit.com/>
- **PowerShell Best Practices**: <https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/strongly-encouraged-development-guidelines>
- **Git Hooks Documentation**: <https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks>

---

**Ready to contribute? Start with: `.\Setup-Hooks.ps1` and `.\Run-Tests.ps1`** 🚀
