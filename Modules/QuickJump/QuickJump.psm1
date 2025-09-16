# QuickJump.psm1
using namespace System.Collections.Generic

# Module variables
$script:ConfigPath = Join-Path (Split-Path $PROFILE -Parent) '.config\quickjump\paths.json'
$script:DefaultConfig = @{
    paths = @()
    version = '1.0'
}

#region Helper Functions
function Get-QuickJumpConfigPath {
    <#
    .SYNOPSIS
    Gets the path to the QuickJump configuration file.

    .DESCRIPTION
    Returns the path to the JSON file where QuickJump path configurations are stored.
    Creates the directory if it doesn't exist.

    .PARAMETER ReturnDirectory
    Return the directory path instead of the file path.

    .EXAMPLE
    Get-QuickJumpConfigPath
    Returns the full path to paths.json

    .EXAMPLE
    Get-QuickJumpConfigPath -ReturnDirectory
    Returns the directory containing the config file

    .EXAMPLE
    code (Get-QuickJumpConfigPath)
    Opens the config file in VS Code

    .EXAMPLE
    explorer (Get-QuickJumpConfigPath -ReturnDirectory)
    Opens the config directory in Windows Explorer
    #>
    [CmdletBinding()]
    param(
        [switch]$ReturnDirectory
    )

    $configDir = Join-Path (Split-Path $PROFILE -Parent) '.config\quickjump'
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    if ($ReturnDirectory) {
        return $configDir
    } else {
        return Join-Path $configDir 'paths.json'
    }
}

function Get-QuickJumpConfig {
    $configPath = Get-QuickJumpConfigPath
    if (Test-Path $configPath) {
        try {
            $content = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            return $content
        } catch {
            Write-Warning 'Invalid paths.json file. Creating backup and using default config.'
            Copy-Item $configPath "$configPath.backup"
            return $script:DefaultConfig
        }
    }
    return $script:DefaultConfig
}

function Save-QuickJumpConfig {
    param([hashtable]$Config)

    try {
        $configPath = Get-QuickJumpConfigPath
        $Config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    } catch {
        throw "Failed to save configuration: $_"
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

function Update-PathUsage {
    param(
        [string]$Path,
        [string]$Alias = $null
    )

    $config = Get-QuickJumpConfig
    $currentTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $updated = $false

    # Update by alias or path
    foreach ($entry in $config.paths) {
        if (($Alias -and $entry.alias -eq $Alias) -or $entry.path -eq $Path) {
            $entry.lastUsed = $currentTime
            $entry.useCount = [int]$entry.useCount + 1
            $updated = $true
            break
        }
    }

    if ($updated) {
        Save-QuickJumpConfig -Config $config
    }
}
#endregion

#region Core Functions
function Add-QuickJumpPath {
    <#
    .SYNOPSIS
    Adds a directory path to your QuickJump saved paths with optional alias and category.

    .DESCRIPTION
    Adds a directory path to your QuickJump configuration, allowing you to quickly navigate to it later.
    You can organize paths with categories and create memorable aliases for quick access.

    .PARAMETER Path
    The path to the directory. Defaults to current directory. Must exist and be a directory.

    .PARAMETER Alias
    A memorable alias/keyword to associate with this path for quick access.

    .PARAMETER Category
    An optional category to organize your paths (e.g., "projects", "work", "personal").

    .PARAMETER Force
    Overwrites an existing path or alias if it already exists.

    .EXAMPLE
    Add-QuickJumpPath -Alias "docs"
    Adds the current directory with alias "docs"

    .EXAMPLE
    Add-QuickJumpPath -Path "C:\Projects\MyApp" -Alias "myapp" -Category "projects"
    Adds the specified path with alias "myapp" in the "projects" category

    .EXAMPLE
    Add-QuickJumpPath -Category "work" -Force
    Adds current directory to "work" category, overwriting if it exists

    .EXAMPLE
    Get-Location | Add-QuickJumpPath -Alias "temp"
    Adds current location using pipeline input
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Path = (Get-Location).Path,

        [string]$Alias,

        [string]$Category,

        [switch]$Force
    )

    process {
        # Resolve and validate path
        try {
            $resolvedPath = Resolve-Path $Path -ErrorAction Stop
            if (-not (Test-Path $resolvedPath -PathType Container)) {
                Write-Error "Path '$Path' is not a directory."
                return
            }
        } catch {
            Write-Error "Path '$Path' does not exist or cannot be accessed."
            return
        }

        $config = Get-QuickJumpConfig
        $pathStr = $resolvedPath.Path

        # Check if path already exists
        $existingEntry = $config.paths | Where-Object { $_.path -eq $pathStr }
        if ($existingEntry -and -not $Force) {
            Write-Error "Path '$pathStr' already exists. Use -Force to update, or use a different path."
            Write-Host "Existing entry: Alias='$($existingEntry.alias)', Category='$($existingEntry.category)'" -ForegroundColor Yellow
            return
        }

        # Check if alias already exists for a different path
        if ($Alias) {
            $existingAlias = $config.paths | Where-Object { $_.alias -eq $Alias -and $_.path -ne $pathStr }
            if ($existingAlias -and -not $Force) {
                Write-Error "Alias '$Alias' already exists for a different path. Use -Force to overwrite, or choose a different alias."
                Write-Host "Existing path: $($existingAlias.path)" -ForegroundColor Yellow
                return
            }
        }

        $currentTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

        if ($existingEntry) {
            # Update existing entry
            $existingEntry.alias = $Alias
            $existingEntry.category = $Category
            Write-Host "Updated path entry: $pathStr" -ForegroundColor Green
        } else {
            # Add new entry
            $newEntry = @{
                path = $pathStr
                alias = $Alias
                category = $Category
                added = $currentTime
                lastUsed = $null
                useCount = 0
            }
            $config.paths = @($config.paths) + @($newEntry)
            Write-Host "Added path entry: $pathStr" -ForegroundColor Green
        }

        if ($Alias) { Write-Host "  Alias: $Alias" -ForegroundColor Gray }
        if ($Category) { Write-Host "  Category: $Category" -ForegroundColor Gray }

        Save-QuickJumpConfig -Config $config
    }
}

function Remove-QuickJumpPath {
    <#
    .SYNOPSIS
    Removes a path from your QuickJump saved paths.

    .DESCRIPTION
    Removes a path entry from your QuickJump configuration by path, alias, or through
    interactive selection. This only removes it from QuickJump, not from your filesystem.

    .PARAMETER Path
    The path to remove from saved paths.

    .PARAMETER Alias
    The alias of the path to remove.

    .PARAMETER Interactive
    Use fzf to interactively select which path(s) to remove.

    .PARAMETER Multiple
    Allow selecting and removing multiple paths at once (requires fzf with multi-select).

    .EXAMPLE
    Remove-QuickJumpPath -Alias "docs"
    Removes the path with alias "docs"

    .EXAMPLE
    Remove-QuickJumpPath -Path "C:\Temp"
    Removes the specified path from saved paths

    .EXAMPLE
    Remove-QuickJumpPath -Interactive
    Use fzf to select which path to remove

    .EXAMPLE
    Remove-QuickJumpPath -Interactive -Multiple
    Use fzf with multi-select to remove multiple paths at once
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Path,

        [string]$Alias,

        [switch]$Interactive,

        [switch]$Multiple
    )

    $config = Get-QuickJumpConfig

    if ($config.paths.Count -eq 0) {
        Write-Host 'No paths saved.' -ForegroundColor Yellow
        return
    }

    if ($Interactive) {
        if (-not (Test-FzfAvailable)) {
            Write-Error 'fzf is not available. Please install fzf first.'
            Write-Host 'Install fzf: https://github.com/junegunn/fzf#installation' -ForegroundColor Yellow
            return
        }

        # Prepare data for fzf
        $fzfItems = @()
        $config.paths | Sort-Object { $_.alias }, { $_.path } | ForEach-Object {
            $alias = if ($_.alias) { $_.alias } else { '(no alias)' }
            $category = if ($_.category) { " [$($_.category)]" } else { '' }
            $lastUsed = if ($_.lastUsed) { " (Last: $($_.lastUsed))" } else { ' (Never used)' }
            $fzfItems += "$alias | $($_.path)$category$lastUsed"
        }

        try {
            $headerText = if ($Multiple) { 'Select Paths to Remove (Tab to multi-select, Enter to confirm)' } else { 'Select Path to Remove' }
            $fzfArgs = @('--height=40%', '--reverse', '--border', "--header=$headerText", '--delimiter=|', '--with-nth=1,2')

            if ($Multiple) {
                $fzfArgs += '--multi'
            }

            $selected = $fzfItems | fzf @fzfArgs

            if ($selected) {
                if ($Multiple) {
                    # Handle multiple selections
                    $pathsToRemove = @()
                    $selected | ForEach-Object {
                        $parts = $_ -split ' \| '
                        $aliasOrNoAlias = $parts[0].Trim()
                        $pathPart = ($parts[1] -split ' \[')[0].Trim()  # Remove category part

                        # Find the actual entry
                        $entry = $config.paths | Where-Object {
                            $_.path -eq $pathPart -or
                            ($aliasOrNoAlias -ne '(no alias)' -and $_.alias -eq $aliasOrNoAlias)
                        }
                        if ($entry) {
                            $pathsToRemove += $entry
                        }
                    }

                    if ($pathsToRemove.Count -gt 0) {
                        Write-Host "`nPaths to remove:" -ForegroundColor Yellow
                        foreach ($entry in $pathsToRemove) {
                            $alias = if ($entry.alias) { " (Alias: $($entry.alias))" } else { '' }
                            $category = if ($entry.category) { " [$($entry.category)]" } else { '' }
                            Write-Host "  - $($entry.path)$alias$category" -ForegroundColor White
                        }

                        $confirmation = Read-Host "`nAre you sure you want to remove these $($pathsToRemove.Count) paths? (y/N)"
                        if ($confirmation -match '^[Yy]') {
                            foreach ($entry in $pathsToRemove) {
                                $config.paths = @($config.paths | Where-Object { $_ -ne $entry })
                                Write-Host "Removed: $($entry.path)" -ForegroundColor Green
                            }
                            Save-QuickJumpConfig -Config $config
                            Write-Host "`nSuccessfully removed $($pathsToRemove.Count) paths" -ForegroundColor Green
                        } else {
                            Write-Host 'Removal cancelled.' -ForegroundColor Yellow
                        }
                    }
                } else {
                    # Handle single selection
                    $parts = $selected -split ' \| '
                    $aliasOrNoAlias = $parts[0].Trim()
                    $pathPart = ($parts[1] -split ' \[')[0].Trim()

                    if ($aliasOrNoAlias -ne '(no alias)') {
                        $Alias = $aliasOrNoAlias
                    } else {
                        $Path = $pathPart
                    }
                }
            } else {
                return # User cancelled
            }
        } catch {
            Write-Error "Error running fzf: $($_.Exception.Message)"
            return
        }

        # Handle single removal (either from parameters or interactive single selection)
        if (-not $Multiple -and ($Path -or $Alias)) {
            $entryToRemove = $null

            if ($Alias) {
                $entryToRemove = $config.paths | Where-Object { $_.alias -eq $Alias }
                if (-not $entryToRemove) {
                    Write-Error "No path found with alias '$Alias'"
                    $availableAliases = $config.paths | Where-Object { $_.alias } | Select-Object -ExpandProperty alias
                    if ($availableAliases) {
                        Write-Host "Available aliases: $($availableAliases -join ', ')" -ForegroundColor Yellow
                    }
                    return
                }
            } elseif ($Path) {
                try {
                    $resolvedPath = Resolve-Path $Path -ErrorAction Stop
                    $entryToRemove = $config.paths | Where-Object { $_.path -eq $resolvedPath.Path }
                } catch {
                    $entryToRemove = $config.paths | Where-Object { $_.path -eq $Path }
                }

                if (-not $entryToRemove) {
                    Write-Error "No saved path found matching '$Path'"
                    return
                }
            }

            if ($entryToRemove) {
                $displayAlias = if ($entryToRemove.alias) { " (Alias: $($entryToRemove.alias))" } else { '' }
                $displayCategory = if ($entryToRemove.category) { " [$($entryToRemove.category)]" } else { '' }

                if ($PSCmdlet.ShouldProcess("QuickJump path '$($entryToRemove.path)'$displayAlias$displayCategory", 'Remove from saved paths')) {
                    $config.paths = @($config.paths | Where-Object { $_ -ne $entryToRemove })
                    Save-QuickJumpConfig -Config $config

                    Write-Host "Removed path from QuickJump: $($entryToRemove.path)" -ForegroundColor Green
                    if ($entryToRemove.alias) {
                        Write-Host "  Alias was: $($entryToRemove.alias)" -ForegroundColor Gray
                    }
                    if ($entryToRemove.category) {
                        Write-Host "  Category was: $($entryToRemove.category)" -ForegroundColor Gray
                    }
                }
            }
        }
    } elseif (-not $Interactive -and -not $Path -and -not $Alias) {
        Write-Error 'Specify -Path, -Alias, or use -Interactive flag.'
    }
}

function Get-QuickJumpPaths {
    <#
    .SYNOPSIS
    Lists saved QuickJump paths or navigates to a selected one.

    .DESCRIPTION
    Displays all saved QuickJump paths with their aliases and categories, or uses interactive
    selection to choose and navigate to a path. Can filter by category and sort by usage.

    .PARAMETER Category
    Filter paths by category.

    .PARAMETER Interactive
    Use fzf for interactive selection and navigation.

    .PARAMETER Alias
    Navigate directly to the path with this alias, or return its path.

    .PARAMETER SortByRecent
    Sort paths by last used date (most recent first).

    .PARAMETER SortByMostUsed
    Sort paths by use count (most used first).

    .PARAMETER Path
    Return the path instead of navigating to it. Can be used with -Alias or -Interactive.

    .PARAMETER ListCategories
    List all available categories.

    .EXAMPLE
    Get-QuickJumpPaths
    Lists all saved paths

    .EXAMPLE
    Get-QuickJumpPaths -Interactive
    Uses fzf to select and navigate to a path

    .EXAMPLE
    Get-QuickJumpPaths -Category "projects" -Interactive
    Shows only paths in "projects" category for selection

    .EXAMPLE
    Get-QuickJumpPaths -Alias "docs" -Path
    Returns the path associated with alias "docs"

    .EXAMPLE
    cd (Get-QuickJumpPaths -Alias "docs" -Path)
    Changes to the directory of the specified alias

    .EXAMPLE
    Get-QuickJumpPaths -SortByMostUsed
    Lists paths sorted by usage count

    .EXAMPLE
    Get-QuickJumpPaths -ListCategories
    Shows all available categories
    #>
    [CmdletBinding()]
    param(
        [string]$Category,

        [switch]$Interactive,

        [string]$Alias,

        [switch]$SortByRecent,

        [switch]$SortByMostUsed,

        [switch]$Path,

        [switch]$ListCategories
    )

    $config = Get-QuickJumpConfig

    if ($config.paths.Count -eq 0) {
        Write-Host "No paths saved yet. Use 'Add-QuickJumpPath' to add some paths." -ForegroundColor Yellow
        return
    }

    # Handle list categories
    if ($ListCategories) {
        $categories = $config.paths | Where-Object { $_.category } |
            Select-Object -ExpandProperty category -Unique | Sort-Object

        if ($categories.Count -eq 0) {
            Write-Host 'No categories found.' -ForegroundColor Yellow
            return
        }

        Write-Host "`nAvailable Categories:" -ForegroundColor Cyan
        Write-Host ('=' * 50) -ForegroundColor Cyan

        foreach ($cat in $categories) {
            $count = ($config.paths | Where-Object { $_.category -eq $cat }).Count
            Write-Host ('{0} ({1} paths)' -f $cat, $count) -ForegroundColor White
        }
        return
    }

    # Handle direct alias lookup
    if ($Alias) {
        $entry = $config.paths | Where-Object { $_.alias -eq $Alias }
        if ($entry) {
            if ($Path) {
                return $entry.path
            } else {
                Update-PathUsage -Path $entry.path -Alias $Alias
                Set-Location $entry.path
                Write-Host "Jumped to '$Alias': $($entry.path)" -ForegroundColor Green
            }
        } else {
            Write-Error "No path found with alias '$Alias'"
            $availableAliases = $config.paths | Where-Object { $_.alias } | Select-Object -ExpandProperty alias
            if ($availableAliases) {
                Write-Host "Available aliases: $($availableAliases -join ', ')" -ForegroundColor Yellow
            }
        }
        return
    }

    # Filter by category if specified
    $filteredPaths = $config.paths
    if ($Category) {
        $filteredPaths = $filteredPaths | Where-Object { $_.category -eq $Category }
        if ($filteredPaths.Count -eq 0) {
            Write-Error "No paths found in category '$Category'"
            $availableCategories = $config.paths | Where-Object { $_.category } |
                Select-Object -ExpandProperty category -Unique | Sort-Object
            if ($availableCategories) {
                Write-Host "Available categories: $($availableCategories -join ', ')" -ForegroundColor Yellow
            }
            return
        }
    }

    # Interactive selection
    if ($Interactive) {
        if (-not (Test-FzfAvailable)) {
            Write-Error 'fzf is not available. Please install fzf first.'
            Write-Host 'Install fzf: https://github.com/junegunn/fzf#installation' -ForegroundColor Yellow
            return
        }

        # Sort paths based on options
        $sortedPaths = if ($SortByRecent) {
            $filteredPaths | Sort-Object {
                if ($_.lastUsed) {
                    [DateTime]::ParseExact($_.lastUsed, 'yyyy-MM-dd HH:mm:ss', $null)
                } else {
                    [DateTime]::MinValue
                }
            } -Descending
        } elseif ($SortByMostUsed) {
            $filteredPaths | Sort-Object { [int]$_.useCount } -Descending
        } else {
            $filteredPaths | Sort-Object { $_.alias }, { $_.path }
        }

        # Prepare fzf items
        $fzfItems = @()
        $sortedPaths | ForEach-Object {
            $alias = if ($_.alias) { "$($_.alias): " } else { '' }
            $category = if ($_.category) { " [$($_.category)]" } else { '' }
            $lastUsed = if ($_.lastUsed) { "Last: $($_.lastUsed)" } else { 'Never used' }
            $useCount = "Uses: $($_.useCount)"

            # Shorten path for display
            $displayPath = $_.path
            if ($displayPath.Length -gt 60) {
                $pathParts = $displayPath -split '[\\\/]'
                if ($pathParts.Length -gt 3) {
                    $drive = $pathParts[0]
                    $lastParts = $pathParts[-2..-1] -join '\'
                    $displayPath = "$drive\[...]\$lastParts"
                }
            }

            $fzfItems += @("$alias$displayPath$category", "$useCount", "$lastUsed", "$($_.path)") -join ' | '
        }

        try {
            $headerText = if ($Path) { 'Select Path (will return path)' } else { 'Select Path to Jump To' }
            if ($Category) { $headerText += " - Category: $Category" }

            $selected = $fzfItems | & fzf --height=60% --reverse --border --header="$headerText" --delimiter="|" --with-nth="1,2,3" --preview="powershell -c `"if (Get-Command eza -ErrorAction SilentlyContinue) { eza -la '{4}' } elseif (Get-Command ls -ErrorAction SilentlyContinue) { ls -la '{4}' } else { Get-ChildItem '{4}' }`""

            if ($selected) {
                $selectedPath = ($selected -split ' \| ')[-1].Trim()  # Last part is the full path

                if ($Path) {
                    return $selectedPath
                } else {
                    $entry = $config.paths | Where-Object { $_.path -eq $selectedPath }
                    if ($entry) {
                        Update-PathUsage -Path $selectedPath -Alias $entry.alias
                        Set-Location $selectedPath
                        Write-Host "Jumped to: $selectedPath" -ForegroundColor Green
                    }
                }
            }
        } catch {
            Write-Error "Error running fzf: $($_.Exception.Message)"
        }
    } else {
        # Just list paths
        $categoryText = if ($Category) { " in Category '$Category'" } else { '' }
        Write-Host "`nSaved QuickJump Paths${categoryText}:" -ForegroundColor Cyan
        Write-Host ('=' * 100) -ForegroundColor Cyan

        # Sort paths
        $sortedPaths = if ($SortByRecent) {
            $filteredPaths | Sort-Object {
                if ($_.lastUsed) {
                    [DateTime]::ParseExact($_.lastUsed, 'yyyy-MM-dd HH:mm:ss', $null)
                } else {
                    [DateTime]::MinValue
                }
            } -Descending
        } elseif ($SortByMostUsed) {
            $filteredPaths | Sort-Object { [int]$_.useCount } -Descending
        } else {
            $filteredPaths | Sort-Object { $_.alias }, { $_.path }
        }

        $sortedPaths | ForEach-Object {
            $alias = if ($_.alias) { $_.alias.PadRight(15) } else { '(no alias)'.PadRight(15) }
            $category = if ($_.category) { "[$($_.category)]".PadRight(12) } else { ''.PadRight(12) }
            $lastUsed = if ($_.lastUsed) { $_.lastUsed } else { 'Never' }
            $useCount = "Uses: $($_.useCount)".PadRight(10)

            Write-Host "$alias $category $useCount $lastUsed" -ForegroundColor White
            Write-Host "$(' '*15) $($_.path)" -ForegroundColor Gray
            Write-Host ''
        }

        Write-Host 'Usage Examples:' -ForegroundColor Yellow
        Write-Host '  Get-QuickJumpPaths -Interactive                  # Use fzf selection' -ForegroundColor Yellow
        Write-Host "  Get-QuickJumpPaths -Category 'projects'         # Filter by category" -ForegroundColor Yellow
        Write-Host '  Get-QuickJumpPaths -SortByMostUsed              # Sort by usage count' -ForegroundColor Yellow
        Write-Host "  Get-QuickJumpPaths -Alias 'docs'                # Jump to alias directly" -ForegroundColor Yellow
        Write-Host "  Get-QuickJumpPaths -Alias 'docs' -Path          # Get path for alias" -ForegroundColor Yellow
    }
}

function Invoke-QuickJump {
    <#
    .SYNOPSIS
    Quick navigation to saved paths by alias or interactive selection.

    .DESCRIPTION
    The main QuickJump function for fast directory navigation. Supports direct alias lookup,
    category filtering, and interactive selection with fzf.

    .PARAMETER Query
    Alias to jump to directly, or search term for path matching.

    .PARAMETER Category
    Filter paths by category before selection.

    .PARAMETER Interactive
    Force interactive selection even if Query matches an alias.

    .PARAMETER Path
    Return the path instead of navigating to it.

    .PARAMETER Recent
    Show paths sorted by most recently used.

    .PARAMETER MostUsed
    Show paths sorted by most frequently used.

    .EXAMPLE
    Invoke-QuickJump
    Shows interactive selection of all paths

    .EXAMPLE
    Invoke-QuickJump docs
    Jumps directly to path with alias "docs"

    .EXAMPLE
    Invoke-QuickJump -Category projects -Interactive
    Shows interactive selection filtered to "projects" category

    .EXAMPLE
    Invoke-QuickJump docs -Path
    Returns the path for alias "docs"

    .EXAMPLE
    cd (Invoke-QuickJump docs -Path)
    Changes to the directory using the returned path

    .EXAMPLE
    Invoke-QuickJump -Recent
    Shows paths sorted by most recently used
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Query,

        [string]$Category,

        [switch]$Interactive,

        [switch]$Path,

        [switch]$Recent,

        [switch]$MostUsed
    )

    $config = Get-QuickJumpConfig

    if ($config.paths.Count -eq 0) {
        Write-Host "No paths saved yet. Use 'Add-QuickJumpPath' to add some paths." -ForegroundColor Yellow
        return
    }

    # Direct alias match (unless Interactive is forced)
    if ($Query -and -not $Interactive) {
        $aliasMatch = $config.paths | Where-Object { $_.alias -eq $Query }
        if ($aliasMatch) {
            if ($Path) {
                return $aliasMatch.path
            } else {
                Update-PathUsage -Path $aliasMatch.path -Alias $Query
                Set-Location $aliasMatch.path
                Write-Host "Jumped to '$Query': $($aliasMatch.path)" -ForegroundColor Green
                return
            }
        }

        # If no exact alias match, fall through to interactive with search
        Write-Host "No exact alias match for '$Query'. Showing interactive selection..." -ForegroundColor Yellow
    }

    # Build parameters for Get-QuickJumpPaths
    $params = @{
        Interactive = $true
        Path = $Path
    }

    if ($Category) { $params.Category = $Category }
    if ($Recent) { $params.SortByRecent = $true }
    if ($MostUsed) { $params.SortByMostUsed = $true }

    Get-QuickJumpPaths @params
}

function Invoke-QuickJumpCategory {
    <#
    .SYNOPSIS
    Navigate to paths by first selecting a category.

    .DESCRIPTION
    Two-step navigation: first select a category, then select a path within that category.
    Useful when you have many paths organized into categories.

    .PARAMETER Path
    Return the selected path instead of navigating
        .EXAMPLE
    Invoke-QuickJumpCategory
    Select category, then select path within that category

    .EXAMPLE
    Invoke-QuickJumpCategory -Path
    Select category and path, then return the path

    .EXAMPLE
    cd (Invoke-QuickJumpCategory -Path)
    Use returned path to change directory
    #>
    [CmdletBinding()]
    param(
        [switch]$Path
    )

    $config = Get-QuickJumpConfig

    if ($config.paths.Count -eq 0) {
        Write-Host "No paths saved yet. Use 'Add-QuickJumpPath' to add some paths." -ForegroundColor Yellow
        return
    }

    # Get all categories
    $categories = $config.paths | Where-Object { $_.category } |
        Select-Object -ExpandProperty category -Unique | Sort-Object

    if ($categories.Count -eq 0) {
        Write-Warning 'No categories found. Showing all paths instead.'
        Get-QuickJumpPaths -Interactive -Path:$Path
        return
    }

    if (-not (Test-FzfAvailable)) {
        Write-Error 'fzf is not available. Please install fzf first.'
        return
    }

    # First selection: Choose category with path counts
    $categoryItems = @()
    $categories | ForEach-Object {
        $pathCount = ($config.paths | Where-Object { $_.category -eq $_ }).Count
        $categoryItems += "$_ ($pathCount paths)"
    }

    try {
        $selectedCategoryItem = $categoryItems | fzf --height=40% --reverse --border --header="Select Category" --prompt="Category> "

        if (-not $selectedCategoryItem) {
            Write-Host 'No category selected.' -ForegroundColor Yellow
            return
        }

        $selectedCategory = ($selectedCategoryItem -split ' \(')[0]
        Write-Host "Selected category: $selectedCategory" -ForegroundColor Cyan

        # Second selection: Choose path from category
        Get-QuickJumpPaths -Category $selectedCategory -Interactive -Path:$Path
    } catch {
        Write-Error "Error during category selection: $($_.Exception.Message)"
    }
}

function Get-QuickJumpCategories {
    <#
    .SYNOPSIS
    Lists all available QuickJump categories.

    .DESCRIPTION
    Returns a list of all categories used in your saved QuickJump paths,
    along with the count of paths in each category.

    .PARAMETER Name
    Return only category names without counts.

    .EXAMPLE
    Get-QuickJumpCategories
    Lists all categories with path counts

    .EXAMPLE
    Get-QuickJumpCategories -Name
    Returns just the category names

    .EXAMPLE
    Get-QuickJumpCategories | Where-Object { $_.Count -gt 5 }
    Find categories with more than 5 paths
    #>
    [CmdletBinding()]
    param(
        [switch]$Name
    )

    $config = Get-QuickJumpConfig

    $categories = $config.paths | Where-Object { $_.category } |
        Select-Object -ExpandProperty category -Unique | Sort-Object

    if ($categories.Count -eq 0) {
        Write-Host 'No categories found.' -ForegroundColor Yellow
        return
    }

    if ($Name) {
        return $categories
    }

    return $categories | ForEach-Object {
        $pathCount = ($config.paths | Where-Object { $_.category -eq $_ }).Count
        [PSCustomObject]@{
            Category = $_
            Count = $pathCount
        }
    }
}

function Open-QuickJumpRecent {
    <#
    .SYNOPSIS
    Navigate to the most recently used QuickJump path.

    .DESCRIPTION
    Quickly jump to the path that was most recently accessed through QuickJump.
    If no paths have been used yet, shows interactive selection sorted by recent.

    .PARAMETER Path
    Return the most recent path instead of navigating to it.

    .PARAMETER Interactive
    Force interactive selection even if a recent path exists.

    .EXAMPLE
    Open-QuickJumpRecent
    Jump to the most recently used path

    .EXAMPLE
    Open-QuickJumpRecent -Path
    Get the path of the most recently used location

    .EXAMPLE
    cd (Open-QuickJumpRecent -Path)
    Change to the most recent path

    .EXAMPLE
    Open-QuickJumpRecent -Interactive
    Show interactive selection sorted by recent usage
    #>
    [CmdletBinding()]
    param(
        [switch]$Path,

        [switch]$Interactive
    )

    $config = Get-QuickJumpConfig

    if ($config.paths.Count -eq 0) {
        Write-Host "No paths saved yet. Use 'Add-QuickJumpPath' to add some paths." -ForegroundColor Yellow
        return
    }

    # Find the most recently used path
    $mostRecent = $null
    $mostRecentDate = [DateTime]::MinValue

    foreach ($entry in $config.paths) {
        if ($entry.lastUsed) {
            try {
                $usedDate = [DateTime]::ParseExact($entry.lastUsed, 'yyyy-MM-dd HH:mm:ss', $null)
                if ($usedDate -gt $mostRecentDate) {
                    $mostRecentDate = $usedDate
                    $mostRecent = $entry
                }
            } catch {
                Write-Warning "Could not parse date for path '$($entry.path)': $($entry.lastUsed)"
            }
        }
    }

    # If we found a recent path and not in interactive mode, use it
    if ($mostRecent -and -not $Interactive) {
        if ($Path) {
            return $mostRecent.path
        } else {
            $alias = if ($mostRecent.alias) { " ('$($mostRecent.alias)')" } else { '' }
            Write-Host "Opening most recent path${alias}: $($mostRecent.path)" -ForegroundColor Green
            Write-Host "Last used: $($mostRecent.lastUsed)" -ForegroundColor Gray

            Update-PathUsage -Path $mostRecent.path -Alias $mostRecent.alias
            Set-Location $mostRecent.path
        }
        return
    }

    # If no recent path found or interactive mode requested
    if (-not $mostRecent) {
        Write-Host 'No recently used paths found. Showing all paths sorted by recent...' -ForegroundColor Yellow
    }

    # Show interactive selection sorted by recent
    Get-QuickJumpPaths -Interactive -SortByRecent -Path:$Path
}
#endregion

#region Aliases and Argument Completers
# Set up aliases
Set-Alias -Name 'qj' -Value 'Invoke-QuickJump'
Set-Alias -Name 'qja' -Value 'Add-QuickJumpPath'
Set-Alias -Name 'qjr' -Value 'Remove-QuickJumpPath'
Set-Alias -Name 'qjl' -Value 'Get-QuickJumpPaths'
Set-Alias -Name 'qjc' -Value 'Invoke-QuickJumpCategory'
Set-Alias -Name 'qjrecent' -Value 'Open-QuickJumpRecent'

# Enhanced argument completer for aliases
Register-ArgumentCompleter -CommandName 'Invoke-QuickJump', 'Get-QuickJumpPaths', 'Remove-QuickJumpPath', 'qj', 'qjl', 'qjr' -ParameterName 'Alias' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    try {
        $config = Get-QuickJumpConfig
        $config.paths | Where-Object {
            $_.alias -and $_.alias -like "$wordToComplete*"
        } | ForEach-Object {
            $category = if ($_.category) { " [$($_.category)]" } else { '' }
            $lastUsed = if ($_.lastUsed) { " (Last: $($_.lastUsed))" } else { '' }
            $useCount = if ([int]$_.useCount -gt 0) { " Uses: $($_.useCount)" } else { '' }

            [System.Management.Automation.CompletionResult]::new(
                "'$($_.alias)'",                    # CompletionText (what gets inserted)
                $_.alias,                           # ListItemText (what shows in list)
                'ParameterValue',                   # CompletionResultType
                "$($_.path)$category$useCount$lastUsed"  # ToolTip
            )
        }
    } catch {
        @()
    }
}

# Argument completer for Query parameter
Register-ArgumentCompleter -CommandName 'Invoke-QuickJump', 'qj' -ParameterName 'Query' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    try {
        $config = Get-QuickJumpConfig
        $config.paths | Where-Object {
            $_.alias -and $_.alias -like "$wordToComplete*"
        } | ForEach-Object {
            $category = if ($_.category) { " [$($_.category)]" } else { '' }
            $lastUsed = if ($_.lastUsed) { " (Last: $($_.lastUsed))" } else { '' }
            $useCount = if ([int]$_.useCount -gt 0) { " Uses: $($_.useCount)" } else { '' }

            [System.Management.Automation.CompletionResult]::new(
                $_.alias,                           # CompletionText (what gets inserted)
                $_.alias,                           # ListItemText (what shows in list)
                'ParameterValue',                   # CompletionResultType
                "$($_.path)$category$useCount$lastUsed"  # ToolTip
            )
        }
    } catch {
        @()
    }
}

# Argument completer for categories
Register-ArgumentCompleter -CommandName 'Invoke-QuickJump', 'Get-QuickJumpPaths', 'Add-QuickJumpPath', 'qj', 'qjl', 'qja' -ParameterName 'Category' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    try {
        $config = Get-QuickJumpConfig
        $categories = $config.paths | Where-Object {
            $_.category -and $_.category -like "$wordToComplete*"
        } | Select-Object -ExpandProperty category -Unique | Sort-Object

        $categories | ForEach-Object {
            $pathCount = ($config.paths | Where-Object { $_.category -eq $_ }).Count

            [System.Management.Automation.CompletionResult]::new(
                "'$_'",                             # CompletionText (what gets inserted)
                $_,                                 # ListItemText (what shows in list)
                'ParameterValue',                   # CompletionResultType
                "Category: $_ ($pathCount paths)"   # ToolTip
            )
        }
    } catch {
        @()
    }
}

# Argument completer for Remove-QuickJumpPath paths
Register-ArgumentCompleter -CommandName 'Remove-QuickJumpPath', 'qjr' -ParameterName 'Path' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    try {
        $config = Get-QuickJumpConfig
        $config.paths | Where-Object {
            $_.path -like "*$wordToComplete*"
        } | ForEach-Object {
            $category = if ($_.category) { " [$($_.category)]" } else { '' }
            $alias = if ($_.alias) { " (Alias: $($_.alias))" } else { '' }

            [System.Management.Automation.CompletionResult]::new(
                "'$($_.path)'",                     # CompletionText (what gets inserted)
                (Split-Path $_.path -Leaf),         # ListItemText (just folder name)
                'ParameterValue',                   # CompletionResultType
                "$($_.path)$category$alias"         # ToolTip (full path with details)
            )
        }
    } catch {
        @()
    }
}

# Argument completer for Add-QuickJumpPath alias (show existing as reference)
Register-ArgumentCompleter -CommandName 'Add-QuickJumpPath', 'qja' -ParameterName 'Alias' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    try {
        $config = Get-QuickJumpConfig
        $existingAliases = $config.paths | Where-Object { $_.alias } | Select-Object -ExpandProperty alias

        # Show existing aliases as reference (they'll be marked as already used)
        $existingAliases | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(
                "'$_'",                             # CompletionText
                $_,                                 # ListItemText
                'ParameterValue',                   # CompletionResultType
                'Alias already exists (use -Force to update)'  # ToolTip
            )
        }
    } catch {
        @()
    }
}
#endregion

# Export module members
Export-ModuleMember -Function @(
    'Add-QuickJumpPath',
    'Remove-QuickJumpPath',
    'Get-QuickJumpPaths',
    'Invoke-QuickJump',
    'Invoke-QuickJumpCategory',
    'Get-QuickJumpCategories',
    'Open-QuickJumpRecent',
    'Get-QuickJumpConfigPath'
) -Alias @('qj', 'qja', 'qjr', 'qjl', 'qjc', 'qjrecent')
