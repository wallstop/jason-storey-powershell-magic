#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

<#
.SYNOPSIS
Runs the Pester test suite for PowerShell Magic with code coverage.

.DESCRIPTION
This script executes the comprehensive Pester test suite with code coverage
analysis and generates detailed test reports.

.PARAMETER Tag
Specific tags to include in test run (e.g., 'Unit', 'E2E', 'Performance')

.PARAMETER ExcludeTag
Tags to exclude from test run

.PARAMETER CodeCoverage
Enable code coverage analysis (default: true)

.PARAMETER CI
Run in CI mode with strict failure handling

.PARAMETER CoverageThreshold
Minimum code coverage percentage required to pass (default: 80)

.EXAMPLE
.\Invoke-PesterTests.ps1
Runs all tests with code coverage

.EXAMPLE
.\Invoke-PesterTests.ps1 -Tag 'Unit'
Runs only unit tests

.EXAMPLE
.\Invoke-PesterTests.ps1 -CI -CoverageThreshold 85
Runs in CI mode requiring 85% code coverage
#>

[CmdletBinding()]
param(
    [string[]]$Tag,

    [string[]]$ExcludeTag,

    [switch]$CodeCoverage = $true,

    [switch]$CI,

    [int]$CoverageThreshold = 80
)

# Ensure Pester 5.x is available
$pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge '5.0.0' } | Select-Object -First 1

if (-not $pesterModule) {
    Write-Error 'Pester 5.x or higher is required. Install with: Install-Module -Name Pester -MinimumVersion 5.0.0 -Force'
    exit 1
}

Import-Module Pester -MinimumVersion 5.0.0 -Force

Write-Host 'Starting PowerShell Magic Test Suite with Pester' -ForegroundColor Cyan
Write-Host "Pester Version: $($pesterModule.Version)" -ForegroundColor Gray
Write-Host ''

# Load Pester configuration
$configPath = Join-Path $PSScriptRoot 'Tests\Pester\PesterConfiguration.ps1'
$config = & $configPath

# Apply command-line overrides
if ($Tag) {
    $config.Filter.Tag = $Tag
}

if ($ExcludeTag) {
    $config.Filter.ExcludeTag = $ExcludeTag
}

if (-not $CodeCoverage) {
    $config.CodeCoverage.Enabled = $false
}

if ($CI) {
    $config.Run.Exit = $true
    $config.Output.Verbosity = 'Normal'
}

# Run tests
Write-Host 'Running tests...' -ForegroundColor Yellow
$result = Invoke-Pester -Configuration $config

# Display summary
Write-Host ''
Write-Host '=' * 80 -ForegroundColor Cyan
Write-Host 'Test Summary' -ForegroundColor Cyan
Write-Host '=' * 80 -ForegroundColor Cyan
Write-Host "Total Tests:  $($result.TotalCount)" -ForegroundColor Gray
Write-Host "Passed:       $($result.PassedCount)" -ForegroundColor Green
Write-Host "Failed:       $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Gray' })
Write-Host "Skipped:      $($result.SkippedCount)" -ForegroundColor Yellow
Write-Host "Duration:     $($result.Duration)" -ForegroundColor Gray

# Code coverage summary
if ($config.CodeCoverage.Enabled -and $result.CodeCoverage) {
    $coverage = $result.CodeCoverage
    $coveragePercent = [math]::Round(($coverage.CoveredPercent), 2)

    Write-Host ''
    Write-Host 'Code Coverage' -ForegroundColor Cyan
    Write-Host '-' * 80 -ForegroundColor Cyan
    Write-Host "Commands Analyzed: $($coverage.NumberOfCommandsAnalyzed)" -ForegroundColor Gray
    Write-Host "Commands Executed: $($coverage.NumberOfCommandsExecuted)" -ForegroundColor Gray
    Write-Host "Coverage:          $coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge $CoverageThreshold) { 'Green' } else { 'Red' })
    Write-Host "Threshold:         $CoverageThreshold%" -ForegroundColor Gray

    if ($coveragePercent -lt $CoverageThreshold) {
        Write-Host ''
        Write-Host "WARNING: Code coverage ($coveragePercent%) is below threshold ($CoverageThreshold%)" -ForegroundColor Red
    }

    # Show missed commands
    if ($coverage.MissedCommands.Count -gt 0) {
        Write-Host ''
        Write-Host "Missed Commands (top 10):" -ForegroundColor Yellow
        $coverage.MissedCommands | Select-Object -First 10 | ForEach-Object {
            Write-Host "  $($_.File):$($_.Line) - $($_.Command)" -ForegroundColor Gray
        }
    }

    Write-Host ''
    Write-Host "Coverage report: $($config.CodeCoverage.OutputPath)" -ForegroundColor Cyan
}

Write-Host ''
Write-Host "Test results: $($config.TestResult.OutputPath)" -ForegroundColor Cyan
Write-Host ''

# Exit with appropriate code
if ($result.FailedCount -gt 0) {
    Write-Host 'FAILED: One or more tests failed' -ForegroundColor Red
    if ($CI) {
        exit 1
    }
} elseif ($config.CodeCoverage.Enabled -and $coveragePercent -lt $CoverageThreshold) {
    Write-Host "FAILED: Code coverage ($coveragePercent%) is below threshold ($CoverageThreshold%)" -ForegroundColor Red
    if ($CI) {
        exit 1
    }
} else {
    Write-Host 'SUCCESS: All tests passed!' -ForegroundColor Green
    if ($CI) {
        exit 0
    }
}
