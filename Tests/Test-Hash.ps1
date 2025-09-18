# Simple test for hash calculation
param([string]$FilePath)

# Set non-interactive mode to prevent blocking on prompts
$ErrorActionPreference = 'Continue'
$ConfirmPreference = 'None'

if (-not $FilePath) {
    Write-Host 'Usage: Test-Hash.ps1 <filepath>'
    exit 1
}

if (-not (Test-Path $FilePath)) {
    Write-Host "File not found: $FilePath"
    exit 1
}

Write-Host "Testing hash calculation for: $FilePath"

# Try Get-FileHash first
try {
    $hashResult = Get-FileHash -Path $FilePath -Algorithm SHA256 -ErrorAction Stop
    Write-Host "Get-FileHash result: $($hashResult.Hash)"
} catch {
    Write-Host "Get-FileHash failed: $($_.Exception.Message)"

    # Try .NET fallback
    try {
        Write-Host 'Trying .NET fallback...'
        $fileStream = [System.IO.File]::OpenRead($FilePath)
        try {
            $hasher = [System.Security.Cryptography.SHA256]::Create()
            $hashBytes = $hasher.ComputeHash($fileStream)
            $actualHash = [System.BitConverter]::ToString($hashBytes).Replace('-', '')
            Write-Host ".NET fallback result: $actualHash"
            $hasher.Dispose()
        } finally {
            $fileStream.Close()
        }
    } catch {
        Write-Host ".NET fallback failed: $($_.Exception.Message)"
    }
}