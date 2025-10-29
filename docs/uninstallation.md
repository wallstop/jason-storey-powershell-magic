# Uninstallation

PowerShell Magic removes cleanly without touching the rest of your environment.

## Remove Module Imports

If you previously ran the setup helper, it appended imports to your PowerShell
profile. Remove those lines manually or re-run the helper with `-Fix` and answer
`n` to remove support modules.

```powershell
notepad $PROFILE  # or your editor of choice
```

Delete the block that references `QuickJump`, `Templater`, and `Unitea`.

## Delete Configuration Data

```powershell
Remove-Item -Recurse -Force (Get-PSMagicConfigPath -Component 'quickjump' -ReturnDirectory)
Remove-Item -Recurse -Force (Get-PSMagicConfigPath -Component 'templater' -ReturnDirectory)
Remove-Item -Recurse -Force (Get-PSMagicConfigPath -Component 'unity' -ReturnDirectory)
```

Alternatively, delete the entire `%LOCALAPPDATA%\PowerShellMagic` (or
`$XDG_CONFIG_HOME/PowerShellMagic`) directory to remove logs and cached
downloads as well.

## Optionally Remove the Repository

```powershell
Set-Location ..
Remove-Item -Recurse -Force .\powershell-magic
```

## Reinstall Later

You can reinstall at any time by cloning the repository again and following the
[installation guide](installation.md).
