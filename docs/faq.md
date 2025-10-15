# Frequently Asked Questions (FAQ)

Common questions and answers about PowerShell Magic.

---

## General Questions

### What is PowerShell Magic?

PowerShell Magic is a collection of three PowerShell modules that improve
developer workflow:

- **QuickJump**: Fast directory navigation with aliases and fuzzy finding
- **Templater**: Project template management and deployment
- **Unitea**: Unity project management

### Do I need all three modules?

No! Each module works independently. Use what you need:

- Just QuickJump for navigation
- Just Templater for templates
- All three for complete workflow improvement

### Is it safe to use?

Yes! PowerShell Magic is:

- ✅ Open source - inspect all code
- ✅ Local only - no data sent anywhere
- ✅ Permission-based - asks before any changes
- ✅ Reversible - easy to uninstall
- ✅ Automatic backups - configs backed up before changes

### Does it work on macOS or Linux?

Yes! PowerShell Magic now supports Windows, macOS, and Linux as long as you're
running PowerShell 7 or newer. The setup script automatically detects your
platform and uses the right install location and package managers:

- **Windows:** Stores files in `%LOCALAPPDATA%\PowerShellMagic` and offers to use
  winget, Scoop, or Chocolatey.
- **macOS:** Uses the XDG-compliant path `~/.local/share/powershell-magic` and
  leverages Homebrew if available.
- **Linux:** Installs under `~/.local/share/powershell-magic` and supports apt,
  dnf, or pacman when they're present.

Install PowerShell 7 first if you don't already have it:

- [Install PowerShell on Windows, macOS, or Linux](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)
- [Download the latest PowerShell 7 release](https://github.com/PowerShell/PowerShell/releases)

### Which platforms are supported?

- Windows 10/11
- Windows Server 2016+
- macOS 12+ (Intel or Apple Silicon)
- Linux distributions with PowerShell 7 support (e.g., Ubuntu 20.04+, Fedora 38+,
  Arch/Manjaro)

PowerShell 7.0 or higher is required on every platform.

---

## Installation & Setup

### Do I need administrator rights?

No! Installation is user-level only (except if using Chocolatey for
dependencies).

### What does the setup script do?

The setup script:

1. Checks for dependencies (fzf, 7-Zip/7zz, eza)
2. **Asks permission** to install missing tools
3. **Creates backup** of your PowerShell profile
4. **Asks permission** to modify your profile
5. Adds module imports to your profile

Nothing happens without typing 'YES' to confirm.

### Can I install manually?

Yes! See the [Installation Guide](installation.md) for manual installation
instructions.

### How do I uninstall?

```powershell
# 1. Restore profile from backup
$backups = Get-ChildItem "$PROFILE.backup.*" |
    Sort-Object LastWriteTime -Descending
Copy-Item $backups[0].FullName $PROFILE -Force

# 2. Remove portable tools (if installed)
Remove-Item "$env:LOCALAPPDATA\PowerShellMagic" -Recurse -Force

# 3. Restart PowerShell
```

See [Uninstallation Guide](uninstallation.md) for details.

---

## QuickJump Questions

### How is QuickJump different from CDPATH or pushd/popd?

**QuickJump vs CDPATH:**

- QuickJump: Memorable aliases (`qj myproject`)
- CDPATH: Still need to know directory names

**QuickJump vs pushd/popd:**

- QuickJump: Jump to ANY saved directory, any time
- pushd/popd: Only navigate stack history (limited)

**QuickJump advantages:**

- Fuzzy finding (with fzf)
- Categories for organization
- Usage tracking
- Tab completion
- Persistent across sessions

### Do I need fzf to use QuickJump?

No! fzf enables interactive fuzzy finding, but QuickJump works without it:

**With fzf:**

```powershell
qj    # Interactive fuzzy finder
```

**Without fzf:**

```powershell
qj myproject    # Direct alias navigation
qjl             # List all paths
qjl -Category work  # Filter by category
```

fzf is highly recommended for the best experience.

### How many paths can I save?

Practically unlimited! Performance stays good with hundreds of paths. Use
categories to organize large numbers.

### Can I share my saved paths with a team?

Yes! Config file at `~\.config\quickjump\paths.json` can be shared.

**Note:** Paths are absolute, so team members need to adjust for their systems.

### What happens if I delete a directory I saved?

QuickJump will show an error when you try to jump to it. Remove the saved path
with:

```powershell
qjr -Alias oldpath
# OR
qjr -Interactive
```

### Can I use QuickJump in scripts?

Yes! Get paths programmatically:

```powershell
$path = qj myproject -Path
cd "$path\subfolder"
Copy-Item file.txt (qj deploy -Path)
```

---

## Templater Questions

### What file formats are supported?

**Archives:**

- .zip (built-in, no dependencies)
- .7z, .rar, .tar, .gz, .bz2, .xz (requires 7-Zip)

**Folders:**

- Any folder can be used as a template

### Do I need 7-Zip?

Only for non-ZIP archives (.7z, .rar, etc.). ZIP files work with no
dependencies.

**Recommendation:** Use ZIP for widest compatibility, or install 7-Zip.

### Can I use templates from archives and folders?

Yes! Mix and match:

```powershell
# Archive template
add-tpl webapp "C:\Templates\webapp.zip"

# Folder template
add-tpl api-base "C:\Templates\API-Starter"
```

### How do I create a template?

**From existing project:**

1. **Folder template:**

   ```powershell
   cd C:\MyProject
   add-tpl myproject -Description "My project template"
   ```

2. **Archive template:**

   ```powershell
   # Create ZIP of your project first
   Compress-Archive -Path "C:\MyProject\*" `
       -DestinationPath "C:\Templates\myproject.zip"

   # Register as template
   add-tpl myproject "C:\Templates\myproject.zip" `
       -Description "My project template"
   ```

### Can I modify templates after creating them?

Yes! Templates are just references:

- **Archive templates**: Edit the original ZIP/7z file
- **Folder templates**: Edit the original folder

Changes take effect immediately (templates reference the source).

### Can templates include variables or placeholders?

Not currently. Templates are copied/extracted as-is.

**Workaround:** Use template + manual find/replace:

```powershell
use-tpl mytemplate -SubfolderName "NewProject"
cd NewProject
# Then manually replace placeholders in files
```

### How do I share templates with my team?

1. **Share template files** (ZIPs or folders)
2. **Export template configs:**

   ```powershell
   Export-Templates -Path "team-templates.json"
   ```

3. **Team imports:**

   ```powershell
   Import-Templates -Path "team-templates.json"
   # Then adjust paths to their systems
   ```

### Are templates portable?

Templates reference paths on your system. When sharing:

- Archive templates: Share the archive files + config
- Folder templates: Share the folders + config
- Team members adjust paths for their systems

---

## Unitea Questions

### Do I need Unity Hub?

Recommended! Unitea uses Unity Hub to:

- Auto-detect Unity project versions
- Open projects in correct Editor version

**Without Unity Hub:** You can still save project paths and navigate to them.

### Will it work with all Unity versions?

Yes! Unitea detects project versions. It uses the appropriate Unity Editor via
Unity Hub.

### Can I use it with Unity projects on external drives?

Yes! Save projects from any location:

```powershell
unity-add myproject "D:\ExternalDrive\UnityProjects\MyGame"
```

### Does it modify Unity projects?

No! Unitea only:

- Saves project paths
- Opens projects via Unity Hub
- Tracks usage

It never modifies project files.

---

## Dependency Questions

### What dependencies are needed?

**Required:** None! Core functionality works without dependencies.

**Optional (highly recommended):**

- **fzf**: Interactive fuzzy finding (for QuickJump and Templater)
- **7-Zip / 7zz**: Non-ZIP archive support (for Templater)
- **eza**: Enhanced directory previews (nice to have)

### How do I install fzf?

```powershell
# Scoop (recommended)
scoop install fzf

# Chocolatey
choco install fzf

# Winget
winget install junegunn.fzf
```

Restart PowerShell after installing.

### How do I install 7-Zip?

- **Windows:** `scoop install 7zip`, `choco install 7zip`, or
  `winget install 7zip.7zip`
- **macOS:** `brew install p7zip` *(installs the `7zz` CLI)*
- **Linux:** `sudo apt install p7zip-full`, `sudo dnf install p7zip`, or
  `sudo pacman -S p7zip`
- **Manual:** download binaries from <https://www.7-zip.org/> (ships `7z.exe`
  for Windows and `7zz` for macOS/Linux)

> Verify manual downloads by running
> `pwsh ./Setup-PowerShellMagic.ps1 -ListPortableDownloads` to view the official
> URLs and SHA256 hashes, then confirm with `Get-FileHash` or `shasum -a 256`
> before installing.

### Can I use without a package manager?

Yes! Manual installation:

- Download binaries
- Extract to a folder
- Add folder to PATH

Or use portable installations via setup script.

---

## Configuration Questions

### Where are configs stored?

Default location: `~\.config\`

- QuickJump: `~\.config\quickjump\paths.json`
- Templater: `~\.config\templater\templates.json`
- Unitea: `~\.config\unity\projects.json`

### Can I edit config files manually?

Yes, but use caution:

- Keep valid JSON structure
- Use double backslashes in paths: `C:\\Path\\To\\Dir`
- Don't edit while commands are running

**Safer:** Use commands to manage configs.

### Are configs backed up automatically?

Yes! Before any modifications, configs are backed up:

```powershell
# Find backups
Get-ChildItem "~\.config\quickjump\paths.json.backup.*"
Get-ChildItem "~\.config\templater\templates.json.backup.*"
```

### Can I move config files?

Yes! Set environment variable:

```powershell
$env:XDG_CONFIG_HOME = "C:\CustomLocation"
```

Add to your profile to make permanent.

### How do I reset configs?

**Start fresh:**

```powershell
# QuickJump
Remove-Item (Get-QuickJumpConfigPath)

# Templater
Remove-Item (Get-TemplaterConfigPath)
```

Configs will be recreated automatically when you run commands.

**Or restore from backup (if available).**

---

## Performance Questions

### Does it slow down PowerShell startup?

Minimal impact. Modules load in ~100-200ms typically.

**To optimize:**

- Remove unused modules from profile
- Use lazy loading (import only when needed)

### Can I handle hundreds of saved paths?

Yes! Tested with 500+ paths, performance stays good.

**Tips for large numbers:**

- Use categories to organize
- Use filters (`qjl -Category work`)
- Regular cleanup of unused paths

### Are there file size limits for templates?

No strict limits, but:

- **Large archives** (>1GB): May be slow to extract
- **Many files** (>10,000): May be slow to copy (folder templates)

**Recommendation:** Keep templates focused and relevant.

---

## Workflow Questions

### Can I use with Git?

Yes! Combine seamlessly:

```powershell
qj myproject
git status
git pull
```

### Does it work with VS Code?

Yes! Examples:

```powershell
# Open project in VS Code
code (qj myproject -Path)

# Use in VS Code terminal
qj frontend
npm start
```

### Can I use in scripts and automation?

Absolutely! Examples:

```powershell
# Deployment script
qj frontend
npm run build
Copy-Item .\dist\* (qj deploy -Path) -Recurse

# Backup script
$projects = qjl -Category work
foreach ($p in $projects) {
    # Backup each project
}
```

### Can I use QuickJump with Templater?

Yes! Common workflow:

```powershell
# Create new project from template
use-tpl webapp -SubfolderName "MyNewApp"
cd MyNewApp

# Save it with QuickJump
qja myapp -Category work

# Later, jump back instantly
qj myapp
```

---

## Troubleshooting

### Commands don't work after installation

1. Restart PowerShell
2. Check modules loaded: `Get-Module QuickJump, Templater, Unitea`
3. Manually import: `Import-Module QuickJump -Force`
4. Re-run setup: `.\Setup-PowerShellMagic.ps1 -Force`

### fzf shows weird characters

Your terminal might not support UTF-8 properly.

**Fix:**

```powershell
# Set console to UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Add to profile to make permanent
```

### Tab completion stopped working

```powershell
# Re-import modules
Import-Module QuickJump, Templater, Unitea -Force

# If still not working, restart PowerShell
```

### Config file got corrupted

```powershell
# Restore from automatic backup
$backups = Get-ChildItem "$(Get-QuickJumpConfigPath).backup.*" |
    Sort-Object LastWriteTime -Descending
Copy-Item $backups[0].FullName (Get-QuickJumpConfigPath) -Force
```

**See [Troubleshooting Guide](troubleshooting.md) for more solutions.**

---

## Contributing & Support

### How can I contribute?

1. Fork the repository
2. Make improvements
3. Submit pull requests

See [Contributing Guidelines](../CONTRIBUTING.md)

### Where do I report bugs?

GitHub Issues: <https://github.com/your-username/powershell-magic/issues>

Include:

- PowerShell version
- Steps to reproduce
- Error messages
- Expected vs actual behavior

### Can I request features?

Yes! GitHub Discussions or Issues.

### Is there a community?

- GitHub Discussions: <https://github.com/your-username/powershell-magic/discussions>
- Issues: Bug reports and feature requests

---

## Advanced Usage

### Can I customize fzf behavior?

Yes! Set environment variables:

```powershell
$env:FZF_DEFAULT_OPTS =
    "--height=50% --reverse --border --preview-window=right:50%"
```

Add to profile to make permanent.

### Can I extend PowerShell Magic?

Yes! Modules are standard PowerShell:

- Add custom functions to your profile
- Wrap module commands in your own
- Contribute improvements to the project

### Can I use with other PowerShell modules?

Yes! PowerShell Magic works alongside other modules:

- posh-git
- PSReadLine
- oh-my-posh
- Any others

---

## Comparison to Alternatives

### vs z / autojump / fasd

**Similar:** Frecency-based directory jumping

**PowerShell Magic advantages:**

- Explicit aliases (more control)
- Categories for organization
- Works with templates and Unity too
- Tab completion
- Windows-optimized

**When to use z/autojump:**

- Prefer automatic frecency ranking
- Cross-platform (Linux/Mac)

### vs cookiecutter / yeoman

**Similar:** Project template management

**PowerShell Magic advantages:**

- Simpler (no Node.js/Python required)
- Windows-native
- Integrated with navigation
- Archives or folders

**When to use cookiecutter/yeoman:**

- Need complex variable substitution
- Need interactive prompts during generation
- Cross-platform templates

---

## Still Have Questions?

- **Documentation:** [Complete guides](.)
- **Troubleshooting:** [Troubleshooting guide](troubleshooting.md)
- **GitHub:** [Issues and discussions](https://github.com/your-username/powershell-magic)

---

**→ [Back to Main README](../README.md)**
**→ [Troubleshooting](troubleshooting.md)**
**→ [Installation Guide](installation.md)**
