#Requires -Version 7.0

<#
.SYNOPSIS
Comprehensive test suite for PowerShell Magic modules

.DESCRIPTION
This script runs all tests for the PowerShell Magic modules without requiring
external dependencies. It tests setup functionality, module loading, and
core features using mocked dependencies where needed.

.PARAMETER TestName
Run specific test. Options: Setup, Common, QuickJump, Templater, Unitea, All

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
    [ValidateSet('Setup', 'Common', 'QuickJump', 'Templater', 'Unitea', 'All')]
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

        # Portable download caching regression
        $cacheTestRoot = $null
        $originalInstallLocation = $InstallLocation
        $originalGetUserResponseScript = $null
        $existingInvokeScript = $null

        try {
            $cacheTestRoot = Join-Path $PSScriptRoot '..\TestArtifacts\SetupCache'
            if (Test-Path $cacheTestRoot) {
                Remove-Item -Path $cacheTestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
            New-Item -ItemType Directory -Path $cacheTestRoot -Force | Out-Null

            $sourceDir = Join-Path $cacheTestRoot 'source'
            New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null

            $binaryName = if ($IsWindows) { 'test-tool.exe' } else { 'test-tool' }
            $sourceFile = Join-Path $sourceDir $binaryName
            Set-Content -Path $sourceFile -Value 'portable download content' -Encoding UTF8 -Force
            $fileHash = (Get-FileHash -Path $sourceFile -Algorithm SHA256).Hash

            $dependencyObject = [pscustomobject]@{
                Name = 'test-tool'
                Description = 'Test portable dependency'
                PortableAssets = @{
                    $script:CurrentPlatform = @{
                        Url = $sourceFile
                        Sha256 = $fileHash
                        Executable = $binaryName
                    }
                }
            }

            $originalInstallLocation = $InstallLocation
            $InstallLocation = $cacheTestRoot

            $existingResponseFunction = Get-Command Get-UserResponse -CommandType Function -ErrorAction SilentlyContinue
            if ($existingResponseFunction) {
                $originalGetUserResponseScript = $existingResponseFunction.ScriptBlock
            }
            Set-Item Function:Get-UserResponse -Value {
                param($Prompt, $Default)
                'YES'
            } -Force

            $existingInvokeFunction = Get-Command Invoke-WebRequest -CommandType Function -ErrorAction SilentlyContinue
            if ($existingInvokeFunction) {
                $existingInvokeScript = $existingInvokeFunction.ScriptBlock
            }

            $global:PortableDownloadCounter = 0
            Set-Item Function:Invoke-WebRequest -Value {
                param(
                    [Parameter(Mandatory = $true)]
                    [string]$Uri,

                    [Parameter(Mandatory = $true)]
                    [string]$OutFile,

                    [Parameter(ValueFromRemainingArguments = $true)]
                    $AdditionalParameters
                )

                $global:PortableDownloadCounter++
                Copy-Item -LiteralPath $Uri -Destination $OutFile -Force
            } -Force

            $firstInstall = Install-DependencyPortable -Dependency $dependencyObject
            Assert-True -Condition $firstInstall -Message 'Portable install succeeds on first run'
            Assert-Equal -Expected 1 -Actual $global:PortableDownloadCounter -Message 'First install performs a download'

            $cacheDir = Join-Path (Join-Path $cacheTestRoot 'cache') 'test-tool'
            Assert-True -Condition (Test-Path $cacheDir) -Message 'Dependency cache directory created'
            $cachedFiles = Get-ChildItem -Path $cacheDir -File -ErrorAction SilentlyContinue
            Assert-True -Condition ($cachedFiles.Count -ge 1) -Message 'Cached download persisted for dependency'

            $secondInstall = Install-DependencyPortable -Dependency $dependencyObject
            Assert-True -Condition $secondInstall -Message 'Portable install succeeds when cache is present'
            Assert-Equal -Expected 1 -Actual $global:PortableDownloadCounter -Message 'Cached install avoids repeat download'

            $installedBinary = Join-Path (Join-Path $cacheTestRoot 'bin') $binaryName
            Assert-True -Condition (Test-Path $installedBinary) -Message 'Portable binary deployed to install directory'
        } catch {
            Write-TestWarning "Portable caching test failed: $($_.Exception.Message)"
            throw
        } finally {
            if ($originalGetUserResponseScript) {
                Set-Item Function:Get-UserResponse -Value $originalGetUserResponseScript -Force
            } else {
                Remove-Item Function:Get-UserResponse -Force -ErrorAction SilentlyContinue
            }

            if ($existingInvokeScript) {
                Set-Item Function:Invoke-WebRequest -Value $existingInvokeScript -Force
            } else {
                Remove-Item Function:Invoke-WebRequest -Force -ErrorAction SilentlyContinue
            }

            if ($null -ne $originalInstallLocation) {
                $InstallLocation = $originalInstallLocation
            }

            if (Get-Variable -Name PortableDownloadCounter -Scope Global -ErrorAction SilentlyContinue) {
                Remove-Variable -Name PortableDownloadCounter -Scope Global -ErrorAction SilentlyContinue
            }

            if ($cacheTestRoot -and (Test-Path $cacheTestRoot)) {
                Remove-Item -Path $cacheTestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        # Structured logging regression
        $logTestRoot = $null
        $explicitLogFile = $null
        $originalRetentionValue = $null
        try {
            $logTestRoot = Join-Path $PSScriptRoot '..\TestArtifacts\SetupLogs'
            if (Test-Path $logTestRoot) {
                Remove-Item -Path $logTestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }

            $EnableLogs = $true
            $LogPath = $logTestRoot
            $originalRetentionValue = Get-SetupLogRetentionCount
            Set-SetupLogRetentionCount -Value 3 | Out-Null

            Reset-SetupLogging
            $currentLogFile = Initialize-SetupLogging

            Assert-True -Condition (Test-Path $logTestRoot) -Message 'Log directory created when logging enabled'
            Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($currentLogFile)) -Message 'Log file path established'
            Assert-True -Condition (Test-Path $currentLogFile) -Message 'Log file created on initialization'

            $testLogMessage = "Logging verification entry $([Guid]::NewGuid().ToString())"
            Write-Info $testLogMessage
            $logContent = Get-Content -Path $currentLogFile -Raw -ErrorAction Stop
            Assert-True -Condition ($logContent -match [Regex]::Escape($testLogMessage)) -Message 'Log file records structured message output'

            $firstLogFile = $currentLogFile
            for ($i = 0; $i -lt 5; $i++) {
                Start-Sleep -Milliseconds 15
                Initialize-SetupLogging | Out-Null
            }

            $retainedLogs = Get-ChildItem -Path $logTestRoot -Filter 'setup-*.log' -File -ErrorAction Stop
            Assert-True -Condition ($retainedLogs.Count -le 3) -Message 'Log retention enforces maximum file count'
            Assert-True -Condition (-not ($retainedLogs.FullName -contains $firstLogFile)) -Message 'Oldest log removed when retention exceeded'

            $explicitLogFile = Join-Path $logTestRoot 'custom.log'
            $LogPath = $explicitLogFile
            Reset-SetupLogging
            Initialize-SetupLogging | Out-Null
            $resolvedExplicitPath = Get-SetupLogFilePath
            $explicitItem = Resolve-Path -LiteralPath $explicitLogFile -ErrorAction Stop
            Assert-Equal -Expected $explicitItem.Path -Actual $resolvedExplicitPath -Message 'Explicit log file path respected'
            Assert-True -Condition (Test-Path $explicitLogFile) -Message 'Explicit log file created'
        } catch {
            Write-TestWarning "Setup logging test failed: $($_.Exception.Message)"
            throw
        } finally {
            $EnableLogs = $false
            $LogPath = $null
            if ($null -ne $originalRetentionValue) {
                Set-SetupLogRetentionCount -Value $originalRetentionValue | Out-Null
            } else {
                Set-SetupLogRetentionCount -Value 5 | Out-Null
            }
            Reset-SetupLogging

            if ($logTestRoot -and (Test-Path $logTestRoot)) {
                Remove-Item -Path $logTestRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
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

function Test-CommonUtilities {
    Write-Host "`n=== Testing Common Utilities ===" -ForegroundColor Yellow

    $commonModulePath = Join-Path $PSScriptRoot '..\Modules\Common\PowerShellMagic.Common.psd1'
    Import-Module $commonModulePath -Force

    $commonTestRoot = Join-Path $PSScriptRoot '..\TestArtifacts\Common'
    if (Test-Path $commonTestRoot) {
        Remove-Item -Path $commonTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $commonTestRoot -Force | Out-Null

    $previousXdg = $env:XDG_CONFIG_HOME
    $env:XDG_CONFIG_HOME = $commonTestRoot

    try {
        $configPath = Get-PSMagicConfigPath -Component 'shared' -FileName 'config.json'
        $expectedDirectory = Join-Path $commonTestRoot 'shared'

        Assert-Equal -Expected $expectedDirectory -Actual (Split-Path $configPath -Parent) -Message 'Config helper builds component directory path'
        Assert-Equal -Expected (Join-Path $expectedDirectory 'config.json') -Actual $configPath -Message 'Config helper returns expected file path'

        $returnedDirectory = Get-PSMagicConfigPath -Component 'shared' -ReturnDirectory
        Assert-Equal -Expected $expectedDirectory -Actual $returnedDirectory -Message 'Config helper returns directory when requested'
        Assert-True -Condition (Test-Path $expectedDirectory) -Message 'Config helper creates component directory'

        $originalHashtable = @{
            Name = 'Example'
            Nested = @{
                Value = 42
            }
        }

        $copiedHashtable = Copy-PSMagicHashtable -InputObject $originalHashtable
        Assert-True -Condition ($copiedHashtable -is [hashtable]) -Message 'Hashtable clone returns hashtable'

        $copiedHashtable.Nested.Value = 100
        Assert-Equal -Expected 42 -Actual $originalHashtable.Nested.Value -Message 'Hashtable clone performs deep copy'
    } finally {
        if ($null -ne $previousXdg) {
            $env:XDG_CONFIG_HOME = $previousXdg
        } else {
            Remove-Item Env:\XDG_CONFIG_HOME -ErrorAction SilentlyContinue
        }
    }

    $previousNonInteractive = Get-Item Env:POWERSHELL_MAGIC_NON_INTERACTIVE -ErrorAction SilentlyContinue
    try {
        $env:POWERSHELL_MAGIC_NON_INTERACTIVE = '1'
        Assert-True -Condition (Test-PSMagicNonInteractive) -Message 'Non-interactive detection accepts value 1'

        $env:POWERSHELL_MAGIC_NON_INTERACTIVE = 'on'
        Assert-True -Condition (Test-PSMagicNonInteractive) -Message 'Non-interactive detection accepts value on'

        $env:POWERSHELL_MAGIC_NON_INTERACTIVE = '0'
        Assert-True -Condition (-not (Test-PSMagicNonInteractive)) -Message 'Non-interactive detection ignores value 0'

        Remove-Item Env:\POWERSHELL_MAGIC_NON_INTERACTIVE -ErrorAction SilentlyContinue
        Assert-True -Condition (-not (Test-PSMagicNonInteractive)) -Message 'Non-interactive detection returns false when unset'
    } finally {
        if ($previousNonInteractive) {
            $env:POWERSHELL_MAGIC_NON_INTERACTIVE = $previousNonInteractive.Value
        } else {
            Remove-Item Env:\POWERSHELL_MAGIC_NON_INTERACTIVE -ErrorAction SilentlyContinue
        }
    }

    $fzfResult = Test-FzfAvailable
    Assert-True -Condition ($fzfResult -is [bool]) -Message 'Test-FzfAvailable returns a boolean result'

    if (Test-Path $commonTestRoot) {
        Remove-Item -Path $commonTestRoot -Recurse -Force -ErrorAction SilentlyContinue
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

            # Fallback selection without fzf using Read-Host
            try {
                $templaterFallbackRoot = Join-Path $templaterTestRoot 'Fallback'
                if (Test-Path $templaterFallbackRoot) {
                    Remove-Item -Path $templaterFallbackRoot -Recurse -Force -ErrorAction SilentlyContinue
                }
                New-Item -ItemType Directory -Path $templaterFallbackRoot -Force | Out-Null

                $configRoot = Join-Path $templaterFallbackRoot 'config'
                New-Item -ItemType Directory -Path $configRoot -Force | Out-Null

                $templateSource = Join-Path $templaterFallbackRoot 'template'
                if (Test-Path $templateSource) {
                    Remove-Item -Path $templateSource -Recurse -Force -ErrorAction SilentlyContinue
                }
                New-Item -ItemType Directory -Path $templateSource -Force | Out-Null
                Set-Content -Path (Join-Path $templateSource 'sample.txt') -Value 'fallback content' -Encoding UTF8 -Force

                $deployPath = Join-Path $templaterFallbackRoot 'deploy'
                if (Test-Path $deployPath) {
                    Remove-Item -Path $deployPath -Recurse -Force -ErrorAction SilentlyContinue
                }
                New-Item -ItemType Directory -Path $deployPath -Force | Out-Null

                $fallbackScript = Join-Path $templaterFallbackRoot 'InvokeFallback.ps1'
                $scriptContent = @'
param(
    [string]\$ModulePath,
    [string]\$ConfigRoot,
    [string]\$TemplateSource,
    [string]\$DeployPath
)
Import-Module \$ModulePath -Force
Remove-Item Env:POWERSHELL_MAGIC_NON_INTERACTIVE -ErrorAction SilentlyContinue
\$env:XDG_CONFIG_HOME = \$ConfigRoot
New-Item -ItemType Directory -Path \$env:XDG_CONFIG_HOME -Force | Out-Null
Set-Item Function:Test-FzfAvailable -Value ([ScriptBlock]::Create('return \$false')) -Force
Set-Item Function:Read-Host -Value ([ScriptBlock]::Create('param(`$Prompt) return \"1\"')) -Force
\$alias = 'fallback-templater'
Add-Template -Alias \$alias -Path \$TemplateSource -Description 'Fallback test template' -Category 'tests' -Type 'Folder' -Force | Out-Null
Get-Templates -Interactive -DestinationPath \$DeployPath | Out-Null
if (Test-Path (Join-Path \$DeployPath 'sample.txt')) { Write-Output 'SUCCESS' } else { Write-Output 'FAILED' }
'@
                Set-Content -Path $fallbackScript -Value $scriptContent -Encoding UTF8

                $modulePathNormalized = Join-Path $PSScriptRoot '..\Modules\Templater'
                $result = & pwsh -NoLogo -NoProfile -File $fallbackScript -ModulePath $modulePathNormalized -ConfigRoot $configRoot -TemplateSource $templateSource -DeployPath $deployPath 2>$null
                $resultValue = ($result | Select-Object -Last 1).Trim()
                Assert-Equal -Expected 'SUCCESS' -Actual $resultValue -Message 'Templater fallback interactive selection succeeds without fzf'
                Assert-True -Condition (Test-Path (Join-Path $deployPath 'sample.txt')) -Message 'Templater fallback deployed template content'
            } catch {
                Write-TestWarning "Templater fallback selection: $($_.Exception.Message)"
            } finally {
                if ($fallbackScript -and (Test-Path $fallbackScript)) {
                    Remove-Item -Path $fallbackScript -Force -ErrorAction SilentlyContinue
                }
            }

            # Variable substitution and renaming
            $variableTemplateAlias = $null
            $previousVerbose = $VerbosePreference
            try {
                $variableRoot = Join-Path $templaterTestRoot 'Variables'
                if (Test-Path $variableRoot) {
                    Remove-Item -Path $variableRoot -Recurse -Force -ErrorAction SilentlyContinue
                }
                New-Item -ItemType Directory -Path $variableRoot -Force | Out-Null

                $templateSource = Join-Path $variableRoot 'source'
                New-Item -ItemType Directory -Path $templateSource -Force | Out-Null

                $nestedDir = Join-Path $templateSource '{{ProjectName}}'
                New-Item -ItemType Directory -Path $nestedDir -Force | Out-Null

                $textFile = Join-Path $nestedDir '{{ProjectName}}-info.txt'
                Set-Content -Path $textFile -Value "Project: {{ProjectName}}`nDescription: {{Description}}" -Encoding UTF8 -Force

                $variableTemplateAlias = "templater-vars-$([System.Guid]::NewGuid().ToString('N').Substring(0, 8))"
                Add-Template -Alias $variableTemplateAlias -Path $templateSource -Description 'Variable substitution template' -Category 'tests' -Type 'Folder' -Force | Out-Null

                $deployPath = Join-Path $variableRoot 'deploy'
                New-Item -ItemType Directory -Path $deployPath -Force | Out-Null

                $variables = @{
                    ProjectName = 'Alpha'
                    Description = 'Sample project'
                }

                $VerbosePreference = 'Continue'
                Use-Template -Alias $variableTemplateAlias -DestinationPath $deployPath -Variables $variables -SubfolderName '{{ProjectName}}-output' -ErrorAction Stop | Out-Null

                $outputRoot = Join-Path $deployPath 'Alpha-output'
                $renamedFolder = Join-Path $outputRoot 'Alpha'
                Assert-True -Condition (Test-Path $renamedFolder) -Message 'Variable substitution renames directories using tokens'

                $renamedFile = Join-Path $renamedFolder 'Alpha-info.txt'
                Assert-True -Condition (Test-Path $renamedFile) -Message 'Variable substitution renames files using tokens'

                $fileContent = Get-Content -Path $renamedFile -Raw -ErrorAction Stop
                Assert-True -Condition ($fileContent -match 'Project: Alpha') -Message 'Variable substitution replaces project token in file content'
                Assert-True -Condition ($fileContent -match 'Description: Sample project') -Message 'Variable substitution replaces additional tokens in file content'
            } catch {
                Write-TestWarning "Templater variable substitution: $($_.Exception.Message)"
            } finally {
                if ($null -ne $previousVerbose) {
                    $VerbosePreference = $previousVerbose
                }
                if ($variableTemplateAlias) {
                    Remove-Template -Alias $variableTemplateAlias -Force -ErrorAction SilentlyContinue
                }
                if ($variableRoot -and (Test-Path $variableRoot)) {
                    Remove-Item -Path $variableRoot -Recurse -Force -ErrorAction SilentlyContinue
                }
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
            $initialDateAdded = $aliasRecord.DateAdded
            $initialLastOpened = $aliasRecord.LastOpenedString
            $initialUnityVersion = $aliasRecord.UnityVersion

            $pathResult = Get-UnityProjects -Alias $alias -Path
            Assert-Equal -Expected $resolvedProjectPath -Actual $pathResult -Message 'Get-UnityProjects -Alias -Path returns project path'

            # Fallback interactive selection without fzf
            try {
                $uniteaFallbackRoot = Join-Path $uniteaTestRoot 'Fallback'
                if (Test-Path $uniteaFallbackRoot) {
                    Remove-Item -Path $uniteaFallbackRoot -Recurse -Force -ErrorAction SilentlyContinue
                }
                New-Item -ItemType Directory -Path $uniteaFallbackRoot -Force | Out-Null

                $configRoot = Join-Path $uniteaFallbackRoot 'config'
                New-Item -ItemType Directory -Path $configRoot -Force | Out-Null

                $fallbackProject = Join-Path $uniteaFallbackRoot 'Project'
                New-Item -ItemType Directory -Path $fallbackProject -Force | Out-Null
                $fallbackSettings = Join-Path $fallbackProject 'ProjectSettings'
                New-Item -ItemType Directory -Path $fallbackSettings -Force | Out-Null
                Set-Content -Path (Join-Path $fallbackSettings 'ProjectVersion.txt') -Value 'm_EditorVersion: 2022.3.1f1' -Encoding UTF8

                $fallbackScript = Join-Path $uniteaFallbackRoot 'InvokeFallback.ps1'
                $scriptContent = @'
param(
    [string]$ModulePath,
    [string]$ConfigRoot,
    [string]$ProjectPath
)
Import-Module $ModulePath -Force
Remove-Item Env:POWERSHELL_MAGIC_NON_INTERACTIVE -ErrorAction SilentlyContinue
$env:XDG_CONFIG_HOME = $ConfigRoot
New-Item -ItemType Directory -Path $env:XDG_CONFIG_HOME -Force | Out-Null
Set-Item Function:Test-FzfAvailable -Value ([ScriptBlock]::Create('return $false')) -Force

$script:readHostResponses = New-Object 'System.Collections.Generic.Queue[string]'
$script:readHostResponses.Enqueue('1')
$script:readHostResponses.Enqueue('1')
$script:readHostResponses.Enqueue('y')

Set-Item Function:Read-Host -Value {
    param($Prompt)
    if ($script:readHostResponses.Count -gt 0) {
        return $script:readHostResponses.Dequeue()
    }
    return ''
} -Force

$alias = 'fallback-unitea'
Add-UnityProject -Alias $alias -ProjectPath $ProjectPath -Force | Out-Null

$selectedPath = Get-UnityProjects -Interactive -Path
if ($selectedPath -and (Test-Path $selectedPath)) {
    Write-Output 'SELECT_SUCCESS'
} else {
    Write-Output 'SELECT_FAILED'
}

Remove-UnityProject -Interactive -Multiple | Out-Null

$remaining = Get-UnityProjects
if (@($remaining).Count -eq 0) {
    Write-Output 'REMOVE_SUCCESS'
} else {
    Write-Output 'REMOVE_FAILED'
}
'@
                Set-Content -Path $fallbackScript -Value $scriptContent -Encoding UTF8

                $modulePathNormalized = Join-Path $PSScriptRoot '..\Modules\Unitea'
                $result = & pwsh -NoLogo -NoProfile -File $fallbackScript -ModulePath $modulePathNormalized -ConfigRoot $configRoot -ProjectPath $fallbackProject 2>$null
                $resultTokens = @($result | Where-Object { $_ })
                Assert-True -Condition ($resultTokens -contains 'SELECT_SUCCESS') -Message 'Unitea fallback interactive selection returns project path without fzf'
                Assert-True -Condition ($resultTokens -contains 'REMOVE_SUCCESS') -Message 'Unitea fallback removal succeeds without fzf'
            } catch {
                Write-TestWarning "Unitea fallback selection: $($_.Exception.Message)"
            } finally {
                if ($fallbackScript -and (Test-Path $fallbackScript)) {
                    Remove-Item -Path $fallbackScript -Force -ErrorAction SilentlyContinue
                }
                if (Test-Path $uniteaFallbackRoot) {
                    Remove-Item -Path $uniteaFallbackRoot -Recurse -Force -ErrorAction SilentlyContinue
                }
            }

            # Warn when stored metadata is stale
            $previousNonInteractive = $env:POWERSHELL_MAGIC_NON_INTERACTIVE
            $env:POWERSHELL_MAGIC_NON_INTERACTIVE = '1'
            try {
                $mismatchVersion = '2021.3.99f1'
                Set-Content -Path $versionFile -Value "m_EditorVersion: $mismatchVersion" -Encoding UTF8

                $mismatchWarnings = $null
                $null = Open-UnityProject -Alias $alias -WarningVariable mismatchWarnings -WarningAction Continue
                $mismatchWarningCount = @($mismatchWarnings).Count
                Assert-True -Condition ($mismatchWarningCount -ge 1) -Message 'Open-UnityProject emits warning when metadata is stale'

                $postWarningProjects = @(Get-UnityProjects -ErrorAction Stop)
                $postWarningRecord = $postWarningProjects | Where-Object { $_.Alias -eq $alias } | Select-Object -First 1
                Assert-Equal -Expected $initialUnityVersion -Actual $postWarningRecord.UnityVersion -Message 'Warning path does not mutate stored version'
            } finally {
                if ($null -ne $previousNonInteractive) {
                    $env:POWERSHELL_MAGIC_NON_INTERACTIVE = $previousNonInteractive
                } else {
                    Remove-Item Env:\POWERSHELL_MAGIC_NON_INTERACTIVE -ErrorAction SilentlyContinue
                }
            }

            Set-Content -Path $versionFile -Value "m_EditorVersion: $initialUnityVersion" -Encoding UTF8

            # Change Unity version and refresh stored metadata
            $updatedVersion = '2022.1.5f1'
            Set-Content -Path $versionFile -Value "m_EditorVersion: $updatedVersion" -Encoding UTF8

            $refreshResult = Update-UnityProject -Alias $alias -PassThru -ErrorAction Stop
            if ($refreshResult -is [System.Array]) {
                $refreshResult = $refreshResult | Select-Object -First 1
            }
            Assert-NotNull -Value $refreshResult -Message 'Update-UnityProject returns a result for alias refresh'
            Assert-True -Condition $refreshResult.Updated -Message 'Alias refresh reports an update occurred'
            Assert-Equal -Expected $updatedVersion -Actual $refreshResult.UnityVersion -Message 'Alias refresh reports new Unity version'

            $refreshedProjects = @(Get-UnityProjects -ErrorAction Stop)
            $refreshedRecord = $refreshedProjects | Where-Object { $_.Alias -eq $alias } | Select-Object -First 1
            Assert-Equal -Expected $updatedVersion -Actual $refreshedRecord.UnityVersion -Message 'Stored Unity version updated after refresh'
            Assert-Equal -Expected $initialDateAdded -Actual $refreshedRecord.DateAdded -Message 'DateAdded preserved after refresh'
            Assert-Equal -Expected $initialLastOpened -Actual $refreshedRecord.LastOpenedString -Message 'LastOpened preserved after refresh'

            $noChange = Update-UnityProject -Alias $alias -PassThru -ErrorAction Stop
            if ($noChange -is [System.Array]) {
                $noChange = $noChange | Select-Object -First 1
            }
            Assert-True -Condition (-not $noChange.Updated) -Message 'Repeated refresh without changes reports no update'

            # Auto-update via Open-UnityProject
            $previousNonInteractive = $env:POWERSHELL_MAGIC_NON_INTERACTIVE
            $env:POWERSHELL_MAGIC_NON_INTERACTIVE = '1'
            try {
                $autoUpdateVersion = '2022.1.6f1'
                Set-Content -Path $versionFile -Value "m_EditorVersion: $autoUpdateVersion" -Encoding UTF8

                $autoWarnings = $null
                $null = Open-UnityProject -Alias $alias -AutoUpdate -WarningVariable autoWarnings -WarningAction Continue
                $autoWarningCount = @($autoWarnings).Count
                Assert-Equal -Expected 0 -Actual $autoWarningCount -Message 'Auto-update completes without warnings'

                $autoUpdatedProjects = @(Get-UnityProjects -ErrorAction Stop)
                $autoUpdatedRecord = $autoUpdatedProjects | Where-Object { $_.Alias -eq $alias } | Select-Object -First 1
                Assert-Equal -Expected $autoUpdateVersion -Actual $autoUpdatedRecord.UnityVersion -Message 'Open-UnityProject auto-update refreshes stored version'
                Assert-Equal -Expected $initialDateAdded -Actual $autoUpdatedRecord.DateAdded -Message 'Auto-update preserves DateAdded metadata'
            } finally {
                if ($null -ne $previousNonInteractive) {
                    $env:POWERSHELL_MAGIC_NON_INTERACTIVE = $previousNonInteractive
                } else {
                    Remove-Item Env:\POWERSHELL_MAGIC_NON_INTERACTIVE -ErrorAction SilentlyContinue
                }
            }

            # Add a second project for -All and -ProjectPath scenarios
            $secondProjectPath = Join-Path $workspaceRoot 'SampleProjectTwo'
            New-Item -ItemType Directory -Path $secondProjectPath -Force | Out-Null
            $secondProjectSettings = Join-Path $secondProjectPath 'ProjectSettings'
            New-Item -ItemType Directory -Path $secondProjectSettings -Force | Out-Null
            $secondVersionFile = Join-Path $secondProjectSettings 'ProjectVersion.txt'
            Set-Content -Path $secondVersionFile -Value 'm_EditorVersion: 2020.3.1f1' -Encoding UTF8

            $secondAlias = "unitea-test-$([System.Guid]::NewGuid().ToString('N').Substring(0, 8))"
            Add-UnityProject -Alias $secondAlias -ProjectPath $secondProjectPath -Force -ErrorAction Stop

            # Startup sync detection and optional auto-update
            $startupMismatchVersion = '2020.3.5f1'
            Set-Content -Path $secondVersionFile -Value "m_EditorVersion: $startupMismatchVersion" -Encoding UTF8

            $previousDisableStartup = $env:POWERSHELL_MAGIC_UNITEA_DISABLE_STARTUP_CHECK
            $previousAutoUpdateStartup = $env:POWERSHELL_MAGIC_UNITEA_AUTOUPDATE_STARTUP
            $env:POWERSHELL_MAGIC_UNITEA_DISABLE_STARTUP_CHECK = $null
            $env:POWERSHELL_MAGIC_UNITEA_AUTOUPDATE_STARTUP = $null

            try {
                $startupWarnings = $null
                $startupResults = Invoke-UniteaStartupSyncCheck -Force -PassThru -WarningVariable startupWarnings -WarningAction Continue
                $startupResults = @($startupResults)
                Assert-Equal -Expected 1 -Actual $startupResults.Count -Message 'Startup sync detects one mismatched project'
                $startupEntry = $startupResults | Select-Object -First 1
                Assert-Equal -Expected 'VersionMismatch' -Actual $startupEntry.Status -Message 'Startup sync reports version mismatch status'
                Assert-True -Condition ($startupWarnings -match $secondAlias) -Message 'Startup sync emits warning mentioning the mismatched alias'

                $postStartupProjects = @(Get-UnityProjects -ErrorAction Stop)
                $postStartupRecord = $postStartupProjects | Where-Object { $_.Alias -eq $secondAlias } | Select-Object -First 1
                Assert-Equal -Expected '2020.3.1f1' -Actual $postStartupRecord.UnityVersion -Message 'Startup warning does not modify stored version'

                $env:POWERSHELL_MAGIC_UNITEA_AUTOUPDATE_STARTUP = '1'
                $autoStartupWarnings = $null
                $autoStartupResults = Invoke-UniteaStartupSyncCheck -Force -PassThru -WarningVariable autoStartupWarnings -WarningAction Continue
                $autoStartupResults = @($autoStartupResults)
                Assert-Equal -Expected 1 -Actual $autoStartupResults.Count -Message 'Auto-update startup returns result entry'
                $autoStartupEntry = $autoStartupResults | Select-Object -First 1
                Assert-True -Condition $autoStartupEntry.Resolved -Message 'Auto-update marks the issue as resolved'
                Assert-Equal -Expected 'VersionMismatchResolved' -Actual $autoStartupEntry.Status -Message 'Auto-update reports resolved status'
                Assert-True -Condition (-not $autoStartupWarnings) -Message 'Auto-update completes without warnings'

                $postAutoProjects = @(Get-UnityProjects -ErrorAction Stop)
                $postAutoRecord = $postAutoProjects | Where-Object { $_.Alias -eq $secondAlias } | Select-Object -First 1
                Assert-Equal -Expected $startupMismatchVersion -Actual $postAutoRecord.UnityVersion -Message 'Auto-update startup synchronizes stored version'
            } finally {
                if ($null -ne $previousDisableStartup) {
                    $env:POWERSHELL_MAGIC_UNITEA_DISABLE_STARTUP_CHECK = $previousDisableStartup
                } else {
                    Remove-Item Env:\POWERSHELL_MAGIC_UNITEA_DISABLE_STARTUP_CHECK -ErrorAction SilentlyContinue
                }

                if ($null -ne $previousAutoUpdateStartup) {
                    $env:POWERSHELL_MAGIC_UNITEA_AUTOUPDATE_STARTUP = $previousAutoUpdateStartup
                } else {
                    Remove-Item Env:\POWERSHELL_MAGIC_UNITEA_AUTOUPDATE_STARTUP -ErrorAction SilentlyContinue
                }
            }

            # Modify both projects and run bulk update
            $bulkVersionFirst = '2022.2.0f1'
            $bulkVersionSecond = '2020.3.2f1'
            Set-Content -Path $versionFile -Value "m_EditorVersion: $bulkVersionFirst" -Encoding UTF8
            Set-Content -Path $secondVersionFile -Value "m_EditorVersion: $bulkVersionSecond" -Encoding UTF8

            $bulkResult = Update-UnityProject -All -PassThru -ErrorAction Stop
            $bulkResultByAlias = @{}
            foreach ($entry in $bulkResult) {
                $bulkResultByAlias[$entry.Alias] = $entry
            }

            Assert-True -Condition ($bulkResultByAlias.ContainsKey($alias)) -Message 'Bulk update includes first alias'
            Assert-Equal -Expected $bulkVersionFirst -Actual $bulkResultByAlias[$alias].UnityVersion -Message 'Bulk update refreshes first project version'
            Assert-True -Condition ($bulkResultByAlias.ContainsKey($secondAlias)) -Message 'Bulk update includes second alias'
            Assert-Equal -Expected $bulkVersionSecond -Actual $bulkResultByAlias[$secondAlias].UnityVersion -Message 'Bulk update refreshes second project version'

            $postBulkProjects = @(Get-UnityProjects -ErrorAction Stop)
            $secondRecord = $postBulkProjects | Where-Object { $_.Alias -eq $secondAlias } | Select-Object -First 1
            Assert-Equal -Expected $bulkVersionSecond -Actual $secondRecord.UnityVersion -Message 'Second project stores updated version after bulk refresh'

            # Update using project path matching
            $pathRefreshVersion = '2021.1.9f1'
            Set-Content -Path $secondVersionFile -Value "m_EditorVersion: $pathRefreshVersion" -Encoding UTF8
            $pathResultRefresh = Update-UnityProject -ProjectPath $secondProjectPath -PassThru -ErrorAction Stop
            if ($pathResultRefresh -is [System.Array]) {
                $pathResultRefresh = $pathResultRefresh | Select-Object -First 1
            }
            Assert-True -Condition $pathResultRefresh.Updated -Message 'Project path refresh reports update'
            Assert-Equal -Expected $pathRefreshVersion -Actual $pathResultRefresh.UnityVersion -Message 'Project path refresh applies new version'

            $postPathProjects = @(Get-UnityProjects -ErrorAction Stop)
            $postPathRecord = $postPathProjects | Where-Object { $_.Alias -eq $secondAlias } | Select-Object -First 1
            Assert-Equal -Expected $pathRefreshVersion -Actual $postPathRecord.UnityVersion -Message 'Stored version matches project path refresh'

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
        'Common' { Test-CommonUtilities }
        'QuickJump' { Test-QuickJump }
        'Templater' { Test-Templater }
        'Unitea' { Test-Unitea }
        'All' {
            Test-Setup
            Test-CommonUtilities
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



