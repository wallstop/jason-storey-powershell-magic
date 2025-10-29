# PowerShell Basics

New to PowerShell? These resources will help you become comfortable with the
shell before diving into PowerShell Magic.

## Official Resources

- [PowerShell Documentation](https://learn.microsoft.com/powershell/)
- [PowerShell Gallery](https://www.powershellgallery.com/) – explore community
  modules and scripts.
- [PowerShell Samples](https://github.com/fleschutz/PowerShell) – hands-on code.

## Tutorials & Crash Courses

- [Microsoft Learn Paths](https://learn.microsoft.com/training/browse/?expanded=powershell&resource_type=learning%20path)
- [PowerShell 7 in a Nutshell](https://learnxinyminutes.com/docs/powershell/)
- [PowerShell + VS Code Setup](https://code.visualstudio.com/docs/languages/powershell)

## Essential Concepts

| Concept    | Why It Matters                                                       |
| ---------- | -------------------------------------------------------------------- |
| Profiles   | Store your preferred modules (`$PROFILE`).                           |
| Modules    | Package reusable functions (`Import-Module`, `Export-ModuleMember`). |
| Providers  | Navigate data stores as drives (`Get-PSDrive`).                      |
| Pipelining | Compose commands with `\|` to avoid temporary files.                 |
| Splatting  | Pass grouped parameters with `@{}` for readability.                  |

## Recommended Practice

- Explore tab completion and `Get-Help`.
- Write a simple script that uses parameters and `Write-Verbose`.
- Use `Set-StrictMode -Version Latest` in scripts to catch mistakes early.

Once you are comfortable with these fundamentals, head back to the PowerShell
Magic modules for a productivity boost.
