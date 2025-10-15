# PowerShell Magic 🪄

> **Supercharge your PowerShell workflow** with lightning-fast directory
> navigation, instant project templates, and Unity project management.

[![PowerShell][badge-pwsh]][link-pwsh]
[![License: MIT][badge-license]](LICENSE)
![Platform][badge-platform]

---

## 📑 Table of Contents

- [What is PowerShell Magic?](#-what-is-powershell-magic)
- [Why Use PowerShell Magic?](#-why-use-powershell-magic)
- [Quick Start](#-quick-start)
- [Modules Overview](#-modules-overview)
  - [QuickJump - Directory Navigation](#-quickjump---directory-navigation)
  - [Templater - Project Templates](#-templater---project-templates)
  - [Unitea - Unity Management](#-unitea---unity-management)
- [Installation](#installation)
- [Documentation](#-documentation)
- [Examples & Use Cases](#-examples--use-cases)
- [Troubleshooting](#troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 What is PowerShell Magic?

**PowerShell Magic** is a collection of three powerful PowerShell modules that
solve common developer workflow problems:

```text
┌─────────────────────────────────────────────────────────────┐
│                    PowerShell Magic                          │
├─────────────────┬─────────────────┬─────────────────────────┤
│   QuickJump     │    Templater    │       Unitea            │
│  Navigate Fast  │ Deploy Templates│  Manage Unity Projects  │
└─────────────────┴─────────────────┴─────────────────────────┘
```

**In simple terms:** It makes navigating your computer, starting new projects,
and managing Unity games much faster and easier through your command line.

---

## 💡 Why Use PowerShell Magic?

### Problems It Solves

| **Problem** | **Without PowerShell Magic** | **With PowerShell Magic** |
|-------------|------------------------------|---------------------------|
| **Too much typing to navigate** | `cd C:\Users\Me\Documents\Projects\MyGame\Assets\Scripts\Player` | `qj player` ⚡ |
| **Repeating project setup** | Manually copy folders, rename files, update configs every time | `use-tpl my-project` 🚀 |
| **Finding Unity projects** | Click through folders, remember which Unity version, launch manually | `unity mygame` 🎮 |
| **Lost in deep directories** | Keep track of multiple terminal windows, re-type paths constantly | Save once, jump instantly 📍 |

### Key Benefits

✅ **Save Time** - Navigate anywhere in 1-2 keystrokes instead of dozens
✅ **Consistency** - Use the same project structure every time with templates
✅ **No More Searching** - All your important paths saved with memorable names
✅ **Fuzzy Finding** - Type partial names, instantly find what you need
✅ **Track Usage** - See which folders you use most, jump to recent locations

---

## 🚀 Quick Start

### Installation (3 Steps)

```powershell
# 1. Clone or download this repository
git clone https://github.com/your-username/powershell-magic.git
cd powershell-magic

# 2. Run the setup script (completely safe, asks permission for everything)
.\Setup-PowerShellMagic.ps1

# 3. Restart PowerShell - you're ready to go! 🎉
```

**The setup script will:**

- ✅ Ask your permission before any downloads or changes
- ✅ Create automatic backups of your PowerShell profile
- ✅ Install optional tools (fzf, 7-Zip, eza) with your consent
- ✅ Show exactly what it's doing at each step

**→ [Full Installation Guide](docs/installation.md)**

### Your First Commands

Once installed, try these commands:

```powershell
# Save your current directory
qja myproject

# List all saved directories
qjl

# Jump back to that directory from anywhere
qj myproject

# Use interactive fuzzy finder (super fast!)
qj
```

**That's it!** You just learned QuickJump. See below for more modules.

---

## 📦 Modules Overview

PowerShell Magic includes three independent modules. Use one, two, or all
three based on your needs.

### 🔍 QuickJump - Directory Navigation

**Problem:** Typing long file paths is slow and error-prone.
**Solution:** Save directories with memorable aliases, jump to them instantly.

#### QuickJump Tasks You Can Do

```powershell
# Save important directories
qja docs                          # Save current directory as "docs"
qja myproject -Category work      # Save with a category for organization

# Jump around instantly
qj docs                           # Go to "docs" directory
qj                                # Interactive fuzzy finder (if fzf installed)

# View your saved paths
qjl                               # List all paths
qjl -Category work                # Filter by category
qjrecent                          # Jump to most recently used

# Organize by category
qjc                               # Choose category, then choose path
```

#### QuickJump Key Features

- 💾 **Save paths** with memorable aliases (no more long paths!)
- 📂 **Organize** with categories (work, personal, projects, etc.)
- ⚡ **Fuzzy finding** with fzf (type partial names, instant results)
- 📊 **Usage tracking** (see which paths you use most)
- 🕐 **Recent history** (quickly return to recent locations)
- ⌨️ **Tab completion** (aliases, categories auto-complete)

**→ [Complete QuickJump Guide](docs/quickjump-guide.md)**

---

### 📁 Templater - Project Templates

**Problem:** Setting up new projects from scratch is repetitive and
time-consuming.
**Solution:** Save project structures as templates, deploy them with one
command.

#### Templater Tasks You Can Do

```powershell
# Register templates (from ZIP files or folders)
add-tpl react-starter -Description "React app with TypeScript" -Category web

# Browse templates interactively
templates

# Use a template
use-tpl react-starter                    # Deploy in current directory
use-tpl react-starter -CreateSubfolder   # Create subfolder automatically

# Manage templates
templates -Category web              # Filter by category
Get-TemplateStats                    # See usage statistics
Export-Templates -Path backup.json   # Backup your templates
```

#### Templater Key Features

- 📦 **Multiple formats** (ZIP, 7Z, RAR, TAR archives, or plain folders)
- 🏷️ **Organize** with categories and tags
- 👀 **Preview** template contents before deploying
- 📊 **Statistics** track which templates you use most
- 💾 **Import/Export** share templates with your team
- 🔍 **Fuzzy finding** quickly find the right template

**→ [Complete Templater Guide](docs/templater-guide.md)**

---

### 🎮 Unitea - Unity Management

**Problem:** Managing multiple Unity projects and editor versions is
cumbersome.
**Solution:** Save Unity projects with aliases, open them with one command.

#### Unitea Tasks You Can Do

```powershell
# Add Unity projects
unity-add mygame                     # Add current Unity project
unity-add othergame "D:\Unity\Other" # Add specific project

# Open projects
unity                                # Interactive selector
unity mygame                         # Open specific project
unity-recent                         # Open most recently used

# Manage projects
unity-list                           # View all saved projects
unity-remove mygame                  # Remove from list
```

#### Unitea Key Features

- 🎯 **Auto-detect** Unity projects and their versions
- 🚀 **Direct launch** opens Unity Editor automatically
- 🔗 **Unity Hub integration** uses correct editor version
- 📜 **Recent tracking** quickly reopen last project
- 💾 **Save favorites** no more browsing folders

**→ [Complete Unitea Guide](docs/unitea-guide.md)**

---

<a id="installation"></a>

## 🛠️ Installation

### Prerequisites

**Required:**

- Windows 10/11 (or Windows Server 2016+)
- PowerShell 5.1 or higher (included in Windows)

**Optional Tools** (setup script can install these):

- **fzf** - Enables interactive fuzzy finding (highly recommended)
- **7-Zip** - Required only for Templater archive support
- **eza** - Enhanced directory previews (optional, nice to have)

### Installation Methods

#### Method 1: Automatic Setup (Recommended)

```powershell
# Clone repository
git clone https://github.com/your-username/powershell-magic.git
cd powershell-magic

# Run setup with permission prompts
.\Setup-PowerShellMagic.ps1
```

**What the setup does:**

1. Checks for existing tools (fzf, 7-Zip, eza)
2. **Asks permission** before downloading anything
3. Offers to install missing tools via package managers or portable installs
4. **Creates backup** of your PowerShell profile
5. **Asks permission** before modifying your profile
6. Adds module imports to your profile

All operations require typing **'YES'** to confirm. Nothing happens without
your explicit consent.

#### Method 2: Manual Setup

See **[detailed installation guide](docs/installation.md)** for manual setup
instructions, advanced configurations, and troubleshooting.

### Installation Verification

After installation, restart PowerShell and verify:

```powershell
# Check if modules loaded
Get-Command qj, templates, unity

# Should show all available commands
Get-Command -Module QuickJump
Get-Command -Module Templater
Get-Command -Module Unitea

# Test a simple command
qja test-location
qjl
qjr test-location
```

If you see the commands listed, you're all set!

**[Installation Troubleshooting](docs/troubleshooting.md#installation-issues)**

---

## 📖 Documentation

### Comprehensive Guides

| Guide | Description |
|-------|-------------|
| **[Installation Guide](docs/installation.md)** | Detailed setup instructions, manual installation, verification |
| **[QuickJump Guide](docs/quickjump-guide.md)** | Complete directory navigation tutorial with examples |
| **[Templater Guide](docs/templater-guide.md)** | Template management, creating templates, workflows |
| **[Unitea Guide](docs/unitea-guide.md)** | Unity project management, editor detection |
| **[Troubleshooting](docs/troubleshooting.md)** | Common issues, solutions, debugging |
| **[FAQ](docs/faq.md)** | Frequently asked questions |
| **[Command Reference](docs/command-reference.md)** | Complete command and parameter reference |
| **[Configuration](docs/configuration.md)** | Advanced customization, config files |

### Quick Command Reference

<details>
<summary><b>QuickJump Commands</b></summary>

| Command | Alias | Description |
|---------|-------|-------------|
| `Invoke-QuickJump [alias]` | `qj` | Navigate to saved path or show interactive menu |
| `Add-QuickJumpPath -Alias <name>` | `qja` | Save current directory with an alias |
| `Get-QuickJumpPaths` | `qjl` | List all saved paths |
| `Remove-QuickJumpPath` | `qjr` | Remove a saved path |
| `Invoke-QuickJumpCategory` | `qjc` | Navigate by category |
| `Open-QuickJumpRecent` | `qjrecent` | Jump to most recent path |

</details>

<details>
<summary><b>Templater Commands</b></summary>

| Command | Alias | Description |
|---------|-------|-------------|
| `Get-Templates` | `templates`, `tpl` | Browse and use templates |
| `Add-Template -Alias <name>` | `add-tpl` | Register a new template |
| `Use-Template -Alias <name>` | `use-tpl` | Deploy a template |
| `Remove-Template -Alias <name>` | `remove-tpl` | Remove a template |
| `Update-Template` | - | Update template properties |
| `Get-TemplateStats` | - | View usage statistics |
| `Export-Templates` | - | Export templates to JSON |
| `Import-Templates` | - | Import templates from JSON |

</details>

<details>
<summary><b>Unitea Commands</b></summary>

| Command | Alias | Description |
|---------|-------|-------------|
| `Open-UnityProject [alias]` | `unity` | Open Unity project or show interactive menu |
| `Add-UnityProject -Alias <name>` | `unity-add` | Add current Unity project |
| `Get-UnityProjects` | `unity-list` | List all saved Unity projects |
| `Remove-UnityProject` | `unity-remove` | Remove a Unity project |
| `Open-RecentUnityProject` | `unity-recent` | Open most recently used project |

</details>

**→ [Complete Command Reference](docs/command-reference.md)**

---

## 🌟 Examples & Use Cases

### Real-World Workflows

<details>
<summary><b>Web Developer Workflow</b></summary>

```powershell
# Setup: Save your project directories once
qja frontend "C:\Projects\WebApps\Frontend" -Category web
qja backend "C:\Projects\WebApps\Backend" -Category web
qja deploy "C:\Projects\WebApps\Deploy" -Category web

# Daily use: Jump between projects instantly
qj frontend        # Work on frontend
qj backend         # Switch to backend
qj deploy          # Deploy changes

# Create new projects from templates
use-tpl react-starter -SubfolderName "new-feature"
use-tpl nodejs-api -SubfolderName "microservice-auth"

# Navigate by category when you forget the alias
qjc                # Select "web" category → Select project
```

**Time saved:** Instead of typing long paths or navigating through Explorer 20+
times per day, jump instantly to any project. Estimated **30+ minutes saved
daily**.

</details>

<details>
<summary><b>Game Developer Workflow</b></summary>

```powershell
# Save your Unity projects
cd "D:\Unity\MyAwesomeGame"
unity-add mygame

cd "D:\Unity\PrototypeRacing"
unity-add racing -Category prototypes

# Work on projects
unity mygame       # Opens in correct Unity version
unity-recent       # Reopen last project quickly

# Navigate to project folders for version control
qj mygame          # If you also saved it with QuickJump
cd "$(unity mygame -Path)\Assets\Scripts"  # Get path programmatically
```

</details>

<details>
<summary><b>System Administrator Workflow</b></summary>

```powershell
# Save common server locations
qja logs "\\ServerA\Logs" -Category servers
qja configs "\\ServerB\Configs" -Category servers
qja backups "\\NAS\Backups" -Category servers

# Quick access
qj logs            # Jump to server logs
qjl -Category servers  # See all server paths

# Save script templates
add-tpl server-check -Category admin
add-tpl backup-script -Category admin

# Deploy template when needed
use-tpl server-check -SubfolderName "monthly-audit"
```

</details>

<details>
<summary><b>Student/Learner Workflow</b></summary>

```powershell
# Organize coursework
qja cs101 "C:\School\ComputerScience101" -Category school
qja math202 "C:\School\Math202" -Category school
qja notes "C:\School\Notes" -Category school

# Jump between classes quickly
qj cs101
qj math202

# Create assignment structure from template
use-tpl assignment-template -SubfolderName "homework-week5"

# View all school-related paths
qjl -Category school
```

</details>

**→ [More Examples and Workflows](docs/examples.md)**

---

## 🔍 Beginner-Friendly Concepts

New to PowerShell or command-line tools? Here are key concepts explained:

<details>
<summary><b>What is an "alias"?</b></summary>

An **alias** is a short, memorable name you give to something.

**Example:**

- Long path: `C:\Users\YourName\Documents\Projects\WebDevelopment\React\MyApp`
- Alias: `myapp`

Instead of typing the long path, you type `qj myapp`. Much easier!

</details>

<details>
<summary><b>What is a "category"?</b></summary>

A **category** is a label to group related items together.

**Example:**

- Category "work": Contains all work-related projects
- Category "personal": Contains personal projects
- Category "school": Contains school assignments

This helps you organize and filter your paths when you have many saved.

</details>

<details>
<summary><b>What is "fuzzy finding"?</b></summary>

**Fuzzy finding** means you don't need to type the exact name. You can type
parts of it, and it finds matches.

**Example:**
If you have paths named:

- `frontend-react-project`
- `frontend-vue-project`
- `backend-nodejs-project`

Typing `fron` will show both frontend projects. Typing `node` will show the
backend. Fast and flexible!

</details>

<details>
<summary><b>What is a "template"?</b></summary>

A **template** is a pre-made folder structure or project that you can copy and
reuse.

**Example:**
Instead of creating these files every time:

```text
my-project/
  ├── src/
  ├── tests/
  ├── README.md
  ├── .gitignore
  └── package.json
```

You save it as a template once, then deploy it instantly for new projects:
`use-tpl my-project`

</details>

<details>
<summary><b>What is PowerShell?</b></summary>

**PowerShell** is a command-line interface (CLI) for Windows. It's like a more
powerful version of the old "Command Prompt".

You type commands to control your computer, instead of clicking with your
mouse. It's faster and more powerful once you learn the basics!

**Opening PowerShell:**

- Press `Windows + X`, then select "Windows PowerShell" or "Terminal"
- Or search for "PowerShell" in the Start Menu

</details>

**[Complete Glossary](docs/glossary.md)**

---

## 🛡️ Safety & Security

### What the Setup Script Does

**PowerShell Magic is designed with safety first:**

✅ **No automatic changes** - Everything requires explicit
  `YES` confirmation
✅ **Automatic backups** - Your PowerShell profile is backed up before
  modifications
✅ **User-level only** - No administrator/elevated privileges required
✅ **Transparent operations** - Shows exactly what will be done before doing it
✅ **Fully reversible** - Easy uninstall process

### Data & Privacy

- **All data stays local** - Configurations stored in `~\.config\` on your
  machine
- **No telemetry** - No data sent anywhere
- **No internet required** - Works completely offline (after initial setup)
- **Open source** - Inspect all code yourself

### Security Verification

All downloads (when using portable installation) are verified:

- **Package managers** (Scoop, Winget, Chocolatey) - Automatic cryptographic
  verification
- **Portable installations** - SHA256 hash verification before extraction
- **No execution** - Downloaded tools are binaries, not scripts

**[Security Details](docs/security.md)**

---

<a id="troubleshooting"></a>

## ⚠️ Troubleshooting

### Common Issues

<details>
<summary><b>"fzf not found" error</b></summary>

**Problem:** You see an error saying `fzf is not available`.

**Solution:**

```powershell
# Install fzf using a package manager
scoop install fzf
# OR
choco install fzf
# OR
winget install junegunn.fzf

# Then restart PowerShell
```

**Note:** Without fzf, you can still use aliases directly (for example,
`qj myproject`). You won't have the interactive fuzzy finder.

</details>

<details>
<summary><b>Modules not loading after setup</b></summary>

**Problem:** Commands like `qj` are not recognized.

**Solution:**

```powershell
# 1. Check if your profile exists and has the imports
Get-Content $PROFILE

# You should see lines like:
# Import-Module "...\Modules\QuickJump"

# 2. If missing, re-run setup
.\Setup-PowerShellMagic.ps1 -Force

# 3. Restart PowerShell
```

</details>

<details>
<summary><b>Setup script blocked by execution policy</b></summary>

**Problem:** PowerShell won't run the setup script.

**Solution:**

```powershell
# Check current policy
Get-ExecutionPolicy

# If it's "Restricted", temporarily bypass for setup
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Then run setup
.\Setup-PowerShellMagic.ps1
```

</details>

<details>
<summary><b>"Path not found" after saving</b></summary>

**Problem:** You saved a path with `qja`, but `qj` says it's not found.

**Solution:**

```powershell
# Verify the path was saved
qjl

# Check the config file directly
code (Get-QuickJumpConfigPath)

# If config is corrupted, it will auto-backup and reset
# Your data is in the backup file
```

</details>

<details>
<summary><b>Template extraction fails (7-Zip error)</b></summary>

**Problem:** `use-tpl` fails when trying to extract a ZIP or 7Z file.

**Solution:**

```powershell
# Install 7-Zip
scoop install 7zip
# OR
choco install 7zip
# OR
winget install 7zip.7zip

# Verify installation
7z
```

**Alternative:** Use folder-based templates instead of archives.

</details>

**→ [Complete Troubleshooting Guide](docs/troubleshooting.md)**

---

## 🔄 Updating

Keep PowerShell Magic up to date:

```powershell
# Navigate to PowerShell Magic directory
cd powershell-magic

# Pull latest changes
git pull origin main

# Re-run setup if needed (optional)
.\Setup-PowerShellMagic.ps1 -Force

# Restart PowerShell
```

**→ [Update Guide](docs/updating.md)**

---

## 🗑️ Uninstallation

To completely remove PowerShell Magic:

```powershell
# 1. Restore your profile from backup
$backups = Get-ChildItem "$PROFILE.backup.*" |
    Sort-Object LastWriteTime -Descending
Copy-Item $backups[0].FullName $PROFILE -Force

# 2. Remove portable tools (if installed)
Remove-Item "$env:LOCALAPPDATA\PowerShellMagic" -Recurse -Force

# 3. Optionally uninstall dependencies
scoop uninstall fzf 7zip eza

# 4. Restart PowerShell
```

**[Complete Uninstall Guide](docs/uninstallation.md)**

---

## 🤝 Contributing

Contributions are welcome! Whether you're fixing bugs, adding features, or
improving documentation.

### How to Contribute

1. **Fork** this repository
2. **Clone** your fork locally
3. **Set up development environment:**

   ```powershell
   .\Setup-Hooks.ps1  # Install pre-commit hooks
   ```

4. **Make your changes**
5. **Test thoroughly:**

   ```powershell
   .\Run-Tests.ps1    # Run all tests
   ```

6. **Submit a pull request**

### Development Tools

```powershell
# Run all tests
.\Run-Tests.ps1

# Run tests for specific module
.\Tests\Test-PowerShellMagic.ps1 -TestName QuickJump

# Check code formatting
.\Format-PowerShell.ps1 -Check

# Auto-fix formatting issues
.\Format-PowerShell.ps1 -Fix

# Set up pre-commit hooks
.\Setup-Hooks.ps1
```

**→ [Contributing Guidelines](CONTRIBUTING.md)**
**→ [Code of Conduct](CODE_OF_CONDUCT.md)**

---

## 📋 Requirements Summary

| Component | Requirement | Notes |
|-----------|-------------|-------|
| **OS** | Windows 10/11+ | Windows Server 2016+ also supported |
| **PowerShell** | 5.1 or higher | Usually pre-installed on Windows |
| **fzf** | Optional | Highly recommended for interactive features |
| **7-Zip** | Optional | Required only for Templater archive support |
| **eza** | Optional | Nice to have for enhanced previews |
| **Unity Hub** | Optional | Required only for Unitea module |

**All optional tools can be installed automatically by the setup script.**

---

## 🎓 Learning Resources

New to PowerShell? Here are resources to get started:

- **[PowerShell Basics](docs/powershell-basics.md)** - Quick introduction for
  beginners
- **[Microsoft PowerShell Docs][link-ms-docs]** - Official
  documentation
- **[PowerShell Gallery](https://www.powershellgallery.com/)** - Discover more
  modules
- **[fzf Documentation](https://github.com/junegunn/fzf)** - Learn about fuzzy
  finding

**[Learning Guide](docs/learning-resources.md)**

---

## 🏆 Acknowledgments

PowerShell Magic is built on the shoulders of these amazing projects:

- **[fzf](https://github.com/junegunn/fzf)** by junegunn - The command-line
  fuzzy finder
- **[7-Zip](https://www.7-zip.org/)** by Igor Pavlov - File archiver
- **[eza](https://github.com/eza-community/eza)** - Modern `ls` replacement
- **PowerShell Community** - For inspiration and best practices

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE)
file for details.

**TL;DR:** You can use, modify, and distribute this freely, even commercially.
Just keep the license notice.

---

## 💬 Support & Feedback

- **Issues:** [GitHub Issues][link-issues]
- **Discussions:** [GitHub Discussions][link-discussions]
- **Documentation:** [docs/](docs/)

---

## 🌟 Show Your Support

If PowerShell Magic saves you time and frustration:

⭐ **Star this repository** to show your support
🐛 **Report issues** to help improve it
📢 **Share it** with others who might find it useful
🤝 **Contribute** to make it even better

---

## 📊 Quick Stats

```text
📁 3 Powerful Modules
⚡ 20+ Commands
🎯 100% PowerShell
🔒 0 External Dependencies (core functionality)
💾 Local-Only Data Storage
🆓 Free & Open Source
```

---

**Happy coding!** 🚀
*PowerShell Magic - Navigate fast, code faster.*

[badge-pwsh]: https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg
[badge-license]: https://img.shields.io/badge/License-MIT-yellow.svg
[badge-platform]: https://img.shields.io/badge/Platform-Windows-lightgrey.svg
[link-pwsh]: https://github.com/PowerShell/PowerShell
[link-issues]: https://github.com/your-username/powershell-magic/issues
[link-discussions]: https://github.com/your-username/powershell-magic/discussions
[link-ms-docs]: https://docs.microsoft.com/en-us/powershell/
