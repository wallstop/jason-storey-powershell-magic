# ConfigCache.ps1
# Advanced in-memory configuration caching with FileSystemWatcher for automatic invalidation

# Module-level cache storage
if (-not $script:PSMagicConfigCaches) {
    $script:PSMagicConfigCaches = @{}
}

if (-not $script:PSMagicFileWatchers) {
    $script:PSMagicFileWatchers = @{}
}

function Initialize-PSMagicConfigCache {
    <#
    .SYNOPSIS
    Initializes a configuration cache with automatic file watching for invalidation.

    .DESCRIPTION
    Creates an in-memory cache for configuration files with a FileSystemWatcher
    that automatically invalidates the cache when the file changes.

    .PARAMETER CacheKey
    Unique identifier for this cache (e.g., 'quickjump', 'templater', 'unitea')

    .PARAMETER ConfigPath
    Path to the configuration file to watch

    .EXAMPLE
    Initialize-PSMagicConfigCache -CacheKey 'quickjump' -ConfigPath $configPath
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CacheKey,

        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    # Clean up existing watcher if present
    if ($script:PSMagicFileWatchers.ContainsKey($CacheKey)) {
        $oldWatcher = $script:PSMagicFileWatchers[$CacheKey]
        if ($oldWatcher) {
            $oldWatcher.EnableRaisingEvents = $false
            $oldWatcher.Dispose()
        }
        $script:PSMagicFileWatchers.Remove($CacheKey)
    }

    # Initialize cache entry
    $script:PSMagicConfigCaches[$CacheKey] = @{
        Data = $null
        Timestamp = $null
        ConfigPath = $ConfigPath
    }

    # Set up FileSystemWatcher if config file exists
    $configDir = Split-Path $ConfigPath -Parent
    $configFile = Split-Path $ConfigPath -Leaf

    if (Test-Path $configDir) {
        try {
            $watcher = New-Object System.IO.FileSystemWatcher
            $watcher.Path = $configDir
            $watcher.Filter = $configFile
            $watcher.NotifyFilter = (
                [System.IO.NotifyFilters]::LastWrite -bor
                [System.IO.NotifyFilters]::FileName -bor
                [System.IO.NotifyFilters]::Size
            )
            $watcher.IncludeSubdirectories = $false

            # Create event handler for file changes
            $onChange = {
                param($source, $eventArgs)
                $key = $Event.MessageData
                if ($script:PSMagicConfigCaches.ContainsKey($key)) {
                    Write-Verbose "Config cache invalidated for '$key' due to file change"
                    $script:PSMagicConfigCaches[$key].Data = $null
                    $script:PSMagicConfigCaches[$key].Timestamp = $null
                }
            }

            # Register events
            $null = Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $onChange -MessageData $CacheKey
            $null = Register-ObjectEvent -InputObject $watcher -EventName Created -Action $onChange -MessageData $CacheKey
            $null = Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action $onChange -MessageData $CacheKey
            $null = Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $onChange -MessageData $CacheKey

            $watcher.EnableRaisingEvents = $true
            $script:PSMagicFileWatchers[$CacheKey] = $watcher

            Write-Verbose "FileSystemWatcher initialized for '$CacheKey' at '$ConfigPath'"
        } catch {
            Write-Warning "Failed to initialize FileSystemWatcher for '$CacheKey': $($_.Exception.Message)"
        }
    }
}

function Get-PSMagicCachedConfig {
    <#
    .SYNOPSIS
    Retrieves a configuration from cache or loads it if not cached.

    .DESCRIPTION
    Returns cached configuration data if available, otherwise loads from file
    and caches it. The cache is automatically invalidated when the file changes.

    .PARAMETER CacheKey
    Unique identifier for this cache

    .PARAMETER ConfigPath
    Path to the configuration file

    .PARAMETER LoadScriptBlock
    ScriptBlock that loads and returns the configuration data

    .EXAMPLE
    $config = Get-PSMagicCachedConfig -CacheKey 'quickjump' -ConfigPath $path -LoadScriptBlock {
        Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
    }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CacheKey,

        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $true)]
        [scriptblock]$LoadScriptBlock
    )

    # Initialize cache if not present
    if (-not $script:PSMagicConfigCaches.ContainsKey($CacheKey)) {
        Initialize-PSMagicConfigCache -CacheKey $CacheKey -ConfigPath $ConfigPath
    }

    $cacheEntry = $script:PSMagicConfigCaches[$CacheKey]

    # Return cached data if available and still valid
    if ($cacheEntry.Data -ne $null) {
        Write-Verbose "Returning cached config for '$CacheKey'"
        return $cacheEntry.Data
    }

    # Load config from file
    Write-Verbose "Loading config from file for '$CacheKey'"
    try {
        $data = & $LoadScriptBlock
        $cacheEntry.Data = $data
        $cacheEntry.Timestamp = Get-Date
        return $data
    } catch {
        Write-Error "Failed to load configuration for '$CacheKey': $($_.Exception.Message)"
        throw
    }
}

function Clear-PSMagicConfigCache {
    <#
    .SYNOPSIS
    Clears the configuration cache for a specific key or all caches.

    .PARAMETER CacheKey
    Cache key to clear. If not specified, clears all caches.

    .EXAMPLE
    Clear-PSMagicConfigCache -CacheKey 'quickjump'

    .EXAMPLE
    Clear-PSMagicConfigCache  # Clear all caches
    #>
    [CmdletBinding()]
    param(
        [string]$CacheKey
    )

    if ($CacheKey) {
        if ($script:PSMagicConfigCaches.ContainsKey($CacheKey)) {
            $script:PSMagicConfigCaches[$CacheKey].Data = $null
            $script:PSMagicConfigCaches[$CacheKey].Timestamp = $null
            Write-Verbose "Cleared config cache for '$CacheKey'"
        }
    } else {
        foreach ($key in $script:PSMagicConfigCaches.Keys) {
            $script:PSMagicConfigCaches[$key].Data = $null
            $script:PSMagicConfigCaches[$key].Timestamp = $null
        }
        Write-Verbose 'Cleared all config caches'
    }
}

function Remove-PSMagicConfigCache {
    <#
    .SYNOPSIS
    Removes a configuration cache and disposes its FileSystemWatcher.

    .PARAMETER CacheKey
    Cache key to remove. If not specified, removes all caches.

    .EXAMPLE
    Remove-PSMagicConfigCache -CacheKey 'quickjump'
    #>
    [CmdletBinding()]
    param(
        [string]$CacheKey
    )

    $keysToRemove = if ($CacheKey) { @($CacheKey) } else { @($script:PSMagicFileWatchers.Keys) }

    foreach ($key in $keysToRemove) {
        if ($script:PSMagicFileWatchers.ContainsKey($key)) {
            $watcher = $script:PSMagicFileWatchers[$key]
            if ($watcher) {
                $watcher.EnableRaisingEvents = $false
                $watcher.Dispose()
            }
            $script:PSMagicFileWatchers.Remove($key)
            Write-Verbose "Removed FileSystemWatcher for '$key'"
        }

        if ($script:PSMagicConfigCaches.ContainsKey($key)) {
            $script:PSMagicConfigCaches.Remove($key)
            Write-Verbose "Removed config cache for '$key'"
        }
    }
}

# Note: FileSystemWatchers are automatically disposed when PowerShell session ends.
# For manual cleanup, use: Remove-PSMagicConfigCache

Export-ModuleMember -Function @(
    'Initialize-PSMagicConfigCache',
    'Get-PSMagicCachedConfig',
    'Clear-PSMagicConfigCache',
    'Remove-PSMagicConfigCache'
)
