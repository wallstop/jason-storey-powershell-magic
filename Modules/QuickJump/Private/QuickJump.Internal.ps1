function New-QuickJumpConfig {
    return @{
        paths = @()
        version = '1.0'
    }
}

function Copy-QuickJumpConfig {
    param(
        [hashtable]$Config
    )

    if (-not $Config) {
        return New-QuickJumpConfig
    }

    return Copy-PSMagicHashtable -InputObject $Config
}

function ConvertTo-QuickJumpRecord {
    param(
        [hashtable]$Entry
    )

    $useCount = 0
    if ($Entry.ContainsKey('useCount') -and $Entry.useCount -ne $null) {
        [int]::TryParse($Entry.useCount.ToString(), [ref]$useCount) | Out-Null
    }

    $lastUsedDate = $null
    if ($Entry.lastUsed) {
        [DateTime]::TryParseExact(
            $Entry.lastUsed,
            'yyyy-MM-dd HH:mm:ss',
            $null,
            [System.Globalization.DateTimeStyles]::AssumeLocal,
            [ref]$lastUsedDate
        ) | Out-Null
    }

    return [PSCustomObject]@{
        Alias = $Entry.alias
        Path = $Entry.path
        Category = $Entry.category
        LastUsed = $lastUsedDate
        LastUsedString = $Entry.lastUsed
        UseCount = $useCount
    }
}

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

    return Get-PSMagicConfigPath -Component 'quickjump' -FileName 'paths.json' -ReturnDirectory:$ReturnDirectory
}

function Get-QuickJumpConfig {
    $configPath = Get-QuickJumpConfigPath
    if (Test-Path $configPath) {
        try {
            $fileInfo = Get-Item $configPath -ErrorAction Stop

            if ($script:QuickJumpConfigCache -ne $null -and
                $script:QuickJumpConfigTimestamp -eq $fileInfo.LastWriteTimeUtc) {
                return Copy-QuickJumpConfig -Config $script:QuickJumpConfigCache
            }

            $config = Get-Content $configPath -Raw -ErrorAction Stop |
                ConvertFrom-Json -AsHashtable -ErrorAction Stop

            if (-not $config) {
                $config = New-QuickJumpConfig
            }

            if (-not $config.ContainsKey('paths') -or -not $config.paths) {
                $config.paths = @()
            }

            $script:QuickJumpConfigCache = Copy-QuickJumpConfig -Config $config
            $script:QuickJumpConfigTimestamp = $fileInfo.LastWriteTimeUtc

            return Copy-QuickJumpConfig -Config $config
        } catch {
            Write-Warning "QuickJump configuration at '$configPath' is invalid: $($_.Exception.Message)"
            $timestamp = Get-Date -Format 'yyyyMMddTHHmmss'
            $backupPath = "$configPath.backup.$timestamp"

            try {
                Copy-Item $configPath $backupPath -Force
                Write-Warning "Backup created at: $backupPath"
            } catch {
                Write-Warning "Failed to create backup for corrupt QuickJump configuration: $($_.Exception.Message)"
            }

            $resetConfig = New-QuickJumpConfig
            try {
                Save-QuickJumpConfig -Config $resetConfig
            } catch {
                Write-Warning "Failed to reset QuickJump configuration: $($_.Exception.Message)"
            }

            return Copy-QuickJumpConfig -Config $resetConfig
        }
    }

    $config = New-QuickJumpConfig
    $script:QuickJumpConfigCache = Copy-QuickJumpConfig -Config $config
    $script:QuickJumpConfigTimestamp = $null
    return Copy-QuickJumpConfig -Config $config
}

function Save-QuickJumpConfig {
    param([hashtable]$Config)

    $configPath = Get-QuickJumpConfigPath

    try {
        $json = $Config | ConvertTo-Json -Depth 10
        $json | Set-Content $configPath -Encoding UTF8
        $fileInfo = Get-Item $configPath -ErrorAction Stop
        $script:QuickJumpConfigCache = Copy-QuickJumpConfig -Config $Config
        $script:QuickJumpConfigTimestamp = $fileInfo.LastWriteTimeUtc
    } catch {
        $message = "Failed to save QuickJump configuration to '$configPath'. $($_.Exception.Message)"
        throw (New-Object System.Exception($message, $_.Exception))
    }
}

function Get-QuickJumpRecordDisplay {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Record
    )

    $aliasText = if ($Record.Alias) { "$($Record.Alias): " } else { '' }
    $categoryText = if ($Record.Category) { " [$($Record.Category)]" } else { '' }
    $useText = if ($Record.UseCount -gt 0) { " (Uses: $($Record.UseCount))" } else { '' }
    $lastUsedText = if ($Record.LastUsed) { " (Last: $($Record.LastUsed.ToString('yyyy-MM-dd HH:mm:ss')))" } else { '' }

    return "$aliasText$($Record.Path)$categoryText$useText$lastUsedText"
}

function Invoke-QuickJumpFallbackSelection {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Records,

        [string]$Header = 'Select a QuickJump path:',

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

    $aliasLookup = @{}
    for ($index = 0; $index -lt $Records.Count; $index++) {
        $record = $Records[$index]
        $display = Get-QuickJumpRecordDisplay -Record $record
        Write-Host ('[{0}] {1}' -f ($index + 1), $display) -ForegroundColor Gray

        if ($record.Alias) {
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
            Write-Warning "No entry found for selection '$token'."
        }
    }

    if ($selected.Count -eq 0) {
        return $AllowMulti ? @() : $null
    }

    if ($AllowMulti) {
        return @($selected | Select-Object -Unique)
    } else {
        return $selected[0]
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
