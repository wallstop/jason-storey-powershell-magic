# Skill: Release and Versioning

Use this skill when preparing a release, bumping versions, or updating the
changelog.

## Version Files

The project tracks versions in two places:

- `version.txt` - Simple version string (e.g., `1.2.3`)
- `build/version.json` - Detailed version metadata

## Version Bumping

### Manual Version Update

1. Update `version.txt`:

   ```text
   1.2.4
   ```

1. Update `build/version.json`:

   ```json
   {
     "version": "1.2.4",
     "major": 1,
     "minor": 2,
     "patch": 4
   }
   ```

1. Update module manifests if needed (`ModuleVersion` in `.psd1` files)

### Semantic Versioning

Follow [SemVer](https://semver.org/):

| Change Type                        | Version Bump | Example       |
| ---------------------------------- | ------------ | ------------- |
| Breaking changes                   | Major        | 1.0.0 → 2.0.0 |
| New features (backward compatible) | Minor        | 1.0.0 → 1.1.0 |
| Bug fixes                          | Patch        | 1.0.0 → 1.0.1 |

## Changelog Updates

Update `CHANGELOG.md` with each release:

```markdown
## [1.2.4] - 2025-01-15

### Added

- New feature X in QuickJump module
- Support for Y in Templater

### Changed

- Improved performance of Z operation
- Updated dependency versions

### Fixed

- Bug where A caused B on Linux
- Issue with C not working when D

### Removed

- Deprecated function OldFunction
```

### Changelog Categories

- **Added** - New features
- **Changed** - Changes to existing functionality
- **Deprecated** - Features to be removed in future
- **Removed** - Removed features
- **Fixed** - Bug fixes
- **Security** - Security-related changes

### CHANGELOG Entry Quality

Each entry must be:

- **Specific** - Clearly state what changed
- **Action-oriented** - Start with verb (Added, Fixed, Changed)
- **User-focused** - Describe the impact, not implementation details
- **Referenced** - Include issue numbers where applicable

```markdown
# Good entries

- Added `Get-QuickJumpStats` cmdlet to display usage statistics
- Fixed concurrent config updates corrupting JSON file on Windows (#87)

# Bad entries

- Made improvements ❌ (too vague)
- Fixed bug ❌ (which bug?)
- Updated code ❌ (not user-focused)
```

See [documentation.md](documentation.md) for comprehensive documentation
standards.

## Module Manifest Versions

Each module has its own version in its `.psd1`:

```powershell
# Modules/QuickJump/QuickJump.psd1
@{
    ModuleVersion = '1.2.4'
    # ...
}
```

Keep module versions synchronized with the main project version unless a module
needs independent versioning.

## Pre-Release Checklist

```powershell
# 1. Ensure all tests pass
.\Run-Tests.ps1 -CI

# 2. Check formatting
.\Format-PowerShell.ps1 -Check

# 3. Verify module imports
Import-Module ./Modules/QuickJump -Force
Import-Module ./Modules/Templater -Force
Import-Module ./Modules/Unitea -Force

# 4. Check all commands are exported
Get-Command -Module QuickJump
Get-Command -Module Templater
Get-Command -Module Unitea
```

## Release Process

1. **Update version files**

   - `version.txt`
   - `build/version.json`
   - Module manifests (`.psd1`)

2. **Update CHANGELOG.md**

   - Add new version section
   - Document all changes since last release
   - Include date in ISO format

3. **Commit version bump**

   ```bash
   git add version.txt build/version.json CHANGELOG.md Modules/**/*.psd1
   git commit -m "chore: bump version to 1.2.4"
   ```

4. **Create git tag**

   ```bash
   git tag -a v1.2.4 -m "Release v1.2.4"
   ```

5. **Push with tags**

   ```bash
   git push origin main --tags
   ```

## Publishing to PowerShell Gallery

See [docs/publishing.md](../../docs/publishing.md) for detailed instructions on
publishing modules to the PowerShell Gallery.

Quick overview:

```powershell
# Test the module first
Test-ModuleManifest -Path ./Modules/QuickJump/QuickJump.psd1

# Publish (requires API key)
Publish-Module -Path ./Modules/QuickJump -NuGetApiKey $apiKey
```

## Checklist

- [ ] All tests pass (`.\Run-Tests.ps1 -CI`)
- [ ] Formatting is clean (`.\Format-PowerShell.ps1 -Check`)
- [ ] `version.txt` updated
- [ ] `build/version.json` updated
- [ ] Module manifests updated (`.psd1` files)
- [ ] **`CHANGELOG.md` complete** with ALL changes since last release
- [ ] **User documentation updated** for all new/changed features
- [ ] **Code samples verified** - all examples tested and working
- [ ] **command-reference.md current** with all commands
- [ ] Commit message follows conventions
- [ ] Git tag created

See [documentation.md](documentation.md) for documentation standards.
