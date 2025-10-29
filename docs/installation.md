# Installation Guide

PowerShell Magic supports Windows, macOS, and Linux. This guide expands on the
quick-start instructions from the README and collects platform-specific tips.

## Prerequisites

- PowerShell 7.0 or later (`pwsh --version` should report 7.x).
- Git (for cloning or applying updates).
- Internet access for optional dependency downloads (`fzf`, `7-Zip/7zz`, `eza`).

> ℹ️ Installing the optional tools is strongly recommended – the modules fall
> back gracefully when they are unavailable, but fuzzy pickers and template
> extraction are significantly better with them.

## Setup Script

From the repository root run:

```powershell
# Windows
.\Setup-PowerShellMagic.ps1

# macOS / Linux
pwsh ./Setup-PowerShellMagic.ps1
```

The script:

- Detects your operating system and preferred package managers.
- Requests consent before installing any dependency or editing profiles.
- Caches downloads in `%LOCALAPPDATA%\PowerShellMagic` (or the platform
  equivalent).
- Backs up your PowerShell profile before appending module imports.
- Stores setup logs under `%LOCALAPPDATA%\PowerShellMagic\logs`.

After the script finishes, restart your shell so the module autoloaders are
available in new sessions.

## Manual Module Import

If you prefer manual installation:

```powershell
Import-Module (Join-Path $PSScriptRoot 'Modules/QuickJump/QuickJump.psd1')
Import-Module (Join-Path $PSScriptRoot 'Modules/Templater/Templater.psd1')
Import-Module (Join-Path $PSScriptRoot 'Modules/Unitea/Unitea.psd1')
```

You can add those lines to your PowerShell profile (`$PROFILE`) after cloning.

## Verifying the Installation

```powershell
Get-Command -Module QuickJump,Templater,Unitea
```

You should see the exported cmdlets for each module. Try `Invoke-QuickJump`,
`Use-Template`, and `Open-UnityProject` to confirm everything loads without
errors.

## Keeping the Modules Updated

1. Pull the latest changes: `git pull origin main`.
2. Re-run the setup script with `-Fix` to update optional dependencies:

   ```powershell
   .\Setup-PowerShellMagic.ps1 -Fix
   ```

3. Restart your shell.

Additional update strategies are described in [docs/updating.md](updating.md).
