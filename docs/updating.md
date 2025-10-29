# Updating PowerShell Magic

Stay current to benefit from new features, bug fixes, and security patches.

## Pull the Latest Changes

```powershell
git pull origin main
```

If you are working from a fork, pull from your fork’s default branch or rebase
onto the upstream repository.

## Refresh Optional Dependencies

Run the setup helper with the `-Fix` switch to re-check portable downloads and
profile entries:

```powershell
.\Setup-PowerShellMagic.ps1 -Fix
```

This refreshes cached hashes, reinstalls missing tools, and ensures profiles
import the latest module version.

## Update Modules in the Current Session

```powershell
Remove-Module QuickJump,Templater,Unitea -ErrorAction SilentlyContinue
Import-Module (Join-Path $PSScriptRoot 'Modules/QuickJump/QuickJump.psd1')
Import-Module (Join-Path $PSScriptRoot 'Modules/Templater/Templater.psd1')
Import-Module (Join-Path $PSScriptRoot 'Modules/Unitea/Unitea.psd1')
```

## Verify After Updating

```powershell
pwsh -NoProfile -File .\Run-Tests.ps1 -CI
pwsh -NoProfile -File .\Scripts\Run-PreCommit.ps1
```

Testing immediately after updating avoids surprises when pushing changes or
cutting releases.

## Rolling Back

Use Git to return to a known-good revision:

```powershell
git checkout <commit-or-tag>
.\Setup-PowerShellMagic.ps1 -Fix
```

If you pinned a release via the gallery packaging workflow, reinstalling that
specific version also rolls back updates.

Need help? Open an issue on
[GitHub](https://github.com/wallstop/jason-storey-powershell-magic/issues).
