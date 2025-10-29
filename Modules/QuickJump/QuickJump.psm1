# QuickJump.psm1
using namespace System.Collections.Generic

$commonModulePath = Join-Path $PSScriptRoot '..\Common\PowerShellMagic.Common.psd1'
Import-Module $commonModulePath -Force -ErrorAction Stop

$script:QuickJumpConfigCache = $null
$script:QuickJumpConfigTimestamp = $null
$script:PwshExecutable = try {
    [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
} catch {
    $null
}
if (-not $script:PwshExecutable -or [string]::IsNullOrWhiteSpace($script:PwshExecutable)) {
    $script:PwshExecutable = 'pwsh'
}

$privateFolder = Join-Path $PSScriptRoot 'Private'
if (Test-Path -LiteralPath $privateFolder) {
    Get-ChildItem -Path $privateFolder -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object {
        . $_.FullName
    }
}

$publicFolder = Join-Path $PSScriptRoot 'Public'
if (Test-Path -LiteralPath $publicFolder) {
    Get-ChildItem -Path $publicFolder -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object {
        . $_.FullName
    }
}

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
