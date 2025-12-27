# Skill: Documentation

Use this skill when adding features, fixing bugs, or making any user-facing
changes. **Documentation is not optional**—every change that affects behavior
must be documented before the work is considered complete. Incomplete
documentation means incomplete work.

## Core Principle

> **Every change that affects users must be documented.**

This includes:

- New features or commands
- Changed behavior (even "improvements")
- Bug fixes that change observable behavior
- Removed or deprecated functionality
- Changed defaults or configuration options

## Documentation Artifacts

**All** of the following must be kept current and accurate:

| Artifact           | Location       | Purpose                           |
| ------------------ | -------------- | --------------------------------- |
| Markdown docs      | `docs/`        | User guides, tutorials, reference |
| Comment-based help | In cmdlets     | Parameter docs, examples, outputs |
| Code samples       | Throughout     | Working examples users can copy   |
| CHANGELOG          | `CHANGELOG.md` | Version history, upgrade notes    |
| Inline comments    | In code        | Explain "why" (sparingly)         |

## Documentation Checklist

After any feature or bug fix, update ALL of the following:

- [ ] **CHANGELOG.md** - User-facing changes in correct format
- [ ] **User docs** - Relevant guides in `docs/` folder
- [ ] **Command help** - Comment-based help in the cmdlet
- [ ] **Code samples** - All examples must be correct and tested
- [ ] **README.md** - If the change affects setup or overview
- [ ] **Version annotations** - Mark new behavior with version introduced

## CHANGELOG Requirements

**Every user-facing change must have a CHANGELOG entry.** No exceptions.

### Format

Follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format exactly:

```markdown
## [Unreleased]

### Added

- New `qjsearch` command for fuzzy searching across all saved paths
- `-Category` parameter for filtering saved paths by type

### Changed

- `qj` now displays path count in selection header
- Improved error messages when path doesn't exist

### Fixed

- QuickJump no longer fails when alias contains special characters (#42)
- Config file corruption when saving during concurrent access (#87)

### Deprecated

- `qj-old` will be removed in v3.0.0; use `qj` instead

### Removed

- Removed legacy `quickjump.json` migration code (deprecated in v2.0)

### Security

- Validate SHA256 hashes for all downloaded executables
```

### Entry Guidelines

| Do                               | Don't                              |
| -------------------------------- | ---------------------------------- |
| Start with action verb           | Start with "The" or "This"         |
| Be specific about what changed   | Be vague ("improved performance")  |
| Reference issue numbers (#42)    | Leave out context                  |
| Note breaking changes clearly    | Hide breaking changes in "Changed" |
| Keep entries concise (1-2 lines) | Write paragraphs                   |
| Explain user impact              | Describe implementation details    |

### Examples of Good Entries

```markdown
### Added

- `Get-QuickJumpStats` cmdlet to display usage statistics and path counts
- `-Recurse` parameter for `Remove-QuickJumpPath` to remove category and all
  paths

### Changed

- `Add-QuickJumpPath` now validates that the target path exists before saving
- Default config location changed from `~/.quickjump` to `~/.config/quickjump`

### Fixed

- Concurrent config updates no longer corrupt the JSON file on Windows (#87)
- Path completion now works with paths containing spaces (#92)
```

### Examples of Bad Entries

```markdown
### Changed

- Made improvements to the code ❌ (too vague, what improvements?)
- Updated QuickJump ❌ (what specifically changed?)
- Performance improvements ❌ (where? how much? what scenario?)
- Code cleanup ❌ (not user-facing, don't include)

### Fixed

- Fixed a bug ❌ (which bug? what was the symptom?)
- The path thing ❌ (not a sentence, completely unclear)
- Fixed issue ❌ (what issue? how did it manifest?)
```

### When NOT to Add CHANGELOG Entries

- Internal refactoring (no user-visible change)
- Test additions/fixes (unless fixing flaky public behavior)
- Documentation-only changes (except significant additions)
- CI/CD changes (unless affecting user installation)

## User Documentation (`docs/`)

### When to Update

| Change Type           | Files to Update                              |
| --------------------- | -------------------------------------------- |
| New QuickJump command | `quickjump-guide.md`, `command-reference.md` |
| New Templater command | `templater-guide.md`, `command-reference.md` |
| New Unitea command    | `unitea-guide.md`, `command-reference.md`    |
| Configuration change  | `configuration.md`                           |
| Installation change   | `installation.md`, `updating.md`             |
| Security-related      | `security.md`                                |

### Documentation Style

**Be clear and concise:**

````markdown
## Using QuickJump Categories

Organize saved paths into categories for easier navigation:

```powershell
# Save a path with a category
qja myproject -Category work

# List paths in a category
qjc work
```
````

Categories are case-insensitive. Paths can belong to only one category.

**NOT:**

```markdown
## Categories

QuickJump has a feature called categories. Categories are a way to organize your
paths. When you have lots of paths, you might want to use categories. Categories
can be really helpful for organization. To use categories, you need to specify a
category when you add a path... ❌ (too wordy)
```

### Code Sample Requirements

**Code samples are documentation. Broken samples are bugs.**

Every code sample in documentation must:

1. **Be correct** - Actually work when copy-pasted
2. **Be complete** - Include all necessary context
3. **Be tested** - Run the sample before committing
4. **Show output** - Include expected output where helpful
5. **Use realistic examples** - Not "foo", "bar", "test"
6. **Be current** - Reflect the latest behavior

#### Good Code Samples

```powershell
# Good: Realistic, shows expected output, complete
PS> qja ~/Projects/WebApp -Alias webapp -Category work
Saved 'webapp' → ~/Projects/WebApp (category: work)

PS> qj webapp
# Changes to ~/Projects/WebApp

# Good: Shows multiple related operations
PS> qjl -Category work
Alias    Path                    LastUsed
-----    ----                    --------
webapp   ~/Projects/WebApp       2024-01-15
api      ~/Projects/ApiServer    2024-01-14
```

#### Bad Code Samples

```powershell
# Bad: Unclear what happens, no output shown
PS> qja path alias  ❌

# Bad: Uses meaningless placeholder values
PS> Add-QuickJumpPath -Path "foo" -Alias "bar"  ❌

# Bad: Incomplete, missing required context
PS> qj myalias  ❌ (what's myalias? was it set up?)
```

#### Testing Code Samples

Before committing documentation with code samples:

```powershell
# 1. Copy each sample
# 2. Paste into a fresh PowerShell session
# 3. Verify it works exactly as documented
# 4. Verify the output matches

# If ANY sample doesn't work, fix it before committing
```

## Comment-Based Help (Cmdlets)

Every public cmdlet must have complete comment-based help:

```powershell
function Get-QuickJumpPath {
    <#
    .SYNOPSIS
    Retrieves saved QuickJump paths.

    .DESCRIPTION
    Returns all saved paths, or filters by alias, category, or search pattern.
    Results are sorted by most recently used by default.

    .PARAMETER Alias
    Filter by exact alias name. Supports wildcards.

    .PARAMETER Category
    Filter by category name. Case-insensitive.

    .EXAMPLE
    Get-QuickJumpPath
    Returns all saved paths sorted by recent usage.

    .EXAMPLE
    Get-QuickJumpPath -Alias "proj*"
    Returns all paths with aliases starting with "proj".

    .EXAMPLE
    Get-QuickJumpPath -Category work | Select-Object Alias, Path
    Lists all paths in the "work" category.

    .OUTPUTS
    PSCustomObject with Alias, Path, Category, LastUsed properties.

    .NOTES
    Alias: qjl
    #>
    [CmdletBinding()]
    param(
        # ... parameters
    )
}
```

### Help Requirements

| Section        | Required   | Purpose                       |
| -------------- | ---------- | ----------------------------- |
| `.SYNOPSIS`    | Yes        | One-line description          |
| `.DESCRIPTION` | Yes        | Detailed behavior explanation |
| `.PARAMETER`   | Yes (each) | Explain every parameter       |
| `.EXAMPLE`     | Yes (2-3)  | Show realistic usage          |
| `.OUTPUTS`     | Yes        | What the cmdlet returns       |
| `.NOTES`       | Optional   | Aliases, related commands     |

### Example Quality

Examples must be:

- **Realistic** - Use actual scenarios users would encounter
- **Progressive** - Start simple, add complexity
- **Annotated** - Brief comment explaining what happens

```powershell
.EXAMPLE
Get-QuickJumpPath -Category work | Remove-QuickJumpPath -Confirm
Removes all paths in the "work" category after confirmation prompts.
```

## Indicating New Behavior

When documenting new or changed behavior, **explicitly communicate that it's
new**. Users need to know what's changed so they can take advantage of new
features and understand any behavior differences.

### In CHANGELOG

The CHANGELOG naturally indicates new behavior via the appropriate section. Be
specific about what's new:

```markdown
### Added

- `Get-QuickJumpStats` cmdlet to display usage statistics and path counts
- `-Category` parameter for `Add-QuickJumpPath` to organize paths by type
- Fuzzy matching support in `qj` when multiple aliases match

### Changed

- `qj` now displays path count in selection header (was previously hidden)
- Default sort order changed from alphabetical to most-recently-used
```

### In User Docs

Add version annotations for significant new features:

````markdown
## Path Statistics _(Added in v2.3.0)_

View usage statistics for your saved paths:

```powershell
Get-QuickJumpStats
```
````

This shows total paths, categories, and most frequently used locations.

### In Command Help

Note version in `.NOTES` section:

```powershell
.NOTES
Added in version 2.3.0
Alias: qjstats
Related: Get-QuickJumpPath, Add-QuickJumpPath
```

### For Changed Behavior

If behavior changed from previous versions, explicitly document the change:

````markdown
> **Changed in v2.3.0:** The `-Force` parameter now skips both confirmation
> prompts and backup creation. Previously it only skipped confirmation.

### Migration Example

**Before (v2.2.x):**

```powershell
Remove-QuickJumpPath -Alias old -Force  # Still created backup
```
````

**After (v2.3.0):**

```powershell
Remove-QuickJumpPath -Alias old -Force  # No backup created
Remove-QuickJumpPath -Alias old -Force -Backup  # Use -Backup to keep old behavior
```

### For Breaking Changes

Breaking changes require prominent documentation:

1. **CHANGELOG**: Mark with `### Breaking Changes` or `### Removed`
2. **Migration guide**: Create or update `docs/upgrading.md`
3. **Command help**: Note in `.DESCRIPTION` and `.NOTES`
4. **Error messages**: Make breaking changes discoverable via helpful errors

## Common Documentation Mistakes

### 1. Missing Code Samples

❌ "Use the `-Category` parameter to filter by category."

✅ "Filter by category:

```powershell
qjl -Category work
# Returns only paths in the 'work' category
```

"

### 2. Outdated or Broken Examples

**Always verify code samples work with the current version. Run them.**

Signs of outdated examples:

- Parameter names changed
- Output format changed
- Function renamed or removed
- Default behavior changed

### 3. Assuming User Knowledge

❌ "Use fzf integration for selection."

✅ "When multiple paths match, QuickJump shows an interactive picker (requires
fzf). Select with arrow keys and press Enter:

````powershell
PS> qj proj
# If multiple aliases start with 'proj', shows interactive picker:
#   > projects
#     project-api
#     project-web
# Use arrow keys to select, Enter to confirm
```"

### 4. Missing Error Cases

Document what happens when things go wrong:

```markdown
### Error Handling

If the path doesn't exist:

```powershell
PS> qja /nonexistent/path -Alias test
Error: Path '/nonexistent/path' does not exist. Use -Force to save anyway.
````

If the alias already exists:

```powershell
PS> qja ~/Projects -Alias existing
Error: Alias 'existing' already exists (→ ~/Other). Use -Force to overwrite.
```

### 5. Forgetting Related Documentation

When adding a feature, check if it affects:

- Installation docs (new dependencies?)
- Configuration docs (new settings?)
- FAQ (common questions about the feature?)
- Troubleshooting (new error messages?)
- Command reference (new commands or parameters?)
- Examples page (new usage patterns?)

## Documentation Quality Standards

### Clarity

Documentation must be **immediately understandable** to someone new to the tool:

- Use simple, direct language
- Define terms before using them
- Provide context before details
- Lead with the most common use case

### Succinctness

**Say more with less.** Every word should earn its place:

❌ "QuickJump has a feature called categories. Categories are a way to organize
your paths. When you have lots of paths, you might want to use categories.
Categories can be really helpful for organization..."

✅ "**Categories** group related paths together:

```powershell
qja ~/Work/ProjectA -Category work
qja ~/Work/ProjectB -Category work
qjl -Category work  # Lists only work paths
```

"

### Accuracy

**Incorrect documentation is worse than no documentation.**

- Every code sample must work when copy-pasted
- Every description must match actual behavior
- Every parameter must be documented correctly
- Every output example must be real

### Completeness

Document the full picture:

- What it does (purpose)
- How to use it (syntax, parameters)
- Why you'd use it (use cases)
- What to expect (outputs, side effects)
- What can go wrong (errors, edge cases)

## Verification Steps

Before committing documentation changes:

```powershell
# 1. Spell-check markdown files
# (Use editor spell-check or aspell)

# 2. Test ALL code samples manually
# Copy-paste and run each example in a fresh session
# Verify output matches documentation

# 3. Verify markdown renders correctly
# Preview in VS Code or GitHub

# 4. Check link validity
.\Scripts\Test-MarkdownLinks.ps1

# 5. Ensure consistency with existing style
# Read adjacent sections for tone/format

# 6. Verify version annotations are present
# New features should mention version introduced
```

## Quick Reference

| What Changed          | Update These                                                         |
| --------------------- | -------------------------------------------------------------------- |
| New cmdlet            | CHANGELOG, module guide, command-reference, cmdlet help, examples    |
| New parameter         | CHANGELOG, cmdlet help, module guide (if significant)                |
| Bug fix               | CHANGELOG, troubleshooting (if relevant), code samples (if affected) |
| Changed default       | CHANGELOG, configuration, cmdlet help, migration notes               |
| New config option     | CHANGELOG, configuration.md, examples                                |
| Breaking change       | CHANGELOG (prominent), ALL affected docs, migration guide            |
| Changed output format | CHANGELOG, all examples showing old output                           |
| New error message     | Troubleshooting guide, FAQ (if common)                               |

## Summary Checklist

Before considering documentation complete:

- [ ] CHANGELOG entry added (if user-facing)
- [ ] User guide updated with new/changed behavior
- [ ] Command help complete (SYNOPSIS, DESCRIPTION, PARAMETERS, EXAMPLES)
- [ ] ALL code samples tested and working
- [ ] Version annotations added for new features
- [ ] Migration notes added for breaking changes
- [ ] Related documentation checked and updated
- [ ] Markdown renders correctly
- [ ] Links validated
