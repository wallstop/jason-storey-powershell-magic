# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- In-memory configuration caching with automatic invalidation for faster repeat
  operations
- Compiled regex patterns for improved performance in path matching

### Fixed

- Concurrent config updates no longer lose data when multiple processes write
  simultaneously
- QuickJump now uses atomic read-modify-write operations to prevent race
  conditions
- Test diagnostic output now correctly reports job result counts by filtering
  out non-result objects from `Receive-Job` output

## [2.2.0] - 2024-12-15

### Added

- Common module with shared utilities (`Get-PSMagicConfigPath`,
  `Test-FzfAvailable`, `Test-PSMagicNonInteractive`)
- Public/Private folder structure for cleaner module organization

### Changed

- Improved path handling with `-LiteralPath` for better special character
  support
- More robust path validation for downloads and file operations

## [2.1.0] - 2024-11-20

### Added

- `unity-update` command to manually sync Unity project metadata after version
  changes
- `unity-check` command to detect when saved project versions drift from actual
  versions
- `-AutoUpdate` flag on `unity` command to automatically sync metadata on launch
- Automatic metadata sync at shell startup (opt-in via
  `POWERSHELL_MAGIC_UNITEA_AUTOUPDATE_STARTUP` environment variable)

## [2.0.0] - 2024-10-15

### Added

- True cross-platform support for Windows, macOS, and Linux
- Platform-specific Unity Hub detection (macOS `/Applications`, Linux paths)
- Platform-specific 7-Zip detection (`7zz`, `7z`, `7za`, `7zzs`)
- XDG config directory support on Unix systems
- Configuration caching for faster access with automatic invalidation
- Automatic config backup and corruption recovery with timestamped backups
- Hash-based verification for 7-Zip executables

### Changed

- Better error messages with recovery suggestions
- QuickJump now returns structured records with sorting options
- Improved path display with truncation for long paths

## [1.0.1] - 2024-09-01

Initial public release.

### Added

- **QuickJump** - Fast directory navigation with saved aliases

  - `qj` - Jump to saved path or show interactive picker
  - `qja` - Save current directory with an alias
  - `qjl` - List all saved paths
  - `qjr` - Remove a saved path
  - `qjc` - Navigate by category
  - `qjrecent` - Jump to most recently used path
  - Category organization and usage tracking
  - Fuzzy finding with fzf integration
  - Tab completion for aliases and categories

- **Templater** - Project template management

  - `templates` - Browse and deploy templates interactively
  - `add-tpl` - Register templates from ZIP, 7Z, RAR, TAR, or folders
  - `use-tpl` - Deploy templates with `{{token}}` substitution
  - `remove-tpl` - Remove registered templates
  - Category and tag organization
  - Template preview before deployment
  - Import/export for backup and sharing

- **Unitea** - Unity project management

  - `unity` - Open Unity project or show interactive picker
  - `unity-add` - Register a Unity project
  - `unity-list` - List saved Unity projects
  - `unity-recent` - Open most recently used project
  - `unity-remove` - Remove a saved project
  - Automatic Unity version detection via Unity Hub
  - Recent project tracking

- Interactive setup script with automatic tool installation
- Automatic profile backup before modifications

[Unreleased]:
  https://github.com/wallstop/jason-storey-powershell-magic/compare/v2.2.0...HEAD
[2.2.0]:
  https://github.com/wallstop/jason-storey-powershell-magic/compare/v2.1.0...v2.2.0
[2.1.0]:
  https://github.com/wallstop/jason-storey-powershell-magic/compare/v2.0.0...v2.1.0
[2.0.0]:
  https://github.com/wallstop/jason-storey-powershell-magic/compare/v1.0.1...v2.0.0
[1.0.1]:
  https://github.com/wallstop/jason-storey-powershell-magic/releases/tag/v1.0.1
