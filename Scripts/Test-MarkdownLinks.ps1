#requires -Version 7.0
<#
.SYNOPSIS
Validates local Markdown links and images.

.DESCRIPTION
Scans Markdown files for relative links or images and ensures the referenced
files exist on disk. Remote URLs (http/https), mailto, anchors, and data URIs
are ignored.

.PARAMETER Files
Optional list of Markdown files to validate. When omitted, the entire
repository is scanned.
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Files
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-MarkdownPath {
    param(
        [Parameter(Mandatory)]
        [string]$BaseDirectory,
        [Parameter(Mandatory)]
        [string]$Target
    )

    $decoded = [System.Uri]::UnescapeDataString($Target)
    $decoded = $decoded.Trim()

    if ($decoded.StartsWith('<') -and $decoded.EndsWith('>')) {
        $decoded = $decoded.Substring(1, $decoded.Length - 2)
    }

    if ([string]::IsNullOrWhiteSpace($decoded)) {
        return $null
    }

    # Ignore remote and non-file schemes
    if ($decoded -match '^(?:[a-zA-Z][a-zA-Z0-9+\-.]*:|//)') {
        return $null
    }

    if ($decoded.StartsWith('#') -or $decoded.StartsWith('javascript:', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }

    $pathPart = $decoded
    $anchorIndex = $pathPart.IndexOf('#')
    if ($anchorIndex -ge 0) {
        $pathPart = $pathPart.Substring(0, $anchorIndex)
    }

    $queryIndex = $pathPart.IndexOf('?')
    if ($queryIndex -ge 0) {
        $pathPart = $pathPart.Substring(0, $queryIndex)
    }

    if ([string]::IsNullOrWhiteSpace($pathPart)) {
        return $null
    }

    $pathPart = $pathPart.TrimStart()

    $root = (Get-Item -LiteralPath $BaseDirectory).FullName
    $workspaceRoot = (Get-Location).ProviderPath

    if ($pathPart.StartsWith('./')) {
        $pathPart = $pathPart.Substring(2)
    }

    if ($pathPart.StartsWith('/')) {
        $candidate = Join-Path $workspaceRoot ($pathPart.TrimStart('/'))
    } else {
        $candidate = Join-Path $root $pathPart
    }

    try {
        return [System.IO.Path]::GetFullPath($candidate)
    } catch {
        return $candidate
    }
}

if (-not $Files -or $Files.Count -eq 0) {
    $Files = Get-ChildItem -Path (Get-Location) -Recurse -Include *.md, *.markdown |
        Where-Object { -not $_.PSIsContainer } |
        Select-Object -ExpandProperty FullName
}

$Files = $Files |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
    Sort-Object -Unique

$linkErrors = New-Object System.Collections.Generic.List[pscustomobject]
$linkPattern = '(?<image>!?)\[(?<alt>[^\]]*)\]\((?<target>[^)\s]+(?:\s+"[^"]*")?)\)'

foreach ($file in $Files) {
    $resolvedFile = (Resolve-Path -LiteralPath $file -ErrorAction Stop).ProviderPath
    $content = Get-Content -LiteralPath $resolvedFile -Raw
    $directory = Split-Path -Path $resolvedFile -Parent

    $linkMatches = [System.Text.RegularExpressions.Regex]::Matches($content, $linkPattern)
    foreach ($match in $linkMatches) {
        $target = $match.Groups['target'].Value.Trim()
        if (-not $target) {
            continue
        }

        # Remove optional title e.g. (path "Title")
        $target = $target -replace '\s+"[^"]*"$', ''

        $resolvedPath = Resolve-MarkdownPath -BaseDirectory $directory -Target $target
        if (-not $resolvedPath) {
            continue
        }

        if (-not (Test-Path -LiteralPath $resolvedPath)) {
            $linkErrors.Add([pscustomobject]@{
                    File = $resolvedFile
                    Target = $target
                })
        }
    }
}

if ($linkErrors.Count -gt 0) {
    Write-Host 'Markdown local link validation failed. Missing targets:' -ForegroundColor Red
    foreach ($linkError in $linkErrors) {
        Write-Host ('  {0}: {1}' -f $linkError.File, $linkError.Target) -ForegroundColor Red
    }
    exit 1
}

Write-Host 'Markdown local link validation passed.' -ForegroundColor Green
