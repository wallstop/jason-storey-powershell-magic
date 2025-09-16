#Requires -Version 5.1

<#
.SYNOPSIS
Formats PowerShell scripts using PSScriptAnalyzer rules

.DESCRIPTION
This script formats all PowerShell files in the repository using consistent
formatting rules defined in PSScriptAnalyzerSettings.psd1. It can both
check for formatting issues and automatically fix them.

.PARAMETER Path
Path to format. Defaults to current directory.

.PARAMETER Check
Only check formatting without making changes. Returns exit code 1 if issues found.

.PARAMETER Fix
Automatically fix formatting issues.

.PARAMETER Include
File patterns to include (default: *.ps1, *.psm1, *.psd1)

.PARAMETER IncludeMarkdown
Include markdown files (*.md) for linting and formatting

.EXAMPLE
.\Format-PowerShell.ps1 -Check
Check all PowerShell files for formatting issues

.EXAMPLE
.\Format-PowerShell.ps1 -Fix
Fix all formatting issues in PowerShell files

.EXAMPLE
.\Format-PowerShell.ps1 -Path "Modules" -Fix
Fix formatting issues in the Modules directory

.EXAMPLE
.\Format-PowerShell.ps1 -IncludeMarkdown -Check
Check both PowerShell and Markdown files for formatting issues

.EXAMPLE
.\Format-PowerShell.ps1 -IncludeMarkdown -Fix
Fix formatting issues in both PowerShell and Markdown files
#>

[CmdletBinding()]
param(
    [string]$Path = '.',
    [switch]$Check,
    [switch]$Fix,
    [string[]]$Include = @('*.ps1', '*.psm1', '*.psd1'),
    [switch]$IncludeMarkdown
)

# Color output functions
function Write-Success {
    param($Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}
function Write-Info {
    param($Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}
function Write-ScriptWarning {
    param($Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}
function Write-ScriptError {
    param($Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Test-PSScriptAnalyzer {
    try {
        $module = Get-Module -Name PSScriptAnalyzer -ListAvailable
        if (-not $module) {
            Write-ScriptWarning 'PSScriptAnalyzer not found. Installing...'
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser -SkipPublisherCheck
            } else {
                Write-ScriptError 'PowerShell 5.0+ required for PSScriptAnalyzer auto-install'
                return $false
            }
        }
        Import-Module PSScriptAnalyzer -Force
        return $true
    } catch {
        Write-ScriptError "Failed to load PSScriptAnalyzer: $($_.Exception.Message)"
        return $false
    }
}

function Test-MarkdownLint {
    try {
        $markdownlint = Get-Command markdownlint-cli2 -ErrorAction SilentlyContinue
        if (-not $markdownlint) {
            Write-ScriptWarning 'markdownlint-cli2 not found. Installing...'
            try {
                npm install -g markdownlint-cli2
                Write-Success 'markdownlint-cli2 installed successfully'
            } catch {
                Write-ScriptError 'Failed to install markdownlint-cli2. Please install Node.js and npm first.'
                return $false
            }
        }
        return $true
    } catch {
        Write-ScriptError "Failed to check markdownlint-cli2: $($_.Exception.Message)"
        return $false
    }
}

function Get-PowerShellFile {
    param([string]$SearchPath, [string[]]$Patterns)

    $files = @()
    foreach ($pattern in $Patterns) {
        $found = Get-ChildItem -Path $SearchPath -Filter $pattern -Recurse -File
        $files += $found
    }

    # Remove duplicates and sort
    return $files | Sort-Object FullName -Unique
}

function Get-MarkdownFile {
    param([string]$SearchPath)

    try {
        $files = Get-ChildItem -Path $SearchPath -Filter '*.md' -Recurse -File
        return $files | Sort-Object FullName -Unique
    } catch {
        Write-ScriptError "Failed to find markdown files: $($_.Exception.Message)"
        return @()
    }
}

function Test-PowerShellFormatting {
    param([string]$FilePath)

    $settingsPath = Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1'

    try {
        # Get the original content
        $originalContent = Get-Content -Path $FilePath -Raw

        # Apply formatting to see what would change
        if (Test-Path $settingsPath) {
            $formatted = Invoke-Formatter -ScriptDefinition $originalContent -Settings $settingsPath
        } else {
            Write-ScriptWarning "Settings file not found: $settingsPath, using default formatting"
            $formatted = Invoke-Formatter -ScriptDefinition $originalContent
        }

        # Check if there are formatting differences
        if ($formatted -ne $originalContent) {
            # Create a pseudo-issue to indicate formatting is needed
            return @([PSCustomObject]@{
                    Line = 1
                    Column = 1
                    Severity = 'Information'
                    RuleName = 'PSFormattingRequired'
                    Message = 'File needs formatting to match style guidelines'
                })
        } else {
            return @()
        }
    } catch {
        Write-ScriptError "Failed to analyze ${FilePath}: $($_.Exception.Message)"
        return @()
    }
}

function Invoke-PowerShellFormatting {
    param([string]$FilePath)

    $settingsPath = Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1'

    try {
        # Get the original content
        $originalContent = Get-Content -Path $FilePath -Raw

        # Apply formatting using PSScriptAnalyzer
        if (Test-Path $settingsPath) {
            $formatted = Invoke-Formatter -ScriptDefinition $originalContent -Settings $settingsPath
        } else {
            Write-ScriptWarning "Settings file not found: $settingsPath, using default formatting"
            $formatted = Invoke-Formatter -ScriptDefinition $originalContent
        }

        # Only write if content changed
        if ($formatted -ne $originalContent) {
            Set-Content -Path $FilePath -Value $formatted -Encoding UTF8 -NoNewline
            return $true
        }

        return $false
    } catch {
        Write-ScriptError "Failed to format ${FilePath}: $($_.Exception.Message)"
        return $false
    }
}

function Test-MarkdownFormatting {
    param([string]$FilePath)

    try {
        $result = & markdownlint-cli2 $FilePath 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            return @()
        } else {
            # Parse the output to extract issues
            $issues = @()
            $lines = $result -split "`n"
            foreach ($line in $lines) {
                if ($line -match '^(.+):(\d+)(?::(\d+))?\s+(.+)\s+(.+)$') {
                    $issues += [PSCustomObject]@{
                        File = $matches[1]
                        Line = [int]$matches[2]
                        Column = if ($matches[3]) { [int]$matches[3] } else { 1 }
                        Rule = $matches[4]
                        Message = $matches[5]
                    }
                }
            }
            return $issues
        }
    } catch {
        Write-ScriptError "Failed to check markdown formatting for ${FilePath}: $($_.Exception.Message)"
        return @()
    }
}

function Invoke-MarkdownFormatting {
    param([string]$FilePath)

    try {
        # Try to fix the markdown file
        $result = & markdownlint-cli2 --fix $FilePath 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            return $true
        } else {
            # Check if any fixes were applied by running again
            $afterFix = & markdownlint-cli2 $FilePath 2>&1
            $afterExitCode = $LASTEXITCODE

            # If there were issues before and fewer/none after, fixes were applied
            return $afterExitCode -ne $exitCode
        }
    } catch {
        Write-ScriptError "Failed to format markdown file ${FilePath}: $($_.Exception.Message)"
        return $false
    }
}

function Main {
    Write-Host 'PowerShell Code Formatter' -ForegroundColor Cyan
    Write-Host '=========================' -ForegroundColor Cyan

    # Validate parameters
    if (-not $Check -and -not $Fix) {
        Write-ScriptError 'Must specify either -Check or -Fix'
        exit 1
    }

    if ($Check -and $Fix) {
        Write-ScriptError 'Cannot specify both -Check and -Fix'
        exit 1
    }

    # Test for PSScriptAnalyzer
    if (-not (Test-PSScriptAnalyzer)) {
        Write-ScriptError 'PSScriptAnalyzer is required but not available'
        exit 1
    }

    # Test for markdownlint if markdown files are included
    if ($IncludeMarkdown -and -not (Test-MarkdownLint)) {
        Write-ScriptError 'markdownlint-cli2 is required for markdown processing but not available'
        exit 1
    }

    # Validate path
    if (-not (Test-Path $Path)) {
        Write-ScriptError "Path not found: $Path"
        exit 1
    }

    # Get PowerShell files
    Write-Info "Scanning for PowerShell files in: $Path"
    $files = Get-PowerShellFile -SearchPath $Path -Patterns $Include

    # Get Markdown files if requested
    $markdownFiles = @()
    if ($IncludeMarkdown) {
        Write-Info "Scanning for Markdown files in: $Path"
        $markdownFiles = Get-MarkdownFile -SearchPath $Path
        if ($markdownFiles.Count -gt 0) {
            Write-Info "Found $($markdownFiles.Count) Markdown files"
        }
    }

    if ($files.Count -eq 0 -and $markdownFiles.Count -eq 0) {
        Write-ScriptWarning 'No files found to process'
        exit 0
    }

    $totalFileCount = $files.Count + $markdownFiles.Count
    Write-Info "Found $($files.Count) PowerShell files and $($markdownFiles.Count) Markdown files (Total: $totalFileCount)"

    $totalIssues = 0
    $processedFiles = 0
    $modifiedFiles = 0

    foreach ($file in $files) {
        $relativePath = Resolve-Path -Path $file.FullName -Relative

        if ($Check) {
            Write-Host "`nChecking: $relativePath"
            $issues = Test-PowerShellFormatting -FilePath $file.FullName

            if ($issues.Count -gt 0) {
                $totalIssues += $issues.Count
                Write-ScriptWarning "Found $($issues.Count) issues:"

                foreach ($issue in $issues) {
                    $severity = switch ($issue.Severity) {
                        'Error' { 'Red' }
                        'Warning' { 'Yellow' }
                        'Information' { 'Gray' }
                        default { 'White' }
                    }

                    Write-Host "  Line $($issue.Line): $($issue.Message)" -ForegroundColor $severity
                    Write-Host "    Rule: $($issue.RuleName)" -ForegroundColor Gray
                }
            } else {
                Write-Success 'No issues found'
            }
        } elseif ($Fix) {
            Write-Host "`nFormatting: $relativePath"
            $wasModified = Invoke-PowerShellFormatting -FilePath $file.FullName

            if ($wasModified) {
                Write-Success 'Formatted'
                $modifiedFiles++
            } else {
                Write-Info 'No changes needed'
            }
        }

        $processedFiles++
    }

    # Process Markdown files
    foreach ($file in $markdownFiles) {
        $relativePath = Resolve-Path -Path $file.FullName -Relative

        if ($Check) {
            Write-Host "`nChecking: $relativePath"
            $issues = Test-MarkdownFormatting -FilePath $file.FullName

            if ($issues.Count -gt 0) {
                $totalIssues += $issues.Count
                Write-ScriptWarning "Found $($issues.Count) markdown issues:"

                foreach ($issue in $issues) {
                    Write-Host "  Line $($issue.Line): $($issue.Message)" -ForegroundColor Yellow
                    Write-Host "    Rule: $($issue.Rule)" -ForegroundColor Gray
                }
            } else {
                Write-Success 'No markdown issues found'
            }
        } elseif ($Fix) {
            Write-Host "`nFormatting: $relativePath"
            $wasModified = Invoke-MarkdownFormatting -FilePath $file.FullName

            if ($wasModified) {
                Write-Success 'Formatted'
                $modifiedFiles++
            } else {
                Write-Info 'No changes needed'
            }
        }

        $processedFiles++
    }

    # Summary
    Write-Host -Object ("`n" + ('=' * 50)) -ForegroundColor Cyan
    if ($Check) {
        Write-Host 'Formatting Check Complete' -ForegroundColor Cyan
        Write-Host "Files processed: $processedFiles" -ForegroundColor Gray
        Write-Host "Total issues: $totalIssues" -ForegroundColor Gray

        if ($totalIssues -gt 0) {
            Write-ScriptError 'Formatting issues found. Run with -Fix to resolve them.'
            exit 1
        } else {
            Write-Success 'All files are properly formatted!'
            exit 0
        }
    } elseif ($Fix) {
        Write-Host 'Formatting Complete' -ForegroundColor Cyan
        Write-Host "Files processed: $processedFiles" -ForegroundColor Gray
        Write-Host "Files modified: $modifiedFiles" -ForegroundColor Gray

        if ($modifiedFiles -gt 0) {
            Write-Success "Formatting applied to $modifiedFiles files"
        } else {
            Write-Info 'No files needed formatting'
        }
        exit 0
    }
}

# Run main function
Main