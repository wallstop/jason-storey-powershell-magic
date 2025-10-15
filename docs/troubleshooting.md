# Troubleshooting Guide

Complete troubleshooting guide for PowerShell Magic modules.

---

## Table of Contents

- [General Issues](#general-issues)
- [QuickJump Issues](#quickjump-issues)
- [Templater Issues](#templater-issues)
- [Unitea Issues](#unitea-issues)
- [Installation Issues](#installation-issues)
- [Dependency Issues](#dependency-issues)
- [Configuration Issues](#configuration-issues)
- [Performance Issues](#performance-issues)

---

## General Issues

### Commands Not Recognized

**Symptom:** `qj : The term 'qj' is not recognized as the name of a cmdlet`

**Causes & Solutions:**

1. **Module not imported**

   ```powershell
   # Check if modules are loaded
   Get-Module QuickJump, Templater, Unitea

   # Manually import if needed
   Import-Module "C:\Path\To\Modules\QuickJump"
   Import-Module "C:\Path\To\Modules\Templater"
   Import-Module "C:\Path\To\Modules\Unitea"
   ```

2. **Profile not loaded**

   ```powershell
   # Check if profile exists
   Test-Path $PROFILE

   # View profile content
   Get-Content $PROFILE

   # Should contain lines like:
   # Import-Module "...\Modules\QuickJump"
   ```

3. **PowerShell hasn't been restarted**
   - Close and reopen PowerShell after running setup

4. **Profile doesn't auto-load**

   ```powershell
   # Manually load profile in current session
   . $PROFILE
   ```

**Fix:**

```powershell
# Re-run setup
.\Setup-PowerShellMagic.ps1 -Force

# Restart PowerShell
```

---

### Module Import Errors

**Symptom:** Errors when importing modules

**Common Causes:**

1. **Execution Policy Restricted**

   ```powershell
   # Check current policy
   Get-ExecutionPolicy

   # If "Restricted", change it
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

2. **Path issues**

   ```powershell
   # Verify module paths exist
   Test-Path "C:\Path\To\Modules\QuickJump\QuickJump.psd1"
   Test-Path "C:\Path\To\Modules\Templater\Templater.psd1"
   Test-Path "C:\Path\To\Modules\Unitea\Unitea.psd1"
   ```

3. **Corrupted module files**

   ```powershell
   # Re-download or pull latest from git
   git pull origin main
   ```

---

## QuickJump Issues

### "Path not found" after saving

**Symptom:** Saved a path with `qja`, but `qj` says it doesn't exist

**Solution:**

```powershell
# Verify path was saved
qjl

# If not visible, check config file
code (Get-QuickJumpConfigPath)

# Check for corruption
Get-Content (Get-QuickJumpConfigPath) | ConvertFrom-Json

# If corrupted, restore from backup
$backups = Get-ChildItem "$(Get-QuickJumpConfigPath).backup.*" |
    Sort-Object LastWriteTime -Descending
Copy-Item $backups[0].FullName (Get-QuickJumpConfigPath)
```

### fzf not working

**Symptom:** `qj` shows error "fzf is not available"

**Solution:**

```powershell
# Install fzf
scoop install fzf
# OR
choco install fzf
# OR
winget install junegunn.fzf

# Verify installation
fzf --version

# Restart PowerShell

# If still not working, check PATH
$env:PATH -split ';' | Select-String fzf
```

**Workaround without fzf:**

```powershell
# Use aliases directly
qj myproject

# List and navigate
qjl
# Then manually: cd <path>
```

### Tab completion not working

**Symptom:** Pressing Tab after `qj` doesn't show aliases

**Solution:**

```powershell
# Re-import module
Import-Module QuickJump -Force

# Verify argument completers are registered
Get-ArgumentCompleter -CommandName Invoke-QuickJump

# If still not working, restart PowerShell
```

### Path exists but can't navigate

**Symptom:** `qj mypath` runs but doesn't change directory

**Possible Causes:**

1. **Directory was moved or deleted**

   ```powershell
   # Check if directory still exists
   Test-Path (qj mypath -Path)

   # Update to new location
   cd "C:\NewLocation"
   qja mypath -Force
   ```

2. **Permission issues**

   ```powershell
   # Test if you can navigate manually
   cd (qj mypath -Path)

   # Check permissions
   (Get-Acl (qj mypath -Path)).Access
   ```

### Config file corruption

**Symptom:** JSON parsing errors, commands fail

**Solution:**

```powershell
# QuickJump auto-creates backups
Get-ChildItem "$(Get-QuickJumpConfigPath).backup.*" |
    Sort-Object LastWriteTime -Descending

# Restore from backup
$latest = Get-ChildItem "$(Get-QuickJumpConfigPath).backup.*" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
Copy-Item $latest.FullName (Get-QuickJumpConfigPath) -Force

# Restart PowerShell
```

---

## Templater Issues

### 7-Zip not found

**Symptom:** `use-tpl` fails with "7-Zip not available" for .7z, .rar files

**Solution:**

#### Install 7-Zip / 7zz

- **Windows:** `scoop install 7zip`, `choco install 7zip`, or
  `winget install 7zip.7zip`
- **macOS:** `brew install p7zip`
- **Linux:** `sudo apt install p7zip-full`, `sudo dnf install p7zip`, or
  `sudo pacman -S p7zip`

> Verify manual downloads by running
> `pwsh ./Setup-PowerShellMagic.ps1 -ListPortableDownloads` to view the official
> URLs and SHA256 hashes, then confirm with `Get-FileHash` or `shasum -a 256`
> before installing.

#### Verify installation

```powershell
# Windows
7z --help

# macOS / Linux
7zz --help
```

#### Point Templater to your 7-Zip binary if needed

```powershell
# Windows (default managed install)
$env:POWERSHELLMAGIC_7ZIP_PATH = "$env:LOCALAPPDATA\PowerShellMagic\bin\7z.exe"

# macOS / Linux (default managed install)
$env:POWERSHELLMAGIC_7ZIP_PATH = "$HOME/.local/share/powershell-magic/bin/7zz"

# Restart PowerShell after setting the path
```

**Workaround:**

- Use .zip files instead (built-in support, no 7-Zip needed)
- Use folder-based templates instead of archives

### Template extraction fails

**Symptom:** Archive extracts but with errors

**Common Causes:**

1. **Destination not empty**

   ```powershell
   # Use -Force to overwrite
   use-tpl mytemplate -Force
   ```

2. **Path too long (Windows limitation)**

   ```powershell
   # Use shorter destination path
   use-tpl mytemplate -DestinationPath "C:\Temp"
   ```

3. **Corrupted archive**

   ```powershell
   # Verify archive
   7z t "path\to\template.7z"

   # Re-download or recreate template
   ```

4. **Insufficient permissions**

   ```powershell
   # Check permissions on destination
   (Get-Acl "C:\Destination").Access

   # Use different destination
   use-tpl mytemplate -DestinationPath "$env:USERPROFILE\Projects"
   ```

### Template not found after adding

**Symptom:** Added template with `add-tpl`, but `templates` doesn't show it

**Solution:**

```powershell
# Verify template was added
templates

# Check config file
code (Get-TemplaterConfigPath)

# Check for corruption
Get-Content (Get-TemplaterConfigPath) | ConvertFrom-Json

# Re-add if needed
add-tpl mytemplate "C:\Path\To\Template" -Description "My Template" -Force
```

### Folder template copies slowly

**Symptom:** Folder templates take a long time to copy

**Causes:**

- Large number of files
- Large file sizes
- Network paths

**Solutions:**

- Use archive templates instead (faster extraction)
- Exclude unnecessary files before creating template
- Use local paths instead of network paths

### Preview not showing

**Symptom:** Template preview doesn't appear in interactive mode

**Causes:**

1. **PreviewFile not specified**

   ```powershell
   # Add preview file
   Update-Template -Alias mytemplate -PreviewFile "README.md"
   ```

2. **PreviewFile doesn't exist**

   ```powershell
   # Verify preview file exists
   $template = (Get-TemplateData)["mytemplate"]
   Test-Path (Join-Path (Split-Path $template.Path) $template.PreviewFile)
   ```

3. **Preview file is binary**
   - Previews work best with text files (README.md, etc.)

---

## Unitea Issues

### Unity Hub not found

**Symptom:** `unity` command can't find Unity Hub

**Solution:**

```powershell
# Verify Unity Hub is installed
Test-Path "C:\Program Files\Unity Hub\Unity Hub.exe"

# If installed elsewhere, Unitea should auto-detect
# If not, check default locations:
# - C:\Program Files\Unity Hub\Unity Hub.exe
# - C:\Program Files (x86)\Unity Hub\Unity Hub.exe

# Manual workaround: Open project manually
explorer (unity myproject -Path)
```

### Project not detected as Unity project

**Symptom:** Can't add current directory as Unity project

**Causes:**

- Not a Unity project (missing Assets folder, ProjectSettings folder)
- In wrong subdirectory

**Solution:**

```powershell
# Verify Unity project structure
Test-Path ".\Assets"
Test-Path ".\ProjectSettings"

# Navigate to project root
cd ..
unity-add myproject
```

### Wrong Unity version opens

**Symptom:** Project opens in wrong Unity Editor version

**Causes:**

- Unity Hub version detection issues
- Multiple Unity versions installed

**Workaround:**

- Open Unity Hub manually
- Open project from Hub (ensures correct version)
- Or navigate to project and double-click .sln file

---

## Installation Issues

### Setup script won't run

**Symptom:** `.\Setup-PowerShellMagic.ps1` shows error or won't execute

**Solutions:**

1. **Execution Policy**

   ```powershell
   # Check policy
   Get-ExecutionPolicy

   # If "Restricted"
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

   # Or bypass just for this script
   PowerShell -ExecutionPolicy Bypass -File .\Setup-PowerShellMagic.ps1
   ```

2. **Path issues**

   ```powershell
   # Ensure you're in the right directory
   Get-Location

   # Should be in powershell-magic directory
   cd C:\Path\To\powershell-magic
   ```

3. **File blocked**

   ```powershell
   # Unblock the file
   Unblock-File .\Setup-PowerShellMagic.ps1
   ```

### Profile backup failed

**Symptom:** Setup script warns about profile backup failure

**Solution:**

```powershell
# Manually backup profile
Copy-Item $PROFILE "$PROFILE.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"

# Then re-run setup
.\Setup-PowerShellMagic.ps1
```

### Dependencies won't install

**Symptom:** Setup fails to install fzf, 7-Zip, or eza

**Solutions:**

1. **No package manager**
   - Install Scoop: <https://scoop.sh/>
   - Or install tools manually:
     - fzf: <https://github.com/junegunn/fzf>
     - 7-Zip: <https://www.7-zip.org/>
     - eza: <https://github.com/eza-community/eza>

2. **Network issues**
   - Check internet connection
   - Retry installation
   - Use different package manager

3. **Permission issues**
   - Run PowerShell as Administrator (for Chocolatey)
   - Or use Scoop (no admin needed)

---

## Dependency Issues

### fzf issues

**Installation:**

```powershell
# Scoop (recommended)
scoop install fzf

# Chocolatey
choco install fzf

# Winget
winget install junegunn.fzf

# Manual
# Download from: https://github.com/junegunn/fzf/releases
# Extract to a folder in PATH
```

**Verification:**

```powershell
fzf --version
# Should show version number
```

**PATH issues:**

```powershell
# Check if fzf is in PATH
$env:PATH -split ';' | Select-String fzf

# Add to PATH if needed (example)
$env:PATH += ";C:\Path\To\fzf"

# Make permanent (add to profile)
Add-Content $PROFILE '$env:PATH += ";C:\Path\To\fzf"'
```

### 7-Zip issues

#### Installation

- **Windows:** `scoop install 7zip`, `choco install 7zip`, or
  `winget install 7zip.7zip`
- **macOS:** `brew install p7zip`
- **Linux:** `sudo apt install p7zip-full`, `sudo dnf install p7zip`, or
  `sudo pacman -S p7zip`
- **Manual:** download direct binaries from <https://www.7-zip.org/> (ships
  `7z.exe` on Windows and `7zz` elsewhere)

> Verify manual downloads by running
> `pwsh ./Setup-PowerShellMagic.ps1 -ListPortableDownloads` to view the official
> URLs and SHA256 hashes, then confirm with `Get-FileHash` or `shasum -a 256`
> before installing.

#### Verification

```powershell
# Windows
7z --help

# macOS / Linux
7zz --help
```

#### Custom path

```powershell
# Point to a custom install location if auto-detection fails
# Windows example
$env:POWERSHELLMAGIC_7ZIP_PATH = "C:\Custom\Path\7z.exe"

# macOS/Linux managed install
$env:POWERSHELLMAGIC_7ZIP_PATH = "$HOME/.local/share/powershell-magic/bin/7zz"
```

---

## Configuration Issues

### Config files missing

**Symptom:** Config files not found or missing

**Solution:**

```powershell
# Config files are auto-created on first use
# Force creation by running a command:
qja test
qjr -Alias test

# Check config locations:
Get-QuickJumpConfigPath
Get-TemplaterConfigPath
```

### Config file corruption (all modules)

All modules auto-create backups before overwriting.

**Recovery:**

```powershell
# For QuickJump
$backups = Get-ChildItem "$(Get-QuickJumpConfigPath).backup.*" |
    Sort-Object LastWriteTime -Descending
Copy-Item $backups[0].FullName (Get-QuickJumpConfigPath) -Force

# For Templater
$backups = Get-ChildItem "$(Get-TemplaterConfigPath).backup.*" |
    Sort-Object LastWriteTime -Descending
Copy-Item $backups[0].FullName (Get-TemplaterConfigPath) -Force
```

### Config directory permissions

**Symptom:** Can't write to config directory

**Solution:**

```powershell
# Check permissions
$configDir = Get-QuickJumpConfigPath -ReturnDirectory
(Get-Acl $configDir).Access

# If no access, use alternate location
$env:XDG_CONFIG_HOME = "C:\AlternateLocation"

# Restart PowerShell
```

---

## Performance Issues

### Slow command execution

**QuickJump slow:**

- Large number of saved paths
- Solution: Clean up unused paths

**Templater slow:**

- Large templates (many files)
- Solution: Use archives instead of folders

**Interactive mode (fzf) slow:**

- Very large lists
- Solution: Use categories to filter

### High memory usage

**Causes:**

- Very large config files
- Many saved paths/templates

**Solutions:**

```powershell
# Clean up unused entries
qjl | Where-Object { $_.UseCount -eq 0 }
# Remove unused ones

# For templates
templates | Where-Object { $_.UseCount -eq 0 }
# Remove unused ones
```

---

## Still Having Issues?

### Diagnostic Information

Run these commands to gather diagnostic info:

```powershell
# PowerShell version
$PSVersionTable

# Modules loaded
Get-Module QuickJump, Templater, Unitea

# Config file paths
Get-QuickJumpConfigPath
Get-TemplaterConfigPath

# Dependencies
fzf --version
7z
eza --version

# Execution policy
Get-ExecutionPolicy -List

# Profile location
$PROFILE

# Profile content
Get-Content $PROFILE
```

### Getting Help

1. **Check documentation:**
   - [Main README](../README.md)
   - [QuickJump Guide](quickjump-guide.md)
   - [Templater Guide](templater-guide.md)
   - [FAQ](faq.md)

2. **Report an issue:**
   - GitHub Issues: <https://github.com/your-username/powershell-magic/issues>
   - Include diagnostic information above
   - Describe steps to reproduce
   - Include error messages

3. **Community support:**
   - GitHub Discussions: <https://github.com/your-username/powershell-magic/discussions>

---

## Quick Fixes Summary

| Problem | Quick Fix |
|---------|-----------|
| Commands not found | `Import-Module QuickJump -Force; Restart PowerShell` |
| fzf not working | `scoop install fzf; Restart PowerShell` |
| 7-Zip not found | Install 7-Zip/7zz (per OS); Restart PowerShell |
| Config corrupted | `Copy backup file; Restart PowerShell` |
| Execution policy | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| Module import fails | `.\Setup-PowerShellMagic.ps1 -Force` |
| Tab completion broken | `Import-Module QuickJump -Force` |
| Profile not loading | `. $PROFILE` or restart PowerShell |

---

**→ [Back to Main README](../README.md)**
**→ [FAQ](faq.md)**
**→ [Command Reference](command-reference.md)**
