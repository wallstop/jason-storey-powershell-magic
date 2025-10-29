# Templater.psm1
using namespace System.Collections.Generic

$commonModulePath = Join-Path $PSScriptRoot '..\Common\PowerShellMagic.Common.psd1'
Import-Module $commonModulePath -Force -ErrorAction Stop

$script:TemplaterConfigCache = $null
$script:TemplaterConfigTimestamp = $null
$script:ZipAssemblyLoaded = $false
$script:Trusted7ZipPath = $null
$script:IsWindows = ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)
$script:IsMacOS = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)
$script:IsLinux = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)
$script:CurrentPlatform = if ($script:IsWindows) {
    'Windows'
} elseif ($script:IsMacOS) {
    'MacOS'
} elseif ($script:IsLinux) {
    'Linux'
} else {
    'Unknown'
}
$script:SevenZipWarningEmitted = $false
$script:ManagedSevenZipHashes = @{
    Windows = '78AFA2A1C773CAF3CF7EDF62F857D2A8A5DA55FB0FFF5DA416074C0D28B2B55F'
    MacOS = '26AA75BC262BB10BF0805617B95569C3035C2C590A99F7DB55C7E9607B2685E0'
    Linux = '4CA3B7C6F2F67866B92622818B58233DC70367BE2F36B498EB0BDEAAA44B53F4'
}
$script:SevenZipHashCache = @{}
$script:TemplateVariableDefaultExtensions = @(
    'txt', 'md', 'markdown',
    'ps1', 'psm1', 'psd1', 'ps1xml', 'pssc', 'psrc',
    'json', 'jsonc', 'yaml', 'yml', 'xml', 'config', 'ini',
    'cs', 'csproj', 'vb', 'vbproj', 'sln', 'fs', 'fsproj',
    'js', 'cjs', 'mjs', 'ts', 'tsx', 'jsx', 'vue',
    'css', 'scss', 'sass', 'less',
    'html', 'htm', 'razor', 'cshtml',
    'py', 'rb', 'go', 'rs', 'swift', 'kt', 'kts', 'java',
    'c', 'h', 'cc', 'cpp', 'hpp',
    'sql', 'dbml',
    'sh', 'bash', 'zsh', 'fish', 'bat', 'cmd',
    'gradle', 'props', 'targets', 'nuspec',
    'pl', 'pm', 'lua', 'tex', 'toml'
)

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
    'Add-Template',
    'Get-Templates',
    'Use-Template',
    'Remove-Template',
    'Update-Template',
    'Export-Templates',
    'Import-Templates',
    'Get-TemplateStats',
    'Get-TemplaterConfigPath'
) -Alias @('templates', 'template', 'tpl', 'use-tpl', 'add-tpl', 'remove-tpl')
