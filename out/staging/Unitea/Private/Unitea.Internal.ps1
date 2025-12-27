function Test-EnvironmentToggle {
    param(
        [string]$Value
    )

    if (-not $Value) {
        return $false
    }

    return $Value -match '^(1|true|yes|on)$'
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

function Get-UnityHubDefaultPath {
    if ($script:IsWindows) {
        return 'C:\Program Files\Unity Hub\Unity Hub.exe'
    }

    if ($script:IsMacOS) {
        $candidates = @(
            '/Applications/Unity Hub.app/Contents/MacOS/Unity Hub',
            '/Applications/UnityHub.app/Contents/MacOS/Unity Hub'
        )
        foreach ($candidate in $candidates) {
            if (Test-Path $candidate) {
                return $candidate
            }
        }
        return 'unityhub'
    }

    if ($script:IsLinux) {
        $userHome = $env:HOME
        $candidates = @(
            '/usr/bin/unityhub',
            '/usr/local/bin/unityhub',
            '/opt/unityhub/unityhub',
            '/opt/UnityHub/unityhub'
        )

        if ($userHome) {
            $candidates += @(
                (Join-PathSegments -Segments @($userHome, 'UnityHub', 'UnityHub.AppImage')),
                (Join-PathSegments -Segments @($userHome, 'Applications', 'UnityHub.AppImage'))
            )
        }

        $candidates = $candidates | Where-Object { $_ }

        foreach ($candidate in $candidates) {
            if (Test-Path $candidate) {
                return $candidate
            }
        }

        return 'unityhub'
    }

    return 'unityhub'
}

function Get-UnityEditorBasePaths {
    $paths = New-Object System.Collections.Generic.List[string]

    if ($script:IsWindows) {
        $programFiles = $env:ProgramFiles
        $programFilesX86 = ${env:ProgramFiles(x86)}

        if ($programFiles) {
            $paths.Add((Join-PathSegments -Segments @($programFiles, 'Unity', 'Hub', 'Editor')))
            $paths.Add((Join-PathSegments -Segments @($programFiles, 'Unity')))
        }

        if ($programFilesX86) {
            $paths.Add((Join-PathSegments -Segments @($programFilesX86, 'Unity')))
            $paths.Add((Join-PathSegments -Segments @($programFilesX86, 'Unity Hub', 'Editor')))
        }
    } elseif ($script:IsMacOS) {
        $paths.Add('/Applications/Unity/Hub/Editor')
        $paths.Add('/Applications/Unity')

        if ($env:HOME) {
            $paths.Add((Join-PathSegments -Segments @($env:HOME, 'Applications', 'Unity', 'Hub', 'Editor')))
            $paths.Add((Join-PathSegments -Segments @($env:HOME, 'Unity', 'Hub', 'Editor')))
        }
    } elseif ($script:IsLinux) {
        $paths.Add('/opt/Unity/Hub/Editor')
        $paths.Add('/opt/UnityHub/Editor')

        if ($env:HOME) {
            $paths.Add((Join-PathSegments -Segments @($env:HOME, 'Unity', 'Hub', 'Editor')))
            $paths.Add((Join-PathSegments -Segments @($env:HOME, 'UnityHub', 'Editor')))
            $paths.Add((Join-PathSegments -Segments @($env:HOME, '.local', 'share', 'unity3d', 'Hub', 'Editor')))
        }
    }

    return $paths | Where-Object { $_ } | Select-Object -Unique
}

function Get-UnityExecutableFromDirectory {
    param(
        [System.IO.DirectoryInfo]$Directory
    )

    if (-not $Directory) {
        return $null
    }

    if ($script:IsWindows) {
        return Join-PathSegments -Segments @($Directory.FullName, 'Editor', 'Unity.exe')
    }

    if ($script:IsMacOS) {
        if ($Directory.Name -like '*.app') {
            $appBinary = Join-PathSegments -Segments @($Directory.FullName, 'Contents', 'MacOS', 'Unity')
            if (Test-Path $appBinary) {
                return $appBinary
            }
        }

        $embeddedApp = Join-PathSegments -Segments @($Directory.FullName, 'Unity.app', 'Contents', 'MacOS', 'Unity')
        if (Test-Path $embeddedApp) {
            return $embeddedApp
        }

        $editorApp = Join-PathSegments -Segments @($Directory.FullName, 'Editor', 'Unity.app', 'Contents', 'MacOS', 'Unity')
        if (Test-Path $editorApp) {
            return $editorApp
        }

        return $null
    }

    $editorBinary = Join-PathSegments -Segments @($Directory.FullName, 'Editor', 'Unity')
    if (Test-Path $editorBinary) {
        return $editorBinary
    }

    $fallbackBinary = Join-PathSegments -Segments @($Directory.FullName, 'Unity')
    if (Test-Path $fallbackBinary) {
        return $fallbackBinary
    }

    return $null
}

function Get-UnityExecutableFromBase {
    param(
        [string]$BasePath,
        [string]$UnityVersion
    )

    if (-not $UnityVersion) {
        return $null
    }

    $versionDirectoryPath = Join-PathSegments -Segments @($BasePath, $UnityVersion)
    if (-not (Test-Path $versionDirectoryPath)) {
        return $null
    }

    try {
        $directory = Get-Item -Path $versionDirectoryPath -ErrorAction Stop
        return Get-UnityExecutableFromDirectory -Directory $directory
    } catch {
        return $null
    }
}

function Find-UnityEditorExecutable {
    param(
        [string]$UnityVersion
    )

    $basePaths = Get-UnityEditorBasePaths
    $majorMinor = $null
    if ($UnityVersion -and ($UnityVersion -split '\.').Count -ge 2) {
        $split = $UnityVersion -split '\.'
        $majorMinor = "$($split[0]).$($split[1])"
    }

    foreach ($basePath in $basePaths) {
        if (-not (Test-Path $basePath)) {
            continue
        }

        $exactCandidate = Get-UnityExecutableFromBase -BasePath $basePath -UnityVersion $UnityVersion
        if ($exactCandidate -and (Test-Path $exactCandidate)) {
            return [pscustomobject]@{
                Path = $exactCandidate
                Version = $UnityVersion
                MatchType = 'Exact'
            }
        }

        $directories = Get-ChildItem -Path $basePath -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
        foreach ($directory in $directories) {
            if ($UnityVersion -and $directory.Name -eq $UnityVersion) {
                continue
            }

            if ($majorMinor -and -not ($directory.Name.StartsWith($majorMinor))) {
                continue
            }

            $candidate = Get-UnityExecutableFromDirectory -Directory $directory
            if ($candidate -and (Test-Path $candidate)) {
                return [pscustomobject]@{
                    Path = $candidate
                    Version = $directory.Name
                    MatchType = 'Similar'
                }
            }
        }
    }

    $commandCandidates = @('unity', 'Unity')
    foreach ($command in $commandCandidates) {
        try {
            $commandInfo = Get-Command $command -ErrorAction Stop
            $commandPath = if ($commandInfo.Path) { $commandInfo.Path } else { $commandInfo.Source }
            if ($commandPath) {
                return [pscustomobject]@{
                    Path = $commandPath
                    Version = $UnityVersion
                    MatchType = 'Command'
                }
            }
        } catch {
            continue
        }
    }

    return $null
}

function Start-UnityHubForProject {
    param(
        [string]$UnityHubPath,
        [string]$ProjectPath
    )

    $projectArgument = if ($script:IsWindows) { "`"$ProjectPath`"" } else { $ProjectPath }
    $arguments = @('--projectPath', $projectArgument)

    if ($UnityHubPath -and (Test-Path $UnityHubPath)) {
        $hubExecutable = $UnityHubPath
        if ($script:IsMacOS -and $hubExecutable -like '*.app') {
            $bundleExecutable = Join-PathSegments -Segments @($hubExecutable, 'Contents', 'MacOS', 'Unity Hub')
            if (Test-Path $bundleExecutable) {
                $hubExecutable = $bundleExecutable
            }
        }

        Start-Process -FilePath $hubExecutable -ArgumentList $arguments -NoNewWindow:$false
        return $true
    }

    if ($script:IsMacOS -and (Test-Path '/Applications/Unity Hub.app')) {
        Start-Process -FilePath 'open' -ArgumentList '-a', 'Unity Hub', '--args', '--projectPath', $ProjectPath -NoNewWindow:$false
        return $true
    }

    try {
        $commandInfo = Get-Command $UnityHubPath -ErrorAction Stop
        $hubCommand = if ($commandInfo.Path) { $commandInfo.Path } else { $commandInfo.Source }
        if (-not $hubCommand) {
            $hubCommand = $UnityHubPath
        }

        Start-Process -FilePath $hubCommand -ArgumentList $arguments -NoNewWindow:$false
        return $true
    } catch {
        return $false
    }
}

function New-UnityProjectsData {
    return [ordered]@{}
}

function Copy-UnityProjectsData {
    param(
        [hashtable]$ProjectsData
    )

    if (-not $ProjectsData) {
        return New-UnityProjectsData
    }

    $json = $ProjectsData | ConvertTo-Json -Depth 10
    return $json | ConvertFrom-Json -AsHashtable
}

function ConvertTo-UnityProjectRecord {
    param(
        [string]$Alias,
        [hashtable]$Project
    )

    $lastOpenedString = if ($Project.LastOpened) { $Project.LastOpened } else { 'Never' }
    $lastOpenedDate = $null

    if ($lastOpenedString -and $lastOpenedString -ne 'Never') {
        $parsedLastOpened = [DateTime]::MinValue
        $parsed = [DateTime]::TryParseExact(
            $lastOpenedString,
            'yyyy-MM-dd HH:mm:ss',
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AssumeLocal,
            [ref]$parsedLastOpened
        )

        if ($parsed) {
            $lastOpenedDate = $parsedLastOpened
        }
    }

    return [PSCustomObject]@{
        Alias = $Alias
        Name = $Project.Name
        Path = $Project.Path
        UnityVersion = $Project.UnityVersion
        DateAdded = $Project.DateAdded
        LastOpenedString = $lastOpenedString
        LastOpened = $lastOpenedDate
    }
}

function Get-UniteaProjectDisplayString {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Record
    )

    $name = if ($Record.Name) { $Record.Name } else { '(Unnamed project)' }
    $version = if ($Record.UnityVersion) { $Record.UnityVersion } else { 'Unknown' }
    $lastOpened = if ($Record.LastOpened) {
        $Record.LastOpened.ToString('yyyy-MM-dd HH:mm:ss')
    } elseif ($Record.LastOpenedString) {
        $Record.LastOpenedString
    } else {
        'Never'
    }
    $path = if ($Record.Path) { $Record.Path } else { '(no path)' }

    return "$($Record.Alias) - $name [$version] (Last: $lastOpened) - $path"
}

function Invoke-UniteaFallbackSelection {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Records,

        [string]$Header = 'Select Unity Project',

        [switch]$AllowMulti
    )

    if (-not $Records -or $Records.Count -eq 0) {
        return $AllowMulti ? @() : $null
    }

    if (Test-PSMagicNonInteractive) {
        Write-Warning 'Interactive selection skipped because non-interactive mode is enabled.'
        return $AllowMulti ? @() : $null
    }

    Write-Host ''
    Write-Host $Header -ForegroundColor Cyan

    $aliasLookup = New-Object 'System.Collections.Generic.Dictionary[string,pscustomobject]' ([System.StringComparer]::OrdinalIgnoreCase)
    for ($index = 0; $index -lt $Records.Count; $index++) {
        $record = $Records[$index]
        $display = Get-UniteaProjectDisplayString -Record $record
        Write-Host ('[{0}] {1}' -f ($index + 1), $display) -ForegroundColor Gray

        if ($record.Alias -and -not $aliasLookup.ContainsKey($record.Alias)) {
            $aliasLookup[$record.Alias] = $record
        }
    }

    $prompt = if ($AllowMulti) {
        'Enter number(s) or aliases (comma separated), or press Enter to cancel'
    } else {
        'Enter number or alias (press Enter to cancel)'
    }

    $response = Read-Host $prompt

    if ([string]::IsNullOrWhiteSpace($response)) {
        return $AllowMulti ? @() : $null
    }

    $tokens = $response -split '[,\s]+' | Where-Object { $_ }
    if ($tokens.Count -eq 0) {
        return $AllowMulti ? @() : $null
    }

    $selected = New-Object System.Collections.Generic.List[object]
    foreach ($token in $tokens) {
        if ($token -match '^\d+$') {
            $numericIndex = [int]$token
            if ($numericIndex -ge 1 -and $numericIndex -le $Records.Count) {
                $selected.Add($Records[$numericIndex - 1])
            } else {
                Write-Warning "Selection '$token' is out of range."
            }
        } elseif ($aliasLookup.ContainsKey($token)) {
            $selected.Add($aliasLookup[$token])
        } else {
            Write-Warning "No project found matching '$token'."
        }
    }

    if ($selected.Count -eq 0) {
        return $AllowMulti ? @() : $null
    }

    if ($AllowMulti) {
        return @($selected | Select-Object -Unique)
    }

    return $selected[0]
}

function Get-UnityProjectsData {
    $configPath = Get-UnityConfigPath
    if (Test-Path $configPath) {
        try {
            $fileInfo = Get-Item $configPath -ErrorAction Stop

            if ($script:UnityProjectsCache -ne $null -and
                $script:UnityProjectsTimestamp -eq $fileInfo.LastWriteTimeUtc) {
                return Copy-UnityProjectsData -ProjectsData $script:UnityProjectsCache
            }

            $projectsData = Get-Content $configPath -Raw -ErrorAction Stop |
                ConvertFrom-Json -AsHashtable -ErrorAction Stop

            if (-not $projectsData) {
                $projectsData = New-UnityProjectsData
            }

            $script:UnityProjectsCache = Copy-UnityProjectsData -ProjectsData $projectsData
            $script:UnityProjectsTimestamp = $fileInfo.LastWriteTimeUtc

            return Copy-UnityProjectsData -ProjectsData $projectsData
        } catch {
            Write-Warning "Unity projects configuration at '$configPath' is invalid: $($_.Exception.Message)"
            $timestamp = Get-Date -Format 'yyyyMMddTHHmmss'
            $backupPath = "$configPath.backup.$timestamp"

            try {
                Copy-Item $configPath $backupPath -Force
                Write-Warning "Backup created at: $backupPath"
            } catch {
                Write-Warning "Failed to create backup for corrupt Unity projects configuration: $($_.Exception.Message)"
            }

            $resetData = New-UnityProjectsData

            try {
                Save-UnityProjectsData -ProjectsData $resetData
            } catch {
                Write-Warning "Failed to reset Unity projects configuration: $($_.Exception.Message)"
            }

            return Copy-UnityProjectsData -ProjectsData $resetData
        }
    }

    $data = New-UnityProjectsData
    $script:UnityProjectsCache = Copy-UnityProjectsData -ProjectsData $data
    $script:UnityProjectsTimestamp = $null
    return Copy-UnityProjectsData -ProjectsData $data
}

function Save-UnityProjectsData {
    param([hashtable]$ProjectsData)

    $configPath = Get-UnityConfigPath
    try {
        $json = $ProjectsData | ConvertTo-Json -Depth 5
        $json | Set-Content $configPath -Encoding UTF8
        $fileInfo = Get-Item $configPath -ErrorAction Stop
        $script:UnityProjectsCache = Copy-UnityProjectsData -ProjectsData $ProjectsData
        $script:UnityProjectsTimestamp = $fileInfo.LastWriteTimeUtc
    } catch {
        $message = "Failed to save Unity projects data to '$configPath'. $($_.Exception.Message)"
        throw (New-Object System.Exception($message, $_.Exception))
    }
}

function Update-LastOpened {
    param(
        [string]$ProjectPath,
        [string]$Alias = $null
    )

    $projectsData = Get-UnityProjectsData
    $currentTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $updated = $false

    # If we have an alias, update that project
    if ($Alias -and $projectsData.ContainsKey($Alias)) {
        $projectsData[$Alias].LastOpened = $currentTime
        $updated = $true
    } else {
        # Find project by path and update it
        foreach ($key in $projectsData.Keys) {
            if ($projectsData[$key].Path -eq $ProjectPath) {
                $projectsData[$key].LastOpened = $currentTime
                $updated = $true
                break
            }
        }
    }

    if ($updated) {
        Save-UnityProjectsData -ProjectsData $projectsData
    }
}

function Test-IsUnityProject {
    param([string]$Path = (Get-Location).Path)

    $projectVersionFile = Join-Path $Path 'ProjectSettings' 'ProjectVersion.txt'
    return Test-Path $projectVersionFile
}

function Get-UnityProjectInfo {
    param([string]$Path)

    $projectVersionFile = Join-Path $Path 'ProjectSettings' 'ProjectVersion.txt'
    $projectName = Split-Path $Path -Leaf
    $unityVersion = 'Unknown'

    if (Test-Path $projectVersionFile) {
        try {
            $versionContent = Get-Content $projectVersionFile | Where-Object { $_.StartsWith('m_EditorVersion:') }
            if ($versionContent) {
                $unityVersion = ($versionContent -split ':')[1].Trim()
            }
        } catch {
            Write-Warning "Could not read Unity version from $projectVersionFile"
        }
    }

    $currentTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

    return @{
        Name = $projectName
        Path = (Resolve-Path $Path).Path
        UnityVersion = $unityVersion
        DateAdded = $currentTime
        LastOpened = 'Never'
    }
}
