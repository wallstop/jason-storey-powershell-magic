# Configuration

PowerShell Magic stores its settings under the cross-platform XDG hierarchy so
paths are predictable on every operating system.

## Base Paths

| Platform | Base Directory                                                    |
| -------- | ----------------------------------------------------------------- |
| Windows  | `%LOCALAPPDATA%\PowerShellMagic`                                  |
| macOS    | `$HOME/Library/Application Support/PowerShellMagic`               |
| Linux    | `$XDG_CONFIG_HOME/PowerShellMagic` or `~/.config/PowerShellMagic` |

Set the environment variable `XDG_CONFIG_HOME` to override the base directory at
runtime.

## Module-Specific Files

| Module    | File                       | Purpose                           |
| --------- | -------------------------- | --------------------------------- |
| QuickJump | `quickjump/paths.json`     | Saved path aliases and metadata.  |
| Templater | `templater/templates.json` | Template registry and statistics. |
| Unitea    | `unity/projects.json`      | Unity project metadata cache.     |
| Setup     | `logs/setup-*.log`         | Structured setup logs.            |
| Setup     | `downloads/`               | Cached portable downloads.        |

## Environment Variables

| Variable                                        | Effect                                                     |
| ----------------------------------------------- | ---------------------------------------------------------- |
| `POWERSHELL_MAGIC_NON_INTERACTIVE`              | Suppresses interactive prompts across all modules.         |
| `POWERSHELL_MAGIC_UNITEA_DISABLE_STARTUP_CHECK` | Skips the automatic Unity metadata audit on shell startup. |
| `POWERSHELL_MAGIC_UNITEA_AUTOUPDATE_STARTUP`    | Auto-updates Unity metadata during the startup audit.      |
| `POWERSHELL_MAGIC_SETUP_LOG_PATH`               | Override the default setup log directory.                  |
| `POWERSHELL_MAGIC_SETUP_LOG_RETENTION`          | Configure how many setup logs are retained.                |

## Editing Configuration Safely

- Always close PowerShell sessions before editing JSON files to avoid losing
  in-memory updates.
- Files are automatically backed up with a timestamp suffix before they are
  reset (see Unitea tests for examples).
- Use the provided cmdlets (`Add-QuickJumpPath`, `Save-Template`,
  `Add-UnityProject`) instead of editing JSON directly whenever possible.

## Resetting State

To reset module data without deleting the repository:

```powershell
Remove-Item -Path (Get-PSMagicConfigPath -Component 'quickjump') -Recurse
Remove-Item -Path (Get-PSMagicConfigPath -Component 'templater') -Recurse
Remove-Item -Path (Get-PSMagicConfigPath -Component 'unity') -Recurse
```

Re-run the relevant commands to recreate the stores. Logs and cached downloads
can be cleared by deleting the `logs` and `downloads` subfolders.
