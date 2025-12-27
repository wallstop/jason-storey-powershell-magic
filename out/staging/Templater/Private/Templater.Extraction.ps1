# Templater.Extraction.ps1
# Modular functions for template extraction and deployment

function Resolve-TemplateDestination {
    <#
    .SYNOPSIS
    Resolves the final destination path for template deployment.

    .DESCRIPTION
    Determines where the template should be deployed based on parameters,
    creating subdirectories if needed and applying variable substitution.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [string]$Alias,

        [bool]$CreateSubfolder,

        [string]$SubfolderName,

        [hashtable]$VariableMap
    )

    $finalDestination = $DestinationPath

    if ($SubfolderName) {
        Write-Verbose "SubfolderName parameter received value '$SubfolderName'."
        $resolvedSubfolder = if ($VariableMap.Count -gt 0) {
            Resolve-TemplaterTokens -Text $SubfolderName -VariableMap $VariableMap
        } else {
            $SubfolderName
        }
        Write-Verbose "Resolved subfolder name to '$resolvedSubfolder'."
        $finalDestination = Join-Path $DestinationPath $resolvedSubfolder
    } elseif ($CreateSubfolder) {
        $subfolder = if ($VariableMap.Count -gt 0) {
            Resolve-TemplaterTokens -Text $Alias -VariableMap $VariableMap
        } else {
            $Alias
        }
        Write-Verbose "Using subfolder name '$subfolder' based on alias."
        $finalDestination = Join-Path $DestinationPath $subfolder
    }

    return $finalDestination
}

function Initialize-TemplateDestination {
    <#
    .SYNOPSIS
    Creates the template destination directory if it doesn't exist.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    if (-not (Test-Path $DestinationPath)) {
        try {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
            Write-Verbose "Created directory: $DestinationPath"
        } catch {
            throw "Failed to create destination directory: $DestinationPath"
        }
    }
}

function Copy-TemplateFolder {
    <#
    .SYNOPSIS
    Copies a template folder to the destination with progress tracking.

    .DESCRIPTION
    Efficiently copies all files and directories from a template folder,
    with optional overwrite confirmation and progress display.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [bool]$Force
    )

    $allItems = Get-ChildItem -Path $SourcePath -Recurse -Force
    $directories = @($allItems | Where-Object { $_.PSIsContainer })
    $files = @($allItems | Where-Object { -not $_.PSIsContainer })

    # Create directory structure
    foreach ($directory in $directories) {
        $relativeDir = $directory.FullName.Substring($SourcePath.Length + 1)
        $destDirPath = Join-Path $DestinationPath $relativeDir
        if (-not (Test-Path $destDirPath)) {
            New-Item -ItemType Directory -Path $destDirPath -Force | Out-Null
        }
    }

    $totalFiles = $files.Count
    $copiedFiles = 0
    $overwriteAll = $Force

    if ($totalFiles -gt 0) {
        Write-Verbose "Copying $totalFiles files..."
    } else {
        Write-Verbose 'No files found to copy (only directory structure).'
        return [PSCustomObject]@{
            CopiedFiles = 0
            DirectoryCount = $directories.Count
        }
    }

    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($SourcePath.Length + 1)
        $destPath = Join-Path $DestinationPath $relativePath

        $destDir = Split-Path $destPath -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        if ((Test-Path $destPath) -and -not $overwriteAll) {
            $choice = Read-Host "File exists: $relativePath. Overwrite? (y/N/a for all)"
            if ($choice -match '^[Aa]') {
                $overwriteAll = $true
            } elseif ($choice -notmatch '^[Yy]') {
                Write-Verbose "Skipping: $relativePath"
                continue
            }
        }

        try {
            [System.IO.File]::Copy($file.FullName, $destPath, $overwriteAll)
            $copiedFiles++

            # Show progress for large operations
            if ($totalFiles -gt 50 -and ($copiedFiles % 10) -eq 0) {
                $percent = [math]::Round(($copiedFiles / $totalFiles) * 100)
                Write-Verbose "Progress: $copiedFiles/$totalFiles ($percent%)"
            }
        } catch {
            Write-Warning "Failed to copy: $relativePath - $($_.Exception.Message)"
        }
    }

    return [PSCustomObject]@{
        CopiedFiles = $copiedFiles
        DirectoryCount = $directories.Count
    }
}

function Invoke-TemplateExtraction {
    <#
    .SYNOPSIS
    Extracts or copies a template to the destination.

    .DESCRIPTION
    Handles both archive extraction and folder copying based on template type.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Template,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [bool]$Force
    )

    $processingRoot = $DestinationPath
    $result = @{
        Type = $Template.Type
        FilesProcessed = 0
        DirectoriesProcessed = 0
        ProcessingRoot = $processingRoot
    }

    switch ($Template.Type) {
        'File' {
            # Extract archive
            $extractResult = Expand-PSMagicArchive -ArchivePath $Template.Path -DestinationPath $DestinationPath -Force:$Force
            if ($extractResult) {
                $result.ProcessingRoot = $extractResult
            }
            Write-Verbose 'Template extracted successfully!'
        }
        'Folder' {
            # Copy folder contents
            $copyResult = Copy-TemplateFolder -SourcePath $Template.Path -DestinationPath $DestinationPath -Force $Force
            $result.FilesProcessed = $copyResult.CopiedFiles
            $result.DirectoriesProcessed = $copyResult.DirectoryCount
            Write-Verbose "Template copied successfully! ($($copyResult.CopiedFiles) files, $($copyResult.DirectoryCount) directories)" -ForegroundColor Green
        }
    }

    return $result
}

Export-ModuleMember -Function @(
    'Resolve-TemplateDestination',
    'Initialize-TemplateDestination',
    'Copy-TemplateFolder',
    'Invoke-TemplateExtraction'
)
