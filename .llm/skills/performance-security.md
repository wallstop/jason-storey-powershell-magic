# Skill: Performance and Security

Use this skill when optimizing PowerShell code for performance or implementing
security best practices. For defensive coding patterns, see
[defensive-powershell.md](defensive-powershell.md).

## Performance Hierarchy

From fastest to slowest:

1. **Language constructs** (`foreach`, `if`, `switch`)
2. **.NET Framework methods**
3. **PowerShell script operations**
4. **Pipeline/cmdlet calls**

Choose based on context: pipelines are more readable; raw .NET is faster for hot
paths.

## Collection Performance

### Use Generic List Instead of Array Concatenation

```powershell
# ❌ SLOW: Array concatenation (O(n²) - creates new array each time)
$array = @()
foreach ($item in $source) {
    $array += $item  # Creates new array every iteration!
}

# ✅ FAST: Generic List with pre-allocation
$list = [System.Collections.Generic.List[string]]::new($source.Count)
foreach ($item in $source) {
    $list.Add($item)
}
$result = $list.ToArray()

# ✅ FAST: ArrayList (if types vary)
$list = [System.Collections.ArrayList]::new()
foreach ($item in $source) {
    [void]$list.Add($item)
}
```

### Use foreach Statement Over ForEach-Object

```powershell
# ❌ SLOWER: Pipeline overhead
$collection | ForEach-Object { Process-Item $_ }

# ✅ FASTER: foreach statement
foreach ($item in $collection) {
    Process-Item $item
}
```

**Exception**: Pipelines are fine for readability when performance isn't
critical.

## String Performance

### Use StringBuilder for Multiple Concatenations

```powershell
# ❌ SLOW: String concatenation in loop
$result = ""
foreach ($line in $lines) {
    $result += "$line`n"  # Creates new string each time
}

# ✅ FAST: StringBuilder
$sb = [System.Text.StringBuilder]::new()
foreach ($line in $lines) {
    [void]$sb.AppendLine($line)
}
$result = $sb.ToString()
```

### Use -join for Simple Cases

```powershell
# ✅ Efficient for joining arrays
$result = $lines -join "`n"
```

## File Operations

### Use StreamReader for Large Files

```powershell
# ❌ SLOW: Loads entire file into memory
$content = Get-Content -Path $path
foreach ($line in $content) { ... }

# ✅ FAST: Stream processing (memory efficient)
$reader = [System.IO.StreamReader]::new($path)
try {
    while ($null -ne ($line = $reader.ReadLine())) {
        # Process line
    }
}
finally {
    $reader.Close()
}

# ✅ ALTERNATIVE: Pipeline streaming (built-in)
Get-Content -Path $path -ReadCount 1000 | ForEach-Object {
    foreach ($line in $_) {
        # Process line
    }
}
```

### Use -Raw for Single-Read Operations

```powershell
# When you need entire file content
$content = Get-Content -Path $path -Raw
```

## Pipeline Optimization

### Filter Early, Select Properties Early

```powershell
# ❌ INEFFICIENT: Filtering late, passing full objects
Get-Process | Select-Object * | Where-Object { $_.CPU -gt 100 }

# ✅ EFFICIENT: Filter first, select only needed properties
Get-Process | Where-Object { $_.CPU -gt 100 } | Select-Object Name, CPU
```

### Avoid Pipeline for Simple Lookups

```powershell
# ❌ SLOW: Pipeline for simple check
$exists = $collection | Where-Object { $_.Name -eq $target } | Select-Object -First 1

# ✅ FAST: Direct lookup
$exists = $collection.Where({ $_.Name -eq $target }, 'First')

# ✅ FAST: Hashtable lookup (best for repeated lookups)
$lookup = @{}
foreach ($item in $collection) {
    $lookup[$item.Name] = $item
}
$exists = $lookup[$target]
```

## Measure Before Optimizing

Always measure actual performance impact:

```powershell
# Measure single operation
Measure-Command {
    # Code to benchmark
}

# Compare approaches
$results = @{
    'Pipeline'  = (Measure-Command { $data | ForEach-Object { $_ } }).TotalMilliseconds
    'Foreach'   = (Measure-Command { foreach ($item in $data) { $item } }).TotalMilliseconds
}
$results | Format-Table -AutoSize
```

---

## Security Best Practices

### Credential Handling

### Always Use PSCredential Type

```powershell
# ✅ CORRECT: PSCredential parameter
param(
    [Parameter()]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential
)

# ❌ NEVER: Plain text password parameters
param(
    [string]$Password  # NEVER DO THIS
)
```

### Prompt for Credentials

```powershell
# Interactive credential prompt
$cred = Get-Credential -Message "Enter admin credentials"

# Use credential
Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock { ... }
```

### Secure Credential Storage

```powershell
# Save credentials securely (DPAPI-encrypted, user/machine specific)
$Credential | Export-Clixml -Path "$env:USERPROFILE\.creds\service.xml"

# Load credentials
$Credential = Import-Clixml -Path "$env:USERPROFILE\.creds\service.xml"
```

### Access Password Only When Needed

```powershell
# Decrypt only at point of use, don't store in variable
$api.Authenticate($Credential.GetNetworkCredential().Password)
```

## Avoid Dangerous Patterns

### Never Use Invoke-Expression with User Input

```powershell
# ❌ DANGEROUS: Code injection vulnerability
$command = Read-Host "Enter command"
Invoke-Expression $command

# ❌ DANGEROUS: Even with "validation"
$fileName = Read-Host "Enter file name"
Invoke-Expression "Get-Content -Path '$fileName'"

# ✅ SAFE: Use proper parameters
$fileName = Read-Host "Enter file name"
Get-Content -Path $fileName
```

### Never Use ConvertTo-SecureString with Plain Text

```powershell
# ❌ AVOID: Defeats the purpose of SecureString
$password = ConvertTo-SecureString "MyPassword" -AsPlainText -Force

# ✅ BETTER: Prompt for secure input
$password = Read-Host -Prompt "Password" -AsSecureString

# ✅ BEST: Use PSCredential
$cred = Get-Credential
```

### Never Hardcode Sensitive Values

```powershell
# ❌ NEVER: Hardcoded values
$server = "prod-sql-01"
$apiKey = "sk-1234567890abcdef"

# ✅ CORRECT: Configuration or environment
$server = $env:SQL_SERVER ?? (Get-ConfigValue -Key 'SqlServer')
$apiKey = Get-Secret -Name 'ApiKey' -Vault 'MyVault'
```

## Script Signing

### Sign Production Scripts

```powershell
# Get code signing certificate
$cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert

# Sign script
Set-AuthenticodeSignature -FilePath .\script.ps1 -Certificate $cert

# Verify signature
Get-AuthenticodeSignature -FilePath .\script.ps1
```

### Set Appropriate Execution Policy

```powershell
# For development
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# For production (requires signed scripts)
Set-ExecutionPolicy -ExecutionPolicy AllSigned -Scope LocalMachine
```

## Logging and Auditing

### Use Transcript Logging

```powershell
# Start logging at script beginning
$logPath = Join-Path $env:TEMP "ScriptLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Start-Transcript -Path $logPath

try {
    # Script logic here
}
finally {
    Stop-Transcript
}
```

### Log Critical Operations

```powershell
function Write-AuditLog {
    param(
        [string]$Action,
        [string]$Target,
        [string]$Result
    )

    $entry = [PSCustomObject]@{
        Timestamp = Get-Date -Format 'o'
        User      = $env:USERNAME
        Action    = $Action
        Target    = $Target
        Result    = $Result
    }

    $entry | Export-Csv -Path $auditLogPath -Append -NoTypeInformation
}
```

## PSScriptAnalyzer Security Rules

Enable these rules in your PSScriptAnalyzer configuration:

```powershell
@{
    Rules = @{
        # Security rules
        PSAvoidUsingPlainTextForPassword = @{ Enable = $true }
        PSAvoidUsingConvertToSecureStringWithPlainText = @{ Enable = $true }
        PSAvoidUsingUsernameAndPasswordParams = @{ Enable = $true }
        PSAvoidUsingInvokeExpression = @{ Enable = $true }
        PSAvoidUsingComputerNameHardcoded = @{ Enable = $true }
        PSUsePSCredentialType = @{ Enable = $true }
    }
}
```

## Cross-Platform Security

### Path Handling

```powershell
# ✅ CORRECT: Cross-platform paths
$configPath = Join-Path -Path $HOME -ChildPath '.config' -AdditionalChildPath 'myapp'

# ❌ AVOID: Hardcoded path separators
$path = "$HOME\Documents\file.txt"  # Fails on Linux/macOS
```

### Platform Detection

```powershell
if ($IsWindows) {
    # Windows-specific security (DPAPI, ACLs, etc.)
} elseif ($IsLinux -or $IsMacOS) {
    # Unix-specific security (chmod, etc.)
}

# PowerShell 5.1 compatibility (always Windows)
if ($PSVersionTable.PSVersion.Major -lt 6) {
    # Must be Windows
}
```

---

## Quick Reference: Performance Checklist

- [ ] Use `[List[T]]` instead of `$array += $item`
- [ ] Use `foreach` statement for performance-critical loops
- [ ] Use `StringBuilder` for string concatenation in loops
- [ ] Use `StreamReader` for large file processing
- [ ] Filter and select properties early in pipelines
- [ ] Use hashtables for repeated lookups
- [ ] Measure performance before and after optimization

## Quick Reference: Security Checklist

- [ ] Use `PSCredential` type for all credential parameters
- [ ] Never hardcode passwords, API keys, or server names
- [ ] Never use `Invoke-Expression` with user input
- [ ] Use `Export-Clixml` for secure credential storage
- [ ] Enable PSScriptAnalyzer security rules
- [ ] Sign scripts for production deployment
- [ ] Implement transcript logging for auditing
- [ ] Use cross-platform path handling
