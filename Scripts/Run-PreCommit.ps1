#requires -Version 7.0
<#!
.SYNOPSIS
Runs pre-commit across the repository and attempts automatic fixes.
.DESCRIPTION
Executes `pre-commit run --all-files` twice so that auto-fixable issues are
applied during the first run and verified during the second run. If issues
remain after the second run, the script exits with a non-zero status.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command pre-commit -ErrorAction SilentlyContinue)) {
    throw 'pre-commit CLI not found. Install it before running this script.'
}

function Invoke-PreCommitAll {
    param([switch]$ShowDiff)

    $preCommitArgs = @('run', '--all-files')
    if ($ShowDiff) { $preCommitArgs += '--show-diff-on-failure' }
    & pre-commit @preCommitArgs
    return $LASTEXITCODE
}

$first = Invoke-PreCommitAll -ShowDiff
$second = Invoke-PreCommitAll -ShowDiff

if ($second -ne 0) {
    throw 'Pre-commit detected issues that could not be auto-fixed.'
}

exit 0
