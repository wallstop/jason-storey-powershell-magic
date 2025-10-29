# Command Reference

This page lists the primary cmdlets exported by each PowerShell Magic module.
All commands include comment-based help (`Get-Help <Command> -Detailed`) and
support `-WhatIf`/`-Confirm` where appropriate.

## QuickJump

| Command                    | Description                                           |
| -------------------------- | ----------------------------------------------------- |
| `Invoke-QuickJump`         | Jump to a saved path by alias or fuzzy selection.     |
| `Invoke-QuickJumpCategory` | Browse saved paths grouped by category.               |
| `Add-QuickJumpPath`        | Register a directory with alias, category, and notes. |
| `Get-QuickJumpPaths`       | List saved paths, optionally filtered or as objects.  |
| `Remove-QuickJumpPath`     | Delete one or more saved paths.                       |
| `Open-QuickJumpRecent`     | Return (or jump to) the most recently used path.      |

## Templater

| Command             | Description                                           |
| ------------------- | ----------------------------------------------------- |
| `Use-Template`      | Deploy a template with variable substitution support. |
| `Save-Template`     | Capture a directory tree as a reusable template.      |
| `Get-Templates`     | Enumerate available templates and metadata.           |
| `Update-Template`   | Sync a template with changes made to a deployment.    |
| `Export-Templates`  | Package templates into a portable archive.            |
| `Import-Templates`  | Import templates from an archive.                     |
| `Get-TemplateStats` | Display template usage metrics and integrity hashes.  |
| `Remove-Template`   | Delete one or more templates.                         |

## Unitea

| Command                         | Description                                                     |
| ------------------------------- | --------------------------------------------------------------- |
| `Add-UnityProject`              | Register a Unity project directory under an alias.              |
| `Get-UnityProjects`             | List saved Unity projects with metadata.                        |
| `Remove-UnityProject`           | Remove saved projects (interactive or scripted).                |
| `Open-UnityProject` (`unity`)   | Launch or inspect a Unity project with version drift detection. |
| `Open-RecentUnityProject`       | Resume the most recently opened project.                        |
| `Get-UnityProjectSyncStatus`    | Audit saved metadata for version/path deviations.               |
| `Update-UnityProject`           | Refresh stored metadata from `ProjectVersion.txt`.              |
| `Invoke-UniteaStartupSyncCheck` | Perform the startup drift audit (usually called automatically). |

## Common Utilities

The shared module exports helper functions consumed internally by the feature
modules. For scripts, the most useful are:

| Function                     | Description                                                         |
| ---------------------------- | ------------------------------------------------------------------- |
| `Get-PSMagicConfigPath`      | Resolve configuration paths under the cross-platform XDG directory. |
| `Test-FzfAvailable`          | Detect whether `fzf` is available on the system path.               |
| `Test-PSMagicNonInteractive` | Returns `$true` when prompts should be suppressed.                  |

For deeper usage examples see [docs/examples.md](examples.md).
