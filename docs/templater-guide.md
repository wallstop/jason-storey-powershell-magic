# Templater Guide

Templater accelerates project scaffolding by copying curated directories,
renaming files, and replacing tokens in one step.

## Overview

- **Use-Template** – deploys a template into a target folder with optional
  variable substitution.
- **Get-Templates** – lists available templates on disk.
- **Export-Templates / Import-Templates** – share templates as portable
  archives.
- **Update-Template** – refreshes a template after making improvements to an
  existing deployment.
- **Get-TemplateStats** – surfaces usage metrics and hash information.

All commands accept the fallback interactive mode when `fzf` is unavailable,
mirroring the QuickJump experience.

## Creating Templates

1. Prepare a directory tree that represents the desired starting point.
2. Add templater variables anywhere in file content or file names using the
   `{{VariableName}}` syntax.
3. Save the template:

   ```powershell
   Save-Template -Name 'dotnet-api' -Path 'C:\Scaffolding\DotNetWebApi'
   ```

4. (Optional) Provide default metadata in
   `%LOCALAPPDATA%\PowerShellMagic\templater\templates.json`.

## Deploying Templates

```powershell
Use-Template -Name 'dotnet-api' -Destination 'C:\Work\Contoso.Api' `
    -Variables @{ ProjectName = 'Contoso.Api'; Namespace = 'Contoso.Api' }
```

Key switches:

- `-Force` overwrites existing files when safe.
- `-Preview` simulates the deployment and prints planned operations.
- `-WhatIf` leverages PowerShell's built-in simulation mode.

## Sharing Templates

```powershell
Export-Templates -Name 'dotnet-api' -OutputPath .\build\templates.zip
Import-Templates -Path .\downloads\frontend-templates.zip
```

Exports include metadata, hash validation, and readme snippets. The test suite
(`Run-Tests.ps1 -TestName Templater`) covers round-trip scenarios.

## Troubleshooting

- Run `Get-TemplateStats` to inspect recorded hashes, usage counts, and source
  paths.
- Enable verbose logging for detailed copy diagnostics:

  ```powershell
  Use-Template -Name app -Destination .\app -Verbose
  ```

- If substitutions skip a file, ensure the file's encoding is UTF-8 or specify
  `-VariableExtensions` to explicitly include the extension.

For additional tips see [docs/examples.md](examples.md) and
[docs/troubleshooting.md](troubleshooting.md).
