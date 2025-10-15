#Requires -Version 7.0

<#
.SYNOPSIS
One-click setup for Jason Storey's PowerShell Magic modules.

.DESCRIPTION
This script automatically scans for dependencies, downloads and installs missing tools,
and configures the PowerShell modules in your profile. It supports:

- QuickJump: Fast directory navigation with fzf integration
- Templater: Template management with 7-Zip archive support
- Unitea: Unity project management

Dependencies managed:
- fzf (fuzzy finder)
- 7-Zip (archive extraction)
- eza (modern ls replacement, optional)

.PARAMETER SkipDependencyCheck
Skip dependency scanning and installation.

.PARAMETER SkipProfileImport
Skip importing modules into PowerShell profile.

.PARAMETER Force
Force reinstall of dependencies and overwrite profile changes.

.PARAMETER InstallLocation
Where to install portable tools. Default: $env:LOCALAPPDATA\PowerShellMagic

.PARAMETER NonInteractive
Run in non-interactive mode, automatically answering prompts without waiting for input.

.PARAMETER AssumeYes
When combined with -NonInteractive, automatically answer 'y' to confirmation prompts.

.PARAMETER ListPortableDownloads
Print a manifest of portable download URLs and SHA256 hashes, then exit.

.EXAMPLE
.\Setup-PowerShellMagic.ps1
Full automated setup with prompts

.EXAMPLE
.\Setup-PowerShellMagic.ps1 -Force
Force reinstall everything

.EXAMPLE
.\Setup-PowerShellMagic.ps1 -SkipDependencyCheck
Only import modules, skip dependency installation

.EXAMPLE
.\Setup-PowerShellMagic.ps1 -NonInteractive
Run setup without any user prompts (for testing)

.EXAMPLE
.\Setup-PowerShellMagic.ps1 -NonInteractive -AssumeYes
Run setup without prompts, auto-confirming all questions (for CI)

.EXAMPLE
.\Setup-PowerShellMagic.ps1 -ListPortableDownloads
Display portable download URLs and hashes without running setup
#>

[CmdletBinding()]
param(
    [switch]$SkipDependencyCheck,
    [switch]$SkipProfileImport,
    [switch]$Force,
    [string]$InstallLocation,
    [switch]$NonInteractive,
    [switch]$AssumeYes,
    [switch]$ListPortableDownloads
)

$script:CurrentPlatform = if ($IsWindows) {
    'Windows'
} elseif ($IsMacOS) {
    'MacOS'
} elseif ($IsLinux) {
    'Linux'
} else {
    'Unknown'
}

function Get-DefaultInstallLocation {
    if ($IsWindows -and $env:LOCALAPPDATA) {
        return Join-Path $env:LOCALAPPDATA 'PowerShellMagic'
    }

    if ($env:XDG_DATA_HOME) {
        return Join-Path $env:XDG_DATA_HOME 'powershell-magic'
    }

    if ($env:HOME) {
        return Join-Path (Join-Path $env:HOME '.local/share') 'powershell-magic'
    }

    return Join-Path ([System.IO.Path]::GetTempPath()) 'PowerShellMagic'
}

function Join-PathSegments {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Segments
    )

    if (-not $Segments -or $Segments.Count -eq 0) {
        return [string]::Empty
    }

    $path = $Segments[0]
    for ($i = 1; $i -lt $Segments.Count; $i++) {
        $segment = $Segments[$i]
        if ([string]::IsNullOrWhiteSpace($segment)) {
            continue
        }
        $path = Join-Path $path $segment
    }

    return $path
}

function Get-TempFilePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    $tempRoot = [System.IO.Path]::GetTempPath()
    if (-not $tempRoot) {
        $tempRoot = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetTempFileName())
    }

    return Join-Path $tempRoot $FileName
}

function Get-PathSeparator {
    if ($IsWindows) { return ';' }
    return ':'
}

function Invoke-PackageManagerCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [string[]]$Arguments = @(),
        [switch]$RequiresElevation
    )

    $commandParts = @($Command)
    if ($RequiresElevation -and -not (Test-IsElevated)) {
        $commandParts = @('sudo', $Command)
    }

    $executable = $commandParts[0]
    $commandArguments = @()

    if ($commandParts.Count -gt 1) {
        $commandArguments += $commandParts[1..($commandParts.Count - 1)]
    }

    if ($Arguments) {
        $commandArguments += $Arguments
    }

    $global:LASTEXITCODE = 0
    $result = & $executable @commandArguments 2>&1
    return @{
        Output = $result
        ExitCode = $LASTEXITCODE
    }
}

if (-not $InstallLocation) {
    $InstallLocation = Get-DefaultInstallLocation
}

# Color output functions
function Write-Success {
    param($Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}
function Write-Info {
    param($Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}
function Write-WarningMessage {
    param($Message)
    Microsoft.PowerShell.Utility\Write-Warning "[WARN] $Message"
}
function Write-ErrorMessage {
    param($Message)
    Microsoft.PowerShell.Utility\Write-Error -Message "[ERROR] $Message"
}
function Write-HostWarning {
    param($Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}
function Write-HostError {
    param($Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Prompt helper function for non-interactive mode
function Get-UserResponse {
    param(
        [string]$Prompt,
        [string]$DefaultResponse = 'n'
    )

    if ($NonInteractive) {
        $response = if ($AssumeYes) { 'y' } else { $DefaultResponse }
        Write-Info "Non-interactive mode: Auto-answering '$response' for: $Prompt"
        return $response
    } else {
        return Read-Host $Prompt
    }
}

# Dependency definitions with cryptographic verification (Windows portable assets only)
# NOTE: Update PortableAssets hashes before distribution by:
# 1. Download the file manually
# 2. Run: Get-FileHash -Path "downloaded-file" -Algorithm SHA256
# 3. Replace the Sha256 value with the actual hash
$Dependencies = @{
    'fzf' = @{
        Name = 'fzf'
        Description = 'Fuzzy finder for interactive selection'
        TestCommand = @('fzf', '--version')
        PortableAssets = @{
            Windows = @{
                Url = 'https://github.com/junegunn/fzf/releases/download/v0.66.0/fzf-0.66.0-windows_amd64.zip'
                Sha256 = '9D2A1BC6E38665D0A15D846703A2C9EF1F5FE2630A9F972F9832712709C18823'
                Executable = 'fzf.exe'
                ArchiveType = 'zip'
            }
        }
        ScoopPackage = 'fzf'
        ChocoPackage = 'fzf'
        WingetPackage = 'junegunn.fzf'
        BrewPackage = 'fzf'
        AptPackage = 'fzf'
        DnfPackage = 'fzf'
        PacmanPackage = 'fzf'
        Required = $true
        Modules = @('QuickJump', 'Templater', 'Unitea')
        PackageManagerInfo = @{
            Description = 'Package managers provide automatic verification and updates'
            Scoop = 'Community-maintained manifests with checksums'
            Chocolatey = 'Community packages with moderation and checksums'
            Winget = 'Microsoft-backed with package verification'
            Brew = 'Homebrew formulas maintain checksums and automatic upgrades'
            Apt = 'Debian/Ubuntu package (requires sudo privileges)'
            Dnf = 'Fedora package (requires sudo privileges)'
            Pacman = 'Arch package (requires sudo privileges)'
        }
    }
    '7zip' = @{
        Name = '7-Zip'
        Description = 'Archive extraction tool'
        TestCommand = @{
            Windows = @('7z', '--help')
            MacOS = @('7zz', '--help')
            Linux = @('7zz', '--help')
            Default = @('7z', '--help')
        }
        PortableAssets = @{
            Windows = @{
                Url = 'https://www.7-zip.org/a/7z2501-x64.exe'
                Sha256 = '78AFA2A1C773CAF3CF7EDF62F857D2A8A5DA55FB0FFF5DA416074C0D28B2B55F'
                Executable = '7z.exe'
                ArchiveType = 'exe'
            }
            MacOS = @{
                Url = 'https://www.7-zip.org/a/7z2501-mac.tar.xz'
                Sha256 = '26AA75BC262BB10BF0805617B95569C3035C2C590A99F7DB55C7E9607B2685E0'
                Executable = '7zz'
                ArchiveType = 'tar.xz'
            }
            Linux = @{
                Url = 'https://www.7-zip.org/a/7z2501-linux-x64.tar.xz'
                Sha256 = '4CA3B7C6F2F67866B92622818B58233DC70367BE2F36B498EB0BDEAAA44B53F4'
                Executable = '7zz'
                ArchiveType = 'tar.xz'
            }
        }
        ScoopPackage = '7zip'
        ChocoPackage = '7zip'
        WingetPackage = '7zip.7zip'
        BrewPackage = 'p7zip'
        AptPackage = 'p7zip-full'
        DnfPackage = 'p7zip'
        PacmanPackage = 'p7zip'
        Required = $false
        Modules = @('Templater')
        Note = 'Required for archive template extraction in Templater'
        PackageManagerInfo = @{
            Description = 'Package managers provide automatic verification and updates'
            Scoop = 'Community-maintained with checksums from official releases'
            Chocolatey = 'Official 7-Zip package with verification'
            Winget = 'Microsoft-verified official 7-Zip package'
            Brew = 'Homebrew p7zip port provides cross-platform binaries'
            Apt = 'Debian/Ubuntu package (requires sudo privileges)'
            Dnf = 'Fedora package (requires sudo privileges)'
            Pacman = 'Arch package (requires sudo privileges)'
        }
    }
    'eza' = @{
        Name = 'eza'
        Description = 'Modern ls replacement with better directory previews'
        TestCommand = @('eza', '--version')
        PortableAssets = @{
            Windows = @{
                Url = 'https://github.com/eza-community/eza/releases/download/v0.23.4/eza.exe_x86_64-pc-windows-gnu.zip'
                Sha256 = '05677FD7C2D1B69CE71DF53DB74C29F6331EA0B2BE5AA3A0FCE6976200EE06FC'
                Executable = 'eza.exe'
                ArchiveType = 'zip'
            }
        }
        ScoopPackage = 'eza'
        ChocoPackage = 'eza'
        WingetPackage = 'eza-community.eza'
        BrewPackage = 'eza'
        AptPackage = 'eza'
        DnfPackage = 'eza'
        PacmanPackage = 'eza'
        Required = $false
        Modules = @('QuickJump')
        Note = 'Optional: Provides enhanced directory previews in QuickJump fzf selection'
        PackageManagerInfo = @{
            Description = 'Package managers provide automatic verification and updates'
            Scoop = 'Community-maintained with GitHub release checksums'
            Chocolatey = 'Community package with automatic checksum verification'
            Winget = 'Community-maintained with Microsoft verification'
            Brew = 'Homebrew formula for macOS/Linux (requires brew)'
            Apt = 'Debian/Ubuntu package (requires sudo privileges)'
            Dnf = 'Fedora package (requires sudo privileges)'
            Pacman = 'Arch package (requires sudo privileges)'
        }
    }
}

function Show-PortableDownloads {
    Write-Host 'PowerShell Magic Portable Downloads Manifest' -ForegroundColor Cyan

    $portableDependencies = $Dependencies.GetEnumerator() |
        Where-Object { $_.Value.PortableAssets } |
        Sort-Object Name
    $manifest = @()

    foreach ($entry in $portableDependencies) {
        $dependency = $entry.Value
        Write-Host "`n$($dependency.Name)" -ForegroundColor Yellow

        foreach ($platform in ($dependency.PortableAssets.Keys | Sort-Object)) {
            $asset = $dependency.PortableAssets[$platform]

            Write-Host ('  [{0}] URL: {1}' -f $platform, $asset.Url) -ForegroundColor Gray

            if ($asset.Sha256) {
                Write-Host ('  [{0}] SHA256: {1}' -f $platform, $asset.Sha256) `
                    -ForegroundColor Gray
            } else {
                Write-WarningMessage ('[{0}] SHA256 not available' -f $platform)
            }

            if ($asset.Executable) {
                Write-Host ('  [{0}] Executable: {1}' -f $platform, $asset.Executable) `
                    -ForegroundColor DarkGray
            }

            if ($asset.ArchiveType) {
                Write-Host ('  [{0}] Archive Type: {1}' -f $platform, $asset.ArchiveType) `
                    -ForegroundColor DarkGray
            }

            $manifest += [PSCustomObject]@{
                Name = $dependency.Name
                Platform = $platform
                Url = $asset.Url
                Sha256 = $asset.Sha256
                Executable = $asset.Executable
                ArchiveType = $asset.ArchiveType
            }
        }
    }

    Write-Host "`nValidate downloads with Get-FileHash -Algorithm SHA256" `
        -ForegroundColor Cyan
    Write-Host 'or shasum -a 256 before installing.' -ForegroundColor Cyan

    return $manifest
}

function Test-IsElevated {
    if ($IsWindows) {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    try {
        $uidOutput = & id -u 2>$null
        return ([int]$uidOutput -eq 0)
    } catch {
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
        Write-ErrorMessage "File not found: $FilePath"
        return $false
    }

    if ($ExpectedHash -like 'NOTE:*') {
        Write-WarningMessage 'No checksum available for verification'
        Write-WarningMessage "$ExpectedHash"
        $continue = Get-UserResponse 'Continue without verification? (y/N)' 'N'
        return ($continue -match '^[Yy]')
    }

    try {
        $actualHash = Get-FileHash -Path $FilePath -Algorithm $Algorithm
        $hashMatch = $actualHash.Hash -eq $ExpectedHash.ToUpper()

        if ($hashMatch) {
            Write-Success 'Cryptographic verification passed'
            Write-Info "Expected: $ExpectedHash"
            Write-Info "Actual:   $($actualHash.Hash)"
        } else {
            Write-ErrorMessage 'CRYPTOGRAPHIC VERIFICATION FAILED!'
            Write-ErrorMessage "Expected: $ExpectedHash"
            Write-ErrorMessage "Actual:   $($actualHash.Hash)"
            Write-ErrorMessage 'This could indicate file corruption or tampering.'
        }

        return $hashMatch
    } catch {
        Write-ErrorMessage "Failed to calculate file hash: $($_.Exception.Message)"
        return $false
    }
}

function Test-PackageManager {
    param($Manager)

    switch ($Manager) {
        'scoop' {
            try {
                $null = Get-Command scoop -ErrorAction Stop
                return $true
            } catch {
                return $false
            }
        }
        'choco' {
            try {
                $null = Get-Command choco -ErrorAction Stop
                return $true
            } catch {
                return $false
            }
        }
        'winget' {
            try {
                $null = Get-Command winget -ErrorAction Stop
                return $true
            } catch {
                return $false
            }
        }
        'brew' {
            try {
                $null = Get-Command brew -ErrorAction Stop
                return $true
            } catch {
                return $false
            }
        }
        'apt' {
            try {
                $null = Get-Command apt-get -ErrorAction Stop
                return $true
            } catch {
                try {
                    $null = Get-Command apt -ErrorAction Stop
                    return $true
                } catch {
                    return $false
                }
            }
        }
        'dnf' {
            try {
                $null = Get-Command dnf -ErrorAction Stop
                return $true
            } catch {
                return $false
            }
        }
        'pacman' {
            try {
                $null = Get-Command pacman -ErrorAction Stop
                return $true
            } catch {
                return $false
            }
        }
    }
    return $false
}

function Get-PackageManagerExecutable {
    param($Manager)

    switch ($Manager) {
        'apt' {
            if (Get-Command apt-get -ErrorAction SilentlyContinue) {
                return 'apt-get'
            }
            if (Get-Command apt -ErrorAction SilentlyContinue) {
                return 'apt'
            }
        }
        default { return $Manager }
    }
}

function Get-CommandTokens {
    param(
        [Parameter(Mandatory = $true)]
        $TestCommand,
        [string]$Platform
    )

    if ($null -eq $TestCommand) {
        return @()
    }

    if (-not $Platform) {
        $Platform = $script:CurrentPlatform
    }

    if ($TestCommand -is [System.Collections.IDictionary]) {
        $selected = $null

        if ($Platform -and $TestCommand.ContainsKey($Platform)) {
            $selected = $TestCommand[$Platform]
        } elseif ($TestCommand.ContainsKey('Default')) {
            $selected = $TestCommand['Default']
        }

        if ($null -eq $selected) {
            return @()
        }

        return Get-CommandTokens -TestCommand $selected -Platform $Platform
    }

    if ($TestCommand -is [System.Collections.IEnumerable] -and -not ($TestCommand -is [string])) {
        return @($TestCommand | Where-Object { $_ -is [string] -and $_.Length -gt 0 })
    }

    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseInput($TestCommand, [ref]$tokens, [ref]$errors) | Out-Null

    if ($errors -and $errors.Count -gt 0) {
        throw "Invalid TestCommand '$TestCommand': $($errors[0].Message)"
    }

    $commandTokens = @()
    foreach ($token in $tokens) {
        if ($token.Kind -eq [System.Management.Automation.Language.TokenKind]::EndOfInput) {
            continue
        }

        if ($token -is [System.Management.Automation.Language.StringToken]) {
            $commandTokens += $token.Value
        } elseif ($token.Text) {
            $commandTokens += $token.Text
        }
    }

    return $commandTokens
}

function Test-Dependency {
    param($Dependency)

    try {
        $commandTokens = Get-CommandTokens -TestCommand $Dependency.TestCommand -Platform $script:CurrentPlatform
        if (-not $commandTokens) {
            return $false
        }

        $command = $commandTokens[0]
        $arguments = if ($commandTokens.Count -gt 1) { $commandTokens[1..($commandTokens.Count - 1)] } else { @() }

        $global:LASTEXITCODE = 0
        $null = & $command @arguments 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Install-DependencyPortable {
    param($Dependency)

    if (-not $Dependency.PortableAssets) {
        Write-Warning "No portable installation assets defined for $($Dependency.Name)"
        return $false
    }

    $asset = $Dependency.PortableAssets[$script:CurrentPlatform]
    if (-not $asset) {
        Write-Warning "$($Dependency.Name) does not provide a portable asset for $script:CurrentPlatform"
        return $false
    }

    $portableUrl = $asset.Url
    $portableHash = $asset.Sha256
    $portableExe = $asset.Executable
    $archiveType = ($asset.ArchiveType ?? '').ToLowerInvariant()

    Write-Warning "SECURITY NOTICE: This will download and execute software from: $portableUrl"
    if ($portableHash) {
        Write-Warning "Download will be verified with SHA256: $portableHash"
    } else {
        Write-Warning 'No checksum is available; verification will be skipped'
    }
    Write-Warning 'This will modify your user PATH environment variable'

    $confirm = Get-UserResponse "Do you want to proceed with downloading $($Dependency.Name)? Type 'YES' to confirm" 'NO'
    if ($confirm -ne 'YES') {
        Write-Warning 'Installation cancelled by user'
        return $false
    }

    $installDir = Join-Path $InstallLocation 'bin'
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    $tempFileName = '{0}-{1}' -f $Dependency.Name, ([System.IO.Path]::GetFileName($portableUrl) ?? 'portable.tmp')
    $tempFile = Get-TempFilePath -FileName $tempFileName

    try {
        Write-Info "Downloading $($Dependency.Name) from $portableUrl..."

        # Use modern download method
        if ($PSVersionTable.PSVersion.Major -ge 3) {
            Invoke-WebRequest -Uri $portableUrl -OutFile $tempFile -UseBasicParsing -ErrorAction Stop
        } else {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($portableUrl, $tempFile)
            $webClient.Dispose()
        }

        # Verify downloaded file
        Write-Info 'Verifying download integrity...'
        if (-not (Test-FileHash -FilePath $tempFile -ExpectedHash $portableHash)) {
            Write-ErrorMessage 'File verification failed. Aborting installation.'
            return $false
        }

        $extractedPath = $null
        switch ($archiveType) {
            'zip' {
                Write-Info "Extracting $($Dependency.Name) archive..."
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($tempFile, $installDir, $true)
                $extractedPath = $installDir
            }
            { $_ -in @('tar.gz', 'tgz') } {
                Write-Info "Extracting $($Dependency.Name) tar archive..."
                $tarArgs = @('-xzf', $tempFile, '-C', $installDir)
                $tarResult = & tar @tarArgs 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-ErrorMessage "Failed to extract tar archive: $tarResult"
                    return $false
                }
                $extractedPath = $installDir
            }
            { $_ -in @('tar.xz', 'txz') } {
                Write-Info "Extracting $($Dependency.Name) tar archive..."
                $tarArgs = @('-xJf', $tempFile, '-C', $installDir)
                $tarResult = & tar @tarArgs 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-ErrorMessage "Failed to extract tar archive: $tarResult"
                    return $false
                }
                $extractedPath = $installDir
            }
            { $_ -in @('tar.bz2', 'tbz', 'tbz2') } {
                Write-Info "Extracting $($Dependency.Name) tar archive..."
                $tarArgs = @('-xjf', $tempFile, '-C', $installDir)
                $tarResult = & tar @tarArgs 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-ErrorMessage "Failed to extract tar archive: $tarResult"
                    return $false
                }
                $extractedPath = $installDir
            }
            'exe' {
                if (-not $IsWindows) {
                    Write-ErrorMessage 'Executable installer is only supported on Windows.'
                    return $false
                }

                $finalPath = Join-Path $installDir ($portableExe ?? "$($Dependency.Name).exe")
                Move-Item -Path $tempFile -Destination $finalPath -Force
                $extractedPath = Split-Path -Parent $finalPath
            }
            default {
                # Unknown archive types: treat as direct binary
                $finalName = $portableExe
                if (-not $finalName) {
                    $finalName = [System.IO.Path]::GetFileName($portableUrl)
                }
                if (-not $finalName) {
                    $finalName = "$($Dependency.Name).bin"
                }

                $finalPath = Join-Path $installDir $finalName
                Move-Item -Path $tempFile -Destination $finalPath -Force
                $extractedPath = Split-Path -Parent $finalPath
            }
        }

        if ($archiveType -ne 'exe') {
            # Locate executable if provided
            if ($portableExe) {
                $extractedExe = Get-ChildItem -Path $installDir -Recurse -Filter $portableExe -File -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($extractedExe) {
                    $finalPath = Join-Path $installDir $portableExe
                    if ($extractedExe.FullName -ne $finalPath) {
                        Move-Item -Path $extractedExe.FullName -Destination $finalPath -Force
                        $extractedPath = Split-Path -Parent $finalPath
                    } else {
                        $extractedPath = Split-Path -Parent $extractedExe.FullName
                    }
                }
            }
        }

        if (-not $IsWindows -and $portableExe) {
            $exePath = Join-Path $installDir $portableExe
            if (Test-Path $exePath) {
                & chmod +x $exePath 2>$null | Out-Null
            }
        }

        # Add to PATH if not already there
        $pathScope = if ($IsWindows) { 'User' } else { 'Process' }
        $currentPath = [Environment]::GetEnvironmentVariable('PATH', $pathScope)
        if (-not $currentPath) { $currentPath = '' }

        if ($currentPath -notlike "*$installDir*") {
            $separator = Get-PathSeparator
            Write-Warning 'About to modify your PATH environment variable'
            Write-Info "Current PATH: $currentPath"
            Write-Info "Will add: $installDir"

            $pathConfirm = Get-UserResponse 'Add to PATH? (Y/n)' 'n'
            if ($pathConfirm -notmatch '^[Nn]') {
                Write-Info "Adding $installDir to PATH..."
                $newPath = if ([string]::IsNullOrWhiteSpace($currentPath)) { $installDir } else { "$currentPath$separator$installDir" }
                [Environment]::SetEnvironmentVariable('PATH', $newPath, $pathScope)
                $env:PATH = if ([string]::IsNullOrWhiteSpace($env:PATH)) { $newPath } else { "$env:PATH$separator$installDir" }
            } else {
                Write-Warning "PATH not modified. You'll need to manually add $installDir to PATH to use $($Dependency.Name)"
            }
        }

        Write-Success "Successfully installed $($Dependency.Name) to $installDir"
        return $true

    } catch {
        Write-ErrorMessage "Failed to install $($Dependency.Name): $($_.Exception.Message)"
        return $false
    } finally {
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Install-DependencyPackageManager {
    param($Dependency, $Manager)

    try {
        $package = switch ($Manager) {
            'scoop' { $Dependency.ScoopPackage }
            'choco' { $Dependency.ChocoPackage }
            'winget' { $Dependency.WingetPackage }
            'brew' { $Dependency.BrewPackage }
            'apt' { $Dependency.AptPackage }
            'dnf' { $Dependency.DnfPackage }
            'pacman' { $Dependency.PacmanPackage }
            default { $null }
        }

        if (-not $package) {
            Write-Warning "$($Dependency.Name) not available via $Manager"
            return $false
        }

        Write-Info "Installing $($Dependency.Name) via $Manager..."

        $commandResult = $null

        switch ($Manager) {
            'scoop' {
                $commandResult = Invoke-PackageManagerCommand -Command 'scoop' -Arguments @('install', $package)
            }
            'choco' {
                if (-not (Test-IsElevated)) {
                    Write-Warning 'Chocolatey requires administrator privileges'
                    return $false
                }
                $commandResult = Invoke-PackageManagerCommand -Command 'choco' -Arguments @('install', $package, '-y')
            }
            'winget' {
                $commandResult = Invoke-PackageManagerCommand -Command 'winget' -Arguments @('install', $package, '--accept-source-agreements', '--accept-package-agreements')
            }
            'brew' {
                $commandResult = Invoke-PackageManagerCommand -Command 'brew' -Arguments @('install', $package)
            }
            'apt' {
                $executable = Get-PackageManagerExecutable -Manager 'apt'
                $commandResult = Invoke-PackageManagerCommand -Command $executable -Arguments @('install', '-y', $package) -RequiresElevation
            }
            'dnf' {
                $commandResult = Invoke-PackageManagerCommand -Command 'dnf' -Arguments @('install', '-y', $package) -RequiresElevation
            }
            'pacman' {
                $commandResult = Invoke-PackageManagerCommand -Command 'pacman' -Arguments @('-Sy', '--noconfirm', $package) -RequiresElevation
            }
            default {
                Write-Warning "Unsupported package manager: $Manager"
                return $false
            }
        }

        if ($commandResult -and $commandResult.ExitCode -eq 0) {
            Write-Success "Successfully installed $($Dependency.Name) via $Manager"
            return $true
        }

        if ($commandResult) {
            Write-Warning "Failed to install $($Dependency.Name) via $Manager"
            if ($commandResult.Output) {
                Write-Warning $commandResult.Output
            }
        } else {
            Write-Warning "Failed to install $($Dependency.Name) via $Manager"
        }

        return $false

    } catch {
        Write-ErrorMessage "Error installing $($Dependency.Name) via ${Manager}: $($_.Exception.Message)"
        return $false
    }
}

function Install-Dependency {
    param($Dependency)

    Write-Info "Installing $($Dependency.Name): $($Dependency.Description)"

    # Check available package managers
    $availableManagers = @()
    $managerCandidates = @('scoop', 'winget', 'choco', 'brew', 'apt', 'dnf', 'pacman')

    foreach ($candidate in $managerCandidates) {
        if (-not (Test-PackageManager $candidate)) {
            continue
        }

        $packageAvailable = switch ($candidate) {
            'scoop' { $Dependency.ScoopPackage }
            'winget' { $Dependency.WingetPackage }
            'choco' { $Dependency.ChocoPackage }
            'brew' { $Dependency.BrewPackage }
            'apt' { $Dependency.AptPackage }
            'dnf' { $Dependency.DnfPackage }
            'pacman' { $Dependency.PacmanPackage }
            default { $null }
        }

        if ($packageAvailable) {
            $availableManagers += $candidate
        }
    }

    $portableAvailable = $false
    if ($Dependency.PortableAssets) {
        $portableAvailable = $null -ne $Dependency.PortableAssets[$script:CurrentPlatform]
    }

    if ($availableManagers.Count -gt 0) {
        $managerList = $availableManagers -join ', '
        Write-Info "Available package managers: $managerList"

        if (-not $Force) {
            Write-Host "`nInstallation options for $($Dependency.Name):" -ForegroundColor Yellow
            Write-Host "$($Dependency.PackageManagerInfo.Description)" -ForegroundColor Gray
            Write-Host ''

            $choiceOptions = @()
            foreach ($manager in $availableManagers) {
                $info = $Dependency.PackageManagerInfo.$manager
                $label = if ($info) { "$manager - $info" } else { $manager }
                $choiceOptions += [pscustomobject]@{
                    Label = $label
                    Type = 'manager'
                    Value = $manager
                }
            }

            if ($portableAvailable) {
                $choiceOptions += [pscustomobject]@{
                    Label = 'Portable installation (with SHA256 verification)'
                    Type = 'portable'
                    Value = $null
                }
            }

            for ($i = 0; $i -lt $choiceOptions.Count; $i++) {
                Write-Host "  $($i + 1). $($choiceOptions[$i].Label)" -ForegroundColor Gray
            }
            Write-Host '  s. Skip this dependency' -ForegroundColor Gray

            $maxChoice = $choiceOptions.Count
            $choice = Get-UserResponse "Choose installation method (1-$maxChoice, 's')" 's'

            if ($choice -eq 's') {
                Write-Warning "Skipping $($Dependency.Name)"
                return $false
            }

            try {
                $choiceNum = [int]$choice
                if ($choiceNum -ge 1 -and $choiceNum -le $choiceOptions.Count) {
                    $selection = $choiceOptions[$choiceNum - 1]
                    if ($selection.Type -eq 'manager') {
                        return Install-DependencyPackageManager -Dependency $Dependency -Manager $selection.Value
                    } elseif ($selection.Type -eq 'portable') {
                        return Install-DependencyPortable -Dependency $Dependency
                    }
                }
            } catch {
                Write-Warning 'Invalid choice, falling back to portable installation'
            }
        } else {
            # Force mode: try package managers first, then portable
            foreach ($manager in $availableManagers) {
                if (Install-DependencyPackageManager -Dependency $Dependency -Manager $manager) {
                    return $true
                }
            }

            if ($portableAvailable) {
                return Install-DependencyPortable -Dependency $Dependency
            }
        }
    }

    # Fallback to portable installation
    if ($portableAvailable) {
        return Install-DependencyPortable -Dependency $Dependency
    } else {
        Write-ErrorMessage "No installation method available for $($Dependency.Name)"
        return $false
    }
}

function Get-ModulePaths {
    $scriptPath = $PSScriptRoot
    if (-not $scriptPath) {
        $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    }

    return @{
        'QuickJump' = Join-PathSegments -Segments @($scriptPath, 'Modules', 'QuickJump')
        'Templater' = Join-PathSegments -Segments @($scriptPath, 'Modules', 'Templater')
        'Unitea' = Join-PathSegments -Segments @($scriptPath, 'Modules', 'Unitea')
    }
}

function Import-ModulesInProfile {
    Write-Warning 'PROFILE MODIFICATION NOTICE:'
    Write-Warning "This will modify your PowerShell profile at: $PROFILE"
    Write-Warning 'A backup will be created before any changes'

    $profileConfirm = Get-UserResponse "Do you want to modify your PowerShell profile? Type 'YES' to confirm" 'NO'
    if ($profileConfirm -ne 'YES') {
        Write-Warning 'Profile modification cancelled by user'
        return $false
    }

    $modulePaths = Get-ModulePaths

    # Validate all modules exist
    $missingModules = @()
    foreach ($module in $modulePaths.Keys) {
        if (-not (Test-Path $modulePaths[$module])) {
            $missingModules += $module
        }
    }

    if ($missingModules.Count -gt 0) {
        $missingList = $missingModules -join ', '
        Write-ErrorMessage "Missing modules: $missingList"
        return $false
    }

    # Check if profile exists
    if (-not (Test-Path $PROFILE)) {
        Write-Info "Creating PowerShell profile at: $PROFILE"
        $profileDir = Split-Path $PROFILE -Parent
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }

    # Create backup of existing profile
    if (Test-Path $PROFILE) {
        $backupPath = "$PROFILE.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $PROFILE $backupPath
        Write-Info "Profile backed up to: $backupPath"
    }

    $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if (-not $profileContent) { $profileContent = '' }

    $importBlock = @'

    # PowerShell Magic Modules - Auto-generated by Setup-PowerShellMagic.ps1
    $PowerShellMagicPath = "SCRIPT_PATH_PLACEHOLDER"

    $modulesRoot = Join-Path $PowerShellMagicPath 'Modules'

    # Import QuickJump - Fast directory navigation
    $quickJumpPath = Join-Path $modulesRoot 'QuickJump'
    if (Test-Path $quickJumpPath) {
        Import-Module $quickJumpPath -Force
    }

    # Import Templater - Template management
    $templaterPath = Join-Path $modulesRoot 'Templater'
    if (Test-Path $templaterPath) {
        Import-Module $templaterPath -Force
    }

    # Import Unitea - Unity project management
    $uniteaPath = Join-Path $modulesRoot 'Unitea'
    if (Test-Path $uniteaPath) {
        Import-Module $uniteaPath -Force
    }

    Write-Host 'PowerShell Magic modules loaded!' -ForegroundColor Magenta
    Write-Host "- QuickJump: Use 'qj' for fast directory navigation" -ForegroundColor Gray
    Write-Host "- Templater: Use 'templates' for project templates" -ForegroundColor Gray
    Write-Host "- Unitea: Use 'unity' for Unity project management" -ForegroundColor Gray
    # End PowerShell Magic Modules

'@

    $importBlock = $importBlock.Replace('SCRIPT_PATH_PLACEHOLDER', ($PSScriptRoot -replace '\\', '\\'))

    # Check if already imported
    if ($profileContent -like '*PowerShell Magic Modules*') {
        if (-not $Force) {
            $choice = Get-UserResponse 'PowerShell Magic modules already in profile. Update? (Y/n)' 'n'
            if ($choice -match '^[Nn]') {
                Write-Info 'Skipping profile update'
                return $true
            }
        }

        # Remove existing block and add new one
        $lines = $profileContent -split [Environment]::NewLine
        $newLines = @()
        $skipping = $false

        foreach ($line in $lines) {
            if ($line -like '*PowerShell Magic Modules - Auto-generated*') {
                $skipping = $true
                continue
            }
            if ($skipping -and $line -like '*End PowerShell Magic Modules*') {
                $skipping = $false
                continue
            }
            if (-not $skipping) {
                $newLines += $line
            }
        }

        $profileContent = $newLines -join [Environment]::NewLine
    }

    # Add the import block
    $newProfileContent = $profileContent.TrimEnd() + $importBlock

    try {
        Set-Content -Path $PROFILE -Value $newProfileContent -Encoding UTF8
        Write-Success "Added PowerShell Magic modules to profile: $($PROFILE)"

        # Test import
        Write-Info 'Testing module imports...'
        foreach ($module in $modulePaths.Keys) {
            try {
                Import-Module $modulePaths[$module] -Force -ErrorAction Stop
                Write-Success "$module module imported successfully"
            } catch {
                Write-ErrorMessage "Failed to import $module module: $($_.Exception.Message)"
            }
        }

        return $true

    } catch {
        Write-ErrorMessage "Failed to update profile: $($_.Exception.Message)"
        return $false
    }
}

function Show-Summary {
    param($Results)

    Write-Host ("`n" + ('=' * 60)) -ForegroundColor Cyan
    Write-Host '            SETUP COMPLETE' -ForegroundColor Cyan
    Write-Host ('=' * 60) -ForegroundColor Cyan

    Write-Host "`nInstalled Dependencies:" -ForegroundColor Green
    foreach ($dep in $Dependencies.Keys) {
        $dependency = $Dependencies[$dep]
        $status = if ($Results.Dependencies[$dep]) { '[OK]' } else { '[FAIL]' }
        $color = if ($Results.Dependencies[$dep]) { 'Green' } else { 'Red' }
        Write-Host "  $status $($dependency.Name)" -ForegroundColor $color
        if ($dependency.Note) {
            Write-Host "    $($dependency.Note)" -ForegroundColor Gray
        }
    }

    Write-Host "`nAvailable Modules:" -ForegroundColor Green
    Write-Host '  [OK] QuickJump - Fast directory navigation with aliases and categories' -ForegroundColor Green
    Write-Host '    Commands: qj, qja, qjl, qjr, qjc, qjrecent' -ForegroundColor Gray
    Write-Host '  [OK] Templater - Project template management with archive support' -ForegroundColor Green
    Write-Host '    Commands: templates, add-tpl, use-tpl, remove-tpl' -ForegroundColor Gray
    Write-Host '  [OK] Unitea - Unity project management and launcher' -ForegroundColor Green
    Write-Host '    Commands: unity, unity-add, unity-list, unity-remove, unity-recent' -ForegroundColor Gray

    if ($Results.ProfileImported) {
        Write-Host "`n[OK] Modules imported into PowerShell profile" -ForegroundColor Green
        Write-Host "  Restart PowerShell or run: . `$PROFILE" -ForegroundColor Gray
    }

    Write-Host "`nNext Steps:" -ForegroundColor Yellow
    Write-Host '  1. Restart PowerShell to load all modules' -ForegroundColor Gray
    Write-Host "  2. Run 'Get-Help QuickJump' to learn about directory navigation" -ForegroundColor Gray
    Write-Host "  3. Run 'Get-Help Templater' to learn about template management" -ForegroundColor Gray
    Write-Host "  4. Run 'Get-Help Unitea' to learn about Unity project management" -ForegroundColor Gray
    Write-Host '  5. Check the README.md for detailed usage examples' -ForegroundColor Gray
}

# Main execution
function Main {
    Write-Host 'PowerShell Magic Setup' -ForegroundColor Cyan

    Write-Host "`nSECURITY INFORMATION:" -ForegroundColor Yellow
    Write-Host '- No elevated privileges required except for Chocolatey' -ForegroundColor Gray
    Write-Host '- Downloads are optional and require explicit confirmation' -ForegroundColor Gray
    Write-Host '- Profile modifications create automatic backups' -ForegroundColor Gray
    Write-Host '- All changes are reversible' -ForegroundColor Gray

    $consent = Get-UserResponse "`nProceed with setup? (Y/n)" 'n'
    if ($consent -match '^[Nn]') {
        Write-Warning 'Setup cancelled by user'
        return
    }

    $results = @{
        Dependencies = @{}
        ProfileImported = $false
    }

    # Dependency checking and installation
    if (-not $SkipDependencyCheck) {
        Write-Host "`nScanning dependencies..." -ForegroundColor Yellow

        foreach ($depKey in $Dependencies.Keys) {
            $dependency = $Dependencies[$depKey]

            Write-Host "`nChecking $($dependency.Name)..." -ForegroundColor Gray

            if (Test-Dependency $dependency) {
                Write-Success "$($dependency.Name) is already installed"
                $results.Dependencies[$depKey] = $true
            } else {
                if ($dependency.Required -or $Force) {
                    $requiredModules = $dependency.Modules -join ', '
                    Write-Warning "$($dependency.Name) not found - required for: $requiredModules"
                    if ($dependency.Note) {
                        Write-Host "  Note: $($dependency.Note)" -ForegroundColor Gray
                    }

                    if (-not $Force) {
                        $install = Get-UserResponse "Install $($dependency.Name)? (Y/n)" 'n'
                        if ($install -match '^[Nn]') {
                            Write-Warning "Skipping $($dependency.Name)"
                            $results.Dependencies[$depKey] = $false
                            continue
                        }
                    }

                    $results.Dependencies[$depKey] = Install-Dependency $dependency
                } else {
                    $moduleList = $dependency.Modules -join ', '
                    Write-Info "$($dependency.Name) not found (optional for: $moduleList)"
                    if ($dependency.Note) {
                        Write-Host "  Note: $($dependency.Note)" -ForegroundColor Gray
                    }

                    $install = Get-UserResponse "Install optional $($dependency.Name)? (y/N)" 'N'
                    if ($install -match '^[Yy]') {
                        $results.Dependencies[$depKey] = Install-Dependency $dependency
                    } else {
                        $results.Dependencies[$depKey] = $false
                    }
                }
            }
        }
    } else {
        Write-Info 'Skipping dependency check as requested'
        foreach ($depKey in $Dependencies.Keys) {
            $results.Dependencies[$depKey] = Test-Dependency $Dependencies[$depKey]
        }
    }

    # Profile import
    if (-not $SkipProfileImport) {
        Write-Host "`nConfiguring PowerShell profile..." -ForegroundColor Yellow

        if (-not $Force) {
            $importChoice = Get-UserResponse 'Import modules into your PowerShell profile? (Y/n)' 'n'
            if ($importChoice -match '^[Nn]') {
                Write-Info 'Skipping profile import'
            } else {
                $results.ProfileImported = Import-ModulesInProfile
            }
        } else {
            $results.ProfileImported = Import-ModulesInProfile
        }
    } else {
        Write-Info 'Skipping profile import as requested'
    }

    # Show summary
    Show-Summary $results
}

# Run main function or manifest export
if ($ListPortableDownloads) {
    Show-PortableDownloads
} else {
    Main
}
