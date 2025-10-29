# Security Notes

PowerShell Magic is designed to respect user consent and keep your environment
safe. This document summarises the safeguards in place and how to report issues.

## Setup Script Protections

- **Explicit Consent** – every external download or profile modification
  requires a `Y` confirmation (or `-Fix`/`-Yes` for unattended runs).
- **Hash Verification** – portable downloads (fzf, 7-Zip/7zz, eza) are checked
  against recorded SHA256 hashes before extraction.
- **Backups** – the setup helper backs up your existing PowerShell profile
  before appending module imports.
- **Logging** – structured logs are written to
  `%LOCALAPPDATA%\PowerShellMagic\logs` (or the platform equivalent). Retention
  is configurable via `POWERSHELL_MAGIC_SETUP_LOG_RETENTION`.

## Module Safety

- All destructive cmdlets (`Remove-QuickJumpPath`, `Remove-UnityProject`,
  `Remove-Template`) support `-WhatIf` and `-Confirm`.
- QuickJump and Templater fall back to deterministic menus when `fzf` is not
  present instead of failing with errors.
- Unitea validates Unity project paths before launching to avoid executing
  unexpected binaries.

## Handling Sensitive Paths

- Configuration data is stored in the XDG config folder; access control follows
  your operating system defaults.
- Templates are copied locally – no remote uploads occur.
- If you use PowerShell Secret Management or other vaults alongside PowerShell
  Magic, treat exported templates and logs as sensitive artifacts.

## Reporting a Security Issue

- Email: [power-shell-magic@proton.me](mailto:power-shell-magic@proton.me)
- Alternatively open a private GitHub issue.

We aim to acknowledge reports within two business days and keep you informed as
the fix progresses.
