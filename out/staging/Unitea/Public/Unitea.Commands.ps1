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

    return Get-PSMagicConfigPath -Component 'unity' -FileName 'projects.json' -ReturnDirectory:$ReturnDirectory
}

function Get-UnityProjectSyncStatus {
    <#
    .SYNOPSIS
    Evaluates saved Unity project metadata and reports drift.

    .DESCRIPTION
    Reads ProjectVersion.txt for each saved Unity project (or the aliases you specify) and compares
    the detected editor version with the stored metadata. It also validates that the saved path still
    exists and looks like a Unity project. Status values include:
      * InSync - metadata matches the on-disk project
      * VersionMismatch - the saved version differs from ProjectVersion.txt
      * VersionMismatchResolved - issue resolved automatically during startup
      * PathMissing - the saved path no longer exists
      * NotUnityProject - the directory no longer contains a Unity project
      * UnknownProjectVersion / UnknownStoredVersion - version information is unavailable

    .PARAMETER Alias
    One or more aliases to check. Defaults to all saved projects.

    .PARAMETER IncludeInSync
    Include in-sync projects in the output so scripts can log a full audit.

    .EXAMPLE
    Get-UnityProjectSyncStatus
    Lists projects whose metadata is out of sync with ProjectVersion.txt.

    .EXAMPLE
    Get-UnityProjectSyncStatus -Alias game-dev -IncludeInSync
    Shows the sync state for a single project and includes any in-sync results.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Alias,
        [switch]$IncludeInSync
    )

    $projectsData = Get-UnityProjectsData

    if (-not $projectsData -or $projectsData.Count -eq 0) {
        return @()
    }

    $comparisonType = if ($script:IsWindows) {
        [System.StringComparison]::OrdinalIgnoreCase
    } else {
        [System.StringComparison]::Ordinal
    }

    $aliasesToEvaluate = if ($Alias) {
        $Alias
    } else {
        $projectsData.Keys
    }

    $results = New-Object System.Collections.Generic.List[object]

    foreach ($candidateAlias in $aliasesToEvaluate) {
        if (-not $projectsData.ContainsKey($candidateAlias)) {
            continue
        }

        $projectRecord = $projectsData[$candidateAlias]
        $projectPath = $projectRecord.Path
        $storedVersion = $projectRecord.UnityVersion
        $projectName = $projectRecord.Name
        $status = 'InSync'
        $actualVersion = $null
        $message = $null

        if (-not $projectPath -or -not (Test-Path -LiteralPath $projectPath)) {
            $status = 'PathMissing'
            $message = "Project path '$projectPath' cannot be found."
        } elseif (-not (Test-IsUnityProject -Path $projectPath)) {
            $status = 'NotUnityProject'
            $message = "Directory '$projectPath' no longer appears to be a Unity project."
        } else {
            $projectInfo = Get-UnityProjectInfo -Path $projectPath
            $actualVersion = $projectInfo.UnityVersion

            if (-not $actualVersion -or $actualVersion -eq 'Unknown') {
                $status = 'UnknownProjectVersion'
                $message = "Project version for '$candidateAlias' could not be determined."
            } else {
                if (-not $storedVersion -or $storedVersion -eq 'Unknown') {
                    $status = 'UnknownStoredVersion'
                    $message = "Stored metadata for '$candidateAlias' is missing a Unity version."
                } elseif (-not [string]::Equals($storedVersion, $actualVersion, $comparisonType)) {
                    $status = 'VersionMismatch'
                    $message = "Stored version $storedVersion differs from project version $actualVersion."
                }
            }
        }

        if ($status -ne 'InSync' -or $IncludeInSync) {
            $results.Add([PSCustomObject]@{
                    Alias = $candidateAlias
                    Name = $projectName
                    Path = $projectPath
                    StoredVersion = $storedVersion
                    ActualVersion = $actualVersion
                    Status = $status
                    Message = $message
                })
        }
    }

    return $results
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
    [OutputType([void])]
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
        Write-Verbose "Existing project: $($projectsData[$Alias].Name) at $($projectsData[$Alias].Path)"
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

    Write-Verbose "Added Unity project '$($projectInfo.Name)' with alias '$Alias'"
    Write-Verbose "  Path: $($projectInfo.Path)"
    Write-Verbose "  Unity Version: $($projectInfo.UnityVersion)"
}

function Update-UnityProject {
    <#
    .SYNOPSIS
    Refreshes stored Unity project metadata after the project version changes.

    .DESCRIPTION
    Re-reads ProjectVersion.txt for saved Unity projects and updates the stored Unity version,
    project name, and resolved path so launches continue to work after upgrading Unity.

    .PARAMETER Alias
    Updates a specific saved project by alias.

    .PARAMETER ProjectPath
    Updates the saved project that matches the provided project path.

    .PARAMETER All
    Updates every saved Unity project.

    .PARAMETER PassThru
    Returns the update results for use in scripts.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Alias')]
    param(
        [Parameter(ParameterSetName = 'Alias', Mandatory = $true, Position = 0)]
        [string]$Alias,

        [Parameter(ParameterSetName = 'Path', Mandatory = $true)]
        [string]$ProjectPath,

        [Parameter(ParameterSetName = 'All', Mandatory = $true)]
        [switch]$All,

        [switch]$PassThru
    )

    $projectsData = Get-UnityProjectsData
    if (-not $projectsData -or $projectsData.Count -eq 0) {
        Write-Error 'No saved Unity projects found. Use Add-UnityProject to add projects first.'
        return
    }

    $comparisonType = if ($script:IsWindows) {
        [System.StringComparison]::OrdinalIgnoreCase
    } else {
        [System.StringComparison]::Ordinal
    }

    $targets = @()

    switch ($PSCmdlet.ParameterSetName) {
        'All' {
            $targets = $projectsData.GetEnumerator() | ForEach-Object {
                [PSCustomObject]@{
                    Alias = $_.Key
                    Record = $_.Value
                    Path = $_.Value.Path
                }
            }
        }
        'Path' {
            try {
                $resolvedPath = (Resolve-Path -Path $ProjectPath -ErrorAction Stop).Path
            } catch {
                Write-Error "Project path not found: $ProjectPath"
                return
            }

            $matchedEntry = $projectsData.GetEnumerator() | Where-Object {
                $candidatePath = $_.Value.Path
                if (-not $candidatePath) {
                    return $false
                }

                try {
                    $candidateResolved = (Resolve-Path -Path $candidatePath -ErrorAction Stop).Path
                } catch {
                    $candidateResolved = $candidatePath
                }

                return [string]::Equals($candidateResolved, $resolvedPath, $comparisonType)
            } | Select-Object -First 1

            if (-not $matchedEntry) {
                Write-Error "No saved Unity project matches path '$resolvedPath'"
                return
            }

            $targets += [PSCustomObject]@{
                Alias = $matchedEntry.Key
                Record = $matchedEntry.Value
                Path = $resolvedPath
            }
        }
        default {
            if (-not $projectsData.ContainsKey($Alias)) {
                Write-Error "No project found with alias '$Alias'"
                return
            }

            $targets += [PSCustomObject]@{
                Alias = $Alias
                Record = $projectsData[$Alias]
                Path = $projectsData[$Alias].Path
            }
        }
    }

    if ($targets.Count -eq 0) {
        Write-Verbose 'No matching Unity projects found to update.'
        return
    }

    $updates = @()
    $saveRequired = $false

    foreach ($target in $targets) {
        $aliasName = $target.Alias
        $record = $target.Record
        $projectPathToUse = $target.Path

        if (-not $projectPathToUse) {
            Write-Warning "Skipping '$aliasName' because no project path is stored."
            continue
        }

        if (-not (Test-Path -LiteralPath $projectPathToUse)) {
            Write-Warning "Skipping '$aliasName' because path '$projectPathToUse' does not exist."
            continue
        }

        if (-not (Test-IsUnityProject -Path $projectPathToUse)) {
            Write-Warning "Skipping '$aliasName' because '$projectPathToUse' is not a Unity project."
            continue
        }

        $projectInfo = Get-UnityProjectInfo -Path $projectPathToUse
        $changes = @()

        if ($projectInfo.UnityVersion -and $record.UnityVersion -ne $projectInfo.UnityVersion) {
            $changes += "version $($record.UnityVersion) -> $($projectInfo.UnityVersion)"
        }

        if ($projectInfo.Name -and $record.Name -ne $projectInfo.Name) {
            $changes += "name '$($record.Name)' -> '$($projectInfo.Name)'"
        }

        if ($projectInfo.Path -and -not [string]::Equals($record.Path, $projectInfo.Path, $comparisonType)) {
            $changes += 'path updated'
        }

        if ($changes.Count -eq 0) {
            Write-Verbose "Unity project '$aliasName' is already up to date."
            if ($PassThru) {
                $updates += [PSCustomObject]@{
                    Alias = $aliasName
                    UnityVersion = $record.UnityVersion
                    Path = $record.Path
                    Updated = $false
                    Changes = @()
                }
            }
            continue
        }

        if (-not $projectInfo.UnityVersion -or $projectInfo.UnityVersion -eq 'Unknown') {
            Write-Warning "Skipping '$aliasName' because the Unity version could not be determined."
            continue
        }

        $actionDescription = "Update Unity project '$aliasName' ($($changes -join ', '))"
        if (-not $PSCmdlet.ShouldProcess($projectPathToUse, $actionDescription)) {
            continue
        }

        $record.UnityVersion = $projectInfo.UnityVersion
        $record.Name = $projectInfo.Name
        $record.Path = $projectInfo.Path

        if (-not $record.ContainsKey('DateAdded') -or -not $record.DateAdded) {
            $record.DateAdded = $projectInfo.DateAdded
        }

        if (-not $record.ContainsKey('LastOpened')) {
            $record.LastOpened = $projectInfo.LastOpened
        }

        $updates += [PSCustomObject]@{
            Alias = $aliasName
            UnityVersion = $record.UnityVersion
            Path = $record.Path
            Updated = $true
            Changes = $changes
        }

        $saveRequired = $true
    }

    if ($saveRequired) {
        Save-UnityProjectsData -ProjectsData $projectsData
        foreach ($update in $updates | Where-Object { $_.Updated }) {
            Write-Host "Updated Unity project '$($update.Alias)' to version $($update.UnityVersion)" -ForegroundColor Green
        }
    } else {
        Write-Verbose 'No Unity project metadata needed updating.'
    }

    if ($PassThru -and $updates.Count -gt 0) {
        return $updates
    }
}

function Get-UnityProjects {
    <#
    .SYNOPSIS
    Lists all saved Unity projects or opens a selected one.

    .DESCRIPTION
    Displays all saved Unity projects with their aliases. When -Interactive is specified,
    fzf provides fuzzy finding if available, with a numbered menu fallback when it is not.

    .PARAMETER Interactive
    Uses fzf for interactive selection and opening of a Unity project (falls back to a numbered menu when fzf is missing).

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
        if (Test-FzfAvailable) {
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
        } else {
            Write-Warning 'fzf is not available. Falling back to numbered selection menu.'
            Write-Host 'Install fzf: https://github.com/junegunn/fzf#installation' -ForegroundColor Yellow
            Write-Host "Or use 'scoop install fzf' / 'choco install fzf' / 'winget install junegunn.fzf'" -ForegroundColor Yellow

            $headerText = if ($Path) { 'Select Unity Project (will return path)' } else { 'Select Unity Project' }
            if ($SortByRecent) {
                $headerText += ' - Sorted by Recent'
            }

            $selectedRecord = Invoke-UniteaFallbackSelection -Records @($sortedRecords) -Header $headerText
            if ($selectedRecord) {
                if ($Path) {
                    return $selectedRecord.Path
                } else {
                    Write-Host "Opening $($selectedRecord.Name)..." -ForegroundColor Green
                    Open-UnityProject -ProjectPath $selectedRecord.Path -Alias $selectedRecord.Alias
                }
            }
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
    If no recent project exists, or if specified, show interactive selection sorted by recent (fzf when available, numbered menu otherwise).

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
    Use fzf to interactively select which project to remove (falls back to a numbered menu if fzf is unavailable).

    .PARAMETER Multiple
    Allow selecting and removing multiple projects at once. Supports fzf multi-select or comma/space separated input when using the fallback menu.

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

    $selectedAliases = @()

    if ($Interactive) {
        if (Test-FzfAvailable) {
            $fzfItems = @()
            $projectsData.GetEnumerator() | Sort-Object Key | ForEach-Object {
                $aliasKey = $_.Key
                $project = $_.Value
                $lastOpened = if ($project.LastOpened -eq 'Never') { 'Never' } else { $project.LastOpened }
                $fzfItems += @("$aliasKey", "$($project.Name)", "$lastOpened", "$($project.Path)") -join ' | '
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
                        $selectedAliases = @($selected | ForEach-Object {
                                ($_ -split ' \| ')[0].Trim()
                            }) | Where-Object { $_ } | Sort-Object -Unique

                        if ($selectedAliases.Count -eq 0) {
                            Write-Host 'No Unity projects selected for removal.' -ForegroundColor Yellow
                            return
                        }
                    } else {
                        $Alias = ($selected -split ' \| ')[0].Trim()
                        if (-not $Alias) {
                            Write-Host 'No Unity projects selected for removal.' -ForegroundColor Yellow
                            return
                        }
                    }
                } else {
                    return
                }
            } catch {
                Write-Error "Error running fzf: $($_.Exception.Message)"
                return
            }
        } else {
            Write-Warning 'fzf is not available. Falling back to numbered selection menu.'
            Write-Host 'Install fzf: https://github.com/junegunn/fzf#installation' -ForegroundColor Yellow
            Write-Host "Or use 'scoop install fzf' / 'choco install fzf' / 'winget install junegunn.fzf'" -ForegroundColor Yellow

            $fallbackRecords = @()
            $projectsData.GetEnumerator() | Sort-Object Key | ForEach-Object {
                $fallbackRecords += ConvertTo-UnityProjectRecord -Alias $_.Key -Project $_.Value
            }

            $headerText = if ($Multiple) { 'Select Unity projects to remove' } else { 'Select Unity project to remove' }
            $selection = Invoke-UniteaFallbackSelection -Records @($fallbackRecords) -Header $headerText -AllowMulti:$Multiple

            if ($Multiple) {
                if (-not $selection -or $selection.Count -eq 0) {
                    Write-Host 'No Unity projects selected for removal.' -ForegroundColor Yellow
                    return
                }

                $selectedAliases = $selection | ForEach-Object { $_.Alias } | Where-Object { $_ } | Sort-Object -Unique
            } else {
                if (-not $selection) {
                    return
                }

                $Alias = $selection.Alias
            }
        }
    }

    if ($Multiple) {
        if ($selectedAliases.Count -eq 0) {
            if ($Alias) {
                $selectedAliases = @($Alias)
            } else {
                Write-Host 'No Unity projects selected for removal.' -ForegroundColor Yellow
                return
            }
        }

        Write-Host "`nProjects to remove:" -ForegroundColor Yellow
        foreach ($aliasToRemove in $selectedAliases) {
            if ($projectsData.ContainsKey($aliasToRemove)) {
                $project = $projectsData[$aliasToRemove]
                Write-Host "  - ${aliasToRemove}: $($project.Name)" -ForegroundColor White
            } else {
                Write-Warning "Project '$aliasToRemove' is no longer in the saved list."
            }
        }

        $confirmation = Read-Host "`nAre you sure you want to remove these $($selectedAliases.Count) projects? (y/N)"
        if ($confirmation -match '^[Yy]') {
            $removedCount = 0
            foreach ($aliasToRemove in $selectedAliases) {
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

        return
    }

    if ($Alias) {
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
    } elseif (-not $Interactive) {
        Write-Error 'No alias specified. Use -Alias parameter or -Interactive flag.'
    }
}

function Open-UnityProject {
    <#
    .SYNOPSIS
    Opens a Unity project.

    .DESCRIPTION
    Opens a Unity project either by path, alias, or from pipeline input. The command inspects
    ProjectVersion.txt and compares it with the stored metadata so you are warned when a project has
    moved to a different Unity release. Supply -AutoUpdate to refresh the saved version immediately.
    In automation (POWERSHELL_MAGIC_NON_INTERACTIVE=1) Unity Hub prompts and editor launches are
    skipped so CI scripts remain non-blocking.

    .PARAMETER ProjectPath
    The path to the Unity project.

    .PARAMETER Alias
    The alias of a saved Unity project.

    .PARAMETER UnityHubPath
    Path to Unity Hub executable.

    .PARAMETER AutoUpdate
    Automatically refresh saved Unity metadata when the project version changes. Uses the saved alias
    when supplied, or the resolved project path, and mirrors the behaviour enabled by setting
    POWERSHELL_MAGIC_UNITEA_AUTOUPDATE_STARTUP=1 for startup checks.

    .PARAMETER InputObject
    Alias name from pipeline input.

    .EXAMPLE
    Open-UnityProject -Alias "myGame"

    .EXAMPLE
    "myGame" | Open-UnityProject

    .EXAMPLE
    Get-UnityProjects -Alias "myGame" -Path | Set-Location
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$ProjectPath,
        [string]$Alias,
        [string]$UnityHubPath = (Get-UnityHubDefaultPath),
        [switch]$AutoUpdate,
        [Parameter(ValueFromPipeline = $true)]
        [string]$InputObject
    )

    process {
        # Handle pipeline input
        if ($InputObject) {
            $Alias = $InputObject.Trim()
        }

        $isNonInteractive = Test-PSMagicNonInteractive
        $projectsData = $null
        $storedRecord = $null
        $storedAlias = $null

        # If alias is provided, get the project path from saved projects
        if ($Alias) {
            $projectsData = Get-UnityProjectsData
            if ($projectsData.ContainsKey($Alias)) {
                $storedRecord = $projectsData[$Alias]
                $storedAlias = $Alias
                $ProjectPath = $storedRecord.Path
                Write-Host "Opening saved project '$Alias': $($storedRecord.Name)" -ForegroundColor Green
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

        $resolvedProjectPath = $ProjectPath
        try {
            $resolvedProjectPath = (Resolve-Path -Path $ProjectPath -ErrorAction Stop).Path
        } catch {
            # Fall back to provided path
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

        # Locate stored record by path if alias not supplied
        if (-not $storedRecord) {
            if (-not $projectsData) {
                $projectsData = Get-UnityProjectsData
            }

            $comparisonType = if ($script:IsWindows) {
                [System.StringComparison]::OrdinalIgnoreCase
            } else {
                [System.StringComparison]::Ordinal
            }

            $matchedEntry = $projectsData.GetEnumerator() | Where-Object {
                $candidatePath = $_.Value.Path
                if (-not $candidatePath) {
                    return $false
                }

                $candidateResolved = $candidatePath
                try {
                    $candidateResolved = (Resolve-Path -Path $candidatePath -ErrorAction Stop).Path
                } catch {
                    # Use stored path if resolution fails
                }

                return [string]::Equals($candidateResolved, $resolvedProjectPath, $comparisonType)
            } | Select-Object -First 1

            if ($matchedEntry) {
                $storedRecord = $matchedEntry.Value
                if (-not $storedAlias) {
                    $storedAlias = $matchedEntry.Key
                }
            }
        }

        # Warn or auto-sync when metadata is stale
        $storedVersion = $null
        if ($storedRecord -and $storedRecord.UnityVersion -and $storedRecord.UnityVersion -ne 'Unknown') {
            $storedVersion = $storedRecord.UnityVersion
        }

        if ($storedVersion -and $storedVersion -ne $unityVersion) {
            $context = if ($storedAlias) {
                "for saved alias '$storedAlias'"
            } else {
                "for project '$($storedRecord.Name)'"
            }

            $baseMessage = "Saved Unity version $storedVersion $context differs from detected project version $unityVersion."

            if ($AutoUpdate) {
                try {
                    $updateResult = $null
                    if ($storedAlias) {
                        $updateResult = Update-UnityProject -Alias $storedAlias -PassThru -Confirm:$false -ErrorAction Stop
                        if ($updateResult -is [System.Array]) {
                            $updateResult = $updateResult | Where-Object { $_.Alias -eq $storedAlias } | Select-Object -First 1
                        }
                    } else {
                        $updateResult = Update-UnityProject -ProjectPath $resolvedProjectPath -PassThru -Confirm:$false -ErrorAction Stop
                        if ($updateResult -is [System.Array]) {
                            $updateResult = $updateResult | Select-Object -First 1
                        }
                    }

                    if ($updateResult -and $updateResult.Updated) {
                        Write-Host "Synchronized stored Unity version to $unityVersion." -ForegroundColor Green
                        if ($storedAlias) {
                            $projectsData = Get-UnityProjectsData
                            if ($projectsData.ContainsKey($storedAlias)) {
                                $storedRecord = $projectsData[$storedAlias]
                            }
                        } elseif ($storedRecord.ContainsKey('UnityVersion')) {
                            $storedRecord.UnityVersion = $unityVersion
                        }
                    } else {
                        Write-Warning "$baseMessage Auto-update did not apply any changes."
                    }
                } catch {
                    Write-Warning "$baseMessage Auto-update failed: $($_.Exception.Message)"
                }
            } else {
                Write-Warning $baseMessage
                if ($storedAlias) {
                    Write-Host "Run 'unity-update $storedAlias' to sync metadata with the project." -ForegroundColor Yellow
                } else {
                    Write-Host "Run 'Update-UnityProject -ProjectPath ""$resolvedProjectPath""' to sync metadata with the project." -ForegroundColor Yellow
                }
            }
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

            if ($isNonInteractive) {
                Write-Verbose 'Skipping Unity Hub prompt due to non-interactive mode.'
                return
            }

            Write-Host 'Opening Unity Hub to install/select Unity version...'
            $choice = Read-Host 'Do you want to open Unity Hub to install the required version? (Y/n)'
            if ($choice -notmatch '^[Nn]') {
                if (Start-UnityHubForProject -UnityHubPath $UnityHubPath -ProjectPath $ProjectPath) {
                    Update-LastOpened -ProjectPath $ProjectPath -Alias $storedAlias
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

            if ($isNonInteractive) {
                Write-Verbose 'Skipping Unity launch in non-interactive mode.'
            } elseif ($PSCmdlet.ShouldProcess("Unity project at $ProjectPath", 'Launch Unity Editor')) {
                Start-Process -FilePath $unityEditorPath -ArgumentList $arguments -NoNewWindow:$false
                Write-Host 'Unity launched successfully!'

                # Update the last opened time
                Update-LastOpened -ProjectPath $ProjectPath -Alias $storedAlias
            } else {
                Write-Verbose 'Launch skipped by ShouldProcess.'
            }
        } catch {
            Write-Error "Failed to launch Unity: $($_.Exception.Message)"
        }
    }
}

function Invoke-UniteaStartupSyncCheck {
    <#
    .SYNOPSIS
    Performs a once-per-session metadata sync check for saved Unity projects.

    .DESCRIPTION
    Runs the same detection logic as Get-UnityProjectSyncStatus when the module loads. The first call
    per session emits warnings for any out-of-sync projects and, when the environment variable
    POWERSHELL_MAGIC_UNITEA_AUTOUPDATE_STARTUP is set to 1/true/on, automatically invokes
    Update-UnityProject to refresh metadata. Set POWERSHELL_MAGIC_UNITEA_DISABLE_STARTUP_CHECK to
    suppress the scan entirely.

    .PARAMETER Force
    Forces the check to run even if it has already completed this session.

    .PARAMETER PassThru
    Returns the detected issues for further processing.

    .EXAMPLE
    Invoke-UniteaStartupSyncCheck -Force
    Re-runs the startup check immediately and emits warnings for any detected drift.

    .EXAMPLE
    Invoke-UniteaStartupSyncCheck -Force -PassThru
    Returns the issue objects so scripts can inspect or report them.
    #>
    [CmdletBinding()]
    param(
        [switch]$Force,
        [switch]$PassThru
    )

    if (-not $Force -and $script:StartupSyncCheckCompleted) {
        return
    }

    $script:StartupSyncCheckCompleted = $true

    if (Test-EnvironmentToggle -Value $env:POWERSHELL_MAGIC_UNITEA_DISABLE_STARTUP_CHECK) {
        return
    }

    $issues = Get-UnityProjectSyncStatus
    $issues = @($issues | Where-Object { $_.Status -ne 'InSync' })

    if ($issues.Count -eq 0) {
        if ($PassThru) {
            return @()
        }
        return
    }

    $autoUpdateEnabled = Test-EnvironmentToggle -Value $env:POWERSHELL_MAGIC_UNITEA_AUTOUPDATE_STARTUP
    $results = @()

    foreach ($issue in $issues) {
        $result = [PSCustomObject]@{
            Alias = $issue.Alias
            Status = $issue.Status
            Path = $issue.Path
            StoredVersion = $issue.StoredVersion
            ActualVersion = $issue.ActualVersion
            Resolved = $false
            Message = $issue.Message
        }

        switch ($issue.Status) {
            'VersionMismatch' {
                $context = "Saved Unity version $($issue.StoredVersion) for '$($issue.Alias)' differs from project version $($issue.ActualVersion)."
                if ($autoUpdateEnabled) {
                    try {
                        $updateResult = Update-UnityProject -Alias $issue.Alias -PassThru -Confirm:$false -ErrorAction Stop
                        if ($updateResult -is [System.Array]) {
                            $updateResult = $updateResult | Where-Object { $_.Alias -eq $issue.Alias } | Select-Object -First 1
                        }
                        if ($updateResult -and $updateResult.Updated) {
                            $result.Resolved = $true
                            $result.Status = 'VersionMismatchResolved'
                            $result.StoredVersion = $issue.ActualVersion
                            $result.Message = "Stored version synchronized to $($issue.ActualVersion)."
                        } else {
                            $result.Message = "$context Auto-update did not apply any changes."
                            Write-Warning $result.Message
                        }
                    } catch {
                        $result.Message = "$context Auto-update failed: $($_.Exception.Message)"
                        Write-Warning $result.Message
                    }
                } else {
                    $result.Message = $context
                    Write-Warning $context
                    Write-Host "Run 'unity-update $($issue.Alias)' to synchronize metadata." -ForegroundColor Yellow
                }
            }
            'PathMissing' {
                $message = "Unity project '$($issue.Alias)' references missing path '$($issue.Path)'."
                $result.Message = $message
                Write-Warning $message
            }
            'NotUnityProject' {
                $message = "Saved project '$($issue.Alias)' no longer contains Unity project assets at '$($issue.Path)'."
                $result.Message = $message
                Write-Warning $message
            }
            default {
                if ($issue.Message) {
                    Write-Warning $issue.Message
                }
            }
        }

        $results += $result
    }

    if ($PassThru) {
        return $results
    }
}
# Set up aliases
Set-Alias -Name 'unity' -Value 'Open-UnityProject'
Set-Alias -Name 'unity-add' -Value 'Add-UnityProject'
Set-Alias -Name 'unity-check' -Value 'Get-UnityProjectSyncStatus'
Set-Alias -Name 'unity-list' -Value 'Get-UnityProjects'
Set-Alias -Name 'unity-remove' -Value 'Remove-UnityProject'
Set-Alias -Name 'unity-recent' -Value 'Open-RecentUnityProject'
Set-Alias -Name 'unity-config' -Value 'Get-UnityConfigPath'

# Enhanced argument completer with project info
Register-ArgumentCompleter -CommandName 'Get-UnityProjects', 'Remove-UnityProject', 'Open-UnityProject', 'Update-UnityProject', 'Get-UnityProjectSyncStatus', 'unity', 'unity-list', 'unity-remove', 'unity-update', 'unity-check' -ParameterName 'Alias' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    try {
        $projectsData = Get-UnityProjectsData
        $projectsData.GetEnumerator() | Where-Object { $_.Key -like "$wordToComplete*" } |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    "'$($_.Key)'",
                    $_.Key,
                    'ParameterValue',
                    "$($_.Value.Name) - $($_.Value.UnityVersion)"
                )
            }
    } catch {
        @()
    }
}

Register-ArgumentCompleter -CommandName 'unity', 'unity-list', 'unity-remove', 'unity-update', 'unity-check' -ParameterName 'Alias' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    try {
        $projectsData = Get-UnityProjectsData
        $projectsData.Keys | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { "'$_'" }
    } catch {
        @()
    }
}
