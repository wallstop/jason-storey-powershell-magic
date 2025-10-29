# Unitea Guide

Unitea keeps Unity projects organised, tracks their editor versions, and
launches them through Unity Hub or the local editor.

## Core Commands

- **Add-UnityProject** – register the current directory (or a provided path)
  with an alias.
- **Open-UnityProject / unity** – launch a project with Unity Hub integration,
  automatic version warnings, and optional auto-update.
- **Get-UnityProjects** – list saved projects, optionally sorted by recent
  usage.
- **Get-UnityProjectSyncStatus / unity-check** – detect version drift, missing
  paths, and metadata issues.
- **Update-UnityProject / unity-update** – refresh stored metadata from
  `ProjectVersion.txt`.
- **Open-RecentUnityProject / unity-recent** – resume the last project you
  opened.

See the Quick Reference in [docs/command-reference.md](command-reference.md) for
aliases and parameter summaries.

## Configuration Locations

| Platform | Path                                                            |
| -------- | --------------------------------------------------------------- |
| Windows  | `%LOCALAPPDATA%\PowerShellMagic\unity\projects.json`            |
| macOS    | `$HOME/Library/Application Support/PowerShellMagic/unity/...`   |
| Linux    | `$XDG_CONFIG_HOME/PowerShellMagic/unity/...` or `~/.config/...` |

You can override the base directory by setting `XDG_CONFIG_HOME`.

## Startup Sync Check

When a new shell session starts, Unitea:

1. Loads cached metadata.
2. Compares each entry against the on-disk `ProjectVersion.txt`.
3. Emits warnings for mismatches, missing paths, or invalid projects.
4. Automatically updates metadata when
   `POWERSHELL_MAGIC_UNITEA_AUTOUPDATE_STARTUP=1`.

Disable the startup check with `POWERSHELL_MAGIC_UNITEA_DISABLE_STARTUP_CHECK=1`
(handy for CI).

## Launch Options

```powershell
Open-UnityProject -Alias game
Open-UnityProject -ProjectPath 'D:\Games\SpaceShooter' -AutoUpdate
Open-UnityProject -Alias game -UnityHubPath 'C:\Program Files\Unity Hub\Unity Hub.exe'
```

In non-interactive environments (`POWERSHELL_MAGIC_NON_INTERACTIVE=1`) Unitea
skips launching Unity Hub but still updates metadata.

## Troubleshooting

- `Get-UnityProjectSyncStatus -IncludeInSync` prints a full audit.
- Use `-Verbose` on `Open-UnityProject` to see resolved Unity executables.
- Corrupt metadata files are automatically backed up and reset; see the test
  coverage under `Test-Unitea` for details.

Visit [docs/troubleshooting.md](troubleshooting.md) for additional scenarios.
