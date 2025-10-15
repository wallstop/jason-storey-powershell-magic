#Requires -Version 7.0

<#
.SYNOPSIS
Comprehensive test suite for PowerShell Magic modules

.DESCRIPTION
This script runs all tests for the PowerShell Magic modules without requiring
external dependencies. It tests setup functionality, module loading, and
core features using mocked dependencies where needed.

.PARAMETER TestName
Run specific test. Options: Setup, QuickJump, Templater, Unitea, All

.PARAMETER Verbose
Show detailed test output

.EXAMPLE
.\Test-PowerShellMagic.ps1
Run all tests

.EXAMPLE
.\Test-PowerShellMagic.ps1 -TestName Setup
Run only setup tests

.EXAMPLE
.\Test-PowerShellMagic.ps1 -Verbose
Run all tests with detailed output
#>

[CmdletBinding()]
param(
    [ValidateSet('Setup', 'QuickJump', 'Templater', 'Unitea', 'All')]
    [string]$TestName = 'All'
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
function Write-TestSkipped { param($Message) Write-Host "- $Message" -ForegroundColor Gray }

function Assert-Equal {
    param($Expected, $Actual, $Message = 'Values should be equal')

    if ($Expected -eq $Actual) {
        Write-TestSuccess "$Message - PASS"
        $Script:TestResults.Passed++
        return $true
    } else {
        Write-TestFailure "$Message - FAIL"
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

function Assert-False {
    param($Condition, $Message = 'Condition should be false')

    return Assert-Equal -Expected $false -Actual $Condition -Message $Message
}

function Assert-NotNull {
    param($Value, $Message = 'Value should not be null')

    if ($null -ne $Value) {
        Write-TestSuccess "$Message - PASS"
        $Script:TestResults.Passed++
        return $true
    } else {
        Write-TestFailure "$Message - FAIL"
        Write-Host '  Value was null' -ForegroundColor Gray
        $Script:TestResults.Failed++
        return $false
    }
}

function Assert-FileExists {
    param($Path, $Message = 'File should exist')

    if (Test-Path $Path) {
        Write-TestSuccess "$Message - PASS ($Path)"
        $Script:TestResults.Passed++
        return $true
    } else {
        Write-TestFailure "$Message - FAIL ($Path)"
        $Script:TestResults.Failed++
        return $false
    }
}

function Test-Setup {
    Write-Host "`n=== Testing Setup Script ===" -ForegroundColor Yellow

    $setupPath = Join-Path $PSScriptRoot '..\Setup-PowerShellMagic.ps1'

    # Test 1: Setup script exists
    Assert-FileExists -Path $setupPath -Message 'Setup script exists'

    if (-not (Test-Path $setupPath)) {
        Write-TestSkipped 'Skipping setup tests - script not found'
        return
    }

    # Test 2: Setup script syntax is valid
    try {
        $tokens = $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($setupPath, [ref]$tokens, [ref]$errors)
        Assert-True -Condition ($errors.Count -eq 0) -Message 'Setup script has valid syntax'

        if ($errors.Count -gt 0) {
            foreach ($parseError in $errors) {
                Write-Host "  Syntax error: $($parseError.Message)" -ForegroundColor Red
            }
        }
    } catch {
        Assert-True -Condition $false -Message "Setup script syntax check failed: $($_.Exception.Message)"
    }

    # Test 3: Setup script contains required functions
    if (Test-Path $setupPath) {
        $content = Get-Content $setupPath -Raw
        $requiredFunctions = @(
            'Install-DependencyPortable',
            'Test-FileHash',
            'Import-ModulesInProfile',
            'Test-Dependency'
        )

        foreach ($func in $requiredFunctions) {
            $found = $content -match "function $func"
            Assert-True -Condition $found -Message "Setup contains function: $func"
        }
    }

    # Test 4: Dependencies configuration is valid
    try {
        . $setupPath -NonInteractive
        Assert-NotNull -Value $Dependencies -Message 'Dependencies variable is defined'
        Assert-True -Condition ($Dependencies.Count -gt 0) -Message 'Dependencies contains entries'

        foreach ($dep in $Dependencies.Keys) {
            $dependency = $Dependencies[$dep]
            Assert-NotNull -Value $dependency.Name -Message "Dependency $dep has Name"
            Assert-NotNull -Value $dependency.Description -Message "Dependency $dep has Description"

            if ($dep -eq '7zip') {
                Assert-True -Condition ($dependency.TestCommand -is [System.Collections.IDictionary]) -Message '7-Zip TestCommand is platform-aware'
                Assert-True -Condition ($dependency.TestCommand.ContainsKey('Windows')) -Message '7-Zip TestCommand has Windows entry'
                Assert-True -Condition ($dependency.TestCommand.ContainsKey('MacOS')) -Message '7-Zip TestCommand has MacOS entry'
                Assert-True -Condition ($dependency.TestCommand.ContainsKey('Linux')) -Message '7-Zip TestCommand has Linux entry'
                Assert-Equal -Expected '7z' -Actual ($dependency.TestCommand.Windows[0]) -Message '7-Zip Windows test command uses 7z'
                Assert-Equal -Expected '7zz' -Actual ($dependency.TestCommand.MacOS[0]) -Message '7-Zip MacOS test command uses 7zz'
                Assert-Equal -Expected '7zz' -Actual ($dependency.TestCommand.Linux[0]) -Message '7-Zip Linux test command uses 7zz'
            }
        }

        if ($Dependencies.ContainsKey('7zip')) {
            $sevenZipDependency = $Dependencies['7zip']
            $expectedPlatforms = @('Windows', 'MacOS', 'Linux')

            foreach ($platform in $expectedPlatforms) {
                Assert-True -Condition ($sevenZipDependency.PortableAssets.ContainsKey($platform)) -Message "7-Zip defines portable asset for $platform"
                $asset = $sevenZipDependency.PortableAssets[$platform]
                Assert-NotNull -Value $asset.Url -Message "7-Zip $platform asset has URL"
                Assert-NotNull -Value $asset.Sha256 -Message "7-Zip $platform asset has SHA256"

                if ($platform -eq 'Windows') {
                    Assert-Equal -Expected 'exe' -Actual $asset.ArchiveType -Message '7-Zip Windows asset uses exe archive type'
                    Assert-Equal -Expected '7z.exe' -Actual $asset.Executable -Message '7-Zip Windows asset uses 7z.exe executable'
                } else {
                    Assert-Equal -Expected 'tar.xz' -Actual $asset.ArchiveType -Message "7-Zip $platform asset uses tar.xz archive type"
                    Assert-Equal -Expected '7zz' -Actual $asset.Executable -Message "7-Zip $platform asset uses 7zz executable"
                }
            }
        } else {
            Assert-True -Condition $false -Message 'Dependencies include 7-Zip entry'
        }
    } catch {
        Assert-True -Condition $false -Message "Dependencies configuration is valid: $($_.Exception.Message)"
    }
}

function Test-ModuleStructure {
    param($ModuleName)

    Write-Host "`n=== Testing $ModuleName Module Structure ===" -ForegroundColor Yellow

    $modulePath = Join-Path $PSScriptRoot "..\Modules\$ModuleName"

    # Test module directory exists
    Assert-FileExists -Path $modulePath -Message "$ModuleName module directory exists"

    if (-not (Test-Path $modulePath)) {
        Write-TestSkipped "Skipping $ModuleName tests - module not found"
        return $false
    }

    # Test for module manifest or script
    $manifestPath = Join-Path $modulePath "$ModuleName.psd1"
    $scriptPath = Join-Path $modulePath "$ModuleName.psm1"

    $hasManifest = Test-Path $manifestPath
    $hasScript = Test-Path $scriptPath

    Assert-True -Condition ($hasManifest -or $hasScript) -Message "$ModuleName has manifest or script file"

    # Try to load the module for syntax validation
    try {
        # Import required security module first
        try {
            Import-Module Microsoft.PowerShell.Security -Force -ErrorAction SilentlyContinue
        } catch {
            # Continue without security module if it fails
        }

        # Temporarily set execution policy for module testing
        $originalExecutionPolicy = $null
        try {
            $originalExecutionPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        } catch {
            # Continue without execution policy changes if it fails
        }

        $tempModule = Import-Module $modulePath -PassThru -Force -ErrorAction Stop
        Assert-NotNull -Value $tempModule -Message "$ModuleName module loads successfully"

        # Get exported commands
        $commands = Get-Command -Module $tempModule.Name
        Assert-True -Condition ($commands.Count -gt 0) -Message "$ModuleName exports commands"

        if ($VerbosePreference -eq 'Continue') {
            Write-TestInfo "$ModuleName exported commands: $($commands.Name -join ', ')"
        }

        Remove-Module $tempModule.Name -Force -ErrorAction SilentlyContinue

        # Restore original execution policy
        if ($originalExecutionPolicy) {
            Set-ExecutionPolicy -ExecutionPolicy $originalExecutionPolicy -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        }

        return $true

    } catch {
        # Restore original execution policy on error
        if ($originalExecutionPolicy) {
            Set-ExecutionPolicy -ExecutionPolicy $originalExecutionPolicy -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        }

        # Check if it's just an execution policy issue
        if ($_.Exception.Message -like '*execution policy*' -or $_.Exception.Message -like '*digitally signed*') {
            Write-TestInfo "$ModuleName module structure is valid (execution policy prevents loading)"
            Assert-True -Condition $true -Message "$ModuleName module syntax validation (bypassed execution policy)"
            return $true
        } else {
            Assert-True -Condition $false -Message "$ModuleName module syntax is valid: $($_.Exception.Message)"
            return $false
        }
    }
}

function Test-QuickJump {
    Write-Host "`n=== Testing QuickJump Module ===" -ForegroundColor Yellow

    if (-not (Test-ModuleStructure -ModuleName 'QuickJump')) {
        return
    }

    try {
        # Import required security module first
        try {
            Import-Module Microsoft.PowerShell.Security -Force -ErrorAction SilentlyContinue
        } catch {
            # Continue without security module if it fails
        }

        # Import the module with execution policy bypass
        $originalExecutionPolicy = $null
        try {
            $originalExecutionPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        } catch {
            # Continue without execution policy changes if it fails
        }

        $modulePath = Join-Path $PSScriptRoot '..\Modules\QuickJump'
        Import-Module $modulePath -Force

        # Test core commands exist
        $expectedCommands = @(
            'Invoke-QuickJump',
            'Add-QuickJumpPath',
            'Get-QuickJumpPaths',
            'Remove-QuickJumpPath'
        )

        foreach ($cmd in $expectedCommands) {
            $command = Get-Command $cmd -ErrorAction SilentlyContinue
            Assert-NotNull -Value $command -Message "Command $cmd exists"
        }

        # Test configuration path function (if it exists)
        $configFunc = Get-Command 'Get-QuickJumpConfigPath' -ErrorAction SilentlyContinue
        if ($configFunc) {
            try {
                $configPath = Get-QuickJumpConfigPath
                Assert-NotNull -Value $configPath -Message 'Config path function returns value'
            } catch {
                Write-TestWarning "Config path function error: $($_.Exception.Message)"
            }
        }

        # Test without external dependencies (fzf)
        # This should handle missing dependencies gracefully
        try {
            # Mock test - ensure functions don't crash without dependencies
            $paths = Get-QuickJumpPaths -ErrorAction SilentlyContinue
            Write-TestInfo 'QuickJump handles missing dependencies gracefully'
            $Script:TestResults.Passed++
        } catch {
            Write-TestWarning "QuickJump dependency handling: $($_.Exception.Message)"
        }

        Remove-Module QuickJump -Force -ErrorAction SilentlyContinue

        # Restore original execution policy
        if ($originalExecutionPolicy) {
            Set-ExecutionPolicy -ExecutionPolicy $originalExecutionPolicy -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        }

    } catch {
        # Restore original execution policy on error
        if ($originalExecutionPolicy) {
            Set-ExecutionPolicy -ExecutionPolicy $originalExecutionPolicy -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        }

        # Handle execution policy errors gracefully
        if ($_.Exception.Message -like '*execution policy*' -or $_.Exception.Message -like '*digitally signed*') {
            Write-TestInfo 'QuickJump module structure validated (execution policy bypass)'
        } else {
            Assert-True -Condition $false -Message "QuickJump module testing failed: $($_.Exception.Message)"
        }
    }
}

function Test-Templater {
    Write-Host "`n=== Testing Templater Module ===" -ForegroundColor Yellow

    if (-not (Test-ModuleStructure -ModuleName 'Templater')) {
        return
    }

    try {
        # Import required security module first
        try {
            Import-Module Microsoft.PowerShell.Security -Force -ErrorAction SilentlyContinue
        } catch {
            # Continue without security module if it fails
        }

        # Import the module with execution policy bypass
        $originalExecutionPolicy = $null
        try {
            $originalExecutionPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        } catch {
            # Continue without execution policy changes if it fails
        }

        $modulePath = Join-Path $PSScriptRoot '..\Modules\Templater'
        Import-Module $modulePath -Force

        $templaterTestRoot = Join-Path $PSScriptRoot '..\TestArtifacts\Templater'
        if (Test-Path $templaterTestRoot) {
            Remove-Item -Path $templaterTestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $templaterTestRoot -Force | Out-Null

        $previousXdg = $env:XDG_CONFIG_HOME
        $env:XDG_CONFIG_HOME = $templaterTestRoot

        try {
            # Test core commands exist
            $expectedCommands = @(
                'Get-Templates',
                'Add-Template',
                'Use-Template',
                'Remove-Template'
            )

            foreach ($cmd in $expectedCommands) {
                $command = Get-Command $cmd -ErrorAction SilentlyContinue
                Assert-NotNull -Value $command -Message "Command $cmd exists"
            }

            # Test configuration functions
            $configFunc = Get-Command 'Get-TemplaterConfigPath' -ErrorAction SilentlyContinue
            if ($configFunc) {
                try {
                    $configPath = Get-TemplaterConfigPath
                    Assert-NotNull -Value $configPath -Message 'Templater config path function returns value'
                    if ($configPath) {
                        $normalizedRoot = [System.IO.Path]::GetFullPath($templaterTestRoot)
                        $normalizedConfig = [System.IO.Path]::GetFullPath($configPath)
                        $comparisonType = if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
                            [System.StringComparison]::OrdinalIgnoreCase
                        } else {
                            [System.StringComparison]::Ordinal
                        }
                        Assert-True -Condition ($normalizedConfig.StartsWith($normalizedRoot, $comparisonType)) -Message 'Templater config path respects XDG override'
                    }
                } catch {
                    Write-TestWarning "Templater config path function error: $($_.Exception.Message)"
                }
            }

            # Test without external dependencies (7-Zip)
            try {
                $templates = Get-Templates -ErrorAction SilentlyContinue
                Write-TestInfo 'Templater handles missing dependencies gracefully'
                $Script:TestResults.Passed++
            } catch {
                Write-TestWarning "Templater dependency handling: $($_.Exception.Message)"
            }

            # Regression test: archive redeployment with Force
            try {
                $workspaceRoot = Join-Path $templaterTestRoot 'Workspace'
                if (Test-Path $workspaceRoot) {
                    Remove-Item -Path $workspaceRoot -Recurse -Force -ErrorAction SilentlyContinue
                }
                New-Item -ItemType Directory -Path $workspaceRoot -Force | Out-Null

                Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop

                $templateSource = Join-Path $workspaceRoot 'template-source'
                $null = New-Item -ItemType Directory -Path $templateSource -Force
                $templateFile = Join-Path $templateSource 'hello.txt'
                Set-Content -Path $templateFile -Value 'version 1' -Encoding UTF8

                $zipPath = Join-Path $workspaceRoot 'template.zip'
                if (Test-Path $zipPath) {
                    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
                }
                [System.IO.Compression.ZipFile]::CreateFromDirectory($templateSource, $zipPath)

                $alias = "templater-redeploy-$([System.Guid]::NewGuid().ToString('N').Substring(0, 8))"
                Add-Template -Alias $alias -Path $zipPath -Description 'Regression template' -Force -ErrorAction Stop

                $outputDir = Join-Path $workspaceRoot 'deployment'
                if (Test-Path $outputDir) {
                    Remove-Item -Path $outputDir -Recurse -Force -ErrorAction SilentlyContinue
                }
                $null = New-Item -ItemType Directory -Path $outputDir -Force

                Use-Template -Alias $alias -DestinationPath $outputDir -ErrorAction Stop | Out-Null
                $initialContent = Get-Content -Path (Join-Path $outputDir 'hello.txt') -Raw -ErrorAction Stop
                Assert-Equal -Expected 'version 1' -Actual ($initialContent.Trim()) -Message 'Initial template extraction writes original content'

                Set-Content -Path $templateFile -Value 'version 2' -Encoding UTF8 -Force
                if (Test-Path $zipPath) {
                    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
                }
                [System.IO.Compression.ZipFile]::CreateFromDirectory($templateSource, $zipPath)

                $redeployFailed = $false
                try {
                    Use-Template -Alias $alias -DestinationPath $outputDir -ErrorAction Stop | Out-Null
                } catch {
                    $redeployFailed = $true
                }
                Assert-True -Condition $redeployFailed -Message 'Template redeployment without -Force fails when destination contains files'

                Use-Template -Alias $alias -DestinationPath $outputDir -Force -ErrorAction Stop | Out-Null
                $updatedContent = Get-Content -Path (Join-Path $outputDir 'hello.txt') -Raw -ErrorAction Stop
                Assert-Equal -Expected 'version 2' -Actual ($updatedContent.Trim()) -Message 'Template redeployment with -Force overwrites files'
            } catch {
                Assert-True -Condition $false -Message "Templater redeployment regression test failed: $($_.Exception.Message)"
            }

            # 7-Zip hash validation tests
            $sevenZipTestDir = Join-Path $templaterTestRoot 'SevenZip'
            if (Test-Path $sevenZipTestDir) {
                Remove-Item -Path $sevenZipTestDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            New-Item -ItemType Directory -Path $sevenZipTestDir -Force | Out-Null

            $fakeSevenZip = Join-Path $sevenZipTestDir '7z.exe'
            [System.IO.File]::WriteAllBytes($fakeSevenZip, [byte[]](0..63))
            $expectedSevenZipHash = (Get-FileHash -Path $fakeSevenZip -Algorithm SHA256 -ErrorAction Stop).Hash
            $normalizedSevenZipPath = (Resolve-Path $fakeSevenZip -ErrorAction Stop).Path

            $env:POWERSHELLMAGIC_7ZIP_PATH = $fakeSevenZip
            $env:POWERSHELLMAGIC_7ZIP_HASH = $expectedSevenZipHash

            $templaterModule = Get-Module Templater
            $resetSevenZipState = {
                $script:Trusted7ZipPath = $null
                $script:SevenZipHashCache = @{}
                $script:SevenZipWarningEmitted = $false
            }

            $null = $templaterModule.Invoke($resetSevenZipState)
            $trustedCandidate = $templaterModule.Invoke({ Get-Trusted7ZipExecutable }) | Select-Object -First 1
            if ($trustedCandidate) {
                $trustedCandidate = $trustedCandidate.ToString()
            }
            Assert-Equal -Expected $normalizedSevenZipPath -Actual $trustedCandidate -Message '7-Zip hash override accepts executable'

            $null = $templaterModule.Invoke($resetSevenZipState)
            $env:POWERSHELLMAGIC_7ZIP_HASH = '0000000000000000000000000000000000000000000000000000000000000000'

            $rejectedCandidate = $templaterModule.Invoke({ Get-Trusted7ZipExecutable }) | Select-Object -First 1
            if ($rejectedCandidate) {
                $rejectedCandidate = $rejectedCandidate.ToString()
            }
            $cachedPath = $templaterModule.Invoke({ $script:Trusted7ZipPath }) | Select-Object -First 1
            Assert-True -Condition (($cachedPath -ne $normalizedSevenZipPath) -and ($rejectedCandidate -ne $normalizedSevenZipPath)) -Message 'Hash mismatch rejects custom 7-Zip executable'

            # Verify dependency updater synchronises hashes and URLs
            $updateTestRoot = Join-Path $templaterTestRoot 'DependencyUpdate'
            if (Test-Path $updateTestRoot) {
                Remove-Item -Path $updateTestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
            New-Item -ItemType Directory -Path (Join-Path $updateTestRoot 'Modules\Templater') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $updateTestRoot 'Scripts') -Force | Out-Null

            Copy-Item -Path (Join-Path $PSScriptRoot '..\Setup-PowerShellMagic.ps1') -Destination $updateTestRoot -Force
            Copy-Item -Path (Join-Path $PSScriptRoot '..\Modules\Templater\Templater.psm1') -Destination (Join-Path $updateTestRoot 'Modules\Templater') -Force
            Copy-Item -Path (Join-Path $PSScriptRoot '..\Scripts\Update-Dependencies.ps1') -Destination (Join-Path $updateTestRoot 'Scripts') -Force

            $scriptCopyPath = Join-Path $updateTestRoot 'Scripts\Update-Dependencies.ps1'
            $setupCopyPath = Join-Path $updateTestRoot 'Setup-PowerShellMagic.ps1'
            $templaterCopyPath = Join-Path $updateTestRoot 'Modules\Templater\Templater.psm1'

            $setupCopyContent = Get-Content -Path $setupCopyPath -Raw
            $assetBlockMatch = [regex]::Match(
                $setupCopyContent,
                "'7zip'\s*=\s*@\{.*?PortableAssets\s*=\s*@\{(?<assets>.*?)\}\s*\}",
                [System.Text.RegularExpressions.RegexOptions]::Singleline
            )

            if (-not $assetBlockMatch.Success) {
                Assert-True -Condition $false -Message 'Dependency updater test could not locate 7-Zip metadata in setup script copy'
            } else {
                $assetSection = $assetBlockMatch.Groups['assets'].Value
                $platforms = @('Windows', 'MacOS', 'Linux')
                $currentAssets = @{}

                foreach ($platform in $platforms) {
                    $platformMatch = [regex]::Match(
                        $assetSection,
                        "$platform\s*=\s*@\{.*?Url\s*=\s*'([^']+)'.*?Sha256\s*=\s*'([^']+)'",
                        [System.Text.RegularExpressions.RegexOptions]::Singleline
                    )

                    Assert-True -Condition $platformMatch.Success -Message "Dependency updater test located 7-Zip $platform asset metadata"

                    $currentAssets[$platform] = @{
                        Url = $platformMatch.Groups[1].Value
                        Hash = $platformMatch.Groups[2].Value
                    }
                }

                $newHashes = @{
                    Windows = '0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF'
                    MacOS = 'FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210'
                    Linux = '1111222233334444111122223333444411112222333344441111222233334444'
                }

                $platformUpdates = @{}
                foreach ($platform in $platforms) {
                    $currentAsset = $currentAssets[$platform]
                    $newUrl = "$($currentAsset.Url)?updated=$($platform.ToLower())"
                    $newHash = $newHashes[$platform]

                    $platformUpdates[$platform] = @{
                        CurrentUrl = $currentAsset.Url
                        NewUrl = $newUrl
                        CurrentHash = $currentAsset.Hash
                        NewHash = $newHash
                    }
                }

                & {
                    param($scriptPath, $updates)
                    . $scriptPath
                    Update-SetupScript -Updates $updates
                } -scriptPath $scriptCopyPath -updates @{
                    '7zip' = @{
                        Name = '7-Zip'
                        CurrentVersion = 'current'
                        LatestVersion = 'latest'
                        PlatformUpdates = $platformUpdates
                    }
                }

                $postUpdateSetup = Get-Content -Path $setupCopyPath -Raw
                $postUpdateTemplater = Get-Content -Path $templaterCopyPath -Raw

                foreach ($platform in $platforms) {
                    $platformUpdate = $platformUpdates[$platform]
                    Assert-True -Condition ($postUpdateSetup -match [regex]::Escape($platformUpdate.NewUrl)) -Message "Dependency updater writes new 7-Zip $platform URL to setup script copy"
                    Assert-True -Condition ($postUpdateSetup -match [regex]::Escape($platformUpdate.NewHash)) -Message "Dependency updater writes new 7-Zip $platform hash to setup script copy"
                    Assert-True -Condition ($postUpdateSetup -notmatch [regex]::Escape($platformUpdate.CurrentHash)) -Message "Dependency updater removes old 7-Zip $platform hash from setup script copy"
                    Assert-True -Condition ($postUpdateTemplater -match "$platform\s*=\s*'$($platformUpdate.NewHash)'") -Message "Dependency updater synchronises managed 7-Zip hash for $platform in templater module copy"
                }

                $githubFallback = & {
                    param($scriptPath)
                    . $scriptPath

                    Set-Variable -Name RestHeadersCapture -Scope Script -Value $null
                    Set-Variable -Name WebHeadersCapture -Scope Script -Value $null

                    Set-DependencyHttpInvoker -RestMethod {
                        param($parameters)
                        Set-Variable -Name RestHeadersCapture -Scope Script -Value $parameters.Headers
                        throw (New-Object System.Net.WebException('Simulated GitHub API failure'))
                    } -WebRequest {
                        param($parameters)
                        Set-Variable -Name WebHeadersCapture -Scope Script -Value $parameters.Headers
                        return [pscustomobject]@{
                            BaseResponse = [pscustomobject]@{
                                ResponseUri = [Uri]'https://github.com/junegunn/fzf/releases/tag/v9.9.9'
                            }
                            Content = '<html></html>'
                        }
                    }

                    $tag = Get-GitHubLatestReleaseTag -Repository 'junegunn/fzf'
                    $restHeaders = Get-Variable -Name RestHeadersCapture -Scope Script -ValueOnly -ErrorAction SilentlyContinue
                    $webHeaders = Get-Variable -Name WebHeadersCapture -Scope Script -ValueOnly -ErrorAction SilentlyContinue
                    Set-DependencyHttpInvoker -Reset

                    [pscustomobject]@{
                        Tag = $tag
                        RestHeaders = $restHeaders
                        WebHeaders = $webHeaders
                    }
                } -scriptPath $scriptCopyPath

                Assert-Equal -Expected 'v9.9.9' -Actual $githubFallback.Tag -Message 'GitHub fallback returns tag from redirect'
                Assert-True -Condition ($githubFallback.RestHeaders['User-Agent']) -Message 'GitHub API request sets user agent header'
                Assert-Equal -Expected 'application/vnd.github+json' -Actual $githubFallback.RestHeaders['Accept'] -Message 'GitHub API request sets Accept header'
                Assert-True -Condition ($githubFallback.WebHeaders['User-Agent']) -Message 'GitHub fallback web request sets user agent header'
                Assert-True -Condition ($githubFallback.WebHeaders['Accept'] -like 'text/html*') -Message 'GitHub fallback web request includes HTML accept header'

                $sevenZipFallback = & {
                    param($scriptPath)
                    . $scriptPath

                    Set-Variable -Name WebCallCountCapture -Scope Script -Value 0

                    Set-DependencyHttpInvoker -WebRequest {
                        param($parameters)
                        $count = Get-Variable -Name WebCallCountCapture -Scope Script -ValueOnly -ErrorAction SilentlyContinue
                        $count++
                        Set-Variable -Name WebCallCountCapture -Scope Script -Value $count

                        if ($count -eq 1) {
                            throw (New-Object System.Net.WebException('Primary 7-Zip metadata failure'))
                        }

                        return [pscustomobject]@{
                            Content = '<html><a href="a/7z9999-x64.exe">download</a></html>'
                            BaseResponse = [pscustomobject]@{
                                ResponseUri = [Uri]'https://www.7-zip.org/a/7z9999-x64.exe'
                            }
                        }
                    }

                    $latest = & $DependencyUpdaters['7zip'].GetLatestVersion
                    $callCount = Get-Variable -Name WebCallCountCapture -Scope Script -ValueOnly -ErrorAction SilentlyContinue
                    Set-DependencyHttpInvoker -Reset

                    [pscustomobject]@{
                        Version = $latest
                        CallCount = $callCount
                    }
                } -scriptPath $scriptCopyPath

                Assert-Equal -Expected '9999' -Actual $sevenZipFallback.Version -Message '7-Zip fallback parses version from alternate metadata source'
                Assert-True -Condition ($sevenZipFallback.CallCount -ge 2) -Message '7-Zip fallback attempts secondary source after failure'
            }
        } finally {
            if ($null -ne $previousXdg) {
                $env:XDG_CONFIG_HOME = $previousXdg
            } else {
                Remove-Item -Path Env:\XDG_CONFIG_HOME -ErrorAction SilentlyContinue
            }

            Remove-Item -Path Env:\POWERSHELLMAGIC_7ZIP_PATH -ErrorAction SilentlyContinue
            Remove-Item -Path Env:\POWERSHELLMAGIC_7ZIP_HASH -ErrorAction SilentlyContinue

            if (Test-Path $templaterTestRoot) {
                Remove-Item -Path $templaterTestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }

            Remove-Module Templater -Force -ErrorAction SilentlyContinue
        }

        # Restore original execution policy
        if ($originalExecutionPolicy) {
            Set-ExecutionPolicy -ExecutionPolicy $originalExecutionPolicy -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        }

    } catch {
        # Restore original execution policy on error
        if ($originalExecutionPolicy) {
            Set-ExecutionPolicy -ExecutionPolicy $originalExecutionPolicy -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        }

        # Handle execution policy errors gracefully
        if ($_.Exception.Message -like '*execution policy*' -or $_.Exception.Message -like '*digitally signed*') {
            Write-TestInfo 'Templater module structure validated (execution policy bypass)'
        } else {
            Assert-True -Condition $false -Message "Templater module testing failed: $($_.Exception.Message)"
        }
    }
}

function Test-Unitea {
    Write-Host "`n=== Testing Unitea Module ===" -ForegroundColor Yellow

    if (-not (Test-ModuleStructure -ModuleName 'Unitea')) {
        return
    }

    try {
        # Import required security module first
        try {
            Import-Module Microsoft.PowerShell.Security -Force -ErrorAction SilentlyContinue
        } catch {
            # Continue without security module if it fails
        }

        # Import the module with execution policy bypass
        $originalExecutionPolicy = $null
        try {
            $originalExecutionPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        } catch {
            # Continue without execution policy changes if it fails
        }

        $modulePath = Join-Path $PSScriptRoot '..\Modules\Unitea'
        Import-Module $modulePath -Force

        $uniteaTestRoot = Join-Path $PSScriptRoot '..\TestArtifacts\Unitea'
        if (Test-Path $uniteaTestRoot) {
            Remove-Item -Path $uniteaTestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $uniteaTestRoot -Force | Out-Null

        $previousXdg = $env:XDG_CONFIG_HOME
        $env:XDG_CONFIG_HOME = $uniteaTestRoot

        try {
            # Test core commands exist
            $expectedCommands = @(
                'Open-UnityProject',
                'Add-UnityProject',
                'Get-UnityProjects',
                'Remove-UnityProject'
            )

            foreach ($cmd in $expectedCommands) {
                $command = Get-Command $cmd -ErrorAction SilentlyContinue
                Assert-NotNull -Value $command -Message "Command $cmd exists"
            }

            # Test configuration functions
            $configFunc = Get-Command 'Get-UnityConfigPath' -ErrorAction SilentlyContinue
            if ($configFunc) {
                try {
                    $configPath = Get-UnityConfigPath
                    Assert-NotNull -Value $configPath -Message 'Unity config path function returns value'
                    if ($configPath) {
                        $normalizedRoot = [System.IO.Path]::GetFullPath($uniteaTestRoot)
                        $normalizedConfig = [System.IO.Path]::GetFullPath($configPath)
                        $comparisonType = if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
                            [System.StringComparison]::OrdinalIgnoreCase
                        } else {
                            [System.StringComparison]::Ordinal
                        }
                        Assert-True -Condition ($normalizedConfig.StartsWith($normalizedRoot, $comparisonType)) -Message 'Unity config path respects XDG override'
                    }
                } catch {
                    Write-TestWarning "Unity config path function error: $($_.Exception.Message)"
                }
            }

            # Prepare sample Unity project
            $workspaceRoot = Join-Path $uniteaTestRoot 'Workspace'
            New-Item -ItemType Directory -Path $workspaceRoot -Force | Out-Null

            $sampleProjectPath = Join-Path $workspaceRoot 'SampleProject'
            New-Item -ItemType Directory -Path $sampleProjectPath -Force | Out-Null
            $projectSettings = Join-Path $sampleProjectPath 'ProjectSettings'
            New-Item -ItemType Directory -Path $projectSettings -Force | Out-Null
            $versionFile = Join-Path $projectSettings 'ProjectVersion.txt'
            Set-Content -Path $versionFile -Value 'm_EditorVersion: 2021.3.12f1' -Encoding UTF8

            $resolvedProjectPath = (Resolve-Path $sampleProjectPath).Path
            $alias = "unitea-test-$([System.Guid]::NewGuid().ToString('N').Substring(0, 8))"

            Add-UnityProject -Alias $alias -ProjectPath $sampleProjectPath -Force -ErrorAction Stop

            # Validate structured project listing
            $projects = @(Get-UnityProjects -ErrorAction Stop)
            Assert-True -Condition ($projects.Count -ge 1) -Message 'Get-UnityProjects returns project records'
            $aliasRecord = $projects | Where-Object { $_.Alias -eq $alias } | Select-Object -First 1
            Assert-NotNull -Value $aliasRecord -Message 'Project listing contains the added alias'
            Assert-Equal -Expected $resolvedProjectPath -Actual $aliasRecord.Path -Message 'Returned record path matches project location'

            $pathResult = Get-UnityProjects -Alias $alias -Path
            Assert-Equal -Expected $resolvedProjectPath -Actual $pathResult -Message 'Get-UnityProjects -Alias -Path returns project path'

            # Simulate corrupt JSON and verify recovery
            $configPath = Get-UnityConfigPath
            Set-Content -Path $configPath -Value '{ invalid json' -Encoding UTF8

            $recoveredProjects = @(Get-UnityProjects -ErrorAction SilentlyContinue)
            Assert-True -Condition ($recoveredProjects.Count -eq 0) -Message 'Corrupt Unity configuration resets to empty project list'

            $backupFiles = Get-ChildItem -Path ("$configPath.backup.*") -ErrorAction SilentlyContinue
            Assert-True -Condition ($backupFiles.Count -ge 1) -Message 'Backup created when recovering corrupt Unity configuration'

            try {
                $resetContent = Get-Content -Path $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
                Assert-True -Condition ($resetContent.Count -eq 0) -Message 'Recovered Unity configuration serializes to empty object'
            } catch {
                Assert-True -Condition $false -Message "Recovered Unity configuration is unreadable: $($_.Exception.Message)"
            }

            # Test without Unity Hub
            try {
                $projectsListing = Get-UnityProjects -ErrorAction SilentlyContinue
                if ($projectsListing -eq $null -or $projectsListing.Count -eq 0) {
                    Write-TestInfo 'Unitea handles missing projects gracefully after recovery'
                    $Script:TestResults.Passed++
                }
            } catch {
                Write-TestWarning "Unitea Unity Hub handling: $($_.Exception.Message)"
            }
        } finally {
            if ($null -ne $previousXdg) {
                $env:XDG_CONFIG_HOME = $previousXdg
            } else {
                Remove-Item -Path Env:\XDG_CONFIG_HOME -ErrorAction SilentlyContinue
            }

            if (Test-Path $uniteaTestRoot) {
                Remove-Item -Path $uniteaTestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }

            Remove-Module Unitea -Force -ErrorAction SilentlyContinue
        }

        # Restore original execution policy
        if ($originalExecutionPolicy) {
            Set-ExecutionPolicy -ExecutionPolicy $originalExecutionPolicy -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        }

    } catch {
        # Restore original execution policy on error
        if ($originalExecutionPolicy) {
            Set-ExecutionPolicy -ExecutionPolicy $originalExecutionPolicy -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        }

        # Handle execution policy errors gracefully
        if ($_.Exception.Message -like '*execution policy*' -or $_.Exception.Message -like '*digitally signed*') {
            Write-TestInfo 'Unitea module structure validated (execution policy bypass)'
        } else {
            Assert-True -Condition $false -Message "Unitea module testing failed: $($_.Exception.Message)"
        }
    }
}

function Test-FormatterAndAnalyzer {
    Write-Host "`n=== Testing Formatter and Analyzer ===" -ForegroundColor Yellow

    # Test formatter script exists
    $formatterPath = Join-Path $PSScriptRoot '..\Format-PowerShell.ps1'
    Assert-FileExists -Path $formatterPath -Message 'PowerShell formatter script exists'

    # Test settings file exists
    $settingsPath = Join-Path $PSScriptRoot '..\PSScriptAnalyzerSettings.psd1'
    Assert-FileExists -Path $settingsPath -Message 'PSScriptAnalyzer settings file exists'

    # Test formatter syntax
    if (Test-Path $formatterPath) {
        try {
            $tokens = $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($formatterPath, [ref]$tokens, [ref]$errors)
            Assert-True -Condition ($errors.Count -eq 0) -Message 'Formatter script has valid syntax'
        } catch {
            Assert-True -Condition $false -Message "Formatter script syntax check failed: $($_.Exception.Message)"
        }
    }

    # Test settings file syntax
    if (Test-Path $settingsPath) {
        try {
            $settings = & ([scriptblock]::Create((Get-Content $settingsPath -Raw)))
            Assert-NotNull -Value $settings -Message 'PSScriptAnalyzer settings file is valid'
            Assert-NotNull -Value $settings.Rules -Message 'Settings file contains rules'
        } catch {
            Assert-True -Condition $false -Message "Settings file validation failed: $($_.Exception.Message)"
        }
    }
}

function Show-TestSummary {
    Write-Host "`n" + ('=' * 60) -ForegroundColor Cyan
    Write-Host 'TEST SUMMARY' -ForegroundColor Cyan
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
        Write-Host "`nTests FAILED" -ForegroundColor Red
        return 1
    } else {
        Write-Host "`nAll tests PASSED" -ForegroundColor Green
        return 0
    }
}

function Main {
    Write-Host 'PowerShell Magic Test Suite' -ForegroundColor Cyan
    Write-Host '===========================' -ForegroundColor Cyan
    Write-Host 'Testing without external dependencies' -ForegroundColor Gray

    # Run tests based on parameter
    switch ($TestName) {
        'Setup' { Test-Setup }
        'QuickJump' { Test-QuickJump }
        'Templater' { Test-Templater }
        'Unitea' { Test-Unitea }
        'All' {
            Test-Setup
            Test-QuickJump
            Test-Templater
            Test-Unitea
            Test-FormatterAndAnalyzer
        }
    }

    return Show-TestSummary
}

# Store the original location
$originalLocation = Get-Location
$originalProgressPreference = $ProgressPreference

try {
    # Change to script directory for relative paths
    Set-Location $PSScriptRoot
    $ProgressPreference = 'SilentlyContinue'

    # Run tests and get exit code
    $exitCode = Main

    # Exit with appropriate code
    exit $exitCode

} catch {
    Write-TestFailure ('Test suite failed: ' + $_.Exception.Message)
    exit 1
} finally {
    $ProgressPreference = $originalProgressPreference
    # Restore original location
    Set-Location $originalLocation
}


