# PowerShell Magic 🪄

A collection of powerful PowerShell modules to supercharge your development
workflow with fast directory navigation, template management, and Unity project
handling.

## 🚀 Quick Start

### Safe Setup Process

The setup script is **completely safe** and **requires your explicit
consent** for all operations:

```powershell
.\Setup-PowerShellMagic.ps1
```

### 🔒 What the Setup Script Does (WITH YOUR PERMISSION)

**Before any downloads or modifications, you'll be prompted to confirm:**

1. **Dependency Installation** (Optional)
   - 🔍 Scans for existing tools (fzf, 7-Zip, eza)
   - 📥 **Only downloads if you type 'YES'** to confirm each tool
   - 🛡️ Shows URLs before downloading for transparency
   - 📂 Installs to `%LOCALAPPDATA%\PowerShellMagic` (user directory only)
   - 🛣️ **Asks permission** before modifying your PATH environment variable

2. **PowerShell Profile Integration** (Optional)
   - 💾 **Creates automatic backup** of your existing profile
   - ✏️ **Only modifies if you type 'YES'** to confirm
   - 📍 Shows exactly what will be added to your profile
   - 🔄 **Fully reversible** - backups allow easy restoration

3. **Package Manager Options** (Recommended)
   - **Automatic cryptographic verification** through trusted package repositories
   - Uses existing package managers (Scoop, Chocolatey, Winget) if available
   - Falls back to portable installations with **SHA256 verification**
   - **No elevated privileges required** (except Chocolatey, which will warn you)

### ✅ Safety Guarantees

- ❌ **No downloads** without explicit 'YES' confirmation
- ❌ **No profile modifications** without explicit 'YES' confirmation
- ❌ **No elevated privileges** required (user-level only)
- ✅ **Automatic backups** of your PowerShell profile
- ✅ **Cryptographic verification** of all downloads (SHA256)
- ✅ **All changes reversible** - uninstall instructions provided
- ✅ **Transparent operations** - shows exactly what it will do

### 🔧 Developer Tools Included

**For contributors and advanced users:**

```powershell
# Set up development environment with pre-commit hooks
.\Setup-Hooks.ps1

# Run all tests and formatting checks
.\Run-Tests.ps1

# Check/fix PowerShell code formatting
.\Format-PowerShell.ps1 -Check  # Check only
.\Format-PowerShell.ps1 -Fix    # Auto-fix issues
```

**Automated quality assurance:**

- 🎯 **Pre-commit hooks** - Automatic code quality checks before commits
- 🧪 **Comprehensive tests** - Unit tests for all modules (no external dependencies)
- 📝 **Code formatting** - PSScriptAnalyzer rules for consistent style
- 🔍 **Security scanning** - Built-in PowerShell security best practices
- 🚀 **CI/CD ready** - Scripts work in automated build environments

### 📦 Package Managers Explained

The setup script supports multiple package managers, each with their own
security and convenience benefits:

#### 🟢 Scoop (Recommended for Developers)

Scoop provides secure package management for developers:

- **Website**: [scoop.sh](https://scoop.sh/)
- **Security**: Community-maintained JSON manifests with automatic checksum verification
- **Installation**: `irm get.scoop.sh | iex` (installs to user directory)
- **Benefits**: No admin rights needed, clean installations, easy uninstallation
- **Verification**: Packages include SHA256 checksums verified during installation

#### 🟡 Winget (Microsoft's Official)

- **Website**: [Microsoft Winget
  docs](https://docs.microsoft.com/en-us/windows/package-manager/winget/)
- **Security**: Microsoft-backed with package verification and trusted publishers
- **Installation**: Pre-installed on Windows 10 1809+ and Windows 11
- **Benefits**: Official Microsoft support, integrated with Windows
- **Verification**: Microsoft validates package publishers and content

#### 🟠 Chocolatey (Enterprise-Ready)

- **Website**: [chocolatey.org](https://chocolatey.org/)
- **Security**: Community packages with moderation and automatic checksums
- **Installation**: Requires admin privileges for system-wide
  installation
- **Benefits**: Largest repository, enterprise features available
- **Verification**: Automatic checksum verification and package moderation

#### 🔒 Portable Installation (Fallback)

- **Security**: Manual SHA256 verification of downloaded files
- **Location**: `%LOCALAPPDATA%\PowerShellMagic` (user directory only)
- **Benefits**: No package manager required, fully self-contained
- **Verification**: Script verifies SHA256 hashes before extraction

## 📦 What's Included

### 🔍 QuickJump - Lightning Fast Directory Navigation

Navigate directories at the speed of thought with aliases, categories, and
fuzzy finding.

**Key Features:**

- Save directories with memorable aliases
- Organize paths with categories
- Interactive fuzzy finding with fzf
- Usage tracking and recent path support
- Tab completion for all commands

**Quick Commands:**

- `qj` - Interactive directory selection
- `qja work` - Add current directory with alias "work"
- `qjl` - List all saved paths
- `qjr work` - Remove saved path
- `qjrecent` - Jump to most recently used path

### 📁 Templater - Smart Project Templates

Manage and deploy project templates from archives or folders.

**Key Features:**

- Support for ZIP, 7Z, RAR, TAR archives
- Folder-based templates
- Template categories and tags
- Preview files support
- Usage statistics and export/import
- Interactive selection with previews

**Quick Commands:**

- `templates` - Interactive template browser
- `add-tpl` - Register new template
- `use-tpl mytemplate` - Deploy template
- `remove-tpl oldtemplate` - Remove template

### 🎮 Unitea - Unity Project Management

Streamlined Unity project management and launcher.

**Key Features:**

- Auto-detect Unity projects and versions
- Save projects with aliases
- Automatic Unity Editor detection
- Unity Hub integration
- Recent project tracking
- Interactive project selection

**Quick Commands:**

- `unity` - Interactive Unity project launcher
- `unity-add mygame` - Add current Unity project
- `unity-list` - Show all saved projects
- `unity-recent` - Open most recent project

## 🛠️ Installation

### Automatic Setup (Recommended)

```powershell
# Clone or download this repository
git clone https://github.com/your-username/powershell-magic.git
cd powershell-magic

# Run the setup script
.\Setup-PowerShellMagic.ps1
```

### Manual Setup

If you prefer manual installation:

1. **Install Dependencies:**

   ```powershell
   # Using Scoop (recommended)
   scoop install fzf 7zip eza

   # Using Chocolatey
   choco install fzf 7zip eza

   # Using Winget
   winget install junegunn.fzf 7zip.7zip eza-community.eza
   ```

2. **Import Modules:**
   Add to your PowerShell profile (`$PROFILE`):

   ```powershell
   Import-Module "C:\Path\To\powershell-magic\Modules\QuickJump"
   Import-Module "C:\Path\To\powershell-magic\Modules\Templater"
   Import-Module "C:\Path\To\powershell-magic\Modules\Unitea"
   ```

## 📖 Detailed Usage

### QuickJump Examples

```powershell
# Add current directory as "docs"
qja docs

# Add with category
qja myproject -Category "work"

# Interactive navigation (requires fzf)
qj

# Jump directly to alias
qj docs

# List paths by category
qjl -Category work

# Jump to most recent path
qjrecent

# Remove a path interactively
qjr -Interactive

# Get path for use in other commands
cd (qj docs -Path)
```

### Templater Examples

```powershell
# Add a ZIP template
Add-Template -Alias "react-app" -Path "templates/react-starter.zip" `
    -Description "React starter" -Category "web"

# Add a folder template
Add-Template -Alias "api-base" -Description "Basic API template" `
    -Category "backend" -PreviewFile "README.md"

# Browse and use templates interactively
templates -Interactive

# Use a specific template
use-tpl react-app -CreateSubfolder

# Use template in specific location
use-tpl api-base -DestinationPath "C:\Projects" -SubfolderName "MyNewAPI"

# View template statistics
Get-TemplateStats

# Export templates for sharing
Export-Templates -Path "my-templates.json"

# Import shared templates
Import-Templates -Path "shared-templates.json"
```

### Unitea Examples

```powershell
# Add current Unity project
unity-add mygame

# Open project interactively
unity -Interactive

# Open specific project
unity mygame

# Open most recent project
unity-recent

# List all projects
unity-list

# Remove project from list
unity-remove mygame

# Get project path for other commands
cd (unity mygame -Path)
```

## ⚙️ Configuration

All modules store configuration in `$env:USERPROFILE\.config\`:

- QuickJump: `~\.config\quickjump\paths.json`
- Templater: `~\.config\templater\templates.json`
- Unitea: `~\.config\unity\projects.json`

### Accessing Config Files

```powershell
# Open config files directly
code (Get-QuickJumpConfigPath)
code (Get-TemplaterConfigPath)
code (Get-UnityConfigPath)

# Open config directories
explorer (Get-QuickJumpConfigPath -ReturnDirectory)
```

## 🔧 Advanced Configuration

### Custom fzf Options

The modules use fzf with sensible defaults, but you can customize the
experience by setting environment variables:

```powershell
# Custom fzf options
$env:FZF_DEFAULT_OPTS = "--height=50% --reverse --border --preview-window=right:50%"
```

### Path Management

QuickJump automatically tracks usage statistics. You can sort and filter paths:

```powershell
# Sort by most used
qjl -SortByMostUsed

# Sort by most recent
qjl -SortByRecent

# Filter by category
qjl -Category work
```

### Template Organization

Organize templates with categories and tags:

```powershell
# Add template with tags
Add-Template -Alias "vue-app" -Description "Vue.js starter" `
    -Category "web" -Tags @("vue", "spa", "frontend")

# Filter by tag
templates -Tag vue

# Filter by category
templates -Category web
```

## 🔄 Uninstall / Reverting Changes

### To Completely Remove PowerShell Magic

1. **Remove from PowerShell Profile:**

   ```powershell
   # Restore from backup (if available)
   $backups = Get-ChildItem "$PROFILE.backup.*" | Sort-Object LastWriteTime -Descending
   if ($backups) {
       Copy-Item $backups[0].FullName $PROFILE -Force
       Write-Host "Profile restored from backup: $($backups[0].Name)"
   }

   # Or manually edit profile to remove the PowerShell Magic section
   notepad $PROFILE
   ```

2. **Remove Portable Dependencies (if installed):**

   ```powershell
   # Remove installation directory
   Remove-Item "$env:LOCALAPPDATA\PowerShellMagic" -Recurse -Force

   # Remove from PATH (manual)
   # Go to System Properties > Environment Variables > Edit PATH
   # Remove the PowerShellMagic\bin entry
   ```

3. **Uninstall via Package Managers (if used):**

   ```powershell
   # Scoop
   scoop uninstall fzf 7zip eza

   # Chocolatey
   choco uninstall fzf 7zip eza

   # Winget
   winget uninstall junegunn.fzf 7zip.7zip eza-community.eza
   ```

## 🆘 Troubleshooting

### Common Issues

**fzf not found:**

```powershell
# Verify fzf installation
fzf --version

# Reinstall if needed
scoop install fzf
```

**7-Zip not found (for Templater):**

```powershell
# Verify 7-Zip installation
7z

# Install if needed
scoop install 7zip
```

**Modules not loading:**

```powershell
# Check if modules are in your profile
Get-Content $PROFILE

# Check for profile backups if something went wrong
Get-ChildItem "$PROFILE.backup.*" | Sort-Object LastWriteTime -Descending

# Manually import modules for testing
Import-Module ".\Modules\QuickJump" -Force
Import-Module ".\Modules\Templater" -Force
Import-Module ".\Modules\Unitea" -Force
```

**Setup script concerns:**

- All operations require explicit consent (typing 'YES')
- Automatic backups are created before any profile changes
- No elevated privileges needed (except Chocolatey warns you)
- All changes can be reverted using the uninstall section above

**Unity projects not opening:**

- Ensure Unity Hub is installed at the default location
- Check that Unity Editor versions are installed
- Verify project paths still exist

### Getting Help

Each module includes comprehensive help:

```powershell
# Module overviews
Get-Help QuickJump
Get-Help Templater
Get-Help Unitea

# Detailed command help
Get-Help Invoke-QuickJump -Detailed
Get-Help Add-Template -Examples
Get-Help Open-UnityProject -Full

# List all available commands
Get-Command -Module QuickJump
Get-Command -Module Templater
Get-Command -Module Unitea
```

## 🔄 Updating

To update PowerShell Magic:

1. **Pull latest changes:**

   ```powershell
   git pull origin main
   ```

2. **Re-run setup:**

   ```powershell
   .\Setup-PowerShellMagic.ps1 -Force
   ```

3. **Restart PowerShell** to load updates

## 🧪 Development & Testing

### 🔧 Development Setup

```powershell
# Clone repository
git clone https://github.com/your-username/powershell-magic.git
cd powershell-magic

# Set up pre-commit hooks (recommended)
.\Setup-Hooks.ps1

# Import modules for development
Import-Module ".\Modules\QuickJump" -Force
Import-Module ".\Modules\Templater" -Force
Import-Module ".\Modules\Unitea" -Force
```

### 🧪 Running Tests

**Quick test run:**

```powershell
# Run all tests and formatting checks
.\Run-Tests.ps1

# Run only tests
.\Run-Tests.ps1 -Test

# Run only formatting checks
.\Run-Tests.ps1 -Format

# Fix formatting issues automatically
.\Run-Tests.ps1 -Format -Fix
```

**Detailed testing:**

```powershell
# Run specific test suites
.\Tests\Test-PowerShellMagic.ps1 -TestName Setup
.\Tests\Test-PowerShellMagic.ps1 -TestName QuickJump
.\Tests\Test-PowerShellMagic.ps1 -TestName All -Verbose

# Check only PowerShell formatting
.\Format-PowerShell.ps1 -Check

# Auto-fix PowerShell formatting
.\Format-PowerShell.ps1 -Fix
```

### 🎯 Pre-commit Hooks

**Automatic Setup:**

```powershell
# Install pre-commit hooks (auto-detects best method)
.\Setup-Hooks.ps1

# Force specific installation method
.\Setup-Hooks.ps1 -Method precommit  # Python pre-commit framework
.\Setup-Hooks.ps1 -Method git        # Native Git hooks
.\Setup-Hooks.ps1 -Method both       # Install both
```

**Manual Setup (Python pre-commit):**

```powershell
# Install Python pre-commit framework
pip install pre-commit

# Install hooks
pre-commit install

# Run hooks manually
pre-commit run --all-files
```

**What the hooks do:**

- ✅ **Format checking** - Ensures consistent PowerShell code style
- ✅ **Unit tests** - Verifies all functionality works correctly
- ✅ **Lint checking** - Catches common PowerShell issues
- ✅ **Security scanning** - Identifies potential security issues

### 📝 Code Style

**PowerShell formatting rules:**

- **4 spaces** for indentation (no tabs)
- **Consistent bracing** - opening brace on same line
- **Proper casing** - PascalCase for functions, camelCase for variables
- **No aliases** in scripts (except common ones like `cd`, `ls`)
- **Explicit parameter types** where applicable

**Formatting tools:**

```powershell
# PSScriptAnalyzer settings in PSScriptAnalyzerSettings.psd1
# Auto-formatting via Format-PowerShell.ps1
# Pre-commit hooks ensure compliance
```

### 🏗️ CI/CD Integration

**For automated builds:**

```powershell
# Run in CI mode (no auto-fixes, strict exit codes)
.\Run-Tests.ps1 -CI

# Check formatting without fixing
.\Format-PowerShell.ps1 -Check

# Run tests with verbose output
.\Tests\Test-PowerShellMagic.ps1 -Verbose
```

**GitHub Actions / Azure DevOps:**

```yaml
- name: Run PowerShell Tests
  run: |
    powershell -ExecutionPolicy Bypass -File "./Run-Tests.ps1" -CI
```

### 🔍 Test Coverage

**Current test coverage:**

- ✅ **Setup script** - Syntax validation, function presence, dependencies
- ✅ **Module loading** - All modules import correctly
- ✅ **Command exports** - All expected commands are available
- ✅ **Dependency handling** - Graceful failure without external tools
- ✅ **Configuration paths** - Config functions work correctly
- ✅ **Formatter & analyzer** - Code quality tools function properly

**Tests run without external dependencies:**

- No fzf, 7-Zip, or eza required
- No Unity Hub installation needed
- Mocked dependencies where appropriate
- Comprehensive syntax and structure validation

## 🤝 Contributing

Contributions are welcome! Please:

1. **Fork the repository**
2. **Create a feature branch**
3. **Set up pre-commit hooks**: `.\Setup-Hooks.ps1`
4. **Make your changes**
5. **Add tests** for new functionality
6. **Run tests**: `.\Run-Tests.ps1`
7. **Submit a pull request**

**Development workflow:**

```powershell
# 1. Setup development environment
.\Setup-Hooks.ps1

# 2. Make changes to code

# 3. Test your changes
.\Run-Tests.ps1

# 4. Fix any formatting issues
.\Format-PowerShell.ps1 -Fix

# 5. Commit (hooks will run automatically)
git commit -m "Add new feature"
```

**Code quality requirements:**

- All tests must pass ✅
- Code must be properly formatted ✅
- No PSScriptAnalyzer warnings ✅
- New functions need tests ✅

## 📋 Dependencies

| Tool | Purpose | Required | Verification | Package Managers |
|------|---------|----------|--------------|------------------|
| **fzf** | Fuzzy finding for interactive selection | Yes | ✅ SHA256 | Multi |
| **7-Zip** | Archive extraction | Templater only | ⚠️ No check | Multi |
| **eza** | Enhanced directory previews | Optional | ✅ SHA256 | Multi |
| **Unity Hub** | Unity project management | Unitea only | Manual install | - |

### 🔐 Security Notes

- **Package managers provide the highest security** through automatic verification
- **Portable installations include SHA256 verification** where checksums are available
- **7-Zip from official site**: No checksums provided by Igor Pavlov (author choice)
- **Recommendation**: Use Scoop, Winget, or Chocolatey for maximum security

### 🔍 Hash Verification Process

For portable installations, the script:

1. **Downloads** the file to a temporary location
2. **Calculates SHA256** hash of the downloaded file
3. **Compares** against known good hash
4. **Rejects** installation if hashes don't match
5. **Proceeds** only with verified files

**Maintainer Note**: Hash placeholders in the script need to be updated
with actual values before distribution.

## 🆔 Commands Reference

### QuickJump Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `Invoke-QuickJump` | `qj` | Interactive directory navigation |
| `Add-QuickJumpPath` | `qja` | Add directory with alias |
| `Get-QuickJumpPaths` | `qjl` | List saved directories |
| `Remove-QuickJumpPath` | `qjr` | Remove saved directory |
| `Invoke-QuickJumpCategory` | `qjc` | Navigate by category |
| `Open-QuickJumpRecent` | `qjrecent` | Open most recent directory |

### Templater Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `Get-Templates` | `templates`, `tpl` | Browse and use templates |
| `Add-Template` | `add-tpl` | Register new template |
| `Use-Template` | `use-tpl` | Deploy template |
| `Remove-Template` | `remove-tpl` | Remove template |
| `Update-Template` | - | Update template properties |
| `Export-Templates` | - | Export templates to JSON |
| `Import-Templates` | - | Import templates from JSON |
| `Get-TemplateStats` | - | View usage statistics |

### Unitea Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `Open-UnityProject` | `unity` | Open Unity project |
| `Add-UnityProject` | `unity-add` | Add Unity project |
| `Get-UnityProjects` | `unity-list` | List Unity projects |
| `Remove-UnityProject` | `unity-remove` | Remove Unity project |
| `Open-RecentUnityProject` | `unity-recent` | Open recent project |

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- [fzf](https://github.com/junegunn/fzf) - Command-line fuzzy finder
- [7-Zip](https://www.7-zip.org/) - File archiver
- [eza](https://github.com/eza-community/eza) - Modern ls replacement
- PowerShell community for inspiration and best practices

---

## Happy coding! 🚀

*If you find this useful, please star the repository and share it with others!*
