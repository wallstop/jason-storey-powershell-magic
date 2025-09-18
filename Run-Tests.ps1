#Requires -Version 5.1

<#
.SYNOPSIS
Test runner for PowerShell Magic project

.DESCRIPTION
This script runs all tests and formatting checks for the PowerShell Magic project.
It's designed to be used in CI/CD pipelines and as a pre-commit hook.

.PARAMETER Format
Run formatting checks and fixes

.PARAMETER Test
Run unit tests

.PARAMETER Downloads
Run portable downloads tests only

.PARAMETER All
Run formatting, unit tests, and downloads tests (default)

.PARAMETER Fix
Automatically fix formatting issues

.PARAMETER CI
Run in CI mode (check only, no fixes, strict exit codes)

.EXAMPLE
.\Run-Tests.ps1
Run all tests and formatting checks

.EXAMPLE
.\Run-Tests.ps1 -Format -Fix
Run formatting and automatically fix issues

.EXAMPLE
.\Run-Tests.ps1 -CI
Run in CI mode (for automated builds)

.EXAMPLE
.\Run-Tests.ps1 -Downloads
Run only portable downloads tests

.EXAMPLE
.\Run-Tests.ps1 -Test
Run only unit tests (excluding downloads)
#>

[CmdletBinding()]
param(
    [switch]$Format,
    [switch]$Test,
    [switch]$Downloads,
    [switch]$All,
    [switch]$Fix,
    [switch]$CI
)

# Default to All if no specific option is chosen
if (-not $Format -and -not $Test -and -not $Downloads) {
    $All = $true
}

# Color output functions
function Write-Success { param($Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

function Test-Prerequisites {
    Write-Info 'Checking prerequisites...'

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Error 'PowerShell 5.0 or higher is required'
        return $false
    }

    Write-Success "PowerShell version: $($PSVersionTable.PSVersion)"
    return $true
}

function Invoke-FormatCheck {
    param([switch]$FixIssues)

    Write-Host "`n=== PowerShell Formatting ===" -ForegroundColor Yellow

    $formatterScript = Join-Path $PSScriptRoot 'Format-PowerShell.ps1'

    if (-not (Test-Path $formatterScript)) {
        Write-Error "Formatter script not found: $formatterScript"
        return 1
    }

    try {
        if ($FixIssues -and -not $CI) {
            Write-Info 'Running formatter with fixes...'
            & $formatterScript -Fix
        } else {
            Write-Info 'Checking formatting...'
            & $formatterScript -Check
        }

        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            Write-Success 'Formatting check passed'
        } else {
            Write-Error 'Formatting issues found'
        }

        return $exitCode
    } catch {
        Write-Error "Formatter failed: $($_.Exception.Message)"
        return 1
    }
}

function Invoke-UnitTests {
    Write-Host "`n=== Unit Tests ===" -ForegroundColor Yellow

    $testScript = Join-Path $PSScriptRoot 'Tests\Test-PowerShellMagic.ps1'

    if (-not (Test-Path $testScript)) {
        Write-Error "Test script not found: $testScript"
        return 1
    }

    try {
        Write-Info 'Running unit tests...'
        # Set environment variable for non-interactive mode
        $env:POWERSHELL_MAGIC_NON_INTERACTIVE = '1'
        & $testScript

        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            Write-Success 'All tests passed'
        } else {
            Write-Error 'Some tests failed'
        }

        return $exitCode
    } catch {
        Write-Error "Test execution failed: $($_.Exception.Message)"
        return 1
    }
}

function Invoke-PortableDownloadTests {
    Write-Host "`n=== Portable Downloads Tests ===" -ForegroundColor Yellow

    $testScript = Join-Path $PSScriptRoot 'Tests\Test-PortableDownloads.ps1'

    if (-not (Test-Path $testScript)) {
        Write-Error "Portable downloads test script not found: $testScript"
        return 1
    }

    try {
        Write-Info 'Running portable downloads tests...'
        # Set environment variable for non-interactive mode
        $env:POWERSHELL_MAGIC_NON_INTERACTIVE = '1'
        # Skip actual downloads in CI mode to avoid network dependencies
        if ($CI) {
            & $testScript -SkipDownloads
        } else {
            & $testScript
        }

        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            Write-Success 'All portable downloads tests passed'
        } else {
            Write-Error 'Some portable downloads tests failed'
        }

        return $exitCode
    } catch {
        Write-Error "Portable downloads test execution failed: $($_.Exception.Message)"
        return 1
    }
}

function Show-CIInstructions {
    if ($CI) {
        Write-Host "`n=== CI Mode Information ===" -ForegroundColor Cyan
        Write-Info 'Running in CI mode:'
        Write-Info 'Formatting checks only (no automatic fixes)'
        Write-Info 'Strict exit codes for pipeline integration'
        Write-Info 'All issues must be resolved for success'
    }
}

function Main {
    Write-Host 'PowerShell Magic - Test Runner' -ForegroundColor Cyan
    Write-Host '==============================' -ForegroundColor Cyan

    Show-CIInstructions

    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        exit 1
    }

    $overallSuccess = $true
    $exitCode = 0

    # Run formatting checks
    if ($Format -or $All) {
        $formatResult = Invoke-FormatCheck -FixIssues:$Fix
        if ($formatResult -ne 0) {
            $overallSuccess = $false
            $exitCode = $formatResult
        }
    }

    # Run unit tests
    if ($Test -or $All) {
        $testResult = Invoke-UnitTests
        if ($testResult -ne 0) {
            $overallSuccess = $false
            $exitCode = $testResult
        }
    }

    # Run portable downloads tests
    if ($Downloads -or $All) {
        $downloadTestResult = Invoke-PortableDownloadTests
        if ($downloadTestResult -ne 0) {
            $overallSuccess = $false
            $exitCode = $downloadTestResult
        }
    }

    # Final summary
    Write-Host ("`n" + ('=' * 50)) -ForegroundColor Cyan
    if ($overallSuccess) {
        Write-Success 'All checks passed successfully!'
        Write-Host 'Ready for commit!' -ForegroundColor Green
    } else {
        Write-Error 'Some checks failed'
        Write-Host 'Please fix the issues before committing' -ForegroundColor Red

        if (-not $CI -and -not $Fix) {
            Write-Info 'Tip: Run with -Fix to automatically resolve formatting issues'
        }
    }

    exit $exitCode
}

# Run main function
Main