# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- In-memory configuration caching with automatic invalidation for faster repeat
  operations
- Compiled regex patterns for improved performance in path matching
- Universal `--help` flag support for all commands

### Fixed

- Concurrent config updates no longer lose data when multiple processes write
  simultaneously
- QuickJump now uses atomic read-modify-write operations to prevent race
  conditions

## [1.1.0] - 2025-10-29

### Added

- `unity-update` command to manually sync Unity project metadata after version
  changes
- `unity-check` command to detect when saved project versions drift from actual
  versions
- Automatic Unity metadata sync at shell startup (opt-in via
  `POWERSHELL_MAGIC_UNITEA_AUTOUPDATE_STARTUP` environment variable)
- Build automation for PowerShell Gallery packaging
- Publishing guide with gallery release instructions

### Changed

- Modules now use Public/Private folder structure for cleaner organization
- Setup script detects platform-specific package managers (winget, Scoop,
  Homebrew, apt, dnf, pacman)
- Enhanced transparency during setup with detailed progress messages

## [1.0.0] - 2025-10-01

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

- Cross-platform support for Windows, macOS, and Linux
- Interactive setup script with automatic tool installation
- Automatic profile backup before modifications

[Unreleased]: https://github.com/wallstop/jason-storey-powershell-magic/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/wallstop/jason-storey-powershell-magic/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/wallstop/jason-storey-powershell-magic/releases/tag/v1.0.0
