function ConvertTo-TemplaterVariableMap {
    param(
        [hashtable]$Variables
    )

    $map = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::OrdinalIgnoreCase)
    if (-not $Variables) {
        return $map
    }

    foreach ($entry in $Variables.GetEnumerator()) {
        $key = $entry.Key
        if ([string]::IsNullOrWhiteSpace($key)) {
            continue
        }

        $value = if ($null -ne $entry.Value) { [string]$entry.Value } else { '' }
        $map[$key] = $value
    }

    return $map
}

function Resolve-TemplaterTokens {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.IDictionary[string, string]]$VariableMap
    )

    Write-Verbose "Resolve-TemplaterTokens input '$Text' with $($VariableMap.Count) variables (map type: $($VariableMap.GetType().FullName))."

    if ([string]::IsNullOrEmpty($Text) -or $VariableMap.Count -eq 0) {
        return $Text
    }

    $result = $Text
    foreach ($entry in $VariableMap.GetEnumerator()) {
        $token = '{' + '{' + $entry.Key + '}' + '}'
        $replacement = $entry.Value
        if ($null -eq $replacement) {
            $replacement = ''
        }
        $result = $result.Replace($token, $replacement)
    }

    Write-Verbose "Resolved template tokens to '$result'."

    return $result
}

function Invoke-TemplaterVariableRenames {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.IDictionary[string, string]]$VariableMap
    )

    if ($VariableMap.Count -eq 0) {
        return
    }

    $directories = Get-ChildItem -Path $RootPath -Directory -Recurse | Sort-Object FullName -Descending
    foreach ($directory in $directories) {
        $newName = Resolve-TemplaterTokens -Text $directory.Name -VariableMap $VariableMap
        if ($newName -eq $directory.Name) {
            continue
        }

        $targetPath = Join-Path (Split-Path $directory.FullName -Parent) $newName
        if ((Test-Path -LiteralPath $targetPath) -and -not [string]::Equals($directory.FullName, $targetPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Warning "Skipping rename for '$($directory.FullName)' because '$targetPath' already exists."
            continue
        }

        try {
            Move-Item -LiteralPath $directory.FullName -Destination $targetPath -Force
        } catch {
            Write-Warning "Failed to rename directory '$($directory.FullName)': $($_.Exception.Message)"
        }
    }

    $files = Get-ChildItem -Path $RootPath -File -Recurse
    foreach ($file in $files) {
        $newName = Resolve-TemplaterTokens -Text $file.Name -VariableMap $VariableMap
        if ($newName -eq $file.Name) {
            continue
        }

        $targetPath = Join-Path (Split-Path $file.FullName -Parent) $newName
        if ((Test-Path -LiteralPath $targetPath) -and -not [string]::Equals($file.FullName, $targetPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Warning "Skipping rename for '$($file.FullName)' because '$targetPath' already exists."
            continue
        }

        try {
            Move-Item -LiteralPath $file.FullName -Destination $targetPath -Force
        } catch {
            Write-Warning "Failed to rename file '$($file.FullName)': $($_.Exception.Message)"
        }
    }
}

function Invoke-TemplaterVariableContentUpdate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.IDictionary[string, string]]$VariableMap,

        [string[]]$Extensions = $script:TemplateVariableDefaultExtensions
    )

    if ($VariableMap.Count -eq 0) {
        return
    }

    $normalizedExtensions = @()
    if ($Extensions -and $Extensions.Count -gt 0) {
        $normalizedExtensions = $Extensions | ForEach-Object { $_.ToLowerInvariant().TrimStart('.') } | Where-Object { $_ }
    }

    $pattern = '\{\{(?<name>[A-Za-z0-9_]+)\}\}'

    $candidateFiles = if ($normalizedExtensions -and $normalizedExtensions.Count -gt 0) {
        Get-ChildItem -Path $RootPath -File -Recurse | Where-Object {
            $ext = [System.IO.Path]::GetExtension($_.Name).TrimStart('.').ToLowerInvariant()
            $normalizedExtensions -contains $ext
        }
    } else {
        Get-ChildItem -Path $RootPath -File -Recurse
    }

    foreach ($file in $candidateFiles) {
        try {
            $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
        } catch {
            Write-Verbose "Skipping variable substitution for '$($file.FullName)': unable to read file. $($_.Exception.Message)"
            continue
        }

        if (-not $content -or ($content -notmatch $pattern)) {
            continue
        }

        $updatedContent = [regex]::Replace(
            $content,
            $pattern,
            {
                param($match)
                $name = $match.Groups['name'].Value
                if ($VariableMap.ContainsKey($name)) {
                    return $VariableMap[$name]
                }

                return $match.Value
            }
        )

        if ($updatedContent -ne $content) {
            try {
                Set-Content -Path $file.FullName -Value $updatedContent -Encoding UTF8 -Force
                Write-Verbose "Applied template variables to '$($file.FullName)'."
            } catch {
                Write-Warning "Failed to apply template variables to '$($file.FullName)': $($_.Exception.Message)"
            }
        }
    }
}

function Invoke-TemplaterVariableProcessing {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.IDictionary[string, string]]$VariableMap,

        [string[]]$Extensions = $script:TemplateVariableDefaultExtensions
    )

    if (-not (Test-Path -LiteralPath $RootPath)) {
        return
    }

    Invoke-TemplaterVariableRenames -RootPath $RootPath -VariableMap $VariableMap
    Invoke-TemplaterVariableContentUpdate -RootPath $RootPath -VariableMap $VariableMap -Extensions $Extensions
}

function Get-TemplateData {
    $configPath = Get-TemplaterConfigPath
    if (Test-Path $configPath) {
        try {
            $fileInfo = Get-Item $configPath -ErrorAction Stop
            if ($script:TemplaterConfigCache -ne $null -and
                $script:TemplaterConfigTimestamp -eq $fileInfo.LastWriteTimeUtc) {
                return Copy-PSMagicHashtable -InputObject $script:TemplaterConfigCache
            }

            $data = Get-Content $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            $script:TemplaterConfigCache = Copy-PSMagicHashtable -InputObject $data
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
        $script:TemplaterConfigCache = if ($TemplateData) { Copy-PSMagicHashtable -InputObject $TemplateData } else { @{} }
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

function Get-TemplaterDisplayString {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Alias,
        [Parameter(Mandatory = $true)]
        [hashtable]$Template
    )

    $description = if ($Template.Description) { $Template.Description } else { '(no description)' }
    $category = if ($Template.Category) { $Template.Category } else { 'General' }
    $type = if ($Template.Type) { $Template.Type } else { 'Unknown' }
    $useCount = if ($Template.UseCount) { $Template.UseCount } else { 0 }
    $lastUsed = if ($Template.LastUsed -and $Template.LastUsed -ne 'Never') { $Template.LastUsed } else { 'Never used' }
    $tags = if ($Template.Tags -and $Template.Tags.Count -gt 0) { '[' + ($Template.Tags -join ', ') + ']' } else { '' }

    return "$Alias - $description [$category/$type] (Uses: $useCount, Last: $lastUsed) $tags"
}

function Invoke-TemplaterFallbackSelection {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Records,

        [string]$Header = 'Select Template'
    )

    if (-not $Records -or $Records.Count -eq 0) {
        return $null
    }

    if (Test-PSMagicNonInteractive) {
        Write-Warning 'Interactive selection skipped because non-interactive mode is enabled.'
        return $null
    }

    Write-Host ''
    Write-Host $Header -ForegroundColor Cyan

    $aliasDictionary = New-Object 'System.Collections.Generic.Dictionary[string,pscustomobject]'([System.StringComparer]::OrdinalIgnoreCase)
    for ($index = 0; $index -lt $Records.Count; $index++) {
        $record = $Records[$index]
        $display = Get-TemplaterDisplayString -Alias $record.Alias -Template $record.Template
        Write-Host ('[{0}] {1}' -f ($index + 1), $display) -ForegroundColor Gray
        if (-not $aliasDictionary.ContainsKey($record.Alias)) {
            $aliasDictionary[$record.Alias] = $record
        }
    }

    $response = Read-Host 'Enter number or alias (press Enter to cancel)'
    if ([string]::IsNullOrWhiteSpace($response)) {
        return $null
    }

    if ($response -match '^\d+$') {
        $numericIndex = [int]$response
        if ($numericIndex -lt 1 -or $numericIndex -gt $Records.Count) {
            Write-Warning "Selection '$response' is out of range."
            return $null
        }

        return $Records[$numericIndex - 1]
    }

    if ($aliasDictionary.ContainsKey($response)) {
        return $aliasDictionary[$response]
    }

    Write-Warning "No template found matching '$response'."
    return $null
}

function Test-IsTrusted7ZipPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $safeRoots = @()

    $managedDir = Get-ManagedSevenZipDirectory
    if ($managedDir) {
        $safeRoots += $managedDir
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
        $safeRoots += '/opt/homebrew/bin'
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

function Get-PowerShellMagicDataRoot {
    if ($script:IsWindows) {
        if ($env:LOCALAPPDATA) {
            return Join-Path $env:LOCALAPPDATA 'PowerShellMagic'
        }

        return $null
    }

    if ($env:XDG_DATA_HOME) {
        return Join-Path $env:XDG_DATA_HOME 'powershell-magic'
    }

    if ($env:HOME) {
        return Join-Path (Join-Path $env:HOME '.local/share') 'powershell-magic'
    }

    return $null
}

function Get-ManagedSevenZipDirectory {
    $dataRoot = Get-PowerShellMagicDataRoot
    if (-not $dataRoot) {
        return $null
    }

    return Join-Path $dataRoot 'bin'
}

function Get-ManagedSevenZipHash {
    param(
        [string]$Platform = $script:CurrentPlatform
    )

    if (-not $Platform) {
        return $null
    }

    if ($script:ManagedSevenZipHashes.ContainsKey($Platform)) {
        return $script:ManagedSevenZipHashes[$Platform]
    }

    return $null
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
        Get-ManagedSevenZipHash
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

    $managedBin = Get-ManagedSevenZipDirectory
    if ($managedBin) {
        if ($script:IsWindows) {
            $candidates.Add((Join-Path $managedBin '7z.exe'))
            $candidates.Add((Join-Path $managedBin '7z'))
        } else {
            $candidates.Add((Join-Path $managedBin '7zz'))
            $candidates.Add((Join-Path $managedBin '7z'))
            $candidates.Add((Join-Path $managedBin '7zzs'))
        }
    }

    if ($script:IsWindows) {
        if ($env:ProgramFiles) {
            $candidates.Add((Join-Path (Join-Path $env:ProgramFiles '7-Zip') '7z.exe'))
        }

        if (${env:ProgramFiles(x86)}) {
            $candidates.Add((Join-Path (Join-Path ${env:ProgramFiles(x86)} '7-Zip') '7z.exe'))
        }
    } else {
        $candidates.Add('/usr/bin/7zz')
        $candidates.Add('/usr/local/bin/7zz')
        $candidates.Add('/opt/homebrew/bin/7zz')
        $candidates.Add('/usr/bin/7z')
        $candidates.Add('/usr/local/bin/7z')
        $candidates.Add('/opt/homebrew/bin/7z')
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

    $commandNames = if ($script:IsWindows) { @('7z.exe', '7z') } else { @('7zz', '7z', '7za', '7zzs') }

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

function Expand-PSMagicArchive {
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
    Expand-PSMagicArchive -ArchivePath "template.zip"
    Extracts template.zip to current directory

    .EXAMPLE
    Expand-PSMagicArchive -ArchivePath "template.7z" -DestinationPath "C:\Projects" -CreateSubfolder
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
                    throw 'Trusted 7-Zip executable not found. Install 7-Zip via Setup-PowerShellMagic or set POWERSHELLMAGIC_7ZIP_PATH.'
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
