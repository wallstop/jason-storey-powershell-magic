#Requires -Version 7.0

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

$script:IsWindowsPlatform = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
$script:IsMacOSPlatform = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)
$script:IsLinuxPlatform = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)
$script:CurrentPlatformKey = if ($script:IsWindowsPlatform) { 'Windows' } elseif ($script:IsMacOSPlatform) { 'MacOS' } else { 'Linux' }

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

function Get-TemplaterManagedSevenZipHashes {
    $modulePath = Join-Path $PSScriptRoot '..\Modules\Templater\Templater.psm1'

    if (-not (Test-Path $modulePath)) {
        Write-TestFailure "Templater module not found: $modulePath"
        return @{}
    }

    try {
        $content = Get-Content -Path $modulePath -Raw
        $regex = [System.Text.RegularExpressions.Regex]::Match(
            $content,
            '\$script:ManagedSevenZipHashes\s*=\s*@\{(?<body>.*?)\}',
            [System.Text.RegularExpressions.RegexOptions]::Singleline
        )

        if (-not $regex.Success) {
            Write-TestFailure 'Failed to locate ManagedSevenZipHashes in Templater module'
            return @{}
        }

        $hashes = @{}
        foreach ($line in ($regex.Groups['body'].Value -split "`n")) {
            if ($line -match "^\s*(\w+)\s*=\s*'([A-Fa-f0-9]{64})'") {
                $hashes[$matches[1]] = $matches[2].ToUpper()
            }
        }

        return $hashes
    } catch {
        Write-TestFailure "Failed to parse Templater managed hashes: $($_.Exception.Message)"
        return @{}
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

            $asset = $null
            if ($dependency.PortableAssets -and $dependency.PortableAssets.ContainsKey($script:CurrentPlatformKey)) {
                $asset = $dependency.PortableAssets[$script:CurrentPlatformKey]
            }

            if ($asset) {
                $portableCount++
                Assert-NotNull -Value $asset.Url -Message "$($dependency.Name) has portable URL for $script:CurrentPlatformKey"
                Assert-NotNull -Value $asset.Sha256 -Message "$($dependency.Name) has portable SHA256 for $script:CurrentPlatformKey"

                # Validate URL format
                $urlPattern = '^https?://.+'
                $validUrl = $asset.Url -match $urlPattern
                Assert-True -Condition $validUrl -Message "$($dependency.Name) portable URL is valid HTTP/HTTPS URL"

                # Validate hash format (SHA256 should be 64 hex characters)
                $hashPattern = '^[A-Fa-f0-9]{64}$'
                $validHash = $asset.Sha256 -match $hashPattern
                Assert-True -Condition $validHash -Message "$($dependency.Name) portable SHA256 is valid 64-character hex string"

                if ($Verbose) {
                    Write-TestInfo "  URL: $($asset.Url)"
                    Write-TestInfo "  SHA256: $($asset.Sha256)"
                }

                if ($dependency.Name -eq '7-Zip') {
                    $expectedPlatforms = @('Windows', 'MacOS', 'Linux')
                    foreach ($platform in $expectedPlatforms) {
                        Assert-True -Condition ($dependency.PortableAssets.ContainsKey($platform)) -Message "7-Zip defines portable asset for $platform"
                        $platformAsset = $dependency.PortableAssets[$platform]
                        Assert-NotNull -Value $platformAsset.Url -Message "7-Zip $platform asset has URL"
                        Assert-NotNull -Value $platformAsset.Sha256 -Message "7-Zip $platform asset has SHA256"

                        if ($platform -eq 'Windows') {
                            Assert-Equal -Expected 'exe' -Actual $platformAsset.ArchiveType -Message '7-Zip Windows asset uses exe archive type'
                            Assert-Equal -Expected '7z.exe' -Actual $platformAsset.Executable -Message '7-Zip Windows asset uses 7z.exe executable'
                        } else {
                            Assert-Equal -Expected 'tar.xz' -Actual $platformAsset.ArchiveType -Message "7-Zip $platform asset uses tar.xz archive type"
                            Assert-Equal -Expected '7zz' -Actual $platformAsset.Executable -Message "7-Zip $platform asset uses 7zz executable"
                        }
                    }
                }
            } else {
                Write-TestSkipped "$($dependency.Name) - No portable asset defined for $script:CurrentPlatformKey"
            }
        }

        Write-TestInfo "Found $portableCount dependencies with portable assets for $script:CurrentPlatformKey"

        if ($Dependencies.ContainsKey('7zip')) {
            $templaterHashes = Get-TemplaterManagedSevenZipHashes

            if ($templaterHashes.Count -gt 0) {
                Write-TestInfo 'Validating Templater managed 7-Zip hashes align with setup script'
                foreach ($platform in $templaterHashes.Keys) {
                    Assert-True -Condition ($Dependencies['7zip'].PortableAssets.ContainsKey($platform)) `
                        -Message "Setup defines 7-Zip portable asset for $platform"

                    if ($Dependencies['7zip'].PortableAssets.ContainsKey($platform)) {
                        $assetHash = $Dependencies['7zip'].PortableAssets[$platform].Sha256
                        Assert-Equal -Expected $assetHash.ToUpper() -Actual $templaterHashes[$platform] `
                            -Message "7-Zip $platform hash matches Templater managed hash"
                    }
                }
            } else {
                Write-TestWarning 'Skipped Templater managed hash validation (no hashes found)'
            }
        } else {
            Write-TestWarning 'Skipped Templater managed hash validation (7-Zip dependency missing)'
        }

        return $true

    } catch {
        Write-TestFailure "Failed to load dependencies configuration: $($_.Exception.Message)"
        return $false
    }
}

function Test-PortableManifestExport {
    Write-Host "`n=== Testing Portable Manifest Export ===" -ForegroundColor Yellow

    $setupPath = Join-Path $PSScriptRoot '..\Setup-PowerShellMagic.ps1'

    if (-not (Test-Path $setupPath)) {
        Write-TestFailure "Setup script not found: $setupPath"
        return $false
    }

    try {
        $output = & $setupPath -ListPortableDownloads

        $outputText = ($output | Out-String)
        Assert-True -Condition ($outputText -match '7-Zip') `
            -Message 'Manifest includes 7-Zip entry'
        Assert-True -Condition ($outputText -match 'SHA256') `
            -Message 'Manifest prints SHA256 values'

        return $true
    } catch {
        Write-TestFailure "Portable manifest export failed: $($_.Exception.Message)"
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

            if (-not $dependency.PortableAssets -or -not $dependency.PortableAssets.ContainsKey($script:CurrentPlatformKey)) {
                Write-TestSkipped "$($dependency.Name) - No portable asset defined for $script:CurrentPlatformKey"
                continue
            }

            $asset = $dependency.PortableAssets[$script:CurrentPlatformKey]
            if (-not $asset.Url) {
                Write-TestSkipped "$($dependency.Name) - Portable asset missing URL for $script:CurrentPlatformKey"
                continue
            }

            $downloadCount++
            Write-Host "`n--- Testing $($dependency.Name) ---" -ForegroundColor Cyan

            # Determine file extension from URL
            $url = $asset.Url
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
                    if ($asset.Sha256) {
                        Write-TestInfo "Validating SHA256 hash for $($dependency.Name)..."
                        $hashValid = Test-FileHash -FilePath $downloadPath -ExpectedHash $asset.Sha256
                        Assert-True -Condition $hashValid -Message "$($dependency.Name) SHA256 hash validation"

                        if (-not $hashValid) {
                            $allPassed = $false
                        }
                    } else {
                        Write-TestWarning "$($dependency.Name) portable asset for $script:CurrentPlatformKey lacks SHA256 hash; skipping hash validation"
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
        # Ensure manifest export stays in sync with setup metadata
        $null = Test-PortableManifestExport

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




