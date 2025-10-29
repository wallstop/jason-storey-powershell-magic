# Examples & Use Cases

Need inspiration for how PowerShell Magic can streamline your day? These
scenarios highlight common workflows across the three modules.

## QuickJump

### Jump to Project Roots

```powershell
Add-QuickJumpPath -Path 'C:\Repos\P0' -Alias p0 -Category repos
Invoke-QuickJump p0
```

### Navigate in CI Scripts

```powershell
$env:POWERSHELL_MAGIC_NON_INTERACTIVE = '1'
$path = Invoke-QuickJump -Alias reports -Path
Set-Location $path
```

## Templater

### Spin Up a REST API Skeleton

```powershell
Use-Template -Name 'dotnet-api' -Destination 'C:\Work\Contoso.Api' `
    -Variables @{ ProjectName = 'Contoso.Api'; Namespace = 'Contoso.Api' } `
    -Verbose
```

### Share Templates with Teammates

```powershell
Export-Templates -Name 'react-spa','dotnet-api' -OutputPath '.\dist\templates.zip'
```

## Unitea

### Launch the Latest Project

```powershell
unity mygame -AutoUpdate
```

### Audit Metadata Drift

```powershell
Get-UnityProjectSyncStatus -IncludeInSync | Format-Table Alias,Status,StoredVersion,ActualVersion
```

### Resume the Last Scene

```powershell
Set-Location (Open-RecentUnityProject -Path)
```

For more detailed walkthroughs see the dedicated guides:

- [QuickJump Guide](quickjump-guide.md)
- [Templater Guide](templater-guide.md)
- [Unitea Guide](unitea-guide.md)
