# QuickJump Complete Guide

**QuickJump** is your shortcut to lightning-fast directory navigation.
Save paths with memorable aliases, organize them with categories, and jump
to them instantly from anywhere in your terminal.

---

## Table of Contents

- [What QuickJump Solves](#what-quickjump-solves)
- [Core Concepts](#core-concepts)
- [Getting Started](#getting-started)
- [Command Guide](#command-guide)
- [Practical Examples](#practical-examples)
- [Advanced Usage](#advanced-usage)
- [Best Practices](#best-practices)
- [Common Pitfalls](#common-pitfalls)
- [Tips & Tricks](#tips--tricks)
- [Troubleshooting](#troubleshooting)

---

## What QuickJump Solves

### The Problem

As a developer, you constantly navigate between project directories. This means:

```powershell
# Typing the same long paths repeatedly
cd C:\Users\YourName\Documents\Development\Projects\WebApps\Frontend\MyReactApp
cd C:\Users\YourName\Documents\Development\Projects\WebApps\Backend\MyNodeAPI
cd C:\Users\YourName\Documents\Development\Projects\Unity\MyGame\Assets\Scripts

# Or constantly using 'cd ..' to go back up
cd ..
cd ..
cd ../../../OtherProject
cd ../../Backend
```

**This is slow, error-prone, and tedious.**

### The Solution

With QuickJump:

```powershell
# Save paths once
qja frontend
qja backend
qja gamescripts

# Jump to them anytime from anywhere
qj frontend     # Instantly at C:\...\MyReactApp
qj backend      # Instantly at C:\...\MyNodeAPI
qj gamescripts  # Instantly at C:\...\Scripts
```

**Result:** Navigate to any saved directory in 2 seconds instead of 20.

---

## Core Concepts

### 1. Aliases

An **alias** is a short, memorable name for a directory path.

```text
Long path:  C:\Users\John\Documents\Projects\E-Commerce\Frontend
Alias:      "shop-front"

Usage:      qj shop-front
```

**Think of it like:** Bookmarks in your web browser, but for directories.

### 2. Categories

**Categories** are labels that group related paths together.

```text
Category: "work"
  - shop-front    → C:\...\E-Commerce\Frontend
  - shop-back     → C:\...\E-Commerce\Backend
  - shop-deploy   → C:\...\E-Commerce\Deploy

Category: "personal"
  - blog          → C:\...\Personal\Blog
  - portfolio     → C:\...\Personal\Portfolio
```

**Benefits:**

- Organize paths logically
- Filter views (`qjl -Category work`)
- Browse by category (`qjc`)

### 3. Usage Tracking

QuickJump automatically tracks:

- **Use count** - How many times you've jumped to each path
- **Last used** - When you last accessed each path

**Benefits:**

- See which paths you use most (`qjl -SortByMostUsed`)
- Quickly return to recent paths (`qjrecent`)
- Understand your navigation patterns

### 4. Fuzzy Finding (with fzf)

If you have **fzf** installed, you get interactive fuzzy finding:

```powershell
qj          # Shows interactive menu
# Type: "fron"
# Instantly filters to paths matching "fron" (like "frontend", "shop-front")
# Press Enter to jump
```

**Without fzf:**

- Direct alias jumps still work: `qj frontend`
- List and filter: `qjl -Category work`
- Still useful, just less interactive

---

## Getting Started

### Prerequisites

**Required:**

- PowerShell 5.1 or higher
- QuickJump module imported (via setup script)

**Optional but highly recommended:**

- **fzf** - Enables interactive fuzzy finding

  ```powershell
  scoop install fzf
  # OR
  choco install fzf
  # OR
  winget install junegunn.fzf
  ```

### Your First Path

```powershell
# 1. Navigate to a directory you use often
cd C:\Projects\MyImportantProject

# 2. Save it with an alias
qja myproject

# 3. Go anywhere else
cd C:\

# 4. Jump back instantly
qj myproject
```

**That's it!** You just saved 10+ seconds and a bunch of typing.

### Adding More Context

```powershell
# Save with a category for organization
qja myproject -Category work

# Or save a different path with alias and category
qja backend "C:\Projects\Backend" -Category work
```

---

## Command Guide

### `qj` / `Invoke-QuickJump`

**Purpose:** Navigate to saved paths

**Usage:**

```powershell
# Interactive selection (requires fzf)
qj

# Jump to specific alias
qj myproject

# Filter by category, then select
qj -Category work

# Sort by most recently used
qj -Recent

# Sort by most frequently used
qj -MostUsed

# Get path instead of navigating (useful in scripts)
$path = qj myproject -Path
cd $path\subfolder
```

**Examples:**

```powershell
# Daily workflow
qj                  # Show all paths, select interactively
qj frontend         # Jump directly to "frontend"
qj -Category work   # Show only work paths

# Advanced usage
cd (qj backend -Path)           # Navigate using returned path
Copy-Item file.txt (qj deploy -Path)   # Use path in other commands
```

---

### `qja` / `Add-QuickJumpPath`

**Purpose:** Save paths with aliases and categories

**Usage:**

```powershell
# Save current directory
qja alias-name

# Save current directory with category
qja alias-name -Category category-name

# Save specific path
qja alias-name "C:\Path\To\Directory" -Category category-name

# Update existing path (overwrite)
qja alias-name -Category new-category -Force
```

**Examples:**

```powershell
# Save current directory
cd C:\Projects\WebApp
qja webapp

# Save with category
cd C:\Projects\Backend
qja backend -Category work

# Save specific path
qja logs "C:\Logs\Application" -Category admin

# Update category of existing path
qja webapp -Category work -Force
```

**Parameter Details:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Alias` | String | Short name for the path (optional if using positional) |
| `-Path` | String | Directory to save (defaults to current directory) |
| `-Category` | String | Organizational category |
| `-Force` | Switch | Overwrite existing alias or path |

**Common Patterns:**

```powershell
# Pattern 1: Save current directory with just alias
qja myalias

# Pattern 2: Save current directory with alias and category
qja myalias -Category mycategory

# Pattern 3: Save specific path
qja myalias "C:\Specific\Path"

# Pattern 4: Save specific path with category
qja myalias "C:\Specific\Path" -Category mycategory
```

---

### `qjl` / `Get-QuickJumpPaths`

**Purpose:** List and filter saved paths

**Usage:**

```powershell
# List all paths
qjl

# Filter by category
qjl -Category work

# Sort by most used
qjl -SortByMostUsed

# Sort by most recent
qjl -SortByRecent

# Interactive selection (like qj)
qjl -Interactive

# Get specific alias path
$path = qjl -Alias myproject -Path
```

**Examples:**

```powershell
# View all saved paths
qjl

# View only work-related paths
qjl -Category work

# See which paths you use most
qjl -SortByMostUsed

# See recent navigation history
qjl -SortByRecent

# Combine filtering and sorting
qjl -Category work -SortByMostUsed
```

**Output Format:**

```text
Alias      : frontend
Path       : C:\Projects\WebApp\Frontend
Category   : work
LastUsed   : 2025-10-15 14:23:45
UseCount   : 47

Alias      : backend
Path       : C:\Projects\WebApp\Backend
Category   : work
LastUsed   : 2025-10-15 13:15:22
UseCount   : 38
```

---

### `qjr` / `Remove-QuickJumpPath`

**Purpose:** Remove saved paths

**Usage:**

```powershell
# Remove by alias
qjr -Alias myproject

# Remove by path
qjr -Path "C:\Projects\OldProject"

# Interactive selection (requires fzf)
qjr -Interactive

# Interactive multi-select removal (requires fzf)
qjr -Interactive -Multiple
```

**Examples:**

```powershell
# Remove a specific alias
qjr -Alias oldproject

# Remove using path
qjr -Path "C:\OldProjects\Deprecated"

# Choose what to remove interactively
qjr -Interactive

# Remove multiple paths at once
qjr -Interactive -Multiple
# Then use Tab to select multiple items, Enter to confirm
```

**Warning:** This removes the path from QuickJump only. It does NOT delete the
actual directory from your file system.

---

### `qjc` / `Invoke-QuickJumpCategory`

**Purpose:** Two-step navigation: select category, then select path

**Usage:**

```powershell
# Select category, then select path
qjc

# Get path instead of navigating
$path = qjc -Path
```

**Examples:**

```powershell
# Navigate by category
qjc
# Step 1: Shows list of categories (work, personal, projects, etc.)
# Step 2: After selecting category, shows paths in that category
# Step 3: Select path to jump to

# Use in scripts
cd (qjc -Path)
```

**When to use:**

- You have many saved paths
- You remember the category but not the exact alias
- You want to browse organized paths

---

### `qjrecent` / `Open-QuickJumpRecent`

**Purpose:** Jump to most recently used path

**Usage:**

```powershell
# Jump to most recent path
qjrecent

# Get most recent path
$path = qjrecent -Path

# Force interactive selection of recent paths
qjrecent -Interactive
```

**Examples:**

```powershell
# Quick return to recent location
qjrecent

# Use recent path in script
Copy-Item config.json (qjrecent -Path)

# Browse recent paths interactively
qjrecent -Interactive
```

**Use Case:** You jumped away to check something quickly, now you want to
return:

```powershell
qj backend          # Work on backend
qj frontend         # Quick check on frontend
qjrecent            # Back to backend (most recent)
```

---

## Practical Examples

### Example 1: Web Developer with Multiple Projects

**Scenario:** You work on 3 web projects, each with frontend and backend.

**Setup:**

```powershell
# Project 1: E-commerce site
qja shop-front "C:\Projects\Shop\Frontend" -Category shop
qja shop-back "C:\Projects\Shop\Backend" -Category shop
qja shop-db "C:\Projects\Shop\Database" -Category shop

# Project 2: Blog platform
qja blog-front "C:\Projects\Blog\Frontend" -Category blog
qja blog-back "C:\Projects\Blog\Backend" -Category blog

# Project 3: Portfolio site
qja portfolio "C:\Projects\Portfolio" -Category personal
```

**Daily Usage:**

```powershell
# Jump between projects effortlessly
qj shop-front       # Work on shop frontend
qj shop-back        # Switch to shop backend

# View all shop-related paths
qjl -Category shop

# Navigate by category when you forget the alias
qjc                 # Select "shop" → Select specific path

# Return to recent location
qj blog-front       # Check blog
qjrecent            # Back to shop backend
```

**Time Saved:** Instead of typing long paths or using File Explorer 30+ times
per day, you navigate instantly. **Estimated 30-45 minutes saved daily.**

---

### Example 2: Game Developer with Unity Projects

**Scenario:** Multiple Unity projects with frequently accessed folders.

**Setup:**

```powershell
# Main game project
qja game-root "D:\Unity\MyGame" -Category game
qja game-scripts "D:\Unity\MyGame\Assets\Scripts" -Category game
qja game-prefabs "D:\Unity\MyGame\Assets\Prefabs" -Category game
qja game-scenes "D:\Unity\MyGame\Assets\Scenes" -Category game

# Prototype project
qja proto "D:\Unity\Prototype\Assets" -Category prototypes

# Shared resources
qja unity-assets "D:\UnityAssets\SharedLibrary" -Category resources
```

**Daily Usage:**

```powershell
# Jump between frequently accessed folders
qj game-scripts     # Work on scripts
qj game-prefabs     # Check prefabs
qj unity-assets     # Grab shared asset

# View all game-related paths
qjl -Category game

# See which folders you use most
qjl -SortByMostUsed
```

---

### Example 3: System Administrator

**Scenario:** Managing multiple servers and log locations.

**Setup:**

```powershell
# Server paths
qja server-a-logs "\\ServerA\Logs" -Category servers
qja server-a-config "\\ServerA\Config" -Category servers
qja server-b-logs "\\ServerB\Logs" -Category servers
qja server-b-config "\\ServerB\Config" -Category servers

# Backup locations
qja backups-daily "\\NAS\Backups\Daily" -Category backups
qja backups-weekly "\\NAS\Backups\Weekly" -Category backups

# Scripts and tools
qja admin-scripts "C:\Scripts\Administration" -Category tools
```

**Daily Usage:**

```powershell
# Check server logs
qj server-a-logs
qj server-b-logs

# View all server paths
qjl -Category servers

# Navigate to backup locations
qj backups-daily

# Access admin scripts
qj admin-scripts
```

---

### Example 4: Student Managing Coursework

**Scenario:** Multiple classes with assignments, notes, and projects.

**Setup:**

```powershell
# Class directories
qja cs101 "C:\School\CS101" -Category school
qja math202 "C:\School\Math202" -Category school
qja physics "C:\School\Physics301" -Category school

# Shared resources
qja notes "C:\School\Notes" -Category school
qja textbooks "C:\School\Textbooks" -Category resources

# Projects
qja final-project "C:\School\CS101\FinalProject" -Category projects
```

**Daily Usage:**

```powershell
# Jump to class folder for assignments
qj cs101
qj math202

# Access notes quickly
qj notes

# Work on final project
qj final-project

# View all school-related paths
qjl -Category school
```

---

## Advanced Usage

### 1. Using Paths in Scripts

QuickJump paths can be used programmatically:

```powershell
# Get path as string
$frontendPath = qj frontend -Path

# Navigate to subfolder
cd "$frontendPath\src\components"

# Copy files to saved location
Copy-Item .\dist\* (qj deploy -Path) -Recurse

# Open in VS Code
code (qj myproject -Path)

# Run command in saved location
Push-Location (qj backend -Path)
npm install
Pop-Location
```

### 2. Combining with Other Tools

```powershell
# Open in File Explorer
explorer (qj myproject -Path)

# Search within saved path
Get-ChildItem (qj frontend -Path) -Recurse -Filter "*.js"

# Git operations
cd (qj myproject -Path)
git status
git pull

# Build/Deploy scripts
$deployPath = qj deploy -Path
Copy-Item .\build\* $deployPath -Recurse -Force
```

### 3. Bulk Management

```powershell
# Export all paths to backup
Get-QuickJumpPaths | Export-Csv -Path "quickjump-backup.csv"

# View statistics
qjl -SortByMostUsed | Select-Object -First 10  # Top 10 most used

# Find unused paths
qjl | Where-Object { $_.UseCount -eq 0 }

# Remove all paths in a category
qjl -Category old-projects | ForEach-Object { qjr -Alias $_.Alias }
```

### 4. Team Sharing

```powershell
# Export your paths
$paths = qjl
$paths | ConvertTo-Json | Out-File "team-paths.json"

# Team member imports (after adjusting paths)
$sharedPaths = Get-Content "team-paths.json" | ConvertFrom-Json
foreach ($p in $sharedPaths) {
    # Adjust path for their system, then add
    qja $p.Alias "C:\TheirPath\$($p.Alias)" -Category $p.Category
}
```

---

## Best Practices

### 1. Naming Aliases

**DO:**

- Use short, memorable names: `frontend`, `api`, `docs`
- Be consistent: If you use `shop-front`, use `shop-back` (not `shop-backend`)
- Use descriptive names: `game-scripts` (not just `scripts`)

**DON'T:**

- Use long aliases: `my-really-long-project-name-frontend` (defeats the purpose)
- Use ambiguous names: `folder`, `temp`, `stuff`
- Use special characters: `my@project`, `work#1`

**Examples:**

```powershell
# Good
qja frontend
qja shop-api
qja game-assets

# Bad
qja proj1-frontend-react-typescript  # Too long
qja temp                             # Too vague
qja f                                # Too short, unclear
```

### 2. Using Categories Effectively

**Strategy:** Use broad categories for filtering, specific aliases for jumping.

```powershell
# Good category structure
work/
  - shop-frontend
  - shop-backend
  - client-portal

personal/
  - blog
  - portfolio

learning/
  - tutorials
  - experiments
```

**Categories should:**

- Group related projects
- Be consistent (always plural or singular)
- Be broad enough to be useful (not too specific)

### 3. Maintenance

```powershell
# Periodically review saved paths
qjl

# Remove paths to deleted/moved projects
qjr -Interactive

# Update categories as projects evolve
qja old-alias -Category new-category -Force

# Check for unused paths
qjl | Where-Object { $_.UseCount -eq 0 }
```

### 4. Workflow Integration

```powershell
# Start of day: View recent paths
qjl -SortByRecent

# During work: Jump frequently
qj frontend
qj backend
qjrecent  # Quick toggle

# End of day: Review what you used
qjl -SortByMostUsed
```

---

## Common Pitfalls

### Pitfall 1: Alias Already Exists

**Problem:**

```powershell
qja frontend
# Error: Alias 'frontend' already exists
```

**Solution:**

```powershell
# Update with -Force
qja frontend -Force

# Or use a different alias
qja frontend-new

# Or check existing aliases first
qjl
```

### Pitfall 2: Path Not Found

**Problem:**

```powershell
qj myproject
# Error: No path found with alias 'myproject'
```

**Solution:**

```powershell
# Check what aliases exist
qjl

# Use tab completion (type qj my<Tab>)

# Use interactive finder
qj  # Then search for it
```

### Pitfall 3: fzf Not Installed

**Problem:**

```powershell
qj
# Error: fzf is not available
```

**Solution:**

```powershell
# Install fzf
scoop install fzf

# Or use aliases directly
qj myproject

# Or use non-interactive commands
qjl
```

### Pitfall 4: Removed Directory Still in QuickJump

**Problem:** You deleted a project folder, but QuickJump still has it saved.

**Solution:**

```powershell
# Remove the saved path
qjr -Alias old-project

# Or use interactive removal
qjr -Interactive
# Select the stale path and remove it
```

### Pitfall 5: Forgetting Aliases

**Problem:** You saved a path months ago, can't remember the alias.

**Solution:**

```powershell
# Use interactive finder (fuzzy search)
qj  # Then type partial name

# List all paths
qjl

# Search by category
qjl -Category work

# Or use category browser
qjc
```

---

## Tips & Tricks

### Tip 1: Quick Toggles

```powershell
# Toggle between two locations frequently
qj frontend
# ... do work ...
qj backend
# ... do work ...
qjrecent  # Back to frontend

# This creates a quick toggle between last two locations
```

### Tip 2: Hierarchical Organization

```powershell
# Use dash prefixes for hierarchy in aliases
qja shop-root       "C:\Projects\Shop" -Category shop
qja shop-front      "C:\Projects\Shop\Frontend" -Category shop
qja shop-front-src  "C:\Projects\Shop\Frontend\src" -Category shop
qja shop-back       "C:\Projects\Shop\Backend" -Category shop

# Easy to remember and tab-complete
qj shop-<Tab>  # Shows all shop- paths
```

### Tip 3: Temporary Paths

```powershell
# Save temporary paths for short-term projects
qja temp-fix "C:\Temp\BugFix" -Category temp

# Later, clean up temp category
qjl -Category temp | ForEach-Object { qjr -Alias $_.Alias }
```

### Tip 4: Path Aliases for Common Subfolders

```powershell
# Instead of navigating deep every time
cd C:\Projects\MyGame\Assets\Scripts\Player\Combat

# Save the deep folder
qja player-combat "C:\Projects\MyGame\Assets\Scripts\Player\Combat"

# Jump directly
qj player-combat
```

### Tip 5: Integration with VS Code

```powershell
# Open project in VS Code
code (qj myproject -Path)

# Or create a function in your profile
function Open-VSCode($alias) {
    code (qj $alias -Path)
}

# Usage
Open-VSCode myproject
```

### Tip 6: Backup and Restore

```powershell
# Backup your paths
Copy-Item (Get-QuickJumpConfigPath) `
    "quickjump-backup-$(Get-Date -Format 'yyyy-MM-dd').json"

# Restore from backup
Copy-Item "quickjump-backup-2025-10-01.json" (Get-QuickJumpConfigPath)
```

---

## Troubleshooting

### Issue: Commands Not Found

**Symptoms:** `qj : The term 'qj' is not recognized`

**Solution:**

```powershell
# Check if module is loaded
Get-Module QuickJump

# If not, load it manually
Import-Module "C:\Path\To\Modules\QuickJump"

# Check if it's in your profile
Get-Content $PROFILE
```

### Issue: Config File Corrupted

**Symptoms:** QuickJump commands fail with JSON parsing errors

**Solution:**

```powershell
# QuickJump automatically creates backups
# Check for backup files
Get-ChildItem "$(Get-QuickJumpConfigPath).backup.*"

# Manually restore from backup if needed
Copy-Item "$(Get-QuickJumpConfigPath).backup.20251015" (Get-QuickJumpConfigPath)
```

### Issue: Path Doesn't Navigate

**Symptoms:** `qj mypath` runs but doesn't change directory

**Solution:**

```powershell
# Verify the path exists
qjl | Where-Object { $_.Alias -eq 'mypath' }

# Check if directory still exists
Test-Path (qj mypath -Path)

# Update to current location if moved
cd "C:\NewLocation"
qja mypath -Force
```

### Issue: Tab Completion Not Working

**Symptoms:** Pressing Tab after `qj` doesn't show aliases

**Solution:**

```powershell
# Re-import module
Import-Module QuickJump -Force

# Restart PowerShell

# Check if argument completers are registered
Get-ArgumentCompleter -CommandName Invoke-QuickJump
```

### Issue: Interactive Mode Not Working

**Symptoms:** `qj` shows error or doesn't launch fzf

**Solution:**

```powershell
# Verify fzf is installed
fzf --version

# If not found, install it
scoop install fzf

# Restart PowerShell after installing

# Use alias-based navigation as fallback
qj myproject
```

---

## Configuration

### Config File Location

```powershell
# View config path
Get-QuickJumpConfigPath

# Open config file in editor
code (Get-QuickJumpConfigPath)

# View config directory
explorer (Get-QuickJumpConfigPath -ReturnDirectory)
```

Default location: `~\.config\quickjump\paths.json`

### Config File Structure

```json
{
  "paths": [
    {
      "path": "C:\\Projects\\Frontend",
      "alias": "frontend",
      "category": "work",
      "added": "2025-10-15 10:00:00",
      "lastUsed": "2025-10-15 14:30:00",
      "useCount": 47
    }
  ],
  "version": "1.0"
}
```

### Manual Editing

You can manually edit the config file, but:

**DO:**

- Keep valid JSON structure
- Use double backslashes in paths: `C:\\Path\\To\\Dir`
- Maintain the structure shown above

**DON'T:**

- Remove required fields (`path`, `alias`, etc.)
- Break JSON syntax (missing commas, brackets)
- Edit while QuickJump commands are running

---

## Quick Reference Card

```powershell
# Save paths
qja alias                        # Save current dir
qja alias -Category cat          # Save with category
qja alias "C:\Path"              # Save specific path

# Navigate
qj                               # Interactive (fzf)
qj alias                         # Jump to alias
qj -Category cat                 # Filter by category
qjrecent                         # Most recent

# List/Filter
qjl                              # List all
qjl -Category cat                # Filter category
qjl -SortByMostUsed              # Sort by usage
qjl -SortByRecent                # Sort by recent

# Remove
qjr -Alias alias                 # Remove by alias
qjr -Interactive                 # Interactive removal

# Browse
qjc                              # Category browser

# Advanced
qj alias -Path                   # Get path string
Get-QuickJumpConfigPath          # View config path
```

---

## Summary

**QuickJump makes directory navigation effortless:**

✅ Save paths once, jump to them forever
✅ Organize with categories
✅ Track usage automatically
✅ Fuzzy find with fzf
✅ Use in scripts and automation
✅ Share with your team

**Start simple:** Save a few frequently-used paths.
**Build gradually:** Add more as you work.
**Enjoy the speed:** Navigate in seconds, not minutes.

**→ [Back to Main README](../README.md)**
**→ [Troubleshooting Guide](troubleshooting.md)**
**→ [Command Reference](command-reference.md)**
