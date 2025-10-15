# Repository Guidelines

## Project Structure & Module Organization

- `Modules/QuickJump`, `Modules/Templater`, and
  `Modules/Unitea` house feature-specific cmdlets; keep exports scoped
  to their module manifests.
- Root scripts (`Setup-PowerShellMagic.ps1`, `Run-Tests.ps1`,
  `Format-PowerShell.ps1`) provide bootstrap, verification, and formatting
  entry points.
- `Scripts/` stores maintenance utilities, `hooks/` mirrors Git hook shims, and
  `Tests/` groups suites by concern (`Test-PowerShellMagic.ps1`,
  `Test-PortableDownloads.ps1`, `Test-Hash.ps1`).

## Build, Test, and Development Commands

- `.\Setup-Hooks.ps1` configures pre-commit or native Git hooks so local
  commits align with pipeline behavior.
- `.\Run-Tests.ps1 [-Test|-Format|-Downloads|-CI|-Fix]` orchestrates formatting
  checks, unit coverage, and mocked download validation.
- `pwsh -NoProfile -File .\Format-PowerShell.ps1 -Check` surfaces violations,
  while `-Fix` applies PSScriptAnalyzer-driven corrections.
- `.\Tests\Test-PowerShellMagic.ps1 -TestName QuickJump` targets a single
  module when iterating on a focused feature.

## Coding Style & Naming Conventions

- Follow `PSScriptAnalyzerSettings.psd1`: four-space indentation, same-line
  braces, PascalCase functions, camelCase private variables.
- Name cmdlets with approved verb-noun pairs and avoid aliases
  except ubiquitous shell shortcuts (`cd`, `ls`, `rm`).
- Prefer advanced functions with `[CmdletBinding()]`, explicit parameter
  attributes, and no unbounded `Write-Host` output.
- Run `Format-PowerShell.ps1` before commits; Markdown is linted through
  `markdownlint` in `.pre-commit-config.yaml`.

## Testing Guidelines

- `Run-Tests.ps1` sets `POWERSHELL_MAGIC_NON_INTERACTIVE=1` and performs AST
  validation, module import checks, and download mocks with zero external
  dependencies.
- Add new suites beside related code in `Tests/` and mirror the
  `Test-<Area>.ps1` naming pattern for discoverability.
- Mock network or filesystem effects so tests run offline and respect
  repository boundaries.
- Exercise new public commands via their module entry points to confirm exports
  and parameter binding stay intact.

## Commit & Pull Request Guidelines

- Use short, imperative subjects similar to `Fix security scan`; mixing
  Conventional-style prefixes (`chore: update dependencies`) is acceptable when
  scoped clearly.
- Run hooks or `.\Run-Tests.ps1 -CI` before pushing to guarantee formatting and
  functional checks pass.
- Pull requests should summarize the change, list affected modules or scripts,
  link issues, and include transcripts or screenshots for user-facing prompt
  updates.
- Reference new or altered scripts in `README.md` or `DEVELOPMENT.md` when
  behavior changes the documented workflow.

## Configuration & Security Notes

- `Setup-PowerShellMagic.ps1` writes only to `%LOCALAPPDATA%\PowerShellMagic`
  after explicit YES confirmations and validates portable downloads with SHA256
  hashes.
- Preserve the opt-in consent model for new installations, prompting before
  modifying PATH or profile files.
- Surface additional environment variables or configuration paths in companion
  docs and tests to keep automation predictable.
