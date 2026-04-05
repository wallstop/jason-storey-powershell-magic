#Requires -Version 7.0

<#
.SYNOPSIS
Test runner for PowerShell Magic project

.DESCRIPTION
This script runs all tests and formatting checks for the PowerShell Magic project.
It's designed to be used in CI/CD pipelines and as a pre-commit hook.

.PARAMETER Format
Run formatting checks and fixes

.PARAMETER Test
Run unit tests (legacy custom framework)

.PARAMETER Pester
Run Pester tests with code coverage

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
    [switch]$Pester,
    [switch]$Downloads,
    [switch]$All,
    [switch]$Fix,
    [switch]$CI
)

# Default to All if no specific option is chosen
if (-not $Format -and -not $Test -and -not $Pester -and -not $Downloads) {
    $All = $true
}

# Color output functions
function Write-RunnerSuccess { param($Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-RunnerInfo { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-RunnerWarning { param($Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-RunnerError { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

function Test-Prerequisites {
    Write-RunnerInfo 'Checking prerequisites...'

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-RunnerError 'PowerShell 5.0 or higher is required'
        return $false
    }

    Write-RunnerSuccess "PowerShell version: $($PSVersionTable.PSVersion)"
    return $true
}

function Invoke-FormatCheck {
    param([switch]$FixIssues)

    Write-Host "`n=== PowerShell Formatting ===" -ForegroundColor Yellow

    $formatterScript = Join-Path $PSScriptRoot 'Format-PowerShell.ps1'

    if (-not (Test-Path $formatterScript)) {
        Write-RunnerError "Formatter script not found: $formatterScript"
        return 1
    }

    try {
        if ($FixIssues -and -not $CI) {
            Write-RunnerInfo 'Running formatter with fixes...'
            & $formatterScript -Fix
        } else {
            Write-RunnerInfo 'Checking formatting...'
            & $formatterScript -Check
        }

        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            Write-RunnerSuccess 'Formatting check passed'
        } else {
            Write-RunnerError 'Formatting issues found'
        }

        return $exitCode
    } catch {
        Write-RunnerError "Formatter failed: $($_.Exception.Message)"
        return 1
    }
}

function Invoke-UnitTests {
    Write-Host "`n=== Unit Tests ===" -ForegroundColor Yellow

    $testScript = Join-Path $PSScriptRoot 'Tests\Test-PowerShellMagic.ps1'

    if (-not (Test-Path $testScript)) {
        Write-RunnerError "Test script not found: $testScript"
        return 1
    }

    try {
        Write-RunnerInfo 'Running unit tests...'
        # Set environment variable for non-interactive mode
        $env:POWERSHELL_MAGIC_NON_INTERACTIVE = '1'
        & $testScript

        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            Write-RunnerSuccess 'All tests passed'
        } else {
            Write-RunnerError 'Some tests failed'
        }

        return $exitCode
    } catch {
        Write-RunnerError "Test execution failed: $($_.Exception.Message)"
        return 1
    }
}

function Invoke-PesterTests {
    Write-Host "`n=== Pester Tests ===" -ForegroundColor Yellow

    $pesterRunner = Join-Path $PSScriptRoot 'Invoke-PesterTests.ps1'

    if (-not (Test-Path $pesterRunner)) {
        Write-RunnerWarning "Pester test runner not found: $pesterRunner"
        Write-RunnerInfo 'Skipping Pester tests (optional)'
        return 0
    }

    # Check if Pester 5.x is available
    $pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge '5.0.0' } | Select-Object -First 1

    if (-not $pesterModule) {
        Write-RunnerWarning 'Pester 5.x is not installed'
        Write-RunnerInfo 'Install with: Install-Module -Name Pester -MinimumVersion 5.0.0 -Force'
        Write-RunnerInfo 'Skipping Pester tests (optional)'
        return 0
    }

    try {
        Write-RunnerInfo 'Running Pester tests with code coverage...'

        if ($CI) {
            & $pesterRunner -CI -CoverageThreshold 52
        } else {
            & $pesterRunner -CodeCoverage
        }

        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            Write-RunnerSuccess 'All Pester tests passed'
        } else {
            Write-RunnerError 'Some Pester tests failed'
        }

        return $exitCode
    } catch {
        Write-RunnerError "Pester test execution failed: $($_.Exception.Message)"
        return 1
    }
}

function Invoke-PortableDownloadTests {
    Write-Host "`n=== Portable Downloads Tests ===" -ForegroundColor Yellow

    $testScript = Join-Path $PSScriptRoot 'Tests\Test-PortableDownloads.ps1'

    if (-not (Test-Path $testScript)) {
        Write-RunnerError "Portable downloads test script not found: $testScript"
        return 1
    }

    try {
        Write-RunnerInfo 'Running portable downloads tests...'
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
            Write-RunnerSuccess 'All portable downloads tests passed'
        } else {
            Write-RunnerError 'Some portable downloads tests failed'
        }

        return $exitCode
    } catch {
        Write-RunnerError "Portable downloads test execution failed: $($_.Exception.Message)"
        return 1
    }
}

function Show-CIInstructions {
    if ($CI) {
        Write-Host "`n=== CI Mode Information ===" -ForegroundColor Cyan
        Write-RunnerInfo 'Running in CI mode:'
        Write-RunnerInfo 'Formatting checks only (no automatic fixes)'
        Write-RunnerInfo 'Strict exit codes for pipeline integration'
        Write-RunnerInfo 'All issues must be resolved for success'
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

    # Run Pester tests
    if ($Pester -or $All) {
        $pesterResult = Invoke-PesterTests
        if ($pesterResult -ne 0) {
            $overallSuccess = $false
            $exitCode = $pesterResult
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
        Write-RunnerSuccess 'All checks passed successfully!'
        Write-Host 'Ready for commit!' -ForegroundColor Green
    } else {
        Write-RunnerError 'Some checks failed'
        Write-Host 'Please fix the issues before committing' -ForegroundColor Red

        if (-not $CI -and -not $Fix) {
            Write-RunnerInfo 'Tip: Run with -Fix to automatically resolve formatting issues'
        }
    }

    exit $exitCode
}

# Run main function
Main
