#requires -Version 7.0
<#
.SYNOPSIS
Bootstrapper for building/gallery-packaging PowerShell Magic modules.

.DESCRIPTION
This script will evolve into the automation entry point that stages QuickJump,
Templater, and Unitea for PowerShell Gallery publication. At present it
performs structure validation, prepares an output folder, and surfaces the
steps that the upcoming packaging pipeline must implement.

.PARAMETER Version
Overrides the module version written into manifests during packaging. When not
specified, the script will read from `build/version.json` file. If neither
source exists, the script stops with guidance.

.PARAMETER OutputPath
Directory used to stage artifacts (default: `out/packages`). It is created when
absent; existing contents are preserved for now.

.PARAMETER Release
When supplied, indicates the script is running in a release context (tagged
build/CI). Future iterations will use this to gate publishing behaviour.

.EXAMPLE
.\Scripts\Build-Modules.ps1 -Version 1.1.0
Validates the repo layout and prepares the staging directory for packaging.

.EXAMPLE
.\Scripts\Build-Modules.ps1 -Release
Dry-run packaging in a release context (version sourced from version file).
#>
[CmdletBinding()]
param(
    [string]$Version,
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\out'),
    [switch]$Release
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command Publish-Module -ErrorAction SilentlyContinue)) {
    throw 'Publish-Module is not available. Install PowerShellGet 2.2+ to build packages.'
}

function Get-VersionMetadata {
    param([string]$OverrideVersion)

    if ($OverrideVersion) {
        return [PSCustomObject]@{
            Version = $OverrideVersion
            ReleaseNotes = $null
            Source = 'Parameter'
        }
    }

    $versionFile = Join-Path $PSScriptRoot '..\build\version.json'
    if (Test-Path -LiteralPath $versionFile) {
        try {
            $json = Get-Content -Path $versionFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if (-not $json.Version) {
                throw "Version metadata in $versionFile is missing a Version property."
            }

            return [PSCustomObject]@{
                Version = [string]$json.Version
                ReleaseNotes = if ($json.ReleaseNotes) { [string]$json.ReleaseNotes } else { $null }
                Source = 'build/version.json'
            }
        } catch {
            throw "Failed to read version from ${versionFile}: $($_.Exception.Message)"
        }
    }

    throw 'Module version is required. Pass -Version or add build/version.json.'
}

function Ensure-OutputDirectory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Verbose "Creating output directory at '$Path'."
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-ModuleManifests {
    $manifestPaths = @(
        'Modules/QuickJump/QuickJump.psd1',
        'Modules/Templater/Templater.psd1',
        'Modules/Unitea/Unitea.psd1'
    )

    foreach ($relativePath in $manifestPaths) {
        $fullPath = Join-Path $PSScriptRoot "..\$relativePath"
        if (-not (Test-Path -LiteralPath $fullPath)) {
            throw "Expected module manifest '$relativePath' was not found."
        }

        [PSCustomObject]@{
            Name = [System.IO.Path]::GetFileNameWithoutExtension($fullPath)
            Manifest = $fullPath
            ModuleDir = Split-Path $fullPath -Parent
        }
    }
}

function Get-ReleaseNotes {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,

        [string]$DefaultNotes
    )

    if ($DefaultNotes) {
        return $DefaultNotes
    }

    $changelogPath = Join-Path $PSScriptRoot '..\CHANGELOG.md'
    if (-not (Test-Path -LiteralPath $changelogPath)) {
        return "See CHANGELOG.md for details on version $Version."
    }

    $lines = Get-Content -Path $changelogPath -ErrorAction Stop
    $pattern = '^\s*##\s*(?:\[(?<ver>[^\]]+)\]|(?<ver>\S+))'
    $collecting = $false
    $buffer = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        if ($line -match $pattern) {
            $headingVersion = $Matches['ver']
            if ($collecting) {
                break
            }

            $collecting = ($headingVersion -eq $Version)
            continue
        }

        if ($collecting) {
            $buffer.Add($line)
        }
    }

    if ($buffer.Count -eq 0) {
        return "Updates included in version $Version."
    }

    # Trim leading/trailing blank lines but keep original formatting otherwise
    while ($buffer.Count -gt 0 -and [string]::IsNullOrWhiteSpace($buffer[0])) {
        $buffer.RemoveAt(0)
    }
    while ($buffer.Count -gt 0 -and [string]::IsNullOrWhiteSpace($buffer[$buffer.Count - 1])) {
        $buffer.RemoveAt($buffer.Count - 1)
    }

    if ($buffer.Count -eq 0) {
        return "Updates included in version $Version."
    }

    return ($buffer -join [Environment]::NewLine)
}

function Escape-Psd1String {
    param([string]$Value)

    return ($Value -replace "'", "''")
}

function Compress-ReleaseNotesForManifest {
    param([string]$Notes)

    if (-not $Notes) {
        return $null
    }

    $noteLines = $Notes -split '(\r?\n)+'
    $noteLines = $noteLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if (-not $noteLines) {
        return $null
    }

    if ($noteLines -isnot [System.Array]) {
        $noteLines = @($noteLines)
    }

    $compressed = $noteLines | ForEach-Object {
        (Escape-Psd1String -Value $_.Trim())
    }

    return ($compressed -join '; ')
}

function Update-ManifestFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [string]$ReleaseNotes
    )

    $content = Get-Content -LiteralPath $ManifestPath -Raw

    if ($content -match "ModuleVersion\s*=\s*'[^']*'") {
        $content = [regex]::Replace($content, "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion = '$Version'", 1)
    } else {
        throw "Module manifest '$ManifestPath' is missing ModuleVersion."
    }

    if ($ReleaseNotes) {
        $manifestNotes = Compress-ReleaseNotesForManifest -Notes $ReleaseNotes
        if ($manifestNotes) {
            if ($content -match "ReleaseNotes\s*=\s*'([^']|'')*'") {
                $content = [regex]::Replace($content, "ReleaseNotes\s*=\s*'([^']|'')*'", "ReleaseNotes = '$manifestNotes'", 1)
            } elseif ($content -match "(LicenseUri\s*=\s*'[^']*')") {
                $content = [regex]::Replace($content, "(LicenseUri\s*=\s*'[^']*')", "`$1`n            ReleaseNotes = '$manifestNotes'", 1)
            } elseif ($content -match '(PSData\s*=\s*@\{)') {
                $content = [regex]::Replace($content, '(PSData\s*=\s*@\{)', "`$1`n            ReleaseNotes = '$manifestNotes'", 1)
            } else {
                $content = $content.TrimEnd() + "`n    ReleaseNotes = '$manifestNotes'`n"
            }
        }
    }

    Set-Content -LiteralPath $ManifestPath -Value $content -Encoding UTF8
}

function Stage-Module {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$ManifestInfo,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [string]$ReleaseNotes,

        [Parameter(Mandatory = $true)]
        [string]$OutputRoot
    )

    $targetDir = Join-Path $OutputRoot $ManifestInfo.Name
    if (Test-Path -LiteralPath $targetDir) {
        Remove-Item -Path $targetDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

    $rootModulePath = Join-Path $ManifestInfo.ModuleDir "$($ManifestInfo.Name).psm1"
    Copy-Item -LiteralPath $ManifestInfo.Manifest -Destination $targetDir -Force
    if (Test-Path -LiteralPath $rootModulePath) {
        Copy-Item -LiteralPath $rootModulePath -Destination $targetDir -Force
    }

    foreach ($subdir in @('Private', 'Public')) {
        $sourceDir = Join-Path $ManifestInfo.ModuleDir $subdir
        if (Test-Path -LiteralPath $sourceDir) {
            Copy-Item -LiteralPath $sourceDir -Destination $targetDir -Recurse -Force -Container
        }
    }

    $excludeDirNames = @('tests', 'docs', 'documentation', 'examples', 'sampledata')
    Get-ChildItem -Path $targetDir -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {
        $excludeDirNames -contains $_.Name.ToLowerInvariant()
    } | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

    $excludeExtensions = @('*.md', '*.markdown')
    foreach ($pattern in $excludeExtensions) {
        Get-ChildItem -Path $targetDir -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    $stagingManifest = Join-Path $targetDir (Split-Path $ManifestInfo.Manifest -Leaf)
    Update-ManifestFile -ManifestPath $stagingManifest -Version $Version -ReleaseNotes $ReleaseNotes

    return [PSCustomObject]@{
        Name = $ManifestInfo.Name
        Path = (Resolve-Path -LiteralPath $targetDir).Path
        ManifestPath = $stagingManifest
        Version = $Version
        ReleaseNotes = $ReleaseNotes
    }
}

function Publish-LocalPackage {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$ModuleInfo,

        [Parameter(Mandatory = $true)]
        [string]$PackagesRoot
    )

    $repoName = "PSMagicLocal_$([guid]::NewGuid().ToString('N'))"
    if (-not (Test-Path -LiteralPath $PackagesRoot)) {
        New-Item -ItemType Directory -Path $PackagesRoot -Force | Out-Null
    }

    $existing = Get-ChildItem -Path $PackagesRoot -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "$($ModuleInfo.Name).*" }
    if ($existing) {
        $existing | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }

    $resolvedPackagesRoot = (Resolve-Path -LiteralPath $PackagesRoot -ErrorAction Stop).ProviderPath

    Register-PSRepository -Name $repoName -SourceLocation $resolvedPackagesRoot -PublishLocation $resolvedPackagesRoot -InstallationPolicy Trusted -PackageManagementProvider 'NuGet' -ErrorAction Stop
    try {
        Publish-Module -Path $ModuleInfo.Path -Repository $repoName -ErrorAction Stop | Out-Null
    } finally {
        Unregister-PSRepository -Name $repoName -ErrorAction SilentlyContinue
    }

    $packagePath = Get-ChildItem -Path $PackagesRoot -Recurse -Filter '*.nupkg' -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "$($ModuleInfo.Name).*" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $packagePath) {
        throw "Failed to locate nupkg for module '$($ModuleInfo.Name)' after publishing."
    }

    return $packagePath.FullName
}

function Normalize-StringArray {
    param($Value)

    if (-not $Value) { return @() }

    if ($Value -is [System.Array]) {
        return @($Value | ForEach-Object { [string]$_ })
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        return @($Value | ForEach-Object { [string]$_ })
    }

    return @([string]$Value)
}

try {
    $OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

    $versionMetadata = Get-VersionMetadata -OverrideVersion $Version
    $resolvedVersion = $versionMetadata.Version
    $resolvedNotes = $null

    $stagingRoot = Join-Path $OutputPath 'staging'
    $packageRoot = Join-Path $OutputPath 'packages'

    foreach ($path in @($stagingRoot, $packageRoot)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -Path $path -Recurse -Force
        }
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }

    $manifests = Get-ModuleManifests

    $resolvedNotes = Get-ReleaseNotes -Version $resolvedVersion -DefaultNotes $versionMetadata.ReleaseNotes

    Write-Host 'PowerShell Magic build bootstrap' -ForegroundColor Cyan
    Write-Host "  Version:        $resolvedVersion" -ForegroundColor Gray
    Write-Host "  Staging folder: $((Resolve-Path $stagingRoot).Path)" -ForegroundColor Gray
    Write-Host "  Package folder: $((Resolve-Path $packageRoot).Path)" -ForegroundColor Gray
    Write-Host "  Release mode:   $([bool]$Release)" -ForegroundColor Gray
    Write-Host ''

    $stagedModules = foreach ($manifest in $manifests) {
        Stage-Module -ManifestInfo $manifest -Version $resolvedVersion -ReleaseNotes $resolvedNotes -OutputRoot $stagingRoot
    }

    Write-Host 'Staged modules:' -ForegroundColor Yellow
    foreach ($module in $stagedModules) {
        $notesPreview = if ($module.ReleaseNotes) { $module.ReleaseNotes.Split([Environment]::NewLine)[0] } else { 'Release notes pending' }
        Write-Host ('  • {0} → {1}' -f $module.Name, $module.Path) -ForegroundColor Gray
        Write-Host ('    Version {0} | {1}' -f $module.Version, $notesPreview) -ForegroundColor DarkGray
    }

    $packages = foreach ($module in $stagedModules) {
        $packagePath = Publish-LocalPackage -ModuleInfo $module -PackagesRoot $packageRoot
        [PSCustomObject]@{
            Name = $module.Name
            Manifest = $module.ManifestPath
            PackagePath = $packagePath
        }
    }

    Write-Host ''
    Write-Host 'Generated packages:' -ForegroundColor Yellow
    foreach ($pkg in $packages) {
        $hash = (Get-FileHash -Path $pkg.PackagePath -Algorithm SHA256).Hash
        Write-Host ('  • {0} => {1}' -f $pkg.Name, $pkg.PackagePath) -ForegroundColor Gray
        Write-Host ('    SHA256: {0}' -f $hash) -ForegroundColor DarkGray
    }

    $metadata = foreach ($pkg in $packages) {
        $manifestData = Import-PowerShellDataFile -LiteralPath $pkg.Manifest
        $hash = Get-FileHash -Path $pkg.PackagePath -Algorithm SHA256

        [PSCustomObject]@{
            Name = $pkg.Name
            Version = [string]$manifestData.ModuleVersion
            PackagePath = (Resolve-Path -LiteralPath $pkg.PackagePath).Path
            PackageHashSha256 = $hash.Hash
            FunctionsToExport = Normalize-StringArray $manifestData.FunctionsToExport
            AliasesToExport = Normalize-StringArray $manifestData.AliasesToExport
            Tags = if ($manifestData.PrivateData -and $manifestData.PrivateData.PSData) { Normalize-StringArray $manifestData.PrivateData.PSData.Tags } else { @() }
            ReleaseNotes = if ($manifestData.PrivateData -and $manifestData.PrivateData.PSData) { $manifestData.PrivateData.PSData.ReleaseNotes } else { $null }
            ManifestPath = (Resolve-Path -LiteralPath $pkg.Manifest).Path
        }
    }

    $metadataPath = Join-Path $packageRoot 'module-metadata.json'
    $metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $metadataPath -Encoding UTF8

    Write-Host ''
    Write-Host ('Module metadata written to {0}' -f $metadataPath) -ForegroundColor Green

    Write-Host ''
    Write-Host 'Build Summary:' -ForegroundColor Cyan
    foreach ($pkg in $packages) {
        Write-Host "  ✓ $($pkg.Name) v$versionInfo.Version" -ForegroundColor Green
        Write-Host "    Package: $($pkg.PackagePath)" -ForegroundColor Gray
    }

    if ($Release) {
        Write-Host ''
        Write-Host 'Release mode is enabled. Next steps:' -ForegroundColor Yellow
        Write-Host '  1. Validate packages with Scripts/Test-BuildArtifacts.ps1' -ForegroundColor Gray
        Write-Host '  2. Publish to PowerShell Gallery (requires PSGALLERY_API_KEY)' -ForegroundColor Gray
        Write-Host '  3. Create GitHub release with artifacts and changelog' -ForegroundColor Gray
    } else {
        Write-Host ''
        Write-Host 'Local build complete. To prepare for release:' -ForegroundColor Yellow
        Write-Host '  1. Update build/version.json with new version' -ForegroundColor Gray
        Write-Host '  2. Update CHANGELOG.md with release notes' -ForegroundColor Gray
        Write-Host '  3. Run: git tag v<VERSION> && git push origin v<VERSION>' -ForegroundColor Gray
        Write-Host '  4. CI will automatically build and publish' -ForegroundColor Gray
    }
} catch {
    Write-Error $_
    exit 1
}
