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
| `Get-QuickJumpCategories`  | List all available categories with path counts.       |
| `Remove-QuickJumpPath`     | Delete one or more saved paths.                       |
| `Open-QuickJumpRecent`     | Return (or jump to) the most recently used path.      |
| `Get-QuickJumpConfigPath`  | Resolve the path to the QuickJump configuration file. |

## Templater

| Command                   | Description                                              |
| ------------------------- | -------------------------------------------------------- |
| `Add-Template`            | Register a template directory or archive with an alias.  |
| `Use-Template`            | Deploy a template with variable substitution support.    |
| `Get-Templates`           | Enumerate available templates and metadata.              |
| `Update-Template`         | Update metadata for an existing template registration.   |
| `Export-Templates`        | Package template configurations into a portable archive. |
| `Import-Templates`        | Import template configurations from an archive.          |
| `Get-TemplateStats`       | Display template usage metrics and category information. |
| `Remove-Template`         | Remove a template registration (not the source files).   |
| `Get-TemplaterConfigPath` | Resolve the path to the Templater configuration file.    |

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
| `Get-UnityConfigPath`           | Resolve the path to the Unity projects configuration file.      |

## Common Utilities

The shared module (`PowerShellMagic.Common`) exports helper functions consumed
internally by the feature modules and available for scripts.

### Configuration Functions

| Function                | Description                                                         |
| ----------------------- | ------------------------------------------------------------------- |
| `Get-PSMagicConfigPath` | Resolve configuration paths under the cross-platform XDG directory. |

### Config Caching Functions

| Function                        | Description                                                     |
| ------------------------------- | --------------------------------------------------------------- |
| `Initialize-PSMagicConfigCache` | Initialize a configuration cache for a component.               |
| `Get-PSMagicCachedConfig`       | Retrieve a cached configuration, reloading if the file changed. |
| `Clear-PSMagicConfigCache`      | Clear the cache for a specific component.                       |
| `Remove-PSMagicConfigCache`     | Remove all cached configurations.                               |

### Compiled Regex Functions

| Function                          | Description                                                 |
| --------------------------------- | ----------------------------------------------------------- |
| `Get-PSMagicCompiledRegex`        | Get or create a compiled regex pattern for performance.     |
| `Get-PSMagicCommonRegex`          | Retrieve commonly used regex patterns (paths, GUIDs, etc.). |
| `Clear-PSMagicCompiledRegexCache` | Clear the compiled regex cache.                             |
| `Test-PSMagicRegexPerformance`    | Test and compare regex performance.                         |

### Help System Functions

| Function                       | Description                                    |
| ------------------------------ | ---------------------------------------------- |
| `Test-PSMagicHelpRequest`      | Check if a parameter indicates a help request. |
| `Show-PSMagicHelp`             | Display formatted help for a command.          |
| `Add-PSMagicArgumentCompleter` | Register argument completers for commands.     |
| `Initialize-PSMagicHelpSystem` | Initialize the help system for a module.       |

### Utility Functions

| Function                     | Description                                             |
| ---------------------------- | ------------------------------------------------------- |
| `Test-FzfAvailable`          | Detect whether `fzf` is available on the system path.   |
| `Test-PSMagicNonInteractive` | Returns `$true` when prompts should be suppressed.      |
| `Copy-PSMagicHashtable`      | Deep-copy a hashtable (useful for config manipulation). |

## Command Aliases

Each module exports short aliases for common commands:

### QuickJump Aliases

| Alias      | Command                    |
| ---------- | -------------------------- |
| `qj`       | `Invoke-QuickJump`         |
| `qja`      | `Add-QuickJumpPath`        |
| `qjl`      | `Get-QuickJumpPaths`       |
| `qjr`      | `Remove-QuickJumpPath`     |
| `qjc`      | `Invoke-QuickJumpCategory` |
| `qjrecent` | `Open-QuickJumpRecent`     |

### Templater Aliases

| Alias        | Command           |
| ------------ | ----------------- |
| `templates`  | `Get-Templates`   |
| `template`   | `Get-Templates`   |
| `tpl`        | `Get-Templates`   |
| `add-tpl`    | `Add-Template`    |
| `use-tpl`    | `Use-Template`    |
| `remove-tpl` | `Remove-Template` |

### Unitea Aliases

| Alias          | Command                      |
| -------------- | ---------------------------- |
| `unity`        | `Open-UnityProject`          |
| `unity-add`    | `Add-UnityProject`           |
| `unity-update` | `Update-UnityProject`        |
| `unity-check`  | `Get-UnityProjectSyncStatus` |
| `unity-list`   | `Get-UnityProjects`          |
| `unity-remove` | `Remove-UnityProject`        |
| `unity-recent` | `Open-RecentUnityProject`    |
| `unity-config` | `Get-UnityConfigPath`        |

For deeper usage examples see [examples.md](examples.md).
