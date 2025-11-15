# PesterConfiguration.ps1
# Pester configuration for PowerShell Magic test suite

$pesterConfig = New-PesterConfiguration

# General settings
$pesterConfig.Run.Path = Join-Path $PSScriptRoot 'PowerShellMagic.Tests.ps1'
$pesterConfig.Run.Exit = $false
$pesterConfig.Run.PassThru = $true

# Output settings
$pesterConfig.Output.Verbosity = 'Detailed'
$pesterConfig.Output.StackTraceVerbosity = 'Filtered'
$pesterConfig.Output.CIFormat = 'Auto'

# Code coverage settings
$moduleRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$pesterConfig.CodeCoverage.Enabled = $true
$quickJumpModulePath = Join-Path $moduleRoot 'Modules\QuickJump'
$pesterConfig.CodeCoverage.Path = @(
    (Join-Path $quickJumpModulePath 'Public\QuickJump.Commands.ps1')
)
$pesterConfig.CodeCoverage.OutputPath = Join-Path $PSScriptRoot 'coverage.xml'
$pesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
$pesterConfig.CodeCoverage.OutputEncoding = 'UTF8'
$pesterConfig.CodeCoverage.UseBreakpoints = $false  # Faster without breakpoints

# Test result settings
$pesterConfig.TestResult.Enabled = $true
$pesterConfig.TestResult.OutputPath = Join-Path $PSScriptRoot 'testResults.xml'
$pesterConfig.TestResult.OutputFormat = 'NUnitXml'
$pesterConfig.TestResult.TestSuiteName = 'PowerShell Magic Test Suite'

# Filter settings (can be overridden)
# $pesterConfig.Filter.Tag = @('Unit', 'Integration')
# $pesterConfig.Filter.ExcludeTag = @('Performance')

# Should settings
$pesterConfig.Should.ErrorAction = 'Stop'

return $pesterConfig
