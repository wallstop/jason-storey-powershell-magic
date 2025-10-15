# Templater.psm1
using namespace System.Collections.Generic

$script:TemplaterConfigCache = $null
$script:TemplaterConfigTimestamp = $null
$script:ZipAssemblyLoaded = $false
$script:Trusted7ZipPath = $null
$script:IsWindows = ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)
$script:SevenZipWarningEmitted = $false
$script:Managed7ZipHash = '78AFA2A1C773CAF3CF7EDF62F857D2A8A5DA55FB0FFF5DA416074C0D28B2B55F'
$script:SevenZipHashCache = @{}

# Private helper functions
function Get-TemplaterConfigPath {
    <#
    .SYNOPSIS
    Gets the path to the Templater configuration file.

    .DESCRIPTION
    Returns the path to the JSON file where template configurations are stored.
    Creates the directory if it doesn't exist.

    .PARAMETER ReturnDirectory
    Return the directory path instead of the file path.

    .EXAMPLE
    Get-TemplaterConfigPath
    Returns the full path to templates.json

    .EXAMPLE
    Get-TemplaterConfigPath -ReturnDirectory
    Returns the directory containing the config file

    .EXAMPLE
    code (Get-TemplaterConfigPath)
    Opens the config file in VS Code

    .EXAMPLE
    explorer (Get-TemplaterConfigPath -ReturnDirectory)
    Opens the config directory in Windows Explorer
    #>
    [CmdletBinding()]
    param(
        [switch]$ReturnDirectory
    )

    $configRoot = if ($env:XDG_CONFIG_HOME) {
        $env:XDG_CONFIG_HOME
    } else {
        Join-Path (Split-Path $PROFILE -Parent) '.config'
    }

    $configDir = Join-Path $configRoot 'templater'
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    if ($ReturnDirectory) {
        return $configDir
    } else {
        return Join-Path $configDir 'templates.json'
    }
}

function Get-TemplateData {
    $configPath = Get-TemplaterConfigPath
    if (Test-Path $configPath) {
        try {
            $fileInfo = Get-Item $configPath -ErrorAction Stop
            if ($script:TemplaterConfigCache -ne $null -and
                $script:TemplaterConfigTimestamp -eq $fileInfo.LastWriteTimeUtc) {
                return [hashtable]$script:TemplaterConfigCache.Clone()
            }

            $data = Get-Content $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            $script:TemplaterConfigCache = [hashtable]$data.Clone()
            $script:TemplaterConfigTimestamp = $fileInfo.LastWriteTimeUtc
            return $data
        } catch {
            Write-Warning "Invalid templates.json file detected at '$configPath'. Attempting recovery."
            $timestamp = Get-Date -Format 'yyyyMMddTHHmmss'
            $backupPath = "$configPath.backup.$timestamp"

            try {
                Copy-Item $configPath $backupPath -Force
                Write-Warning "Backup created at: $backupPath"
            } catch {
                Write-Warning "Failed to create backup for corrupt templates.json: $($_.Exception.Message)"
            }

            $script:TemplaterConfigCache = @{}
            $script:TemplaterConfigTimestamp = $null

            try {
                Save-TemplateData -TemplateData @{}
            } catch {
                Write-Warning "Failed to reset templates.json: $($_.Exception.Message)"
            }

            return @{}
        }
    }

    $script:TemplaterConfigCache = @{}
    $script:TemplaterConfigTimestamp = $null
    return @{}
}

function Save-TemplateData {
    param([hashtable]$TemplateData)

    $configPath = Get-TemplaterConfigPath
    try {
        $json = $TemplateData | ConvertTo-Json -Depth 4
        $json | Set-Content $configPath -Encoding UTF8
        $fileInfo = Get-Item $configPath -ErrorAction Stop
        $script:TemplaterConfigCache = if ($TemplateData) { [hashtable]$TemplateData.Clone() } else { @{} }
        $script:TemplaterConfigTimestamp = $fileInfo.LastWriteTimeUtc
    } catch {
        $message = "Failed to save template data to '$configPath'. $($_.Exception.Message)"
        throw (New-Object System.Exception($message, $_.Exception))
    }
}

function Update-LastUsed {
    param(
        [string]$Alias
    )

    $templateData = Get-TemplateData
    $currentTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

    if ($templateData.ContainsKey($Alias)) {
        $templateData[$Alias].LastUsed = $currentTime
        $currentCount = 0

        if ($null -ne $templateData[$Alias].UseCount) {
            [int]::TryParse($templateData[$Alias].UseCount.ToString(), [ref]$currentCount) | Out-Null
        }

        $templateData[$Alias].UseCount = $currentCount + 1
        Save-TemplateData -TemplateData $templateData
    }
}

function Test-FzfAvailable {
    try {
        $null = Get-Command fzf -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Test-IsTrusted7ZipPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $safeRoots = @()

    if ($env:LOCALAPPDATA) {
        $safeRoots += Join-Path (Join-Path $env:LOCALAPPDATA 'PowerShellMagic') 'bin'
    }

    if ($script:IsWindows) {
        if ($env:ProgramFiles) {
            $safeRoots += Join-Path $env:ProgramFiles '7-Zip'
        }

        if (${env:ProgramFiles(x86)}) {
            $safeRoots += Join-Path ${env:ProgramFiles(x86)} '7-Zip'
        }
    } else {
        $safeRoots += '/usr/bin'
        $safeRoots += '/usr/local/bin'
    }

    foreach ($root in $safeRoots | Where-Object { $_ }) {
        try {
            $resolvedRoot = (Resolve-Path $root -ErrorAction Stop).Path
            $comparison = if ($script:IsWindows) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }
            if ($Path.StartsWith($resolvedRoot, $comparison)) {
                return $true
            }
        } catch {
            continue
        }
    }

    return $false
}

function Get-ManagedSevenZipDirectory {
    if (-not $script:IsWindows) {
        return $null
    }

    if (-not $env:LOCALAPPDATA) {
        return $null
    }

    return Join-Path (Join-Path $env:LOCALAPPDATA 'PowerShellMagic') 'bin'
}

function Test-IsManagedSevenZipPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $managedDir = Get-ManagedSevenZipDirectory
    if (-not $managedDir) {
        return $false
    }

    try {
        $resolvedDir = (Resolve-Path $managedDir -ErrorAction Stop).Path
        $resolvedPath = (Resolve-Path $Path -ErrorAction Stop).Path
        $comparison = if ($script:IsWindows) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }
        return $resolvedPath.StartsWith($resolvedDir, $comparison)
    } catch {
        return $false
    }
}

function Test-7ZipHashValid {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExecutablePath
    )

    if (-not (Test-Path $ExecutablePath -PathType Leaf)) {
        return $false
    }

    if ($script:SevenZipHashCache.ContainsKey($ExecutablePath)) {
        return $script:SevenZipHashCache[$ExecutablePath]
    }

    $expectedHash = if ($env:POWERSHELLMAGIC_7ZIP_HASH) {
        $env:POWERSHELLMAGIC_7ZIP_HASH
    } elseif (Test-IsManagedSevenZipPath -Path $ExecutablePath) {
        $script:Managed7ZipHash
    } else {
        $null
    }

    if (-not $expectedHash) {
        $script:SevenZipHashCache[$ExecutablePath] = $true
        return $true
    }

    try {
        $fileHash = Get-FileHash -Path $ExecutablePath -Algorithm SHA256 -ErrorAction Stop
        $isValid = ($fileHash.Hash -eq $expectedHash.ToUpperInvariant())

        if (-not $isValid) {
            Write-Warning "7-Zip executable hash mismatch for '$ExecutablePath'. Expected $expectedHash but found $($fileHash.Hash)."
        }

        $script:SevenZipHashCache[$ExecutablePath] = $isValid
        return $isValid
    } catch {
        Write-Warning "Failed to verify 7-Zip executable hash for '$ExecutablePath': $($_.Exception.Message)"
        $script:SevenZipHashCache[$ExecutablePath] = $false
        return $false
    }
}

function Get-Trusted7ZipExecutable {
    if ($script:Trusted7ZipPath -and (Test-Path $script:Trusted7ZipPath)) {
        return $script:Trusted7ZipPath
    }

    $candidates = New-Object System.Collections.Generic.List[string]

    if ($env:POWERSHELLMAGIC_7ZIP_PATH) {
        $candidates.Add($env:POWERSHELLMAGIC_7ZIP_PATH)
    }

    if ($env:LOCALAPPDATA) {
        $managedBin = Join-Path (Join-Path $env:LOCALAPPDATA 'PowerShellMagic') 'bin'
        $candidates.Add((Join-Path $managedBin '7z.exe'))
        $candidates.Add((Join-Path $managedBin '7z'))
    }

    if ($script:IsWindows) {
        if ($env:ProgramFiles) {
            $candidates.Add((Join-Path (Join-Path $env:ProgramFiles '7-Zip') '7z.exe'))
        }

        if (${env:ProgramFiles(x86)}) {
            $candidates.Add((Join-Path (Join-Path ${env:ProgramFiles(x86)} '7-Zip') '7z.exe'))
        }
    } else {
        $candidates.Add('/usr/bin/7z')
        $candidates.Add('/usr/local/bin/7z')
    }

    foreach ($candidate in $candidates | Where-Object { $_ }) {
        try {
            if (Test-Path $candidate) {
                $resolvedCandidate = (Resolve-Path $candidate -ErrorAction Stop).Path
                if (Test-7ZipHashValid -ExecutablePath $resolvedCandidate) {
                    $script:Trusted7ZipPath = $resolvedCandidate
                    return $script:Trusted7ZipPath
                } elseif (-not $script:SevenZipWarningEmitted) {
                    Write-Warning "Rejected 7-Zip executable at '$resolvedCandidate' due to failed hash verification."
                    $script:SevenZipWarningEmitted = $true
                }
            }
        } catch {
            continue
        }
    }

    $commandNames = if ($script:IsWindows) { @('7z.exe', '7z') } else { @('7z', '7za') }

    foreach ($name in $commandNames) {
        try {
            $commandInfo = Get-Command $name -ErrorAction Stop
            $commandPath = if ($commandInfo.Path) { $commandInfo.Path } else { $commandInfo.Source }

            if ($commandPath) {
                $resolved = (Resolve-Path $commandPath -ErrorAction Stop).Path
                if (Test-IsTrusted7ZipPath -Path $resolved -and (Test-7ZipHashValid -ExecutablePath $resolved)) {
                    $script:Trusted7ZipPath = $resolved
                    return $script:Trusted7ZipPath
                } else {
                    if (-not $script:SevenZipWarningEmitted) {
                        Write-Warning "Ignoring untrusted 7-Zip executable at '$resolved'."
                        $script:SevenZipWarningEmitted = $true
                    }
                }
            }
        } catch {
            continue
        }
    }

    return $null
}

function Test-7ZipAvailable {
    return [bool](Get-Trusted7ZipExecutable)
}

function Extract-Archive {
    <#
    .SYNOPSIS
    Extracts archive files to a destination directory.

    .DESCRIPTION
    Extracts ZIP, 7Z, RAR, and other archive formats using appropriate tools.
    Supports .zip (built-in), .7z, .rar, .tar.gz, etc. (via 7-Zip).

    .PARAMETER ArchivePath
    Path to the archive file to extract.

    .PARAMETER DestinationPath
    Destination directory. Defaults to current directory.

    .PARAMETER CreateSubfolder
    Create a subfolder named after the archive (without extension).

    .PARAMETER Force
    Overwrite existing files at the destination.

    .EXAMPLE
    Extract-Archive -ArchivePath "template.zip"
    Extracts template.zip to current directory

    .EXAMPLE
    Extract-Archive -ArchivePath "template.7z" -DestinationPath "C:\Projects" -CreateSubfolder
    Extracts template.7z to C:\Projects\template\
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,

        [Parameter(Mandatory = $false)]
        [string]$DestinationPath = $null,

        [switch]$CreateSubfolder,

        [switch]$Force
    )

    # Validate archive exists
    if (-not (Test-Path $ArchivePath)) {
        throw "Archive file not found: $ArchivePath"
    }

    # Set destination path to current directory if not provided
    if (-not $DestinationPath) {
        $DestinationPath = (Get-Location).Path
    }

    # Create subfolder if requested
    if ($CreateSubfolder) {
        $archiveBaseName = [System.IO.Path]::GetFileNameWithoutExtension($ArchivePath)
        $DestinationPath = Join-Path $DestinationPath $archiveBaseName
    }

    try {
        if (-not (Test-Path $DestinationPath)) {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        }

        $DestinationPath = (Resolve-Path $DestinationPath -ErrorAction Stop).Path
    } catch {
        throw "Failed to prepare destination directory '$DestinationPath': $($_.Exception.Message)"
    }

    $existingItem = $null
    try {
        $existingItem = Get-ChildItem -LiteralPath $DestinationPath -Force -ErrorAction Stop | Select-Object -First 1
    } catch [System.Management.Automation.ItemNotFoundException] {
        # Directory is empty
    } catch {
        throw "Failed to inspect destination directory '$DestinationPath': $($_.Exception.Message)"
    }

    if ($existingItem -and -not $Force) {
        throw "Destination '$DestinationPath' already contains files. Use -Force to overwrite existing content."
    }

    # Get file extension
    $extension = [System.IO.Path]::GetExtension($ArchivePath).ToLower()

    try {
        switch ($extension) {
            '.zip' {
                if (-not $script:ZipAssemblyLoaded) {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    $script:ZipAssemblyLoaded = $true
                }

                $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
                try {
                    foreach ($entry in $archive.Entries) {
                        if ([string]::IsNullOrWhiteSpace($entry.FullName)) {
                            continue
                        }

                        $pathParts = $entry.FullName -split '[\\/]'
                        $targetPath = $DestinationPath
                        foreach ($part in $pathParts) {
                            if ([string]::IsNullOrWhiteSpace($part)) {
                                continue
                            }
                            $targetPath = Join-Path $targetPath $part
                        }

                        if ([string]::IsNullOrEmpty($entry.Name)) {
                            if (-not (Test-Path $targetPath)) {
                                New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
                            }
                            continue
                        }

                        $targetDir = Split-Path $targetPath -Parent
                        if ($targetDir -and -not (Test-Path $targetDir)) {
                            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                        }

                        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $targetPath, [bool]$Force)
                    }
                } finally {
                    $archive.Dispose()
                }

                Write-Verbose ("Extracted ZIP archive '{0}' to '{1}'" -f $ArchivePath, $DestinationPath)
            }
            { $_ -in @('.7z', '.rar', '.tar', '.gz', '.bz2', '.xz') } {
                $sevenZip = Get-Trusted7ZipExecutable
                if (-not $sevenZip) {
                    throw "Trusted 7-Zip executable not found. Install 7-Zip via Setup-PowerShellMagic or set POWERSHELLMAGIC_7ZIP_PATH."
                }

                $archiveArg = "`"$ArchivePath`""
                $destinationArg = "-o`"$DestinationPath`""
                $argumentList = @('x', $archiveArg, $destinationArg, '-y')

                if ($Force) {
                    $argumentList += '-aoa'
                }

                $process = Start-Process -FilePath $sevenZip -ArgumentList $argumentList -Wait -NoNewWindow -PassThru

                if ($process.ExitCode -eq 0) {
                    Write-Verbose ("Extracted {0} archive '{1}' to '{2}' via 7-Zip" -f $extension, $ArchivePath, $DestinationPath)
                } else {
                    throw "7-Zip extraction failed with exit code: $($process.ExitCode)"
                }
            }
            default {
                throw "Unsupported archive format: $extension. Supported: .zip, .7z, .rar, .tar, .gz, .bz2, .xz"
            }
        }

        return $DestinationPath
    } catch {
        Write-Error "Failed to extract archive: $($_.Exception.Message)"
        throw
    }
}

function Get-TemplatePreview {
    param(
        [string]$TemplatePath,
        [string]$PreviewFile
    )

    $preview = ''

    # Try to show preview file content if specified
    if ($PreviewFile) {
        $templateDir = Split-Path $TemplatePath -Parent
        $previewPath = Join-Path $templateDir $PreviewFile
        if (Test-Path $previewPath) {
            try {
                $preview = Get-Content $previewPath -Raw -Encoding UTF8
                if ($preview.Length -gt 1000) {
                    $preview = $preview.Substring(0, 1000) + "`n... (truncated)"
                }
                return $preview
            } catch {
                $preview = "Preview file exists but couldn't be read: $PreviewFile`n"
            }
        } else {
            $preview = "Preview file not found: $PreviewFile`n"
        }
    }

    # Fallback to archive content listing
    $extension = [System.IO.Path]::GetExtension($TemplatePath).ToLower()

    try {
        switch ($extension) {
            '.zip' {
                if (-not $script:ZipAssemblyLoaded) {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    $script:ZipAssemblyLoaded = $true
                }
                $zip = [System.IO.Compression.ZipFile]::OpenRead($TemplatePath)
                $preview += "Archive Contents:`n"
                $zip.Entries | ForEach-Object {
                    $preview += "  $($_.FullName)`n"
                }
                $zip.Dispose()
            }
            { $_ -in @('.7z', '.rar', '.tar', '.gz', '.bz2', '.xz') } {
                $sevenZip = Get-Trusted7ZipExecutable
                if ($sevenZip) {
                    $result = & $sevenZip 'l' $TemplatePath 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        $preview += "Archive Contents:`n" + ($result -join "`n")
                    } else {
                        $preview += 'Could not list archive contents'
                    }
                } else {
                    $preview += '7-Zip not available for preview'
                }
            }
            default {
                $preview += "Preview not available for $extension files"
            }
        }
    } catch {
        $preview += "Error generating preview: $($_.Exception.Message)"
    }

    return $preview
}

function Add-Template {
    <#
    .SYNOPSIS
    Adds a template file or folder to the Templater registry.

    .DESCRIPTION
    Registers a template file (archive) or folder with an alias, description, category,
    and optional preview file for use with Templater commands.

    .PARAMETER Alias
    The alias/keyword to associate with this template for quick access.

    .PARAMETER Path
    The path to the template file or folder. Defaults to current directory for folders.

    .PARAMETER Description
    Description of what this template provides.

    .PARAMETER Category
    Category to organize templates (e.g., "web", "api", "scripts").

    .PARAMETER PreviewFile
    Relative path to a markdown file to use as preview (relative to template folder).

    .PARAMETER Type
    Type of template: 'File' for archive files, 'Folder' for directories. Auto-detected if not specified.

    .PARAMETER Tags
    Optional tags for better searchability.

    .PARAMETER Force
    Overwrites an existing alias if it already exists.

    .EXAMPLE
    Add-Template -Alias "react-app" -Path "templates/react-starter.zip" -Description "React starter template" -Category "web"
    Adds an archive file template

    .EXAMPLE
    Add-Template -Alias "api-base" -Description "Basic API template" -Category "backend" -PreviewFile "README.md"
    Adds current directory as a folder template with preview

    .EXAMPLE
    Add-Template -Alias "ps-module" -Path "C:\Templates\PowerShell" -Description "PowerShell module template" -Tags @("powershell", "module")
    Adds a folder template with tags
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Alias,

        [string]$Path = (Get-Location).Path,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [string]$Category = 'General',

        [string]$PreviewFile,

        [ValidateSet('File', 'Folder')]
        [string]$Type,

        [string[]]$Tags = @(),

        [switch]$Force
    )

    # Resolve path
    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        $Path = Resolve-Path $Path -ErrorAction SilentlyContinue
        if (-not $Path) {
            Write-Error "Path not found: $Path"
            return
        }
    }

    $Path = (Resolve-Path $Path).Path

    # Auto-detect type if not specified
    if (-not $Type) {
        if (Test-Path $Path -PathType Leaf) {
            $Type = 'File'
            # Validate it's an archive file for File type
            $extension = [System.IO.Path]::GetExtension($Path).ToLower()
            if ($extension -notin @('.zip', '.7z', '.rar', '.tar', '.gz', '.bz2', '.xz')) {
                Write-Warning "File doesn't appear to be a supported archive format. Supported: .zip, .7z, .rar, .tar, .gz, .bz2, .xz"
            }
        } elseif (Test-Path $Path -PathType Container) {
            $Type = 'Folder'
        } else {
            Write-Error "Path not found: $Path"
            return
        }
    } else {
        # Validate the type matches the path
        if ($Type -eq 'File' -and -not (Test-Path $Path -PathType Leaf)) {
            Write-Error "Specified type 'File' but path is not a file: $Path"
            return
        }
        if ($Type -eq 'Folder' -and -not (Test-Path $Path -PathType Container)) {
            Write-Error "Specified type 'Folder' but path is not a directory: $Path"
            return
        }
    }

    # Get current template data
    $templateData = Get-TemplateData

    # Check if alias already exists
    if ($templateData.ContainsKey($Alias) -and -not $Force) {
        Write-Error "Alias '$Alias' already exists. Use -Force to overwrite, or choose a different alias."
        Write-Host "Existing template: $($templateData[$Alias].Description)" -ForegroundColor Yellow
        return
    }

    # Validate preview file if specified
    if ($PreviewFile) {
        if ($Type -eq 'File') {
            $previewDir = Split-Path $Path -Parent
        } else {
            $previewDir = $Path
        }

        $previewPath = Join-Path $previewDir $PreviewFile
        if (-not (Test-Path $previewPath)) {
            Write-Warning "Preview file not found: $previewPath"
            $choice = Read-Host 'Continue without preview file? (Y/n)'
            if ($choice -match '^[Nn]') {
                return
            }
            $PreviewFile = $null
        }
    }

    # Create template info
    $currentTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $templateInfo = @{
        Path = $Path
        Description = $Description
        Category = $Category
        Type = $Type
        PreviewFile = $PreviewFile
        Tags = $Tags
        DateAdded = $currentTime
        LastUsed = 'Never'
        UseCount = 0
    }

    # If updating existing template, preserve usage stats
    if ($templateData.ContainsKey($Alias)) {
        $existing = $templateData[$Alias]
        $templateInfo.LastUsed = if ($existing.LastUsed) { $existing.LastUsed } else { 'Never' }
        $templateInfo.UseCount = if ($existing.UseCount) { $existing.UseCount } else { 0 }
    }

    # Add/update the template
    $templateData[$Alias] = $templateInfo

    # Save to file
    Save-TemplateData -TemplateData $templateData

    Write-Host "Added template '$Alias'" -ForegroundColor Green
    Write-Host "  Description: $Description" -ForegroundColor Gray
    Write-Host "  Category: $Category" -ForegroundColor Gray
    Write-Host "  Type: $Type" -ForegroundColor Gray
    Write-Host "  Path: $Path" -ForegroundColor Gray
    if ($PreviewFile) {
        Write-Host "  Preview: $PreviewFile" -ForegroundColor Gray
    }
    if ($Tags.Count -gt 0) {
        Write-Host "  Tags: $($Tags -join ', ')" -ForegroundColor Gray
    }
}

function Get-Templates {
    <#
    .SYNOPSIS
    Lists all registered templates or opens a selected one.

    .DESCRIPTION
    Displays all registered templates with their information, or if -Interactive is specified,
    uses fzf for fuzzy finding and selection of templates.

    .PARAMETER Interactive
    Uses fzf for interactive selection of templates.

    .PARAMETER Alias
    If specified, uses the template with this alias directly.

    .PARAMETER Category
    Filter templates by category.

    .PARAMETER Tag
    Filter templates by tag.

    .PARAMETER SortByRecent
    Sort templates by last used date (most recent first).

    .PARAMETER SortByUsage
    Sort templates by usage count (most used first).

    .PARAMETER List
    Just list templates without interactive selection.

    .PARAMETER DestinationPath
    Where to extract/copy the template. Defaults to current directory.

    .PARAMETER CreateSubfolder
    Create a subfolder named after the template alias.

    .EXAMPLE
    Get-Templates
    Lists all registered templates

    .EXAMPLE
    Get-Templates -Interactive
    Uses fzf to select and use a template

    .EXAMPLE
    Get-Templates -Category "web" -Interactive
    Shows only web templates for selection

    .EXAMPLE
    Get-Templates -Alias "react-app" -DestinationPath "C:\Projects" -CreateSubfolder
    Uses the react-app template and extracts to C:\Projects\react-app\

    .EXAMPLE
    Get-Templates -Tag "api" -SortByUsage
    Shows templates tagged as "api" sorted by usage count
    #>
    [CmdletBinding()]
    param(
        [switch]$Interactive,
        [string]$Alias,
        [string]$Category,
        [string]$Tag,
        [switch]$SortByRecent,
        [switch]$SortByUsage,
        [switch]$List,
        [string]$DestinationPath = (Get-Location).Path,
        [switch]$CreateSubfolder
    )

    $templateData = Get-TemplateData

    if ($templateData.Count -eq 0) {
        Write-Host "No templates registered yet. Use 'Add-Template' to register templates." -ForegroundColor Yellow
        return
    }

    # Filter templates
    $filteredTemplates = $templateData.GetEnumerator()

    if ($Category) {
        $filteredTemplates = $filteredTemplates | Where-Object { $_.Value.Category -eq $Category }
    }

    if ($Tag) {
        $filteredTemplates = $filteredTemplates | Where-Object { $_.Value.Tags -contains $Tag }
    }

    # Convert to array for further processing
    $filteredTemplates = @($filteredTemplates)

    if ($filteredTemplates.Count -eq 0) {
        $filterMsg = @()
        if ($Category) { $filterMsg += "category '$Category'" }
        if ($Tag) { $filterMsg += "tag '$Tag'" }
        Write-Host "No templates found with $($filterMsg -join ' and ')." -ForegroundColor Yellow
        return
    }

    # If alias specified, use that template directly
    if ($Alias) {
        if ($templateData.ContainsKey($Alias)) {
            Use-Template -Alias $Alias -DestinationPath $DestinationPath -CreateSubfolder:$CreateSubfolder
        } else {
            Write-Error "No template found with alias '$Alias'"
            Write-Host "Available aliases: $($templateData.Keys -join ', ')" -ForegroundColor Yellow
        }
        return
    }

    # Interactive mode with fzf
    if ($Interactive -and -not $List) {
        if (-not (Test-FzfAvailable)) {
            Write-Error 'fzf is not available. Please install fzf first.'
            Write-Host 'Install fzf: https://github.com/junegunn/fzf#installation' -ForegroundColor Yellow
            Write-Host "Or use 'scoop install fzf' / 'choco install fzf' / 'winget install junegunn.fzf'" -ForegroundColor Yellow
            return
        }

        # Sort templates
        $sortedTemplates = if ($SortByRecent) {
            $filteredTemplates | Sort-Object {
                if ($_.Value.LastUsed -eq 'Never') {
                    [DateTime]::MinValue
                } else {
                    [DateTime]::ParseExact($_.Value.LastUsed, 'yyyy-MM-dd HH:mm:ss', $null)
                }
            } -Descending
        } elseif ($SortByUsage) {
            $filteredTemplates | Sort-Object { if ($_.Value.UseCount) { $_.Value.UseCount } else { 0 } } -Descending
        } else {
            $filteredTemplates | Sort-Object Key
        }

        $fzfItems = @()
        $sortedTemplates | ForEach-Object {
            $alias = $_.Key
            $template = $_.Value
            $lastUsed = if ($template.LastUsed -eq 'Never') { 'Never' } else { $template.LastUsed }
            $useCount = if ($template.UseCount) { $template.UseCount } else { 0 }
            $tags = if ($template.Tags -and $template.Tags.Count -gt 0) { '[' + ($template.Tags -join ',') + ']' } else { '' }

            # Format: "alias | description | category | Get-Content | usage | last_used | tags | path | preview_file"
            $fzfItems += @("$alias", "$($template.Description)", "$($template.Category)", "$($template.Type)", "${useCount} uses", "$lastUsed", "$tags", "$($template.Path)", "$(if ($template.PreviewFile) { $template.PreviewFile } else { '' })") -join ' | '
        }

        if ($fzfItems.Count -eq 0) {
            Write-Host 'No templates found.' -ForegroundColor Yellow
            return
        }

        # Use fzf to select template with preview
        try {
            $headerText = 'Select Template'
            $selected = $fzfItems | fzf --height=40% --reverse --border --header="$headerText" --delimiter=' | ' --with-nth=1, 2, 3, 4, 5 --preview-window=right:50%:wrap

            if ($selected) {
                $alias = ($selected -split ' \| ')[0].Trim()
                Write-Host "using template '$alias'..." -ForegroundColor Green
                Use-Template -Alias $alias -DestinationPath $DestinationPath -CreateSubfolder:$CreateSubfolder
            }
        } catch {
            Write-Error "Error running fzf: $($_.Exception.Message)"
        }
    } else {
        # Just list templates
        Write-Host "`nRegistered Templates:" -ForegroundColor Cyan
        Write-Host ('=' * 100) -ForegroundColor Cyan

        # Sort templates
        $sortedTemplates = if ($SortByRecent) {
            $filteredTemplates | Sort-Object {
                if ($_.Value.LastUsed -eq 'Never') {
                    [DateTime]::MinValue
                } else {
                    [DateTime]::ParseExact($_.Value.LastUsed, 'yyyy-MM-dd HH:mm:ss', $null)
                }
            } -Descending
        } elseif ($SortByUsage) {
            $filteredTemplates | Sort-Object { if ($_.Value.UseCount) { $_.Value.UseCount } else { 0 } } -Descending
        } else {
            $filteredTemplates | Sort-Object Key
        }

        $sortedTemplates | ForEach-Object {
            $alias = $_.Key
            $template = $_.Value
            $lastUsed = if ($template.LastUsed -eq 'Never') { 'Never' } else { $template.LastUsed }
            $useCount = if ($template.UseCount) { $template.UseCount } else { 0 }
            $tags = if ($template.Tags -and $template.Tags.Count -gt 0) { ' Tags: [' + ($template.Tags -join ', ') + ']' } else { '' }

            Write-Host "$($alias.PadRight(15)) $($template.Description.PadRight(30)) [$($template.Category)] ($($template.Type)) - ${useCount} uses" -ForegroundColor White
            Write-Host "$(' '*15) Last used: $lastUsed$tags" -ForegroundColor Gray
            Write-Host "$(' '*15) $($template.Path)" -ForegroundColor DarkGray
            if ($template.PreviewFile) {
                Write-Host "$(' ' * 15) Preview: $($template.PreviewFile)" -ForegroundColor DarkGray
            }
            Write-Host ''
        }

        Write-Host 'Commands:' -ForegroundColor Yellow
        Write-Host '  Get-Templates -Interactive          # Interactive selection' -ForegroundColor Yellow
        Write-Host '  Get-Templates -Alias <alias>        # Use specific template' -ForegroundColor Yellow
        Write-Host '  Get-Templates -Category <category>  # Filter by category' -ForegroundColor Yellow
        Write-Host '  Get-Templates -Tag <tag>            # Filter by tag' -ForegroundColor Yellow
    }
}

function Use-Template {
    <#
    .SYNOPSIS
    Uses a registered template by extracting/copying it to a destination.

    .DESCRIPTION
    Extracts an archive template or copies a folder template to the specified destination,
    with optional subfolder creation and variable substitution.

    .PARAMETER Alias
    The alias of the registered template to use.

    .PARAMETER DestinationPath
    Where to extract/copy the template. Defaults to current directory.

    .PARAMETER CreateSubfolder
    Create a subfolder named after the template alias.

    .PARAMETER SubfolderName
    Custom name for the subfolder (implies -CreateSubfolder).

    .PARAMETER Force
    Overwrite existing files without prompting.

    .EXAMPLE
    Use-Template -Alias "react-app"
    Uses the react-app template in current directory

    .EXAMPLE
    Use-Template -Alias "api-base" -DestinationPath "C:\Projects" -CreateSubfolder
    Extracts to C:\Projects\api-base\

    .EXAMPLE
    Use-Template -Alias "ps-module" -SubfolderName "MyNewModule"
    Creates template in .\MyNewModule\
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Alias,

        [string]$DestinationPath = (Get-Location).Path,

        [switch]$CreateSubfolder,

        [string]$SubfolderName,

        [switch]$Force
    )

    process {
        $templateData = Get-TemplateData

        if (-not $templateData.ContainsKey($Alias)) {
            Write-Error "No template found with alias '$Alias'"
            if ($templateData.Count -gt 0) {
                Write-Host "Available aliases: $($templateData.Keys -join ', ')" -ForegroundColor Yellow
            }
            return
        }

        $template = $templateData[$Alias]

        # Validate template path still exists
        if (-not (Test-Path $template.Path)) {
            Write-Error "Template path no longer exists: $($template.Path)"
            Write-Host "Consider removing this template with 'Remove-Template -Alias $Alias'" -ForegroundColor Yellow
            return
        }

        # Determine final destination
        $finalDestination = $DestinationPath

        if ($SubfolderName) {
            $CreateSubfolder = $true
            $finalDestination = Join-Path $DestinationPath $SubfolderName
        } elseif ($CreateSubfolder) {
            $finalDestination = Join-Path $DestinationPath $Alias
        }

        # Create destination directory if needed
        if (-not (Test-Path $finalDestination)) {
            try {
                New-Item -ItemType Directory -Path $finalDestination -Force | Out-Null
                Write-Host "Created directory: $finalDestination" -ForegroundColor Green
            } catch {
                Write-Error "Failed to create destination directory: $finalDestination"
                return
            }
        }

        Write-Host "Using template '$Alias': $($template.Description)" -ForegroundColor Green
        Write-Host "Template type: $($template.Type)" -ForegroundColor Gray
        Write-Host "Destination: $finalDestination" -ForegroundColor Cyan

        try {
            switch ($template.Type) {
                'File' {
                    # Extract archive
                    $result = Extract-Archive -ArchivePath $template.Path -DestinationPath $finalDestination -Force:$Force
                    Write-Host 'Template extracted successfully!' -ForegroundColor Green
                }
                'Folder' {
                    # Copy folder contents with accurate progress tracking
                    $allItems = Get-ChildItem -Path $template.Path -Recurse -Force
                    $directories = @($allItems | Where-Object { $_.PSIsContainer })
                    $files = @($allItems | Where-Object { -not $_.PSIsContainer })

                    foreach ($directory in $directories) {
                        $relativeDir = $directory.FullName.Substring($template.Path.Length + 1)
                        $destDirPath = Join-Path $finalDestination $relativeDir
                        if (-not (Test-Path $destDirPath)) {
                            New-Item -ItemType Directory -Path $destDirPath -Force | Out-Null
                        }
                    }

                    $totalFiles = $files.Count
                    $copiedFiles = 0

                    if ($totalFiles -gt 0) {
                        Write-Host "Copying $totalFiles files..." -ForegroundColor Gray
                    } else {
                        Write-Host 'No files found to copy (only directory structure).' -ForegroundColor Yellow
                    }

                    foreach ($file in $files) {
                        $relativePath = $file.FullName.Substring($template.Path.Length + 1)
                        $destPath = Join-Path $finalDestination $relativePath

                        $destDir = Split-Path $destPath -Parent
                        if (-not (Test-Path $destDir)) {
                            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                        }

                        if ((Test-Path $destPath) -and -not $Force) {
                            $choice = Read-Host "File exists: $relativePath. Overwrite? (y/N/a for all)"
                            if ($choice -match '^[Aa]') {
                                $Force = $true
                            } elseif ($choice -notmatch '^[Yy]') {
                                Write-Host "Skipping: $relativePath" -ForegroundColor Yellow
                                continue
                            }
                        }

                        try {
                            Copy-Item -Path $file.FullName -Destination $destPath -Force:$Force
                            $copiedFiles++

                            # Show progress for large operations
                            if ($totalFiles -gt 50 -and ($copiedFiles % 10) -eq 0) {
                                $percent = [math]::Round(($copiedFiles / $totalFiles) * 100)
                                Write-Host "Progress: $copiedFiles/$totalFiles ($percent%)" -ForegroundColor Gray
                            }
                        } catch {
                            Write-Warning "Failed to copy: $relativePath - $($_.Exception.Message)"
                        }
                    }

                    Write-Host "Template copied successfully! ($copiedFiles files, $($directories.Count) directories)" -ForegroundColor Green
                }
            }

            # Update usage statistics
            Update-LastUsed -Alias $Alias

            Write-Host "Template '$Alias' deployed to: $finalDestination" -ForegroundColor Cyan
        } catch {
            Write-Error "Failed to use template '$Alias': $($_.Exception.Message)"
        }
    }
}

function Remove-Template {
    <#
    .SYNOPSIS
    Removes a template from the Templater registry.

    .DESCRIPTION
    Removes a registered template by alias. Does not delete the actual template files,
    only removes the registration from the Templater system.

    .PARAMETER Alias
    The alias of the template to remove.

    .PARAMETER Force
    Skip confirmation prompt.

    .EXAMPLE
    Remove-Template -Alias "old-template"
    Removes the template with confirmation

    .EXAMPLE
    Remove-Template -Alias "old-template" -Force
    Removes the template without confirmation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Alias,

        [switch]$Force
    )

    process {
        $templateData = Get-TemplateData

        if (-not $templateData.ContainsKey($Alias)) {
            Write-Error "No template found with alias '$Alias'"
            if ($templateData.Count -gt 0) {
                Write-Host "Available aliases: $($templateData.Keys -join ', ')" -ForegroundColor Yellow
            }
            return
        }

        $template = $templateData[$Alias]

        if (-not $Force) {
            Write-Host 'Template to remove:' -ForegroundColor Yellow
            Write-Host "  Alias: $Alias" -ForegroundColor Gray
            Write-Host "  Description: $($template.Description)" -ForegroundColor Gray
            Write-Host "  Path: $($template.Path)" -ForegroundColor Gray
            Write-Host "  Use Count: $(if ($template.UseCount) { $template.UseCount } else { 0 })" -ForegroundColor Gray

            $confirmation = Read-Host 'Are you sure you want to remove this template? (y/N)'
            if ($confirmation -notmatch '^[Yy]') {
                Write-Host 'Operation cancelled.' -ForegroundColor Yellow
                return
            }
        }

        # Remove the template
        $templateData.Remove($Alias)

        # Save updated data
        Save-TemplateData -TemplateData $templateData

        Write-Host "Removed template '$Alias'" -ForegroundColor Green
        Write-Host 'Note: The actual template files were not deleted, only the registration.' -ForegroundColor Gray
    }
}

function Update-Template {
    <#
    .SYNOPSIS
    Updates properties of an existing template.

    .DESCRIPTION
    Updates the description, category, tags, preview file, or path of an existing template
    without changing usage statistics.

    .PARAMETER Alias
    The alias of the template to update.

    .PARAMETER Description
    New description for the template.

    .PARAMETER Category
    New category for the template.

    .PARAMETER Tags
    New tags for the template (replaces existing tags).

    .PARAMETER PreviewFile
    New preview file path (relative to template location).

    .PARAMETER Path
    New path to the template file or folder.

    .EXAMPLE
    Update-Template -Alias "react-app" -Description "Updated React starter with TypeScript"
    Updates the description

    .EXAMPLE
    Update-Template -Alias "api-base" -Category "backend" -Tags @("api", "node", "express")
    Updates category and tags
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Alias,

        [string]$Description,
        [string]$Category,
        [string[]]$Tags,
        [string]$PreviewFile,
        [string]$Path
    )

    $templateData = Get-TemplateData

    if (-not $templateData.ContainsKey($Alias)) {
        Write-Error "No template found with alias '$Alias'"
        if ($templateData.Count -gt 0) {
            Write-Host "Available aliases: $($templateData.Keys -join ', ')" -ForegroundColor Yellow
        }
        return
    }

    $template = $templateData[$Alias]
    $updated = $false

    # Update properties if provided
    if ($Description) {
        $oldValue = $template.Description
        $template.Description = $Description
        Write-Host "Updated description: '$oldValue' â†’ '$Description'" -ForegroundColor Green
        $updated = $true
    }

    if ($Category) {
        $oldValue = $template.Category
        $template.Category = $Category
        Write-Host "Updated category: '$oldValue' â†’ '$Category'" -ForegroundColor Green
        $updated = $true
    }

    if ($Tags) {
        $oldValue = $template.Tags -join ', '
        $template.Tags = $Tags
        $newValue = $Tags -join ', '
        Write-Host "Updated tags: '$oldValue' â†’ '$newValue'" -ForegroundColor Green
        $updated = $true
    }

    if ($PreviewFile) {
        # Validate preview file exists
        $templateDir = if ($template.Type -eq 'File') {
            Split-Path $template.Path -Parent
        } else {
            $template.Path
        }
        $previewPath = Join-Path $templateDir $PreviewFile

        if (Test-Path $previewPath) {
            $oldValue = if ($template.PreviewFile) { $template.PreviewFile } else { 'None' }
            $template.PreviewFile = $PreviewFile
            Write-Host "Updated preview file: '$oldValue' â†’ '$PreviewFile'" -ForegroundColor Green
            $updated = $true
        } else {
            Write-Warning "Preview file not found: $previewPath"
        }
    }

    if ($Path) {
        # Validate new path
        if (Test-Path $Path) {
            $oldValue = $template.Path
            $template.Path = (Resolve-Path $Path).Path
            Write-Host "Updated path: '$oldValue' â†’ '$($template.Path)'" -ForegroundColor Green
            $updated = $true
        } else {
            Write-Error "Path not found: $Path"
            return
        }
    }

    if (-not $updated) {
        Write-Host 'No changes specified. Use -Description, -Category, -Tags, -PreviewFile, or -Path to update properties.' -ForegroundColor Yellow
        return
    }

    # Save updated data
    $templateData[$Alias] = $template
    Save-TemplateData -TemplateData $templateData

    Write-Host "Template '$Alias' updated successfully!" -ForegroundColor Green
}

function Export-Templates {
    <#
    .SYNOPSIS
    Exports template configurations to a JSON file.

    .DESCRIPTION
    Exports all or filtered template configurations to a JSON file for backup or sharing.

    .PARAMETER Path
    Output file path. Defaults to templates-export.json in current directory.

    .PARAMETER Category
    Export only templates from this category.

    .PARAMETER Tag
    Export only templates with this tag.

    .PARAMETER IncludeUsageStats
    Include usage statistics (LastUsed, UseCount) in export.

    .EXAMPLE
    Export-Templates
    Exports all templates to templates-export.json

    .EXAMPLE
    Export-Templates -Path "backup.json" -IncludeUsageStats
    Exports with usage statistics to backup.json

    .EXAMPLE
    Export-Templates -Category "web" -Path "web-templates.json"
    Exports only web templates
    #>
    [CmdletBinding()]
    param(
        [string]$Path = 'templates-export.json',
        [string]$Category,
        [string]$Tag,
        [switch]$IncludeUsageStats
    )

    $templateData = Get-TemplateData

    if ($templateData.Count -eq 0) {
        Write-Warning 'No templates to export.'
        return
    }

    # Filter templates
    $filteredTemplates = $templateData.GetEnumerator()

    if ($Category) {
        $filteredTemplates = $filteredTemplates | Where-Object { $_.Value.Category -eq $Category }
    }

    if ($Tag) {
        $filteredTemplates = $filteredTemplates | Where-Object { $_.Value.Tags -contains $Tag }
    }

    # Convert to hashtable
    $exportData = @{}
    $filteredTemplates | ForEach-Object {
        $templateInfo = $_.Value.Clone()

        # Remove usage stats if not requested
        if (-not $IncludeUsageStats) {
            $templateInfo.Remove('LastUsed')
            $templateInfo.Remove('UseCount')
        }

        $exportData[$_.Key] = $templateInfo
    }

    if ($exportData.Count -eq 0) {
        Write-Warning 'No templates match the specified filters.'
        return
    }

    try {
        $exportData | ConvertTo-Json -Depth 4 | Set-Content $Path -Encoding UTF8
        Write-Host "Exported $($exportData.Count) templates to: $Path" -ForegroundColor Green
    } catch {
        Write-Error "Failed to export templates: $($_.Exception.Message)"
    }
}

function Import-Templates {
    <#
    .SYNOPSIS
    Imports template configurations from a JSON file.

    .DESCRIPTION
    Imports template configurations from a JSON file, with options to handle conflicts.

    .PARAMETER Path
    Path to the JSON file to import.

    .PARAMETER Merge
    Merge with existing templates (default behavior).

    .PARAMETER Overwrite
    Overwrite existing templates without prompting.

    .PARAMETER SkipExisting
    Skip templates that already exist.

    .EXAMPLE
    Import-Templates -Path "backup.json"
    Imports templates with conflict resolution prompts

    .EXAMPLE
    Import-Templates -Path "shared-templates.json" -SkipExisting
    Imports only new templates, skips existing ones

    .EXAMPLE
    Import-Templates -Path "templates.json" -Overwrite
    Imports and overwrites existing templates
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [switch]$Merge,
        [switch]$Overwrite,
        [switch]$SkipExisting
    )

    if (-not (Test-Path $Path)) {
        Write-Error "Import file not found: $Path"
        return
    }

    try {
        $importData = Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable
    } catch {
        Write-Error "Failed to parse import file: $($_.Exception.Message)"
        return
    }

    if ($importData.Count -eq 0) {
        Write-Warning 'No templates found in import file.'
        return
    }

    $currentData = Get-TemplateData
    $imported = 0
    $skipped = 0
    $overwritten = 0

    foreach ($alias in $importData.Keys) {
        $importTemplate = $importData[$alias]
        $exists = $currentData.ContainsKey($alias)

        if ($exists) {
            if ($SkipExisting) {
                Write-Host "Skipping existing template: $alias" -ForegroundColor Yellow
                $skipped++
                continue
            } elseif ($Overwrite) {
                Write-Host "Overwriting template: $alias" -ForegroundColor Green
                $overwritten++
            } else {
                Write-Host "Template '$alias' already exists:" -ForegroundColor Yellow
                Write-Host "  Current: $($currentData[$alias].Description)" -ForegroundColor Gray
                Write-Host "  Import:  $($importTemplate.Description)" -ForegroundColor Gray

                $choice = Read-Host 'Action? (o)verwrite, (s)kip, (a)ll overwrite, (n)one skip'
                switch ($choice.ToLower()) {
                    'o' {
                        Write-Host "Overwriting template: $alias" -ForegroundColor Green
                        $overwritten++
                    }
                    's' {
                        Write-Host "Skipping template: $alias" -ForegroundColor Yellow
                        $skipped++
                        continue
                    }
                    'a' {
                        $Overwrite = $true
                        Write-Host "Overwriting template: $alias (and all future conflicts)" -ForegroundColor Green
                        $overwritten++
                    }
                    'n' {
                        $SkipExisting = $true
                        Write-Host "Skipping template: $alias (and all future conflicts)" -ForegroundColor Yellow
                        $skipped++
                        continue
                    }
                    default {
                        Write-Host "Skipping template: $alias" -ForegroundColor Yellow
                        $skipped++
                        continue
                    }
                }
            }
        } else {
            Write-Host "Adding new template: $alias" -ForegroundColor Green
            $imported++
        }

        # Validate template path exists
        if (-not (Test-Path $importTemplate.Path)) {
            Write-Warning "Template path does not exist: $($importTemplate.Path) for template '$alias'"
            Write-Host 'Template will be imported but may not work until path is corrected.' -ForegroundColor Yellow
        }

        # Add current timestamp if not present
        if (-not $importTemplate.DateAdded) {
            $importTemplate.DateAdded = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        }

        # Ensure usage stats exist
        if (-not $importTemplate.ContainsKey('LastUsed')) {
            $importTemplate.LastUsed = 'Never'
        }
        if (-not $importTemplate.ContainsKey('UseCount')) {
            $importTemplate.UseCount = 0
        }

        $currentData[$alias] = $importTemplate
    }

    # Save updated data
    Save-TemplateData -TemplateData $currentData

    Write-Host "`nImport completed!" -ForegroundColor Green
    Write-Host "  New templates: $imported" -ForegroundColor Green
    Write-Host "  Overwritten: $overwritten" -ForegroundColor Yellow
    Write-Host "  Skipped: $skipped" -ForegroundColor Gray
}

function Get-TemplateStats {
    <#
    .SYNOPSIS
    Shows statistics about registered templates.

    .DESCRIPTION
    Displays usage statistics, categories, and other metrics about registered templates.

    .PARAMETER ShowTop
    Number of top templates to show by usage. Default is 5.

    .EXAMPLE
    Get-TemplateStats
    Shows template statistics

    .EXAMPLE
    Get-TemplateStats -ShowTop 10
    Shows top 10 most used templates
    #>
    [CmdletBinding()]
    param(
        [int]$ShowTop = 5
    )

    $templateData = Get-TemplateData

    if ($templateData.Count -eq 0) {
        Write-Host 'No templates registered yet.' -ForegroundColor Yellow
        return
    }

    Write-Host "`nTemplate Statistics" -ForegroundColor Cyan
    Write-Host ('=' * 50) -ForegroundColor Cyan

    # Basic counts
    Write-Host "Total templates: $($templateData.Count)" -ForegroundColor White

    # Type breakdown
    $fileTemplates = ($templateData.Values | Where-Object { $_.Type -eq 'File' }).Count
    $folderTemplates = ($templateData.Values | Where-Object { $_.Type -eq 'Folder' }).Count
    Write-Host "File templates: $fileTemplates" -ForegroundColor Gray
    Write-Host "Folder templates: $folderTemplates" -ForegroundColor Gray

    # Category breakdown
    Write-Host "`nCategories:" -ForegroundColor White
    $categories = $templateData.Values | Group-Object Category | Sort-Object Count -Descending
    $categories | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor Gray
    }

    # Usage statistics
    $totalUses = ($templateData.Values | ForEach-Object { if ($_.UseCount) { $_.UseCount } else { 0 } } | Measure-Object -Sum).Sum
    $usedTemplates = ($templateData.Values | Where-Object { (if ($_.UseCount) { $_.UseCount } else { 0 }) -gt 0 }).Count
    $neverUsed = $templateData.Count - $usedTemplates

    Write-Host "`nUsage:" -ForegroundColor White
    Write-Host "  Total uses: $totalUses" -ForegroundColor Gray
    Write-Host "  Used templates: $usedTemplates" -ForegroundColor Gray
    Write-Host "  Never used: $neverUsed" -ForegroundColor Gray

    # Top used templates
    if ($usedTemplates -gt 0) {
        Write-Host "`nTop $ShowTop Most Used:" -ForegroundColor White
        $topTemplates = $templateData.GetEnumerator() |
            Sort-Object { if ($_.Value.UseCount) { $_.Value.UseCount } else { 0 } } -Descending |
            Select-Object -First $ShowTop

        $topTemplates | ForEach-Object {
            $useCount = if ($_.Value.UseCount) { $_.Value.UseCount } else { 0 }
            $lastUsed = if ($_.Value.LastUsed -eq 'Never') { 'Never' } else { $_.Value.LastUsed }
            Write-Host "  $($_.Key.PadRight(15)) $useCount uses (Last: $lastUsed)" -ForegroundColor Gray
        }
    }

    # Recent activity
    $recentTemplates = $templateData.GetEnumerator() |
        Where-Object { $_.Value.LastUsed -ne 'Never' } |
        Sort-Object { [DateTime]::ParseExact($_.Value.LastUsed, 'yyyy-MM-dd HH:mm:ss', $null) } -Descending |
        Select-Object -First 3

    if ($recentTemplates) {
        Write-Host "`nRecently Used:" -ForegroundColor White
        $recentTemplates | ForEach-Object {
            Write-Host "  $($_.Key.PadRight(15)) $($_.Value.LastUsed)" -ForegroundColor Gray
        }
    }

    # Tag statistics
    $allTags = $templateData.Values | ForEach-Object { $_.Tags } | Where-Object { $_ } | ForEach-Object { $_ }
    if ($allTags) {
        $tagStats = $allTags | Group-Object | Sort-Object Count -Descending | Select-Object -First 5
        Write-Host "`nTop Tags:" -ForegroundColor White
        $tagStats | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor Gray
        }
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Add-Template',
    'Get-Templates',
    'Use-Template',
    'Remove-Template',
    'Update-Template',
    'Export-Templates',
    'Import-Templates',
    'Get-TemplateStats',
    'Get-TemplaterConfigPath'
)

# Set up aliases for common operations
Set-Alias -Name 'templates' -Value 'Get-Templates'
Set-Alias -Name 'template' -Value 'Get-Templates'
Set-Alias -Name 'tpl' -Value 'Get-Templates'
Set-Alias -Name 'use-tpl' -Value 'Use-Template'
Set-Alias -Name 'add-tpl' -Value 'Add-Template'
Set-Alias -Name 'remove-tpl' -Value 'Remove-Template'

# Alias completer
Register-ArgumentCompleter -CommandName Add-Template, Remove-Template, Update-Template, Use-Template, Get-Templates -ParameterName Alias -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $configPath = Get-TemplaterConfigPath
    if (Test-Path $configPath) {
        $aliases = (Get-Content $configPath -Raw | ConvertFrom-Json).psobject.Properties.Name
        $aliases | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

# Category completer
Register-ArgumentCompleter -CommandName Add-Template, Get-Templates, Update-Template, Export-Templates -ParameterName Category -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $configPath = Get-TemplaterConfigPath
    if (Test-Path $configPath) {
        $categories = (Get-Content $configPath -Raw | ConvertFrom-Json).psobject.Properties.Value |
            ForEach-Object { $_.Category } | Where-Object { $_ } | Sort-Object -Unique
        $categories | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

# Tag completer
Register-ArgumentCompleter -CommandName Add-Template, Get-Templates, Update-Template, Export-Templates -ParameterName Tag -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $configPath = Get-TemplaterConfigPath
    if (Test-Path $configPath) {
        $tags = (Get-Content $configPath -Raw | ConvertFrom-Json).psobject.Properties.Value |
            Where-Object { $_.Tags } | ForEach-Object { $_.Tags } | ForEach-Object { $_ } |
            Where-Object { $_ } | Sort-Object -Unique
        $tags | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

# Path completer (file/folder completion for Add-Template and Update-Template)
Register-ArgumentCompleter -CommandName Add-Template, Update-Template -ParameterName Path -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    # Use built-in file/folder completion
    [System.Management.Automation.CompletionCompleters]::CompleteFilename($wordToComplete)
}

Export-ModuleMember -Alias @('templates', 'template', 'tpl', 'use-tpl', 'add-tpl', 'remove-tpl')
