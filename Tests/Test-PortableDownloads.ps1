#Requires -Version 5.1

<#
.SYNOPSIS
Test portable download URLs and SHA256 hash validation

.DESCRIPTION
This script downloads all portable URLs defined in the Setup-PowerShellMagic.ps1 script
and validates their contents against their respective SHA256 hashes to ensure integrity.

.PARAMETER SkipDownloads
Skip actual downloads and only test the configuration structure

.EXAMPLE
.\Test-PortableDownloads.ps1
Download and validate all portable URLs

.EXAMPLE
.\Test-PortableDownloads.ps1 -SkipDownloads
Test configuration only without downloading

.EXAMPLE
.\Test-PortableDownloads.ps1 -SkipDownloads -Verbose
Test configuration with detailed output
#>

[CmdletBinding()]
param(
    [switch]$SkipDownloads
)

# Set non-interactive mode to prevent blocking on prompts
$ErrorActionPreference = 'Continue'
$ConfirmPreference = 'None'

# Test framework variables
$Script:TestResults = @{
    Passed = 0
    Failed = 0
    Skipped = 0
    Tests = @()
}

# Color output functions
function Write-TestSuccess { param($Message) Write-Host "[PASS] $Message" -ForegroundColor Green }
function Write-TestFailure { param($Message) Write-Host "[FAIL] $Message" -ForegroundColor Red }
function Write-TestInfo { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-TestWarning { param($Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-TestSkipped { param($Message) Write-Host "[SKIP] $Message" -ForegroundColor Gray }

function Assert-Equal {
    param($Expected, $Actual, $Message = 'Values should be equal')

    if ($Expected -eq $Actual) {
        Write-TestSuccess "$Message"
        $Script:TestResults.Passed++
        return $true
    } else {
        Write-TestFailure "$Message"
        Write-Host "  Expected: $Expected" -ForegroundColor Gray
        Write-Host "  Actual: $Actual" -ForegroundColor Gray
        $Script:TestResults.Failed++
        return $false
    }
}

function Assert-True {
    param($Condition, $Message = 'Condition should be true')
    return Assert-Equal -Expected $true -Actual $Condition -Message $Message
}

function Assert-NotNull {
    param($Value, $Message = 'Value should not be null')

    if ($null -ne $Value) {
        Write-TestSuccess "$Message"
        $Script:TestResults.Passed++
        return $true
    } else {
        Write-TestFailure "$Message"
        Write-Host '  Value was null' -ForegroundColor Gray
        $Script:TestResults.Failed++
        return $false
    }
}

function Test-FileHash {
    param(
        [string]$FilePath,
        [string]$ExpectedHash,
        [string]$Algorithm = 'SHA256'
    )

    if (-not (Test-Path $FilePath)) {
        Write-TestFailure "File not found: $FilePath"
        return $false
    }

    if ($ExpectedHash -like 'NOTE:*') {
        Write-TestWarning 'No checksum available for verification'
        Write-TestWarning "$ExpectedHash"
        return $false
    }

    try {
        $actualHash = $null

        # Try to use Get-FileHash if available (PowerShell 4.0+)
        try {
            $hashResult = Get-FileHash -Path $FilePath -Algorithm $Algorithm -ErrorAction Stop
            $actualHash = $hashResult.Hash
        } catch {
            # Fallback for older PowerShell versions using .NET
            Write-TestInfo 'Using .NET fallback for hash calculation (Get-FileHash not available)'
            $fileStream = [System.IO.File]::OpenRead($FilePath)
            try {
                if ($Algorithm -eq 'SHA256') {
                    $hasher = [System.Security.Cryptography.SHA256]::Create()
                } else {
                    throw "Algorithm $Algorithm not supported in fallback mode"
                }

                $hashBytes = $hasher.ComputeHash($fileStream)
                $actualHash = [System.BitConverter]::ToString($hashBytes).Replace('-', '')
                $hasher.Dispose()
            } finally {
                $fileStream.Close()
            }
        }

        $hashMatch = $actualHash.ToUpper() -eq $ExpectedHash.ToUpper()

        if ($hashMatch) {
            Write-TestSuccess "Hash verification passed for $(Split-Path $FilePath -Leaf)"
            Write-TestInfo "Expected: $ExpectedHash"
            Write-TestInfo "Actual:   $actualHash"
        } else {
            Write-TestFailure "Hash verification FAILED for $(Split-Path $FilePath -Leaf)"
            Write-TestFailure "Expected: $ExpectedHash"
            Write-TestFailure "Actual:   $actualHash"
        }

        return $hashMatch
    } catch {
        Write-TestFailure "Failed to calculate file hash: $($_.Exception.Message)"
        return $false
    }
}

function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath,
        [int]$TimeoutSeconds = 300
    )

    try {
        Write-TestInfo "Downloading from: $Url"
        Write-TestInfo "Saving to: $OutputPath"

        # Ensure output directory exists
        $outputDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        # Use Invoke-WebRequest for modern PowerShell versions
        if ($PSVersionTable.PSVersion.Major -ge 3) {
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -TimeoutSec $TimeoutSeconds
        } else {
            # Fallback for older PowerShell versions
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Url, $OutputPath)
            $webClient.Dispose()
        }

        if (Test-Path $OutputPath) {
            $fileSize = (Get-Item $OutputPath).Length
            Write-TestSuccess "Download completed - Size: $([math]::Round($fileSize / 1MB, 2)) MB"
            return $true
        } else {
            Write-TestFailure 'Download failed - File not found after download'
            return $false
        }

    } catch {
        Write-TestFailure "Download failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-DependencyConfiguration {
    Write-Host "`n=== Testing Dependency Configuration ===" -ForegroundColor Yellow

    $setupPath = Join-Path $PSScriptRoot '..\Setup-PowerShellMagic.ps1'

    if (-not (Test-Path $setupPath)) {
        Write-TestFailure "Setup script not found: $setupPath"
        return $false
    }

    try {
        # Load the setup script to get Dependencies variable
        . $setupPath -NonInteractive -ErrorAction Stop

        Assert-NotNull -Value $Dependencies -Message 'Dependencies variable is defined'
        Assert-True -Condition ($Dependencies.Count -gt 0) -Message 'Dependencies contains entries'

        $portableCount = 0
        foreach ($dep in $Dependencies.Keys) {
            $dependency = $Dependencies[$dep]

            Write-TestInfo "Checking dependency: $($dependency.Name)"

            # Check if dependency has portable URL
            if ($dependency.PortableUrl) {
                $portableCount++
                Assert-NotNull -Value $dependency.PortableUrl -Message "$($dependency.Name) has PortableUrl"
                Assert-NotNull -Value $dependency.PortableSHA256 -Message "$($dependency.Name) has PortableSHA256"

                # Validate URL format
                $urlPattern = '^https?://.+'
                $validUrl = $dependency.PortableUrl -match $urlPattern
                Assert-True -Condition $validUrl -Message "$($dependency.Name) PortableUrl is valid HTTP/HTTPS URL"

                # Validate hash format (SHA256 should be 64 hex characters)
                $hashPattern = '^[A-Fa-f0-9]{64}$'
                $validHash = $dependency.PortableSHA256 -match $hashPattern
                Assert-True -Condition $validHash -Message "$($dependency.Name) PortableSHA256 is valid 64-character hex string"

                if ($Verbose) {
                    Write-TestInfo "  URL: $($dependency.PortableUrl)"
                    Write-TestInfo "  SHA256: $($dependency.PortableSHA256)"
                }
            }
        }

        Write-TestInfo "Found $portableCount dependencies with portable URLs"
        return $true

    } catch {
        Write-TestFailure "Failed to load dependencies configuration: $($_.Exception.Message)"
        return $false
    }
}

function Test-PortableDownloads {
    Write-Host "`n=== Testing Portable Downloads and Hash Validation ===" -ForegroundColor Yellow

    if ($SkipDownloads) {
        Write-TestSkipped 'Skipping downloads as requested'
        return $true
    }

    $setupPath = Join-Path $PSScriptRoot '..\Setup-PowerShellMagic.ps1'

    if (-not (Test-Path $setupPath)) {
        Write-TestFailure "Setup script not found: $setupPath"
        return $false
    }

    try {
        # Load the setup script to get Dependencies variable
        . $setupPath -NonInteractive -ErrorAction Stop

        # Create temporary directory for downloads
        $tempDir = Join-Path $env:TEMP "PowerShellMagic-Tests-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Write-TestInfo "Using temporary directory: $tempDir"

        $allPassed = $true
        $downloadCount = 0

        foreach ($dep in $Dependencies.Keys) {
            $dependency = $Dependencies[$dep]

            if (-not $dependency.PortableUrl) {
                Write-TestSkipped "$($dependency.Name) - No portable URL defined"
                continue
            }

            $downloadCount++
            Write-Host "`n--- Testing $($dependency.Name) ---" -ForegroundColor Cyan

            # Determine file extension from URL
            $url = $dependency.PortableUrl
            $fileName = Split-Path $url -Leaf
            if (-not $fileName -or $fileName -eq '/') {
                # Try to extract filename from URL
                $urlParts = $url -split '/'
                $fileName = $urlParts[-1]
                if (-not $fileName) {
                    $fileName = "$($dependency.Name)-portable"
                }
            }

            $downloadPath = Join-Path $tempDir $fileName

            # Test download
            Write-TestInfo "Testing download for $($dependency.Name)..."
            $downloadSuccess = Download-File -Url $url -OutputPath $downloadPath

            if ($downloadSuccess) {
                Assert-True -Condition $downloadSuccess -Message "$($dependency.Name) download successful"

                # Test file exists and has content
                if (Test-Path $downloadPath) {
                    $fileSize = (Get-Item $downloadPath).Length
                    Assert-True -Condition ($fileSize -gt 0) -Message "$($dependency.Name) downloaded file has content ($fileSize bytes)"

                    # Test hash validation
                    Write-TestInfo "Validating SHA256 hash for $($dependency.Name)..."
                    $hashValid = Test-FileHash -FilePath $downloadPath -ExpectedHash $dependency.PortableSHA256
                    Assert-True -Condition $hashValid -Message "$($dependency.Name) SHA256 hash validation"

                    if (-not $hashValid) {
                        $allPassed = $false
                    }
                } else {
                    Assert-True -Condition $false -Message "$($dependency.Name) file exists after download"
                    $allPassed = $false
                }
            } else {
                Assert-True -Condition $false -Message "$($dependency.Name) download"
                $allPassed = $false
            }
        }

        # Cleanup
        try {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-TestInfo 'Cleaned up temporary directory'
        } catch {
            Write-TestWarning "Failed to cleanup temporary directory: $tempDir"
        }

        Write-TestInfo "Tested $downloadCount portable downloads"
        return $allPassed

    } catch {
        Write-TestFailure "Portable downloads test failed: $($_.Exception.Message)"
        return $false
    }
}

function Show-TestSummary {
    Write-Host "`n" + ('=' * 60) -ForegroundColor Cyan
    Write-Host 'PORTABLE DOWNLOADS TEST SUMMARY' -ForegroundColor Cyan
    Write-Host ('=' * 60) -ForegroundColor Cyan

    $total = $Script:TestResults.Passed + $Script:TestResults.Failed + $Script:TestResults.Skipped

    Write-Host "Total Tests: $total" -ForegroundColor White
    Write-TestSuccess "Passed: $($Script:TestResults.Passed)"

    if ($Script:TestResults.Failed -gt 0) {
        Write-TestFailure "Failed: $($Script:TestResults.Failed)"
    } else {
        Write-Host "Failed: $($Script:TestResults.Failed)" -ForegroundColor Green
    }

    if ($Script:TestResults.Skipped -gt 0) {
        Write-TestSkipped "Skipped: $($Script:TestResults.Skipped)"
    } else {
        Write-Host "Skipped: $($Script:TestResults.Skipped)" -ForegroundColor White
    }

    $successRate = if ($total -gt 0) { ($Script:TestResults.Passed / $total) * 100 } else { 0 }
    Write-Host "Success Rate: $([math]::Round($successRate, 1))%" -ForegroundColor $(if ($successRate -gt 90) { 'Green' } elseif ($successRate -gt 70) { 'Yellow' } else { 'Red' })

    # Return appropriate exit code
    if ($Script:TestResults.Failed -gt 0) {
        Write-Host "`nPortable downloads tests FAILED" -ForegroundColor Red
        return 1
    } else {
        Write-Host "`nAll portable downloads tests PASSED" -ForegroundColor Green
        return 0
    }
}

function Main {
    Write-Host 'PowerShell Magic - Portable Downloads Test Suite' -ForegroundColor Cyan
    Write-Host '================================================' -ForegroundColor Cyan

    if ($SkipDownloads) {
        Write-Host 'Configuration validation only (downloads skipped)' -ForegroundColor Gray
    } else {
        Write-Host 'Testing downloads and SHA256 hash validation' -ForegroundColor Gray
        Write-TestWarning 'This test will download files from the internet'
    }

    # Test dependency configuration
    $configValid = Test-DependencyConfiguration

    if ($configValid) {
        # Test actual downloads and hash validation
        Test-PortableDownloads
    } else {
        Write-TestFailure 'Configuration validation failed, skipping downloads'
    }

    return Show-TestSummary
}

# Store the original location
$originalLocation = Get-Location

try {
    # Change to script directory for relative paths
    Set-Location $PSScriptRoot

    # Run tests and get exit code
    $exitCode = Main

    # Exit with appropriate code
    exit $exitCode

} catch {
    Write-TestFailure ('Portable downloads test suite failed: ' + $_.Exception.Message)
    exit 1
} finally {
    # Restore original location
    Set-Location $originalLocation
}