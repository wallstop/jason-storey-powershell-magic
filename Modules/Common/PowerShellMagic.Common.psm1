# PowerShellMagic.Common.psm1
# Shared helpers for PowerShell Magic modules.

function Get-PSMagicConfigRoot {
    if ($env:XDG_CONFIG_HOME) {
        return $env:XDG_CONFIG_HOME
    }

    $profileDir = $null
    if ($PROFILE) {
        try {
            $profileDir = Split-Path $PROFILE -Parent
        } catch {
            $profileDir = $null
        }
    }

    if ($profileDir -and (Test-Path $profileDir)) {
        return Join-Path $profileDir '.config'
    }

    if ($env:HOME) {
        return Join-Path $env:HOME '.config'
    }

    return Join-Path (Get-Location).Path '.config'
}

function Ensure-PSMagicDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }

    return $Path
}

function Copy-PSMagicHashtable {
    param(
        $InputObject
    )

    if (-not $InputObject) {
        return @{}
    }

    $json = $InputObject | ConvertTo-Json -Depth 32
    return $json | ConvertFrom-Json -AsHashtable
}

function Get-PSMagicConfigPath {
    <#
    .SYNOPSIS
    Resolves the configuration directory or file path for a PowerShell Magic component.

    .DESCRIPTION
    Uses XDG-style locations when available and falls back to the current profile's .config folder.
    Ensures the component directory exists before returning the resolved path.

    .PARAMETER Component
    Component name (e.g. 'quickjump', 'templater', 'unity').

    .PARAMETER FileName
    Optional file name to append to the component directory.

    .PARAMETER ReturnDirectory
    Return only the component directory path instead of the file path.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Component,

        [string]$FileName,

        [switch]$ReturnDirectory
    )

    $configRoot = Get-PSMagicConfigRoot
    $componentDirectory = Ensure-PSMagicDirectory -Path (Join-Path $configRoot $Component)

    if ($ReturnDirectory -or [string]::IsNullOrWhiteSpace($FileName)) {
        return $componentDirectory
    }

    return Join-Path $componentDirectory $FileName
}

function Test-FzfAvailable {
    try {
        $null = Get-Command fzf -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Test-PSMagicNonInteractive {
    <#
    .SYNOPSIS
    Determines whether the current PowerShell Magic session should avoid interactive prompts.

    .DESCRIPTION
    Checks the POWERSHELL_MAGIC_NON_INTERACTIVE environment variable (or a supplied override)
    for common truthy values (1/true/yes/on). Supports both process and inherited environment scopes.

    .PARAMETER EnvironmentVariable
    Optional override for the environment variable name to inspect. Defaults to POWERSHELL_MAGIC_NON_INTERACTIVE.
    #>
    param(
        [string]$EnvironmentVariable = 'POWERSHELL_MAGIC_NON_INTERACTIVE'
    )

    $value = $null
    try {
        $valueItem = Get-Item -Path ('Env:{0}' -f $EnvironmentVariable) -ErrorAction SilentlyContinue
        if ($valueItem) {
            $value = $valueItem.Value
        }
    } catch {
        $value = $null
    }

    if ([string]::IsNullOrWhiteSpace($value)) {
        return $false
    }

    return $value -match '^(1|true|yes|on)$'
}

Export-ModuleMember -Function @(
    'Get-PSMagicConfigPath',
    'Copy-PSMagicHashtable',
    'Test-FzfAvailable',
    'Test-PSMagicNonInteractive'
)
