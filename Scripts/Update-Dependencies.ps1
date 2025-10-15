#Requires -Version 5.1

<#
.SYNOPSIS
Automated dependency update script for PowerShell Magic.

.DESCRIPTION
This script checks for the latest versions of dependencies used by PowerShell Magic,
downloads them to verify SHA256 hashes, and updates the Setup-PowerShellMagic.ps1 file
with new URLs and checksums.

Supported dependencies:
- fzf (fuzzy finder)
- 7-Zip (archive extraction)
- eza (modern ls replacement)

.PARAMETER CheckOnly
Only check for updates without applying them. Sets UPDATES_AVAILABLE environment variable.

.PARAMETER Apply
Apply the updates to Setup-PowerShellMagic.ps1 file.

.PARAMETER Force
Force update even if versions appear the same.

.EXAMPLE
.\Update-Dependencies.ps1 -CheckOnly
Check for updates without applying them

.EXAMPLE
.\Update-Dependencies.ps1 -Apply
Apply available updates to the setup script
#>

[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [switch]$Apply,
    [switch]$Force
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

$script:DependencyUserAgent = 'PowerShellMagic-DependencyUpdater/1.0 (+https://github.com/jason-storey/powershell-magic)'
$script:DefaultAcceptLanguages = 'en-US,en;q=0.9'

function Reset-DependencyHttpInvoker {
    $script:InvokeRestMethodDelegate = {
        param($parameters)
        Invoke-RestMethod @parameters
    }

    $script:InvokeWebRequestDelegate = {
        param($parameters)
        Invoke-WebRequest @parameters
    }
}

Reset-DependencyHttpInvoker

function Set-DependencyHttpInvoker {
    param(
        [ScriptBlock]$RestMethod,
        [ScriptBlock]$WebRequest,
        [switch]$Reset
    )

    if ($Reset) {
        Reset-DependencyHttpInvoker
        return
    }

    if ($PSBoundParameters.ContainsKey('RestMethod')) {
        $script:InvokeRestMethodDelegate = $RestMethod
    }

    if ($PSBoundParameters.ContainsKey('WebRequest')) {
        $script:InvokeWebRequestDelegate = $WebRequest
    }
}

function Get-DependencyHttpHeaders {
    param(
        [string]$Accept = '*/*',
        [hashtable]$AdditionalHeaders
    )

    $headers = [ordered]@{
        'User-Agent' = $script:DependencyUserAgent
        'Accept' = $Accept
        'Accept-Language' = $script:DefaultAcceptLanguages
    }

    if ($AdditionalHeaders) {
        foreach ($key in $AdditionalHeaders.Keys) {
            $headers[$key] = $AdditionalHeaders[$key]
        }
    }

    return $headers
}

function Invoke-DependencyRestMethod {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [string]$Accept = 'application/json',

        [hashtable]$AdditionalHeaders
    )

    $headers = Get-DependencyHttpHeaders -Accept $Accept -AdditionalHeaders $AdditionalHeaders
    $parameters = @{
        Uri = $Uri
        Headers = $headers
        ErrorAction = 'Stop'
        Method = 'GET'
    }

    return & $script:InvokeRestMethodDelegate $parameters
}

function Invoke-DependencyWebRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [string]$Accept = 'text/html,application/xhtml+xml',

        [hashtable]$AdditionalHeaders,

        [switch]$DisableRedirect
    )

    $headers = Get-DependencyHttpHeaders -Accept $Accept -AdditionalHeaders $AdditionalHeaders

    $parameters = @{
        Uri = $Uri
        Headers = $headers
        ErrorAction = 'Stop'
    }

    if ($DisableRedirect) {
        $parameters.MaximumRedirection = 0
    }

    if ($PSVersionTable.PSVersion.Major -lt 6) {
        $parameters.UseBasicParsing = $true
    }

    return & $script:InvokeWebRequestDelegate $parameters
}

function Get-GitHubLatestReleaseTag {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Repository
    )

    $apiUri = "https://api.github.com/repos/$Repository/releases/latest"

    try {
        $additionalHeaders = @{
            'Accept' = 'application/vnd.github+json'
            'X-GitHub-Api-Version' = '2022-11-28'
        }

        $response = Invoke-DependencyRestMethod -Uri $apiUri -Accept 'application/vnd.github+json' -AdditionalHeaders $additionalHeaders
        if ($response -and $response.tag_name) {
            return $response.tag_name
        }

        Write-WarningMessage "GitHub API response for '$Repository' did not include a tag_name. Falling back to HTML parsing."
    } catch {
        Write-WarningMessage "GitHub API request for '$Repository' failed: $($_.Exception.Message). Falling back to HTML parsing."
    }

    $fallbackUri = "https://github.com/$Repository/releases/latest"

    try {
        $webResponse = Invoke-DependencyWebRequest -Uri $fallbackUri -Accept 'text/html,application/xhtml+xml'
        $redirectUri = $null

        if ($webResponse.BaseResponse -and $webResponse.BaseResponse.ResponseUri) {
            $redirectUri = $webResponse.BaseResponse.ResponseUri.AbsoluteUri
        }

        if (-not $redirectUri -and $webResponse.Headers -and $webResponse.Headers['Location']) {
            $redirectUri = $webResponse.Headers['Location']
        }

        if ($redirectUri) {
            $match = [regex]::Match($redirectUri, '/releases/tag/(?<tag>[^/]+)$')
            if ($match.Success) {
                return $match.Groups['tag'].Value
            }
        }

        if ($webResponse.Content) {
            $match = [regex]::Match($webResponse.Content, 'releases/tag/(?<tag>[^"''\s]+)')
            if ($match.Success) {
                return $match.Groups['tag'].Value
            }
        }

        Write-WarningMessage "GitHub fallback response for '$Repository' did not include a release tag."
    } catch {
        Write-WarningMessage "GitHub fallback request for '$Repository' failed: $($_.Exception.Message)"
    }

    return $null
}

# Dependency update definitions
$DependencyUpdaters = @{
    'fzf' = @{
        Name = 'fzf'
        GitHubRepo = 'junegunn/fzf'
        AssetPattern = 'fzf-*-windows_amd64.zip'
        CurrentUrlPattern = 'https://github.com/junegunn/fzf/releases/download/v*/fzf-*-windows_amd64.zip'
        GetLatestVersion = {
            $tag = Get-GitHubLatestReleaseTag -Repository 'junegunn/fzf'
            return $tag.TrimStart('v')
        }
        BuildUrl = {
            param($Version)
            return "https://github.com/junegunn/fzf/releases/download/v$Version/fzf-$Version-windows_amd64.zip"
        }
    }
    '7zip' = @{
        Name = '7-Zip'
        GetLatestVersion = {
            # 7-Zip doesn't have a proper API, so we scrape the download page with a fallback mirror
            $primaryUri = "https://www.7-zip.org/download.html"
            $fallbackUri = "https://sourceforge.net/projects/sevenzip/files/7-Zip/"
            $pageContent = $null

            try {
                $response = Invoke-DependencyWebRequest -Uri $primaryUri -Accept 'text/html,application/xhtml+xml'
                $pageContent = $response.Content
            } catch {
                Write-WarningMessage "Failed to fetch primary 7-Zip metadata: $($_.Exception.Message). Trying fallback mirror."
                try {
                    $fallbackResponse = Invoke-DependencyWebRequest -Uri $fallbackUri -Accept 'text/html,application/xhtml+xml'
                    $pageContent = $fallbackResponse.Content
                } catch {
                    Write-WarningMessage "Failed to fetch fallback 7-Zip metadata: $($_.Exception.Message)"
                    return $null
                }
            }

            if (-not $pageContent) {
                Write-WarningMessage 'Unable to retrieve 7-Zip version metadata from all sources.'
                return $null
            }

            $versionMatch = [regex]::Match($pageContent, 'href="a/7z(?<version>\d+)-x64\.exe"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($versionMatch.Success) {
                return $versionMatch.Groups['version'].Value
            }

            $secondaryMatch = [regex]::Match($pageContent, '7z(?<version>\d+)-x64\.exe', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($secondaryMatch.Success) {
                return $secondaryMatch.Groups['version'].Value
            }

            Write-WarningMessage 'Unable to parse 7-Zip version from download metadata.'
            return $null
        }
        BuildUrl = {
            param($Version)
            return "https://www.7-zip.org/a/7z$Version-x64.exe"
        }
    }
    'eza' = @{
        Name = 'eza'
        GitHubRepo = 'eza-community/eza'
        AssetPattern = 'eza.exe_x86_64-pc-windows-gnu.zip'
        CurrentUrlPattern = 'https://github.com/eza-community/eza/releases/download/v*/eza.exe_x86_64-pc-windows-gnu.zip'
        GetLatestVersion = {
            $tag = Get-GitHubLatestReleaseTag -Repository 'eza-community/eza'
            return $tag.TrimStart('v')
        }
        BuildUrl = {
            param($Version)
            return "https://github.com/eza-community/eza/releases/download/v$Version/eza.exe_x86_64-pc-windows-gnu.zip"
        }
    }
}

function Get-CurrentDependencies {
    <#
    .SYNOPSIS
    Parse the current dependencies from Setup-PowerShellMagic.ps1
    #>

    $setupScript = Join-Path $PSScriptRoot "..\Setup-PowerShellMagic.ps1"
    if (-not (Test-Path $setupScript)) {
        throw "Setup-PowerShellMagic.ps1 not found at: $setupScript"
    }

    $content = Get-Content $setupScript -Raw
    $dependencies = @{}

    # Parse fzf dependency
    if ($content -match "PortableUrl = '(https://github\.com/junegunn/fzf/releases/download/v([^/]+)/[^']+)'") {
        $dependencies['fzf'] = @{
            Url = $matches[1]
            Version = $matches[2]
        }

        if ($content -match "'fzf'[^}]+PortableSHA256 = '([A-F0-9]+)'") {
            $dependencies['fzf'].SHA256 = $matches[1]
        }
    }

    # Parse 7-Zip dependency
    if ($content -match "PortableUrl = '(https://www\.7-zip\.org/a/7z(\d+)-x64\.exe)'") {
        $dependencies['7zip'] = @{
            Url = $matches[1]
            Version = $matches[2]
        }

        if ($content -match "'7zip'[^}]+PortableSHA256 = '([A-F0-9]+)'") {
            $dependencies['7zip'].SHA256 = $matches[1]
        }
    }

    # Parse eza dependency
    if ($content -match "PortableUrl = '(https://github\.com/eza-community/eza/releases/download/v([^/]+)/[^']+)'") {
        $dependencies['eza'] = @{
            Url = $matches[1]
            Version = $matches[2]
        }

        if ($content -match "'eza'[^}]+PortableSHA256 = '([a-f0-9]+)'") {
            $dependencies['eza'].SHA256 = $matches[1].ToUpper()
        }
    }

    return $dependencies
}

function Get-FileHash-Remote {
    <#
    .SYNOPSIS
    Download a file temporarily and calculate its SHA256 hash
    #>
    param(
        [string]$Url,
        [string]$DependencyName
    )

    $tempFile = Join-Path $env:TEMP "$DependencyName-$(Get-Date -Format 'yyyyMMddHHmmss').tmp"

    try {
        Write-Info "Downloading $DependencyName from $Url to verify hash..."

        # Download with progress
        $progressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'

        try {
            $downloadHeaders = Get-DependencyHttpHeaders -Accept 'application/octet-stream'
            $invokeParams = @{
                Uri = $Url
                OutFile = $tempFile
                Headers = $downloadHeaders
                ErrorAction = 'Stop'
            }

            if ($PSVersionTable.PSVersion.Major -lt 6) {
                $invokeParams.UseBasicParsing = $true
            }

            Invoke-WebRequest @invokeParams
        } finally {
            $ProgressPreference = $progressPreference
        }

        if (-not (Test-Path $tempFile)) {
            throw "Download failed - file not created"
        }

        $hash = Get-FileHash -Path $tempFile -Algorithm SHA256 -ErrorAction Stop
        Write-Success "Successfully calculated hash for $DependencyName"
        return $hash.Hash

    } catch {
        Write-ErrorMessage "Failed to download and hash $DependencyName from $Url`: $($_.Exception.Message)"
        return $null
    } finally {
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Test-DependencyUpdates {
    <#
    .SYNOPSIS
    Check if any dependencies have updates available
    #>

    Write-Info "Checking for dependency updates..."

    $currentDeps = Get-CurrentDependencies
    $updatesAvailable = @{}
    $summary = @()

    foreach ($depKey in $DependencyUpdaters.Keys) {
        $updater = $DependencyUpdaters[$depKey]
        $currentDep = $currentDeps[$depKey]

        if (-not $currentDep) {
            Write-WarningMessage "No current dependency found for $($updater.Name)"
            continue
        }

        Write-Info "Checking $($updater.Name)..."

        try {
            $latestVersion = & $updater.GetLatestVersion

            if (-not $latestVersion) {
                Write-WarningMessage "Could not determine latest version for $($updater.Name)"
                continue
            }

            Write-Info "Current: $($currentDep.Version), Latest: $latestVersion"

            if ($currentDep.Version -ne $latestVersion -or $Force) {
                $newUrl = & $updater.BuildUrl $latestVersion
                $newHash = Get-FileHash-Remote -Url $newUrl -DependencyName $updater.Name

                if ($newHash) {
                    $updatesAvailable[$depKey] = @{
                        Name = $updater.Name
                        CurrentVersion = $currentDep.Version
                        LatestVersion = $latestVersion
                        CurrentUrl = $currentDep.Url
                        NewUrl = $newUrl
                        CurrentHash = $currentDep.SHA256
                        NewHash = $newHash
                    }

                    $summary += "- $($updater.Name): $($currentDep.Version) -> $latestVersion"
                    Write-Success "$($updater.Name) update available: $($currentDep.Version) -> $latestVersion"
                } else {
                    Write-ErrorMessage "Failed to verify new version of $($updater.Name)"
                }
            } else {
                Write-Success "$($updater.Name) is up to date"
            }
        } catch {
            Write-ErrorMessage "Error checking $($updater.Name): $($_.Exception.Message)"
        }
    }

    # Save summary for GitHub Actions
    if ($summary.Count -gt 0) {
        $summaryText = $summary -join "`n"
        Set-Content -Path "dependency-update-summary.txt" -Value $summaryText
        $env:UPDATES_AVAILABLE = "true"
        Write-Info "Updates available: $($updatesAvailable.Count) dependencies"
    } else {
        $env:UPDATES_AVAILABLE = "false"
        Write-Info "No updates available"
    }

    return $updatesAvailable
}

function Update-SetupScript {
    <#
    .SYNOPSIS
    Apply dependency updates to Setup-PowerShellMagic.ps1
    #>
    param(
        [hashtable]$Updates
    )

    $setupScript = Join-Path $PSScriptRoot "..\Setup-PowerShellMagic.ps1"

    if (-not (Test-Path $setupScript)) {
        throw "Setup-PowerShellMagic.ps1 not found at: $setupScript"
    }

    Write-Info "Updating Setup-PowerShellMagic.ps1..."

    # Create backup
    $backupPath = "$setupScript.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $setupScript $backupPath
    Write-Info "Backup created at: $backupPath"

    $content = Get-Content $setupScript -Raw
    $templaterModulePath = Join-Path $PSScriptRoot "..\Modules\Templater\Templater.psm1"
    $templaterContent = $null
    $templaterUpdated = $false

    foreach ($depKey in $Updates.Keys) {
        $update = $Updates[$depKey]

        Write-Info "Updating $($update.Name)..."

        # Update URL
        $content = $content.Replace($update.CurrentUrl, $update.NewUrl)

        # Update SHA256 hash
        $content = $content.Replace($update.CurrentHash, $update.NewHash)

        Write-Success "Updated $($update.Name): $($update.CurrentVersion) -> $($update.LatestVersion)"

        if ($depKey -eq '7zip' -and (Test-Path $templaterModulePath)) {
            if (-not $templaterContent) {
                $templaterContent = Get-Content $templaterModulePath -Raw
            }

            $originalModuleContent = $templaterContent
            $newHashValue = $update.NewHash
            $pattern = "(\$script:Managed7ZipHash = ')[A-F0-9]+'"
            $templaterContent = [System.Text.RegularExpressions.Regex]::Replace(
                $templaterContent,
                $pattern,
                { param($m) "{0}{1}'" -f $m.Groups[1].Value, $newHashValue }
            )

            if ($templaterContent -ne $originalModuleContent) {
                $templaterUpdated = $true
                Write-Success "Updated Templater managed 7-Zip hash"
            } else {
                Write-Warning "Failed to update managed 7-Zip hash in Templater module automatically."
            }
        }
    }

    # Write updated content
    Set-Content -Path $setupScript -Value $content -Encoding UTF8
    Write-Success "Setup script updated successfully"

    if ($templaterUpdated -and $templaterContent) {
        Set-Content -Path $templaterModulePath -Value $templaterContent -Encoding UTF8
    }
}

function Main {
    try {
        if ($CheckOnly) {
            Write-Info "Running in check-only mode..."
            $updates = Test-DependencyUpdates

            if ($updates.Count -gt 0) {
                Write-Success "Found $($updates.Count) dependency updates available"
                exit 0
            } else {
                Write-Info "No dependency updates available"
                exit 0
            }
        }

        if ($Apply) {
            Write-Info "Applying dependency updates..."
            $updates = Test-DependencyUpdates

            if ($updates.Count -gt 0) {
                Update-SetupScript -Updates $updates
                Write-Success "All dependency updates applied successfully"
                exit 0
            } else {
                Write-Info "No updates to apply"
                exit 0
            }
        }

        # Default behavior: check for updates and show what would be done
        Write-Info "Checking for available dependency updates..."
        $updates = Test-DependencyUpdates

        if ($updates.Count -gt 0) {
            Write-Host "`nUpdates available:" -ForegroundColor Yellow
            foreach ($depKey in $updates.Keys) {
                $update = $updates[$depKey]
                Write-Host "  $($update.Name): $($update.CurrentVersion) -> $($update.LatestVersion)" -ForegroundColor Green
                Write-Host "    URL: $($update.NewUrl)" -ForegroundColor Gray
                Write-Host "    SHA256: $($update.NewHash)" -ForegroundColor Gray
            }
            Write-Host "`nRun with -Apply to update the setup script" -ForegroundColor Cyan
        } else {
            Write-Success "All dependencies are up to date!"
        }

    } catch {
        Write-ErrorMessage "Script failed: $($_.Exception.Message)"
        exit 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    # Run main function when executed normally (not dot-sourced)
    Main
}
