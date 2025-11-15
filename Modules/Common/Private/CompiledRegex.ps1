# CompiledRegex.ps1
# Pre-compiled regex patterns for improved performance across PowerShell Magic modules

# Module-level regex cache
if (-not $script:PSMagicCompiledRegex) {
    $script:PSMagicCompiledRegex = @{}
}

function Get-PSMagicCompiledRegex {
    <#
    .SYNOPSIS
    Gets or creates a compiled regex pattern for optimal performance.

    .DESCRIPTION
    Returns a compiled regex from cache if available, otherwise compiles and caches it.
    Compiled regex patterns offer significant performance improvements for frequently
    used patterns.

    .PARAMETER Pattern
    The regex pattern to compile

    .PARAMETER Options
    Regex options (e.g., IgnoreCase, Multiline). Defaults to None.

    .PARAMETER CacheKey
    Optional cache key. If not provided, uses the pattern as the key.

    .EXAMPLE
    $regex = Get-PSMagicCompiledRegex -Pattern '^\d{4}-\d{2}-\d{2}$'

    .EXAMPLE
    $regex = Get-PSMagicCompiledRegex -Pattern 'hello' -Options 'IgnoreCase'
    #>
    [CmdletBinding()]
    [OutputType([regex])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [System.Text.RegularExpressions.RegexOptions]$Options = [System.Text.RegularExpressions.RegexOptions]::None,

        [string]$CacheKey
    )

    if (-not $CacheKey) {
        $CacheKey = "$Pattern|$Options"
    }

    if ($script:PSMagicCompiledRegex.ContainsKey($CacheKey)) {
        Write-Verbose "Returning cached compiled regex for: $CacheKey"
        return $script:PSMagicCompiledRegex[$CacheKey]
    }

    try {
        # Add Compiled option for better performance
        $compiledOptions = $Options -bor [System.Text.RegularExpressions.RegexOptions]::Compiled

        $regex = [regex]::new($Pattern, $compiledOptions)
        $script:PSMagicCompiledRegex[$CacheKey] = $regex

        Write-Verbose "Compiled and cached regex for: $CacheKey"
        return $regex
    } catch {
        Write-Error "Failed to compile regex pattern '$Pattern': $($_.Exception.Message)"
        throw
    }
}

function Clear-PSMagicCompiledRegexCache {
    <#
    .SYNOPSIS
    Clears the compiled regex cache.

    .DESCRIPTION
    Removes all cached compiled regex patterns to free memory.

    .EXAMPLE
    Clear-PSMagicCompiledRegexCache
    #>
    [CmdletBinding()]
    param()

    $count = $script:PSMagicCompiledRegex.Count
    $script:PSMagicCompiledRegex = @{}
    Write-Verbose "Cleared $count compiled regex patterns from cache"
}

# Common regex patterns used across PowerShell Magic
function Get-PSMagicCommonRegex {
    <#
    .SYNOPSIS
    Returns commonly used compiled regex patterns.

    .PARAMETER Name
    Name of the common regex pattern to retrieve.

    .EXAMPLE
    $dateRegex = Get-PSMagicCommonRegex -Name 'ISODate'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet(
            'ISODate',
            'ISODateTime',
            'WindowsPath',
            'UnixPath',
            'EmailAddress',
            'TemplateToken',
            'YesNo',
            'TruthyValue',
            'UnityVersion',
            'SemanticVersion'
        )]
        [string]$Name
    )

    $patterns = @{
        # Date and time patterns
        'ISODate' = @{
            Pattern = '^\d{4}-\d{2}-\d{2}$'
            Options = [System.Text.RegularExpressions.RegexOptions]::None
        }
        'ISODateTime' = @{
            Pattern = '^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}$'
            Options = [System.Text.RegularExpressions.RegexOptions]::None
        }

        # Path patterns
        'WindowsPath' = @{
            Pattern = '^[a-zA-Z]:\\(?:[^\\/:*?"<>|\r\n]+\\)*[^\\/:*?"<>|\r\n]*$'
            Options = [System.Text.RegularExpressions.RegexOptions]::None
        }
        'UnixPath' = @{
            Pattern = '^/(?:[^/\0]+/)*[^/\0]*$'
            Options = [System.Text.RegularExpressions.RegexOptions]::None
        }

        # Email pattern (basic validation)
        'EmailAddress' = @{
            Pattern = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
            Options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        }

        # Template token pattern ({{VariableName}})
        'TemplateToken' = @{
            Pattern = '\{\{([a-zA-Z_][a-zA-Z0-9_]*)\}\}'
            Options = [System.Text.RegularExpressions.RegexOptions]::None
        }

        # Yes/No response pattern
        'YesNo' = @{
            Pattern = '^[YyNn]$'
            Options = [System.Text.RegularExpressions.RegexOptions]::None
        }

        # Truthy value pattern (1, true, yes, on)
        'TruthyValue' = @{
            Pattern = '^(1|true|yes|on)$'
            Options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        }

        # Unity version pattern (e.g., 2021.3.5f1)
        'UnityVersion' = @{
            Pattern = '^\d{4}\.\d+\.\d+[a-z]\d+$'
            Options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        }

        # Semantic version pattern (MAJOR.MINOR.PATCH)
        'SemanticVersion' = @{
            Pattern = '^\d+\.\d+\.\d+(?:-[a-zA-Z0-9]+(?:\.[a-zA-Z0-9]+)*)?$'
            Options = [System.Text.RegularExpressions.RegexOptions]::None
        }
    }

    if (-not $patterns.ContainsKey($Name)) {
        throw "Unknown common regex pattern: $Name"
    }

    $patternDef = $patterns[$Name]
    return Get-PSMagicCompiledRegex -Pattern $patternDef.Pattern -Options $patternDef.Options -CacheKey "Common:$Name"
}

# Performance test function
function Test-PSMagicRegexPerformance {
    <#
    .SYNOPSIS
    Tests the performance difference between compiled and non-compiled regex.

    .PARAMETER Pattern
    Regex pattern to test

    .PARAMETER TestString
    String to match against

    .PARAMETER Iterations
    Number of iterations for the test (default: 10000)

    .EXAMPLE
    Test-PSMagicRegexPerformance -Pattern '^\d{4}-\d{2}-\d{2}$' -TestString '2025-01-15' -Iterations 10000
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$TestString,

        [int]$Iterations = 10000
    )

    Write-Host "Testing regex performance with $Iterations iterations..." -ForegroundColor Cyan

    # Test non-compiled regex
    $nonCompiledTime = Measure-Command {
        for ($i = 0; $i -lt $Iterations; $i++) {
            $null = $TestString -match $Pattern
        }
    }

    # Test compiled regex
    $compiledRegex = Get-PSMagicCompiledRegex -Pattern $Pattern
    $compiledTime = Measure-Command {
        for ($i = 0; $i -lt $Iterations; $i++) {
            $null = $compiledRegex.IsMatch($TestString)
        }
    }

    $improvement = [math]::Round((($nonCompiledTime.TotalMilliseconds - $compiledTime.TotalMilliseconds) / $nonCompiledTime.TotalMilliseconds) * 100, 2)

    Write-Host "`nResults:" -ForegroundColor Green
    Write-Host "  Non-compiled: $($nonCompiledTime.TotalMilliseconds)ms" -ForegroundColor Gray
    Write-Host "  Compiled:     $($compiledTime.TotalMilliseconds)ms" -ForegroundColor Gray
    Write-Host "  Improvement:  $improvement%" -ForegroundColor Yellow

    return [PSCustomObject]@{
        Pattern = $Pattern
        Iterations = $Iterations
        NonCompiledMs = $nonCompiledTime.TotalMilliseconds
        CompiledMs = $compiledTime.TotalMilliseconds
        ImprovementPercent = $improvement
    }
}

Export-ModuleMember -Function @(
    'Get-PSMagicCompiledRegex',
    'Clear-PSMagicCompiledRegexCache',
    'Get-PSMagicCommonRegex',
    'Test-PSMagicRegexPerformance'
)
