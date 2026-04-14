# Templater.psm1
using namespace System.Collections.Generic

$commonModulePath = Join-Path $PSScriptRoot '..\Common\PowerShellMagic.Common.psd1'
Import-Module $commonModulePath -Force -Global -ErrorAction Stop

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
    Windows = '26CB6E9F56333682122FAFE79DBCDFD51E9F47CC7217DCCD29AC6FC33B5598CD'
    MacOS = '343EAE9CCBBD8F68320ADAAA3C87E0244CF39FAD0FBEC6B9D2CD3E5B0F8A5FBF'
    Linux = '23BABCAB045B78016E443F862363E4AB63C77D75BC715C0B3463F6134CBCF318'
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

