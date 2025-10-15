# Unitea.psm1
using namespace System.Collections.Generic

$script:UnityProjectsCache = $null
$script:UnityProjectsTimestamp = $null

$script:IsWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
$script:IsMacOS = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)
$script:IsLinux = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)

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
        $home = $env:HOME
        $candidates = @(
            '/usr/bin/unityhub',
            '/usr/local/bin/unityhub',
            '/opt/unityhub/unityhub',
            '/opt/UnityHub/unityhub',
            (Join-PathSegments -Segments @($home, 'UnityHub', 'UnityHub.AppImage')),
            (Join-PathSegments -Segments @($home, 'Applications', 'UnityHub.AppImage'))
        ) | Where-Object { $_ }

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

# Private helper functions
function ConvertTo-UnityProjectRecord {
    param(
        [string]$Alias,
        [hashtable]$Project
    )

    $lastOpenedString = if ($Project.LastOpened) { $Project.LastOpened } else { 'Never' }
    $lastOpenedDate = $null

    if ($lastOpenedString -and $lastOpenedString -ne 'Never') {
        [DateTime]::TryParseExact(
            $lastOpenedString,
            'yyyy-MM-dd HH:mm:ss',
            $null,
            [System.Globalization.DateTimeStyles]::AssumeLocal,
            [ref]$lastOpenedDate
        ) | Out-Null
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

function Get-UnityConfigPath {
    <#
    .SYNOPSIS
    Gets the path to the Unity projects configuration file.

    .DESCRIPTION
    Returns the path to the JSON file where Unity project configurations are stored.
    Creates the directory if it doesn't exist.

    .PARAMETER ReturnDirectory
    Return the directory path instead of the file path.

    .EXAMPLE
    Get-UnityConfigPath
    Returns the full path to projects.json

    .EXAMPLE
    Get-UnityConfigPath -ReturnDirectory
    Returns the directory containing the config file

    .EXAMPLE
    code (Get-UnityConfigPath)
    Opens the config file in VS Code

    .EXAMPLE
    explorer (Get-UnityConfigPath -ReturnDirectory)
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

    $configDir = Join-Path $configRoot 'unity'
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    if ($ReturnDirectory) {
        return $configDir
    } else {
        return Join-Path $configDir 'projects.json'
    }
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

    $projectVersionFile = Join-Path $Path 'ProjectSettings\ProjectVersion.txt'
    return Test-Path $projectVersionFile
}

function Get-UnityProjectInfo {
    param([string]$Path)

    $projectVersionFile = Join-Path $Path 'ProjectSettings\ProjectVersion.txt'
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

function Test-FzfAvailable {
    try {
        $null = Get-Command fzf -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Add-UnityProject {
    <#
    .SYNOPSIS
    Adds the current Unity project to your saved projects list with an alias.

    .DESCRIPTION
    Adds the Unity project in the current directory (or specified path) to your saved projects
    configuration, allowing you to quickly open it later using the alias.

    .PARAMETER Alias
    The alias/keyword to associate with this Unity project for quick access.

    .PARAMETER ProjectPath
    The path to the Unity project. Defaults to current directory.

    .PARAMETER Force
    Overwrites an existing alias if it already exists.

    .EXAMPLE
    Add-UnityProject -Alias "myGame"
    Adds the current directory as a Unity project with alias "myGame"

    .EXAMPLE
    Add-UnityProject -Alias "rpg" -ProjectPath "C:\Projects\MyRPG"
    Adds the specified project with alias "rpg"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Alias,

        [string]$ProjectPath = (Get-Location).Path,

        [switch]$Force
    )

    # Validate it's a Unity project
    if (-not (Test-IsUnityProject -Path $ProjectPath)) {
        Write-Error 'The specified path is not a Unity project. ProjectVersion.txt not found in ProjectSettings folder.'
        return
    }

    # Get current projects data
    $projectsData = Get-UnityProjectsData

    # Check if alias already exists
    if ($projectsData.ContainsKey($Alias) -and -not $Force) {
        Write-Error "Alias '$Alias' already exists. Use -Force to overwrite, or choose a different alias."
        Write-Host "Existing project: $($projectsData[$Alias].Name) at $($projectsData[$Alias].Path)" -ForegroundColor Yellow
        return
    }

    # Get project info
    $projectInfo = Get-UnityProjectInfo -Path $ProjectPath

    # If updating existing project, preserve LastOpened if it exists
    if ($projectsData.ContainsKey($Alias) -and $projectsData[$Alias].LastOpened) {
        $projectInfo.LastOpened = $projectsData[$Alias].LastOpened
    }

    # Add/update the project
    $projectsData[$Alias] = $projectInfo

    # Save to file
    Save-UnityProjectsData -ProjectsData $projectsData

    Write-Host "Added Unity project '$($projectInfo.Name)' with alias '$Alias'" -ForegroundColor Green
    Write-Host "  Path: $($projectInfo.Path)" -ForegroundColor Gray
    Write-Host "  Unity Version: $($projectInfo.UnityVersion)" -ForegroundColor Gray
}

function Get-UnityProjects {
    <#
    .SYNOPSIS
    Lists all saved Unity projects or opens a selected one.

    .DESCRIPTION
    Displays all saved Unity projects with their aliases, or if -Interactive is specified,
    uses fzf for fuzzy finding and selection of Unity projects.

    .PARAMETER Interactive
    Uses fzf for interactive selection and opening of a Unity project.

    .PARAMETER Alias
    If specified, opens the project associated with this alias directly.

    .PARAMETER SortByRecent
    Sort projects by last opened date (most recent first).

    .PARAMETER Path
    Return the project path instead of opening the project. Can be used with -Alias or -Interactive.

    .EXAMPLE
    Get-UnityProjects
    Lists all saved Unity projects

    .EXAMPLE
    Get-UnityProjects -Interactive
    Uses fzf to select and open a project

    .EXAMPLE
    Get-UnityProjects -Alias 'myGame' -Path
    Returns the path of the project with alias "myGame"

    .EXAMPLE
    Get-UnityProjects -Interactive -Path
    Uses fzf to select a project and returns its path

    .EXAMPLE
    cd (Get-UnityProjects -Alias "myGame" -Path)
    Changes to the directory of the specified project
    #>
    [CmdletBinding()]
    param(
        [switch]$Interactive,
        [string]$Alias,
        [switch]$SortByRecent,
        [switch]$Path
    )

    $projectsData = Get-UnityProjectsData

    if ($projectsData.Count -eq 0) {
        if ($Alias) {
            Write-Error "No project found with alias '$Alias'"
        } elseif ($Interactive) {
            Write-Host "No Unity projects saved yet. Use 'Add-UnityProject' to add projects." -ForegroundColor Yellow
        }
        return @()
    }

    if ($Alias) {
        if ($projectsData.ContainsKey($Alias)) {
            $project = $projectsData[$Alias]
            if ($Path) {
                return $project.Path
            } else {
                Write-Host "Opening Unity project '$Alias': $($project.Name)" -ForegroundColor Green
                Open-UnityProject -ProjectPath $project.Path -Alias $Alias
            }
        } else {
            Write-Error "No project found with alias '$Alias'"
            $availableAliases = $projectsData.Keys
            if ($availableAliases) {
                Write-Host "Available aliases: $($availableAliases -join ', ')" -ForegroundColor Yellow
            }
        }
        return
    }

    $records = @()
    foreach ($entry in $projectsData.GetEnumerator()) {
        $records += ConvertTo-UnityProjectRecord -Alias $entry.Key -Project $entry.Value
    }

    $sortedRecords = if ($SortByRecent) {
        $records | Sort-Object -Descending -Property @{
            Expression = {
                if ($_.LastOpened) { $_.LastOpened } else { [DateTime]::MinValue }
            }
        }, @{ Expression = { $_.Alias } }
    } else {
        $records | Sort-Object -Property Alias
    }

    if ($Interactive) {
        if (-not (Test-FzfAvailable)) {
            Write-Error 'fzf is not available. Please install fzf first.'
            Write-Host 'Install fzf: https://github.com/junegunn/fzf#installation' -ForegroundColor Yellow
            Write-Host "Or use 'scoop install fzf' / 'choco install fzf' / 'winget install junegunn.fzf'" -ForegroundColor Yellow
            return
        }

        $fzfItems = @()
        foreach ($record in $sortedRecords) {
            $lastOpenedText = if ($record.LastOpened) {
                $record.LastOpened.ToString('yyyy-MM-dd HH:mm:ss')
            } else {
                $record.LastOpenedString
            }

            $fzfItems += @(
                "$($record.Alias)",
                "$($record.Name)",
                "$($record.UnityVersion)",
                "$lastOpenedText",
                "$($record.Path)"
            ) -join ' | '
        }

        if ($fzfItems.Count -eq 0) {
            Write-Host 'No Unity projects found.' -ForegroundColor Yellow
            return
        }

        try {
            $headerText = if ($Path) { 'Select Unity Project (will return path)' } else { 'Select Unity Project' }
            if ($SortByRecent) {
                $headerText += ' - Sorted by Recent'
            }

            $selected = $fzfItems | fzf --height=40% --reverse --border --header="$headerText" --delimiter='|' --with-nth=1, 2, 3, 4 --preview='Write-Output {5}'

            if ($selected) {
                $segments = $selected -split '\s*\|\s*'
                $selectedAlias = $segments[0]
                $selectedRecord = $sortedRecords | Where-Object { $_.Alias -eq $selectedAlias } | Select-Object -First 1

                if (-not $selectedRecord) {
                    Write-Warning "Unable to resolve selection for alias '$selectedAlias'"
                    return
                }

                if ($Path) {
                    return $selectedRecord.Path
                } else {
                    Write-Host "Opening $($selectedRecord.Name)..." -ForegroundColor Green
                    Open-UnityProject -ProjectPath $selectedRecord.Path -Alias $selectedRecord.Alias
                }
            }
        } catch {
            Write-Error "Error running fzf: $($_.Exception.Message)"
        }

        return
    }

    return $sortedRecords
}

function Open-RecentUnityProject {
    <#
    .SYNOPSIS
    Opens the most recently opened Unity project.

    .DESCRIPTION
    Opens the Unity project that was most recently opened. If no projects have been opened yet,
    it will show an interactive list to choose from.

    .PARAMETER Interactive
    If no recent project exists, or if specified, show interactive fzf selection sorted by recent.

    .PARAMETER Path
    Return the path of the most recent project instead of opening it.

    .EXAMPLE
    Open-RecentUnityProject
    Opens the most recently opened Unity project

    .EXAMPLE
    Open-RecentUnityProject -Path
    Returns the path of the most recent project

    .EXAMPLE
    cd (Open-RecentUnityProject -Path)
    Changes to the most recent project directory
    #>
    [CmdletBinding()]
    param(
        [switch]$Interactive,
        [switch]$Path
    )

    $projectsData = Get-UnityProjectsData

    if ($projectsData.Count -eq 0) {
        Write-Host "No Unity projects saved yet. Use 'Add-UnityProject' to add projects." -ForegroundColor Yellow
        return
    }

    # Find the most recently opened project
    $mostRecent = $null
    $mostRecentDate = [DateTime]::MinValue

    foreach ($entry in $projectsData.GetEnumerator()) {
        $project = $entry.Value
        if ($project.LastOpened -ne 'Never') {
            try {
                $openedDate = [DateTime]::ParseExact($project.LastOpened, 'yyyy-MM-dd HH:mm:ss', $null)
                if ($openedDate -gt $mostRecentDate) {
                    $mostRecentDate = $openedDate
                    $mostRecent = @{
                        Alias = $entry.Key
                        Project = $project
                    }
                }
            } catch {
                Write-Warning "Could not parse date for project '$($entry.Key)': $($project.LastOpened)"
            }
        }
    }

    # If we found a recent project and not in interactive mode, open/return it
    if ($mostRecent -and -not $Interactive) {
        if ($Path) {
            return $mostRecent.Project.Path
        } else {
            Write-Host "Opening most recent project '$($mostRecent.Alias)': $($mostRecent.Project.Name)" -ForegroundColor Green
            Write-Host "Last opened: $($mostRecent.Project.LastOpened)" -ForegroundColor Gray
            Open-UnityProject -ProjectPath $mostRecent.Project.Path -Alias $mostRecent.Alias
        }
        return
    }

    # If no recent project found or interactive mode requested
    if (-not $mostRecent) {
        Write-Host 'No recently opened projects found. Showing all projects...' -ForegroundColor Yellow
    }

    # Show interactive selection sorted by recent
    if ($Path) {
        Get-UnityProjects -Interactive -SortByRecent -Path
    } else {
        Get-UnityProjects -Interactive -SortByRecent
    }
}

function Remove-UnityProject {
    <#
    .SYNOPSIS
    Removes a Unity project from the saved projects list.

    .DESCRIPTION
    Removes the specified alias and its associated Unity project from your saved projects.
    This only removes it from the list, not from your filesystem.

    .PARAMETER Alias
    The alias of the project to remove.

    .PARAMETER Interactive
    Use fzf to interactively select which project to remove.

    .PARAMETER Multiple
    Allow selecting and removing multiple projects at once (requires fzf with multi-select).

    .EXAMPLE
    Remove-UnityProject -Alias "myGame"
    Removes the project with alias "myGame" from the saved list

    .EXAMPLE
    Remove-UnityProject -Interactive
    Use fzf to select which project to remove

    .EXAMPLE
    Remove-UnityProject -Interactive -Multiple
    Use fzf with multi-select to remove multiple projects at once
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Alias,
        [switch]$Interactive,
        [switch]$Multiple
    )

    $projectsData = Get-UnityProjectsData

    if ($projectsData.Count -eq 0) {
        Write-Host 'No Unity projects saved.' -ForegroundColor Yellow
        return
    }

    if ($Interactive) {
        if (-not (Test-FzfAvailable)) {
            Write-Error 'fzf is not available. Please install fzf first.'
            return
        }

        # Prepare data for fzf
        $fzfItems = @()
        $projectsData.GetEnumerator() | Sort-Object Key | ForEach-Object {
            $alias = $_.Key
            $project = $_.Value
            $lastOpened = if ($project.LastOpened -eq 'Never') { 'Never' } else { $project.LastOpened }
            $fzfItems += @("$alias", "$($project.Name)", "$lastOpened", "$($project.Path)") -join ' | '
        }

        try {
            $headerText = if ($Multiple) { 'Select Unity Projects to Remove (Tab to multi-select, Enter to confirm)' } else { 'Select Unity Project to Remove' }
            $fzfArgs = @('--height=40%', '--reverse', '--border', "--header=$headerText", '--delimiter=|', '--with-nth=1,2,3')

            if ($Multiple) {
                $fzfArgs += '--multi'
            }

            $selected = $fzfItems | fzf @fzfArgs

            if ($selected) {
                if ($Multiple) {
                    # Handle multiple selections
                    $aliasesToRemove = @()
                    $selected | ForEach-Object {
                        $aliasesToRemove += ($_ -split ' \| ')[0].Trim()
                    }

                    if ($aliasesToRemove.Count -gt 0) {
                        Write-Host "`nProjects to remove:" -ForegroundColor Yellow
                        foreach ($aliasToRemove in $aliasesToRemove) {
                            $project = $projectsData[$aliasToRemove]
                            Write-Host "  - ${aliasToRemove}: $($project.Name)" -ForegroundColor White
                        }

                        $confirmation = Read-Host "`nAre you sure you want to remove these $($aliasesToRemove.Count) projects? (y/N)"
                        if ($confirmation -match '^[Yy]') {
                            $removedCount = 0
                            foreach ($aliasToRemove in $aliasesToRemove) {
                                if ($projectsData.ContainsKey($aliasToRemove)) {
                                    $projectsData.Remove($aliasToRemove)
                                    $removedCount++
                                    Write-Host "Removed '$aliasToRemove'" -ForegroundColor Green
                                }
                            }

                            if ($removedCount -gt 0) {
                                Save-UnityProjectsData -ProjectsData $projectsData
                                Write-Host "`nSuccessfully removed $removedCount projects from saved list" -ForegroundColor Green
                            }
                        } else {
                            Write-Host 'Removal cancelled.' -ForegroundColor Yellow
                        }
                    }
                } else {
                    # Handle single selection
                    $Alias = ($selected -split ' \| ')[0].Trim()
                }
            } else {
                return # User cancelled
            }
        } catch {
            Write-Error "Error running fzf: $($_.Exception.Message)"
            return
        }
    }

    # Handle single alias removal (either from parameter or interactive single selection)
    if ($Alias -and -not $Multiple) {
        if (-not $projectsData.ContainsKey($Alias)) {
            Write-Error "No project found with alias '$Alias'"
            if ($projectsData.Count -gt 0) {
                Write-Host "Available aliases: $($projectsData.Keys -join ', ')" -ForegroundColor Yellow
            }
            return
        }

        $project = $projectsData[$Alias]

        if ($PSCmdlet.ShouldProcess("Unity project '$Alias' ($($project.Name))", 'Remove from saved projects')) {
            $projectsData.Remove($Alias)
            Save-UnityProjectsData -ProjectsData $projectsData

            Write-Host "Removed Unity project '$Alias' from saved projects" -ForegroundColor Green
            Write-Host "  Project files remain at: $($project.Path)" -ForegroundColor Gray
        }
    } elseif (-not $Interactive -and -not $Alias) {
        Write-Error 'No alias specified. Use -Alias parameter or -Interactive flag.'
    }
}

function Open-UnityProject {
    <#
    .SYNOPSIS
    Opens a Unity project.

    .DESCRIPTION
    Opens a Unity project either by path, alias, or from pipeline input.

    .PARAMETER ProjectPath
    The path to the Unity project.

    .PARAMETER Alias
    The alias of a saved Unity project.

    .PARAMETER UnityHubPath
    Path to Unity Hub executable.

    .PARAMETER InputObject
    Alias name from pipeline input.

    .EXAMPLE
    Open-UnityProject -Alias "myGame"

    .EXAMPLE
    "myGame" | Open-UnityProject

    .EXAMPLE
    Get-UnityProjects -Alias "myGame" -Path | Set-Location
    #>
    [CmdletBinding()]
    param(
        [string]$ProjectPath,
        [string]$Alias,
        [string]$UnityHubPath = (Get-UnityHubDefaultPath),
        [Parameter(ValueFromPipeline = $true)]
        [string]$InputObject
    )

    process {
        # Handle pipeline input
        if ($InputObject) {
            $Alias = $InputObject.Trim()
        }

        # If alias is provided, get the project path from saved projects
        if ($Alias) {
            $projectsData = Get-UnityProjectsData
            if ($projectsData.ContainsKey($Alias)) {
                $ProjectPath = $projectsData[$Alias].Path
                Write-Host "Opening saved project '$Alias': $($projectsData[$Alias].Name)" -ForegroundColor Green
            } else {
                Write-Error "No project found with alias '$Alias'"
                if ($projectsData.Count -gt 0) {
                    Write-Host "Available aliases: $($projectsData.Keys -join ', ')" -ForegroundColor Yellow
                }
                return
            }
        }

        # Default to current directory if no path or alias provided
        if (-not $ProjectPath) {
            $ProjectPath = (Get-Location).Path
        }

        # Check if the directory exists
        if (-not (Test-Path $ProjectPath)) {
            Write-Error "Directory not found: $ProjectPath"
            return
        }

        # Check if it's a Unity project
        $projectSettingsPath = Join-Path $ProjectPath 'ProjectSettings'
        $projectVersionFile = Join-Path $projectSettingsPath 'ProjectVersion.txt'

        if (-not (Test-Path $projectVersionFile)) {
            Write-Error "This doesn't appear to be a Unity project. ProjectVersion.txt not found."
            return
        }

        # Read Unity version from ProjectVersion.txt
        try {
            $versionContent = Get-Content $projectVersionFile | Where-Object { $_.StartsWith('m_EditorVersion:') }
            if (-not $versionContent) {
                throw 'Could not find m_EditorVersion in ProjectVersion.txt'
            }

            $unityVersion = ($versionContent -split ':')[1].Trim()
            Write-Host "Project Unity version: $unityVersion"
        } catch {
            Write-Error "Failed to read Unity version: $($_.Exception.Message)"
            return
        }

        # Try to find Unity installation
        $unityEditorPath = $null
        $unityMatch = Find-UnityEditorExecutable -UnityVersion $unityVersion
        if ($unityMatch) {
            $unityEditorPath = $unityMatch.Path
            switch ($unityMatch.MatchType) {
                'Exact' {
                    Write-Host "Found exact Unity version at: $unityEditorPath"
                }
                'Similar' {
                    Write-Host "Found similar Unity version ($($unityMatch.Version)) at: $unityEditorPath"
                }
                'Command' {
                    Write-Host "Using Unity executable from PATH: $unityEditorPath"
                }
            }
        }

        # If no Unity found, try to get it through Unity Hub
        if (-not $unityEditorPath) {
            Write-Warning "Unity version $unityVersion not found locally."

            Write-Host 'Opening Unity Hub to install/select Unity version...'
            $choice = Read-Host 'Do you want to open Unity Hub to install the required version? (Y/n)'
            if ($choice -notmatch '^[Nn]') {
                if (Start-UnityHubForProject -UnityHubPath $UnityHubPath -ProjectPath $ProjectPath) {
                    Update-LastOpened -ProjectPath $ProjectPath -Alias $Alias
                    return
                }

                Write-Error "Unity Hub could not be launched using '$UnityHubPath'. Ensure Unity Hub is installed and available on PATH."
                return
            }

            return
        }

        # Launch Unity directly with the project
        try {
            Write-Host "Opening Unity project at: $ProjectPath"
            Write-Host "Using Unity: $unityEditorPath"

            # Unity command line arguments:
            # -projectPath: specify project path
            $projectArgument = if ($script:IsWindows) { "`"$ProjectPath`"" } else { $ProjectPath }
            $arguments = @('-projectPath', $projectArgument)

            Start-Process -FilePath $unityEditorPath -ArgumentList $arguments -NoNewWindow:$false
            Write-Host 'Unity launched successfully!'

            # Update the last opened time
            Update-LastOpened -ProjectPath $ProjectPath -Alias $Alias
        } catch {
            Write-Error "Failed to launch Unity: $($_.Exception.Message)"
        }
    }
}

# Set up aliases
Set-Alias -Name 'unity' -Value 'Open-UnityProject'
Set-Alias -Name 'unity-add' -Value 'Add-UnityProject'
Set-Alias -Name 'unity-list' -Value 'Get-UnityProjects'
Set-Alias -Name 'unity-remove' -Value 'Remove-UnityProject'
Set-Alias -Name 'unity-recent' -Value 'Open-RecentUnityProject'
Set-Alias -Name 'unity-config' -Value 'Get-UnityConfigPath'


# Enhanced argument completer with project info
Register-ArgumentCompleter -CommandName 'Get-UnityProjects', 'Remove-UnityProject', 'Open-UnityProject', 'unity', 'unity-list', 'unity-remove' -ParameterName 'Alias' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    try {
        $projectsData = Get-UnityProjectsData
        $projectsData.GetEnumerator() | Where-Object { $_.Key -like "$wordToComplete*" } |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    "'$($_.Key)'",           # CompletionText (what gets inserted)
                    $_.Key,                  # ListItemText (what shows in list)
                    'ParameterValue',        # CompletionResultType
                    "$($_.Value.Name) - $($_.Value.UnityVersion)"  # ToolTip
                )
            }
    } catch {
        @()
    }
}

# Register completer for the aliases as well
Register-ArgumentCompleter -CommandName 'unity', 'unity-list', 'unity-remove' -ParameterName 'Alias' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    try {
        $projectsData = Get-UnityProjectsData
        $projectsData.Keys | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { "'$_'" }
    } catch {
        @()
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Open-UnityProject',
    'Add-UnityProject',
    'Get-UnityProjects',
    'Remove-UnityProject',
    'Open-RecentUnityProject',
    'Get-UnityConfigPath'
) -Alias @('unity', 'unity-add', 'unity-list', 'unity-remove', 'unity-recent', 'unity-config')
