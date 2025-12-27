#Requires -Version 5.1

<#
.SYNOPSIS
PowerShell-native pre-commit hook for PowerShell Magic

.DESCRIPTION
This pre-commit hook runs formatting checks and tests before allowing commits.
It's designed specifically for PowerShell environments and provides better
integration than shell-based hooks on Windows.
#>

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Color output functions
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info {
    param($Message) Write-Host -Object "ℹ️ $Message" -ForegroundColor Cyan
}
function Write-HookWarning { param($Message) Write-Host "⚠️ $Message" -ForegroundColor Yellow }
function Write-HookError { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }
function Test-PowerShellVersion {
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-HookError 'PowerShell 5.0 or higher is required for pre-commit hooks'
        return $false
    }
    return $true
}

function Get-RepositoryRoot {
    try {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0) {
            return [System.IO.Path]::GetFullPath($gitRoot)
        }
    } catch {}

    # Fallback: find .git directory
    $current = Get-Location
    while ($current) {
        if (Test-Path (Join-Path $current '.git')) {
            return $current.Path
        }
        $current = $current.Parent
    }

    throw 'Not in a Git repository'
}

function Get-StagedPowerShellFiles {
    try {
        $stagedFiles = git diff --cached --name-only --diff-filter=ACM 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $stagedFiles | Where-Object { $_ -match '\.(ps1|psm1|psd1)$' }
        }
    } catch {}
    return @()
}

function Test-PreCommitConditions {
    # Check if this is a merge commit (skip hooks for merge commits)
    $mergeHeadPath = Join-Path '.git' 'MERGE_HEAD'
    if (Test-Path $mergeHeadPath) {
        Write-Info 'Merge commit detected - skipping pre-commit hooks'
        return $false
    }

    # Check if there are any PowerShell files staged
    $stagedPSFiles = Get-StagedPowerShellFiles
    if ($stagedPSFiles.Count -eq 0) {
        Write-Info 'No PowerShell files staged - skipping PowerShell checks'
        return $false
    }

    Write-Info "Found $($stagedPSFiles.Count) staged PowerShell files"
    return $true
}

function Invoke-PreCommitChecks {
    $repoRoot = Get-RepositoryRoot
    Push-Location $repoRoot

    try {
        Write-Info 'Running pre-commit checks for PowerShell Magic...'
        Write-Info "Repository: $repoRoot"

        # Check PowerShell version
        if (-not (Test-PowerShellVersion)) {
            return 1
        }

        # Check if we should run hooks
        if (-not (Test-PreCommitConditions)) {
            Write-Success 'Pre-commit checks skipped'
            return 0
        }

        # Run formatting check
        Write-Info 'Checking PowerShell formatting...'
        $formatterScript = Join-Path $repoRoot 'Format-PowerShell.ps1'

        if (-not (Test-Path $formatterScript)) {
            Write-HookWarning "Formatter script not found: $formatterScript"
            Write-HookWarning 'Skipping formatting check'
        } else {
            try {
                & $formatterScript -Check
                if ($LASTEXITCODE -ne 0) {
                    Write-HookError 'Formatting issues found!'
                    Write-Info "💡 Run './Format-PowerShell.ps1 -Fix' to automatically fix formatting issues"
                    return 1
                }
                Write-Success 'Formatting check passed'
            } catch {
                Write-HookError "Formatting check failed: $($_.Exception.Message)"
                return 1
            }
        }

        # Run tests
        Write-Info 'Running PowerShell tests...'
        $testScript = Join-Path $repoRoot 'Run-Tests.ps1'

        if (-not (Test-Path $testScript)) {
            Write-HookWarning "Test script not found: $testScript"
            Write-HookWarning 'Skipping tests'
        } else {
            try {
                & $testScript -Test
                if ($LASTEXITCODE -ne 0) {
                    Write-HookError 'Tests failed!'
                    Write-Info '💡 Fix the failing tests before committing'
                    return 1
                }
                Write-Success 'Tests passed'
            } catch {
                Write-HookError "Test execution failed: $($_.Exception.Message)"
                return 1
            }
        }

        Write-Success 'All pre-commit checks passed!'
        Write-Success '🚀 Ready to commit'
        return 0

    } catch {
        Write-HookError "Pre-commit hook failed: $($_.Exception.Message)"
        return 1
    } finally {
        Pop-Location
    }
}

# Main execution
try {
    $exitCode = Invoke-PreCommitChecks
    exit $exitCode
} catch {
    Write-HookError "Pre-commit hook error: $($_.Exception.Message)"
    exit 1
}