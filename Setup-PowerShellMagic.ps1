#Requires -Version 5.1

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
Run in non-interactive mode, automatically answering 'n' to all prompts

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
#>

[CmdletBinding()]
param(
    [switch]$SkipDependencyCheck,
    [switch]$SkipProfileImport,
    [switch]$Force,
    [string]$InstallLocation = (Join-Path $env:LOCALAPPDATA 'PowerShellMagic'),
    [switch]$NonInteractive
)

# Color output functions
function Write-Success {
    param($Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}
function Write-Info {
    param($Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}
function Write-Warning {
    param($Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}
function Write-Error {
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
        Write-Info "Non-interactive mode: Auto-answering '$DefaultResponse' for: $Prompt"
        return $DefaultResponse
    } else {
        return Read-Host $Prompt
    }
}

# Dependency definitions with cryptographic verification
# NOTE: Update PortableSHA256 hashes before distribution by:
# 1. Download the file manually
# 2. Run: Get-FileHash -Path "downloaded-file" -Algorithm SHA256
# 3. Replace PortableSHA256 with the actual hash
$Dependencies = @{
    'fzf' = @{
        Name = 'fzf'
        Description = 'Fuzzy finder for interactive selection'
        TestCommand = 'fzf --version'
        PortableUrl = 'https://github.com/junegunn/fzf/releases/download/v0.54.3/fzf-0.54.3-windows_amd64.zip'
        PortableSHA256 = '604D11B1C36D03675DE80D598DFE8A3EBA4F8607E0D8BBCC63734EFFDE209BB6'
        PortableExe = 'fzf.exe'
        ScoopPackage = 'fzf'
        ChocoPackage = 'fzf'
        WingetPackage = 'junegunn.fzf'
        Required = $true
        Modules = @('QuickJump', 'Templater', 'Unitea')
        PackageManagerInfo = @{
            Description = 'Package managers provide automatic verification and updates'
            Scoop = 'Community-maintained, JSON manifests with checksums'
            Chocolatey = 'Community packages with moderation and checksums'
            Winget = 'Microsoft-backed with package verification'
        }
    }
    '7zip' = @{
        Name = '7-Zip'
        Description = 'Archive extraction tool'
        TestCommand = '7z'
        PortableUrl = 'https://www.7-zip.org/a/7z2407-x64.exe'
        PortableSHA256 = 'AD12CEC3A3957FF73A689E0D65A05B6328C80FD76336A1B1A6285335F8DAB1BA'
        ScoopPackage = '7zip'
        ChocoPackage = '7zip'
        WingetPackage = '7zip.7zip'
        Required = $false
        Modules = @('Templater')
        Note = 'Required for archive template extraction in Templater'
        PackageManagerInfo = @{
            Description = 'Package managers provide automatic verification and updates'
            Scoop = 'Community-maintained with checksums from official releases'
            Chocolatey = 'Official 7-Zip package with verification'
            Winget = 'Microsoft-verified official 7-Zip package'
        }
    }
    'eza' = @{
        Name = 'eza'
        Description = 'Modern ls replacement with better directory previews'
        TestCommand = 'eza --version'
        PortableUrl = 'https://github.com/eza-community/eza/releases/download/v0.23.3/eza.exe_x86_64-pc-windows-gnu.zip'
        PortableSHA256 = '032963c3d47134d7976f8e17b0201efcff09fdcc7742d8a0db2135b38c8ce1f8'
        PortableExe = 'eza.exe'
        ScoopPackage = 'eza'
        ChocoPackage = 'eza'
        WingetPackage = 'eza-community.eza'
        Required = $false
        Modules = @('QuickJump')
        Note = 'Optional: Provides enhanced directory previews in QuickJump fzf selection'
        PackageManagerInfo = @{
            Description = 'Package managers provide automatic verification and updates'
            Scoop = 'Community-maintained with GitHub release checksums'
            Chocolatey = 'Community package with automatic checksum verification'
            Winget = 'Community-maintained with Microsoft verification'
        }
    }
}

function Test-IsElevated {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-FileHash {
    param(
        [string]$FilePath,
        [string]$ExpectedHash,
        [string]$Algorithm = 'SHA256'
    )

    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return $false
    }

    if ($ExpectedHash -like 'NOTE:*') {
        Write-Warning 'No checksum available for verification'
        Write-Warning "$ExpectedHash"
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
            Write-Error 'CRYPTOGRAPHIC VERIFICATION FAILED!'
            Write-Error "Expected: $ExpectedHash"
            Write-Error "Actual:   $($actualHash.Hash)"
            Write-Error 'This could indicate file corruption or tampering.'
        }

        return $hashMatch
    } catch {
        Write-Error "Failed to calculate file hash: $($_.Exception.Message)"
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
    }
    return $false
}

function Test-Dependency {
    param($Dependency)

    try {
        $testCmd = $Dependency.TestCommand
        if ($testCmd -like '*7z*') {
            # Special handling for 7zip which might be 7z.exe or 7z
            try {
                $null = & 7z.exe | Out-Null
                return $true
            } catch {
                try {
                    $null = & 7z | Out-Null
                    return $true
                } catch {
                    return $false
                }
            }
        } else {
            $null = Invoke-Expression "$testCmd 2>&1" -ErrorAction Stop
            return $true
        }
    } catch {
        return $false
    }
}

function Install-DependencyPortable {
    param($Dependency)

    Write-Warning "SECURITY NOTICE: This will download and execute software from: $($Dependency.PortableUrl)"
    Write-Warning 'Files are downloaded without cryptographic verification'
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

    $tempFile = Join-Path $env:TEMP "$($Dependency.Name)-portable.tmp"

    try {
        Write-Info "Downloading $($Dependency.Name) from $($Dependency.PortableUrl)..."

        # Use modern download method
        if ($PSVersionTable.PSVersion.Major -ge 3) {
            Invoke-WebRequest -Uri $Dependency.PortableUrl -OutFile $tempFile -UseBasicParsing
        } else {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Dependency.PortableUrl, $tempFile)
            $webClient.Dispose()
        }

        # Verify downloaded file
        Write-Info 'Verifying download integrity...'
        if (-not (Test-FileHash -FilePath $tempFile -ExpectedHash $Dependency.PortableSHA256)) {
            Write-Error 'File verification failed. Aborting installation.'
            return $false
        }

        if ($Dependency.PortableUrl -like '*.zip') {
            # Extract ZIP
            Write-Info "Extracting $($Dependency.Name)..."
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($tempFile, $installDir)

            # Find and move executable if needed
            if ($Dependency.PortableExe) {
                $extractedExe = Get-ChildItem -Path $installDir -Name $Dependency.PortableExe -Recurse | Select-Object -First 1
                if ($extractedExe) {
                    $finalPath = Join-Path $installDir $Dependency.PortableExe
                    if ($extractedExe.FullName -ne $finalPath) {
                        Move-Item -Path $extractedExe.FullName -Destination $finalPath -Force
                    }
                }
            }
        } elseif ($Dependency.PortableUrl -like '*.exe') {
            # Direct executable download
            $finalPath = Join-Path $installDir "$($Dependency.Name).exe"
            Move-Item -Path $tempFile -Destination $finalPath -Force
        }

        # Add to PATH if not already there
        $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
        if ($currentPath -notlike "*$installDir*") {
            Write-Warning 'About to modify your user PATH environment variable'
            Write-Info "Current PATH: $currentPath"
            Write-Info "Will add: $installDir"

            $pathConfirm = Get-UserResponse 'Add to PATH? (Y/n)' 'n'
            if ($pathConfirm -notmatch '^[Nn]') {
                Write-Info "Adding $installDir to user PATH..."
                [Environment]::SetEnvironmentVariable('PATH', "$currentPath;$installDir", 'User')
                $env:PATH += ";$installDir"
            } else {
                Write-Warning "PATH not modified. You'll need to manually add $installDir to PATH to use $($Dependency.Name)"
            }
        }

        Write-Success "Successfully installed $($Dependency.Name) to $installDir"
        return $true

    } catch {
        Write-Error "Failed to install $($Dependency.Name): $($_.Exception.Message)"
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
        }

        if (-not $package) {
            Write-Warning "$($Dependency.Name) not available via $Manager"
            return $false
        }

        Write-Info "Installing $($Dependency.Name) via $Manager..."

        switch ($Manager) {
            'scoop' {
                $result = & scoop install $package 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Successfully installed $($Dependency.Name) via Scoop"
                    return $true
                }
            }
            'choco' {
                if (-not (Test-IsElevated)) {
                    Write-Warning 'Chocolatey requires administrator privileges'
                    return $false
                }
                $result = & choco install $package -y 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Successfully installed $($Dependency.Name) via Chocolatey"
                    return $true
                }
            }
            'winget' {
                $result = & winget install $package --accept-source-agreements --accept-package-agreements 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Successfully installed $($Dependency.Name) via Winget"
                    return $true
                }
            }
        }

        Write-Warning "Failed to install $($Dependency.Name) via $Manager"
        return $false

    } catch {
        Write-Error "Error installing $($Dependency.Name) via ${Manager}: $($_.Exception.Message)"
        return $false
    }
}

function Install-Dependency {
    param($Dependency)

    Write-Info "Installing $($Dependency.Name): $($Dependency.Description)"

    # Check available package managers
    $availableManagers = @()
    if (Test-PackageManager 'scoop') { $availableManagers += 'scoop' }
    if (Test-PackageManager 'winget') { $availableManagers += 'winget' }
    if (Test-PackageManager 'choco') { $availableManagers += 'choco' }

    if ($availableManagers.Count -gt 0) {
        $managerList = $availableManagers -join ', '
        Write-Info "Available package managers: $managerList"

        if (-not $Force) {
            Write-Host "`nInstallation options for $($Dependency.Name):" -ForegroundColor Yellow
            Write-Host "$($Dependency.PackageManagerInfo.Description)" -ForegroundColor Gray
            Write-Host ''

            for ($i = 0; $i -lt $availableManagers.Count; $i++) {
                $manager = $availableManagers[$i]
                $info = $Dependency.PackageManagerInfo.$manager
                Write-Host "  $($i + 1). $manager - $info" -ForegroundColor Gray
            }
            Write-Host "  $($availableManagers.Count + 1). Portable installation (with SHA256 verification)" -ForegroundColor Gray
            Write-Host '  s. Skip this dependency' -ForegroundColor Gray

            $maxChoice = $availableManagers.Count + 1
            $choice = Get-UserResponse "Choose installation method (1-$maxChoice, 's')" 's'

            if ($choice -eq 's') {
                Write-Warning "Skipping $($Dependency.Name)"
                return $false
            }

            try {
                $choiceNum = [int]$choice
                if ($choiceNum -ge 1 -and $choiceNum -le $availableManagers.Count) {
                    $manager = $availableManagers[$choiceNum - 1]
                    return Install-DependencyPackageManager -Dependency $Dependency -Manager $manager
                } elseif ($choiceNum -eq ($availableManagers.Count + 1)) {
                    return Install-DependencyPortable -Dependency $Dependency
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
        }
    }

    # Fallback to portable installation
    if ($Dependency.PortableUrl) {
        return Install-DependencyPortable -Dependency $Dependency
    } else {
        Write-Error "No installation method available for $($Dependency.Name)"
        return $false
    }
}

function Get-ModulePaths {
    $scriptPath = $PSScriptRoot
    if (-not $scriptPath) {
        $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    }

    return @{
        'QuickJump' = Join-Path $scriptPath 'Modules\QuickJump'
        'Templater' = Join-Path $scriptPath 'Modules\Templater'
        'Unitea' = Join-Path $scriptPath 'Modules\Unitea'
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
        Write-Error "Missing modules: $missingList"
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

    # Import QuickJump - Fast directory navigation
    if (Test-Path (Join-Path $PowerShellMagicPath 'Modules\QuickJump')) {
        Import-Module (Join-Path $PowerShellMagicPath 'Modules\QuickJump') -Force
    }

    # Import Templater - Template management
    if (Test-Path (Join-Path $PowerShellMagicPath 'Modules\Templater')) {
        Import-Module (Join-Path $PowerShellMagicPath 'Modules\Templater') -Force
    }

    # Import Unitea - Unity project management
    if (Test-Path (Join-Path $PowerShellMagicPath 'Modules\Unitea')) {
        Import-Module (Join-Path $PowerShellMagicPath 'Modules\Unitea') -Force
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
                Write-Error "Failed to import $module module: $($_.Exception.Message)"
            }
        }

        return $true

    } catch {
        Write-Error "Failed to update profile: $($_.Exception.Message)"
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

# Run main function
Main
