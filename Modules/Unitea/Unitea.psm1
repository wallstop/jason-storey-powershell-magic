# Unitea.psm1
using namespace System.Collections.Generic

$commonModulePath = Join-Path $PSScriptRoot '..\Common\PowerShellMagic.Common.psd1'
Import-Module $commonModulePath -Force -ErrorAction Stop

$script:UnityProjectsCache = $null
$script:UnityProjectsTimestamp = $null
$script:StartupSyncCheckCompleted = $false

$script:IsWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
$script:IsMacOS = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)
$script:IsLinux = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)

# Load module scripts
$privateFolder = Join-Path $PSScriptRoot 'Private'
if (Test-Path -LiteralPath $privateFolder) {
    Get-ChildItem -Path $privateFolder -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object { . $_.FullName }
}

$publicFolder = Join-Path $PSScriptRoot 'Public'
if (Test-Path -LiteralPath $publicFolder) {
    Get-ChildItem -Path $publicFolder -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object { . $_.FullName }
}

Export-ModuleMember -Function @(
    'Open-UnityProject',
    'Add-UnityProject',
    'Update-UnityProject',
    'Get-UnityProjectSyncStatus',
    'Invoke-UniteaStartupSyncCheck',
    'Get-UnityProjects',
    'Remove-UnityProject',
    'Open-RecentUnityProject',
    'Get-UnityConfigPath'
) -Alias @('unity', 'unity-add', 'unity-update', 'unity-check', 'unity-list', 'unity-remove', 'unity-recent', 'unity-config')
