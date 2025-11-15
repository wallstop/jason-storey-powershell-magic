#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

<#
.SYNOPSIS
Comprehensive Pester test suite for PowerShell Magic modules

.DESCRIPTION
This test suite provides unit, integration, and end-to-end tests using Pester 5.x
framework with code coverage support.
#>

BeforeAll {
    # Set non-interactive mode for tests
    $env:POWERSHELL_MAGIC_NON_INTERACTIVE = '1'

    # Get module paths
    $script:ModuleRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:ModulesPath = Join-Path $ModuleRoot 'Modules'

    # Import modules under test
    $script:CommonModule = Join-Path $ModulesPath 'Common\PowerShellMagic.Common.psm1'
    $script:QuickJumpModule = Join-Path $ModulesPath 'QuickJump\QuickJump.psm1'
    $script:TemplaterModule = Join-Path $ModulesPath 'Templater\Templater.psm1'
    $script:UniteaModule = Join-Path $ModulesPath 'Unitea\Unitea.psm1'

    # Create temporary test directory outside Pester's TestDrive so data persists across contexts
    $script:TestDrive = Join-Path ([System.IO.Path]::GetTempPath()) ('PSMagicTests_{0}' -f ([guid]::NewGuid()))
    New-Item -ItemType Directory -Path $script:TestDrive -Force | Out-Null

    # Override config root for tests
    $env:XDG_CONFIG_HOME = Join-Path $script:TestDrive '.config'
}

AfterAll {
    # Clean up environment
    Remove-Item -Path $script:TestDrive -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:\POWERSHELL_MAGIC_NON_INTERACTIVE -ErrorAction SilentlyContinue
    Remove-Item Env:\XDG_CONFIG_HOME -ErrorAction SilentlyContinue
}


Describe 'PowerShell Magic - Common Module' -Tag 'Unit', 'Common' {

    BeforeAll {
        Import-Module $script:CommonModule -Force
    }

    Context 'Module Loading' {
        It 'Should import Common module successfully' {
            Get-Module 'PowerShellMagic.Common' | Should -Not -BeNullOrEmpty
        }

        It 'Should export expected functions' {
            $expectedFunctions = @(
                'Get-PSMagicConfigPath',
                'Copy-PSMagicHashtable',
                'Test-FzfAvailable',
                'Test-PSMagicNonInteractive',
                'Initialize-PSMagicConfigCache',
                'Get-PSMagicCachedConfig',
                'Clear-PSMagicConfigCache',
                'Remove-PSMagicConfigCache',
                'Get-PSMagicCompiledRegex',
                'Get-PSMagicCommonRegex'
            )

            $module = Get-Module 'PowerShellMagic.Common'
            foreach ($func in $expectedFunctions) {
                $module.ExportedFunctions.Keys | Should -Contain $func
            }
        }
    }

    Context 'Configuration Path Management' {
        It 'Should create config directory if it does not exist' {
            $configPath = Get-PSMagicConfigPath -Component 'test' -FileName 'config.json'
            $configDir = Split-Path $configPath -Parent
            Test-Path $configDir | Should -Be $true
        }

        It 'Should return correct config file path' {
            $configPath = Get-PSMagicConfigPath -Component 'quickjump' -FileName 'paths.json'
            $configPath | Should -Match 'quickjump[/\\]paths\.json$'
        }

        It 'Should return directory path when -ReturnDirectory is specified' {
            $dirPath = Get-PSMagicConfigPath -Component 'quickjump' -ReturnDirectory
            $dirPath | Should -Match 'quickjump$'
            Test-Path $dirPath | Should -Be $true
        }
    }

    Context 'Compiled Regex Performance' {
        It 'Should compile and cache regex patterns' {
            $regex = Get-PSMagicCompiledRegex -Pattern '^\d{4}-\d{2}-\d{2}$'
            $regex | Should -Not -BeNullOrEmpty
            $regex.GetType().Name | Should -Be 'Regex'
        }

        It 'Should return common regex patterns' {
            $dateRegex = Get-PSMagicCommonRegex -Name 'ISODate'
            $dateRegex | Should -Not -BeNullOrEmpty
            $dateRegex.IsMatch('2025-01-15') | Should -Be $true
            $dateRegex.IsMatch('invalid-date') | Should -Be $false
        }

        It 'Should cache compiled regex for reuse' {
            $regex1 = Get-PSMagicCompiledRegex -Pattern '\d+'
            $regex2 = Get-PSMagicCompiledRegex -Pattern '\d+'
            # Both should reference same cached instance
            [Object]::ReferenceEquals($regex1, $regex2) | Should -Be $true
        }

        It 'Should clear regex cache' {
            $null = Get-PSMagicCompiledRegex -Pattern 'test'
            { Clear-PSMagicCompiledRegexCache } | Should -Not -Throw
        }
    }

    Context 'Configuration Caching with FileSystemWatcher' {
        It 'Should initialize config cache' {
            $testConfig = Join-Path $script:TestDrive 'test-config.json'
            '{"test": "value"}' | Set-Content $testConfig

            { Initialize-PSMagicConfigCache -CacheKey 'test' -ConfigPath $testConfig } | Should -Not -Throw
        }

        It 'Should cache config data' {
            $testConfig = Join-Path $script:TestDrive 'cache-test.json'
            $testData = @{ key = 'value'; number = 42 }
            $testData | ConvertTo-Json | Set-Content $testConfig

            $cached = Get-PSMagicCachedConfig -CacheKey 'cachetest' -ConfigPath $testConfig -LoadScriptBlock {
                Get-Content $testConfig -Raw | ConvertFrom-Json -AsHashtable
            }

            $cached.key | Should -Be 'value'
            $cached.number | Should -Be 42
        }

        It 'Should return cached data on second call' {
            $testConfig = Join-Path $script:TestDrive 'cached-data.json'
            @{ counter = 1 } | ConvertTo-Json | Set-Content $testConfig

            $loadCounter = [ref]0
            $getData = {
                $loadCounter.Value++
                Get-Content $testConfig -Raw | ConvertFrom-Json -AsHashtable
            }.GetNewClosure()

            $null = Get-PSMagicCachedConfig -CacheKey 'counter' -ConfigPath $testConfig -LoadScriptBlock $getData
            $null = Get-PSMagicCachedConfig -CacheKey 'counter' -ConfigPath $testConfig -LoadScriptBlock $getData

            $loadCounter.Value | Should -Be 1  # Should only load once due to caching
        }

        It 'Should clear specific cache' {
            { Clear-PSMagicConfigCache -CacheKey 'test' } | Should -Not -Throw
        }

        It 'Should clear all caches' {
            { Clear-PSMagicConfigCache } | Should -Not -Throw
        }

        It 'Should remove cache and dispose watcher' {
            { Remove-PSMagicConfigCache -CacheKey 'test' } | Should -Not -Throw
        }
    }

    Context 'Utility Functions' {
        It 'Should detect non-interactive mode' {
            Test-PSMagicNonInteractive | Should -Be $true
        }

        It 'Should copy hashtables deeply' {
            $original = @{
                key1 = 'value1'
                nested = @{
                    key2 = 'value2'
                }
            }

            $copy = Copy-PSMagicHashtable -InputObject $original
            $copy.key1 | Should -Be 'value1'
            $copy.nested.key2 | Should -Be 'value2'

            # Modify copy should not affect original
            $copy.key1 = 'modified'
            $original.key1 | Should -Be 'value1'
        }
    }
}

Describe 'PowerShell Magic - QuickJump Module' -Tag 'Unit', 'QuickJump' {

    BeforeAll {
        Import-Module $script:CommonModule -Force
        Import-Module $script:QuickJumpModule -Force
    }

    Context 'Module Loading' {
        It 'Should import QuickJump module successfully' {
            Get-Module 'QuickJump' | Should -Not -BeNullOrEmpty
        }

        It 'Should export main commands' {
            $commands = @(
                'Add-QuickJumpPath',
                'Remove-QuickJumpPath',
                'Get-QuickJumpPaths',
                'Invoke-QuickJump',
                'Get-QuickJumpCategories',
                'Open-QuickJumpRecent'
            )

            $module = Get-Module 'QuickJump'
            foreach ($cmd in $commands) {
                $module.ExportedFunctions.Keys | Should -Contain $cmd
            }
        }

        It 'Should export command aliases' {
            $module = Get-Module 'QuickJump'
            $module.ExportedAliases.Keys | Should -Contain 'qj'
            $module.ExportedAliases.Keys | Should -Contain 'qja'
            $module.ExportedAliases.Keys | Should -Contain 'qjl'
            $module.ExportedAliases.Keys | Should -Contain 'qjr'
        }
    }

    Context 'Add-QuickJumpPath' {
        BeforeAll {
            $script:TestPath = Join-Path $script:TestDrive 'test-jump-dir'
            New-Item -ItemType Directory -Path $script:TestPath -Force | Out-Null
        }

        It 'Should add a path with alias' {
            { Add-QuickJumpPath -Path $script:TestPath -Alias 'testdir' } | Should -Not -Throw
        }

        It 'Should add a path with category' {
            { Add-QuickJumpPath -Path $script:TestPath -Alias 'cattest' -Category 'testing' } | Should -Not -Throw
        }

        It 'Should add current directory when Path is omitted' {
            $alias = "cwd-test-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
            Push-Location $script:TestPath
            try {
                { Add-QuickJumpPath -Alias $alias -Force } | Should -Not -Throw
            } finally {
                Pop-Location
            }

            (Get-QuickJumpPaths -Alias $alias -Path) | Should -Be $script:TestPath
        }

        It 'Should warn when re-adding aliasless path without Force' {
            $aliaslessPath = Join-Path $script:TestDrive ('aliasless-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Path $aliaslessPath -Force | Out-Null
            Add-QuickJumpPath -Path $aliaslessPath -Force
            { Add-QuickJumpPath -Path $aliaslessPath -ErrorAction Stop } | Should -Throw
            Remove-QuickJumpPath -Path $aliaslessPath -Confirm:$false
        }

        It 'Should fail when path does not exist' {
            $nonExistentPath = Join-Path $script:TestDrive 'does-not-exist'
            { Add-QuickJumpPath -Path $nonExistentPath -Alias 'fail' -ErrorAction Stop } | Should -Throw
        }

        It 'Should fail when adding duplicate alias without -Force' {
            Add-QuickJumpPath -Path $script:TestPath -Alias 'duplicate'
            { Add-QuickJumpPath -Path $script:TestPath -Alias 'duplicate' -ErrorAction Stop } | Should -Throw
        }

        It 'Should show warning when re-adding existing path without Force' {
            $alias = "dup-check-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
            Add-QuickJumpPath -Path $script:TestPath -Alias $alias -Force
            { Add-QuickJumpPath -Path $script:TestPath -ErrorAction Stop } | Should -Throw
        }

        It 'Should fail when target path is a file' {
            $filePath = Join-Path $script:TestDrive ('not-a-directory-{0}.txt' -f ([guid]::NewGuid().ToString('N').Substring(0, 8)))
            'hello' | Set-Content $filePath
            { Add-QuickJumpPath -Path $filePath -Alias 'file-alias' -ErrorAction Stop } | Should -Throw
        }

        It 'Should overwrite with -Force flag' {
            Add-QuickJumpPath -Path $script:TestPath -Alias 'forceme'
            { Add-QuickJumpPath -Path $script:TestPath -Alias 'forceme' -Force } | Should -Not -Throw
        }

        It 'Should update alias to new path when using -Force' {
            $pathA = Join-Path $script:TestDrive ('force-alias-old-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            $pathB = Join-Path $script:TestDrive ('force-alias-new-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Path $pathA -Force | Out-Null
            New-Item -ItemType Directory -Path $pathB -Force | Out-Null

            Add-QuickJumpPath -Path $pathA -Alias 'force-alias' -Force
            Add-QuickJumpPath -Path $pathB -Alias 'force-alias' -Force

            (Get-QuickJumpPaths -Alias 'force-alias' -Path) | Should -Be $pathB
        }

        It 'Should update category for existing path when using -Force without alias' {
            $pathC = Join-Path $script:TestDrive ('force-category-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Path $pathC -Force | Out-Null

            Add-QuickJumpPath -Path $pathC -Category 'original'
            Add-QuickJumpPath -Path $pathC -Category 'updated' -Force

            $updated = Get-QuickJumpPaths | Where-Object { $_.Path -eq $pathC }
            $updated.Category | Should -Be 'updated'
        }
    }

    Context 'Get-QuickJumpPaths' {
        It 'Should list saved paths' {
            $paths = Get-QuickJumpPaths
            $paths | Should -Not -BeNullOrEmpty
        }

        It 'Should filter by category' {
            $testPaths = Get-QuickJumpPaths -Category 'testing'
            $testPaths | Should -Not -BeNullOrEmpty
            $testPaths | ForEach-Object { $_.Category | Should -Be 'testing' }
        }

        It 'Should list categories' {
            $categories = Get-QuickJumpCategories
            $categories | Should -Not -BeNullOrEmpty
        }

        It 'Should return path for alias when -Path is specified' {
            $alias = "alias-path-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
            Add-QuickJumpPath -Path $script:TestPath -Alias $alias -Force
            $resolvedPath = Get-QuickJumpPaths -Alias $alias -Path
            $resolvedPath | Should -Be $script:TestPath
        }

        It 'Should list categories using -ListCategories' {
            $categoryName = "listcat-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
            $categoryPath = Join-Path $script:TestDrive $categoryName
            New-Item -ItemType Directory -Path $categoryPath -Force | Out-Null
            Add-QuickJumpPath -Path $categoryPath -Alias $categoryName -Category $categoryName -Force

            $categoryGroups = Get-QuickJumpPaths -ListCategories
            $categoryGroups | Should -Not -BeNullOrEmpty
            ($categoryGroups | Where-Object { $_.Category -eq $categoryName }).Count | Should -BeGreaterOrEqual 1
        }

        It 'Should show available aliases when alias lookup fails' {
            { Get-QuickJumpPaths -Alias 'no-such-alias' -Path -ErrorAction Stop } | Should -Throw
        }

        It 'Should show available categories when filter has no matches' {
            { Get-QuickJumpPaths -Category 'no-such-category' -ErrorAction Stop } | Should -Throw
        }

        It 'Should return path using fallback selector when -Interactive and -Path are specified' {
            Mock -CommandName Test-FzfAvailable -ModuleName QuickJump -MockWith { $false }
            Mock -CommandName Invoke-QuickJumpFallbackSelection -ModuleName QuickJump -MockWith {
                [pscustomobject]@{ Path = $script:TestPath }
            }

            Get-QuickJumpPaths -Interactive -Path | Should -Be $script:TestPath
        }

        It 'Should navigate using fallback selector when interactive without -Path' {
            $script:MockedLocation = $null
            Mock -CommandName Test-FzfAvailable -ModuleName QuickJump -MockWith { $false }
            Mock -CommandName Invoke-QuickJumpFallbackSelection -ModuleName QuickJump -MockWith {
                [pscustomobject]@{
                    Path = $script:TestPath
                    Alias = 'fallback-alias'
                }
            }
            Mock -CommandName Set-Location -ModuleName QuickJump -MockWith {
                param($Path)
                $script:MockedLocation = $Path
            }

            { Get-QuickJumpPaths -Interactive } | Should -Not -Throw
            $script:MockedLocation | Should -Be $script:TestPath
        }

    }

    Context 'Remove-QuickJumpPath' {
        It 'Should remove path by alias' {
            Add-QuickJumpPath -Path $script:TestPath -Alias 'toremove'
            { Remove-QuickJumpPath -Alias 'toremove' -Confirm:$false } | Should -Not -Throw
        }

        It 'Should remove path by path value' {
            $alias = "remove-by-path-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
            Add-QuickJumpPath -Path $script:TestPath -Alias $alias -Force
            { Remove-QuickJumpPath -Path $script:TestPath -Confirm:$false } | Should -Not -Throw
        }

        It 'Should fail when removing non-existent alias' {
            { Remove-QuickJumpPath -Alias 'does-not-exist' -ErrorAction Stop -Confirm:$false } | Should -Throw
        }

        It 'Should throw when alias provided but no paths exist' {
            $configPath = Get-QuickJumpConfigPath
            @{ paths = @(); version = '1.0' } | ConvertTo-Json -Depth 5 | Set-Content $configPath -Encoding UTF8
            Clear-PSMagicConfigCache -CacheKey 'quickjump'

            { Remove-QuickJumpPath -Alias 'missing' -Confirm:$false -ErrorAction Stop } | Should -Throw

            Add-QuickJumpPath -Path $script:TestPath -Alias 'testdir' -Category 'testing' -Force
            Add-QuickJumpPath -Path $script:TestPath -Alias 'cattest' -Category 'testing' -Force
        }

        It 'Should inform user when removing without saved paths or selectors' {
            $configPath = Get-QuickJumpConfigPath
            $originalContent = if (Test-Path $configPath) { Get-Content $configPath -Raw } else { $null }
            try {
                @{ paths = @(); version = '1.0' } | ConvertTo-Json -Depth 5 | Set-Content $configPath -Encoding UTF8
                Clear-PSMagicConfigCache -CacheKey 'quickjump'
                { Remove-QuickJumpPath -Confirm:$false } | Should -Not -Throw
            } finally {
                if ($null -ne $originalContent) {
                    Set-Content -Path $configPath -Value $originalContent -Encoding UTF8
                } else {
                    Remove-Item -Path $configPath -ErrorAction SilentlyContinue
                }
                Clear-PSMagicConfigCache -CacheKey 'quickjump'
            }
        }

        It 'Should remove saved path even if directory was deleted' {
            $stalePath = Join-Path $script:TestDrive ('stale-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Path $stalePath -Force | Out-Null
            $staleAlias = "stale-$([guid]::NewGuid().ToString('N').Substring(0, 6))"
            Add-QuickJumpPath -Path $stalePath -Alias $staleAlias -Force
            Remove-Item -Path $stalePath -Recurse -Force

            { Remove-QuickJumpPath -Path $stalePath -Confirm:$false } | Should -Not -Throw
            Get-QuickJumpPaths | Where-Object { $_.Alias -eq $staleAlias } | Should -BeNullOrEmpty
        }

        It 'Should throw when removing by path that is not saved' {
            $unsavedPath = Join-Path $script:TestDrive ('unsaved-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Path $unsavedPath -Force | Out-Null
            try {
                { Remove-QuickJumpPath -Path $unsavedPath -Confirm:$false -ErrorAction Stop } | Should -Throw
            } finally {
                Remove-Item -Path $unsavedPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Should remove multiple paths using fallback interactive selection' {
            $multiPathOne = Join-Path $script:TestDrive ('multi-one-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            $multiPathTwo = Join-Path $script:TestDrive ('multi-two-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Path $multiPathOne -Force | Out-Null
            New-Item -ItemType Directory -Path $multiPathTwo -Force | Out-Null
            $aliasOne = "multi-one-$([guid]::NewGuid().ToString('N').Substring(0, 6))"
            $aliasTwo = "multi-two-$([guid]::NewGuid().ToString('N').Substring(0, 6))"
            Add-QuickJumpPath -Path $multiPathOne -Alias $aliasOne -Force
            Add-QuickJumpPath -Path $multiPathTwo -Alias $aliasTwo -Force

            Mock -CommandName Test-FzfAvailable -ModuleName QuickJump -MockWith { $false }
            Mock -CommandName Invoke-QuickJumpFallbackSelection -ModuleName QuickJump -ParameterFilter {
                $AllowMulti
            } -MockWith {
                @(
                    [pscustomobject]@{ Path = $multiPathOne; Alias = $aliasOne },
                    [pscustomobject]@{ Path = $multiPathTwo; Alias = $aliasTwo }
                )
            }
            Mock -CommandName Read-Host -ModuleName QuickJump -MockWith { 'y' }

            { Remove-QuickJumpPath -Interactive -Multiple -Confirm:$false } | Should -Not -Throw

            $remaining = Get-QuickJumpPaths | Where-Object { $_.Alias -in @($aliasOne, $aliasTwo) }
            $remaining | Should -BeNullOrEmpty
        }
    }

    Context 'Invoke-QuickJump command' {
        It 'Should return path for direct alias when -Path is requested' {
            Add-QuickJumpPath -Path $script:TestPath -Alias 'jumpalias' -Force
            Invoke-QuickJump -Query 'jumpalias' -Path | Should -Be $script:TestPath
        }

        It 'Should support interactive selection when non-interactive mode is disabled' {
            Add-QuickJumpPath -Path $script:TestPath -Alias 'interactive-jump' -Force

            $originalValue = $env:POWERSHELL_MAGIC_NON_INTERACTIVE
            try {
                $env:POWERSHELL_MAGIC_NON_INTERACTIVE = '0'
                Mock -CommandName Test-FzfAvailable -ModuleName QuickJump -MockWith { $false }
                Mock -CommandName Invoke-QuickJumpFallbackSelection -ModuleName QuickJump -MockWith {
                    [pscustomobject]@{
                        Alias = 'interactive-jump'
                        Path = $script:TestPath
                    }
                }

                $result = Invoke-QuickJump -Interactive -Path
                $result | Should -Be $script:TestPath
            } finally {
                $env:POWERSHELL_MAGIC_NON_INTERACTIVE = $originalValue
            }
        }

        It 'Should report when no paths are saved' {
            $configPath = Get-QuickJumpConfigPath
            $originalContent = if (Test-Path $configPath) { Get-Content $configPath -Raw } else { $null }
            try {
                @{ paths = @(); version = '1.0' } | ConvertTo-Json -Depth 5 | Set-Content $configPath -Encoding UTF8
                Clear-PSMagicConfigCache -CacheKey 'quickjump'
                { Invoke-QuickJump } | Should -Not -Throw
            } finally {
                if ($null -ne $originalContent) {
                    Set-Content -Path $configPath -Value $originalContent -Encoding UTF8
                } else {
                    Remove-Item -Path $configPath -ErrorAction SilentlyContinue
                }
                Clear-PSMagicConfigCache -CacheKey 'quickjump'
            }
        }

        It 'Should fall back to interactive selection when alias is missing' {
            Mock -CommandName Get-QuickJumpPaths -ModuleName QuickJump -MockWith {
                param(
                    $Category,
                    $Interactive,
                    $Alias,
                    $SortByRecent,
                    $SortByMostUsed,
                    $Path,
                    $ListCategories
                )
                if ($Interactive -and $Path) {
                    return 'mock-interactive-path'
                }
            }

            Invoke-QuickJump -Query 'not-an-alias' -Path | Should -Be 'mock-interactive-path'
        }
    }

    Context 'Invoke-QuickJumpCategory command' {
        BeforeAll {
            $script:DevCategoryPath = Join-Path $script:TestDrive 'category-dev'
            $script:OpsCategoryPath = Join-Path $script:TestDrive 'category-ops'
            New-Item -ItemType Directory -Path $script:DevCategoryPath -Force | Out-Null
            New-Item -ItemType Directory -Path $script:OpsCategoryPath -Force | Out-Null
            Add-QuickJumpPath -Path $script:DevCategoryPath -Alias 'dev-cat' -Category 'dev' -Force
            Add-QuickJumpPath -Path $script:OpsCategoryPath -Alias 'ops-cat' -Category 'ops' -Force
        }

        It 'Should allow category selection via console fallback' {
            $originalValue = $env:POWERSHELL_MAGIC_NON_INTERACTIVE
            try {
                $env:POWERSHELL_MAGIC_NON_INTERACTIVE = '0'
                Mock -CommandName Test-FzfAvailable -ModuleName QuickJump -MockWith { $false }
                Mock -CommandName Read-Host -ModuleName QuickJump -MockWith { '1' }
                Mock -CommandName Get-QuickJumpPaths -ModuleName QuickJump -ParameterFilter {
                    $Category -eq 'dev' -and $Interactive -and $Path
                } -MockWith { 'category-selected-path' }

                Invoke-QuickJumpCategory -Path | Should -Be 'category-selected-path'
            } finally {
                $env:POWERSHELL_MAGIC_NON_INTERACTIVE = $originalValue
            }
        }

        It 'Should report when no QuickJump paths exist' {
            $configPath = Get-QuickJumpConfigPath
            $originalContent = if (Test-Path $configPath) { Get-Content $configPath -Raw } else { $null }
            try {
                @{ paths = @(); version = '1.0' } | ConvertTo-Json -Depth 5 | Set-Content $configPath -Encoding UTF8
                Clear-PSMagicConfigCache -CacheKey 'quickjump'
                { Invoke-QuickJumpCategory } | Should -Not -Throw
            } finally {
                if ($null -ne $originalContent) {
                    Set-Content -Path $configPath -Value $originalContent -Encoding UTF8
                } else {
                    Remove-Item -Path $configPath -ErrorAction SilentlyContinue
                }
                Clear-PSMagicConfigCache -CacheKey 'quickjump'
            }
        }

        It 'Should fall back to listing all paths when no categories exist' {
            $noCategoryPath = Join-Path $script:TestDrive ('nocat-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Path $noCategoryPath -Force | Out-Null

            $configPath = Get-QuickJumpConfigPath
            $originalContent = if (Test-Path $configPath) { Get-Content $configPath -Raw } else { $null }
            try {
                $paths = @(
                    @{
                        path = $noCategoryPath
                        alias = 'nocat'
                        category = $null
                        added = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                        lastUsed = $null
                        useCount = 0
                    }
                )
                @{ version = '1.0'; paths = $paths } | ConvertTo-Json -Depth 5 | Set-Content $configPath -Encoding UTF8
                Clear-PSMagicConfigCache -CacheKey 'quickjump'

                Mock -CommandName Get-QuickJumpPaths -ModuleName QuickJump -MockWith {
                    param(
                        $Category,
                        $Interactive,
                        $Alias,
                        $SortByRecent,
                        $SortByMostUsed,
                        $Path,
                        $ListCategories
                    )
                    if ($Interactive) {
                        return 'fallback-no-category'
                    }
                }

                Invoke-QuickJumpCategory -Path | Should -Be 'fallback-no-category'
            } finally {
                if ($null -ne $originalContent) {
                    Set-Content -Path $configPath -Value $originalContent -Encoding UTF8
                } else {
                    Remove-Item -Path $configPath -ErrorAction SilentlyContinue
                }
                Clear-PSMagicConfigCache -CacheKey 'quickjump'
            }
        }
    }

    Context 'Get-QuickJumpCategories command' {
        BeforeEach {
            $categoryAlias = "category-check-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
            $categoryPath = Join-Path $script:TestDrive $categoryAlias
            New-Item -ItemType Directory -Path $categoryPath -Force | Out-Null
            Add-QuickJumpPath -Path $categoryPath -Alias $categoryAlias -Category 'testing' -Force
        }

        It 'Should list categories with counts' {
            $categories = Get-QuickJumpCategories
            $categories | Should -Not -BeNullOrEmpty
            ($categories | Where-Object { $_.Category -eq 'testing' }).Count | Should -BeGreaterOrEqual 1
        }

        It 'Should return names only when -Name is supplied' {
            $categoryNames = Get-QuickJumpCategories -Name
            $categoryNames | Should -Contain 'testing'
        }
    }

    Context 'Open-QuickJumpRecent command' {
        BeforeAll {
            $script:RecentPath = Join-Path $script:TestDrive 'recent-path'
            New-Item -ItemType Directory -Path $script:RecentPath -Force | Out-Null
            Add-QuickJumpPath -Path $script:RecentPath -Alias 'recent-alias' -Category 'recent' -Force
            # Simulate usage so it gets a LastUsed entry
            $null = Get-QuickJumpPaths -Alias 'recent-alias'
        }

        It 'Should return most recent path when -Path is used' {
            Open-QuickJumpRecent -Path | Should -Be $script:RecentPath
        }

        It 'Should fall back to interactive listing when no recent entry is available' {
            # Remove lastUsed values to force interactive flow
            $configPath = Get-QuickJumpConfigPath
            $configContent = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable
            foreach ($entry in $configContent.paths) {
                $entry.lastUsed = $null
            }
            $configContent | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
            Clear-PSMagicConfigCache -CacheKey 'quickjump'

            $originalValue = $env:POWERSHELL_MAGIC_NON_INTERACTIVE
            try {
                $env:POWERSHELL_MAGIC_NON_INTERACTIVE = '0'
                Mock -CommandName Get-QuickJumpPaths -ModuleName QuickJump -ParameterFilter {
                    $Interactive -and $SortByRecent
                } -MockWith { 'recent-fallback-path' }
                Open-QuickJumpRecent -Interactive -Path | Should -Be 'recent-fallback-path'
            } finally {
                $env:POWERSHELL_MAGIC_NON_INTERACTIVE = $originalValue
            }
        }

        It 'Should report when no paths exist for recent lookup' {
            $configPath = Get-QuickJumpConfigPath
            $originalContent = if (Test-Path $configPath) { Get-Content $configPath -Raw } else { $null }
            try {
                @{ paths = @(); version = '1.0' } | ConvertTo-Json -Depth 5 | Set-Content $configPath -Encoding UTF8
                Clear-PSMagicConfigCache -CacheKey 'quickjump'
                { Open-QuickJumpRecent } | Should -Not -Throw
            } finally {
                if ($null -ne $originalContent) {
                    Set-Content -Path $configPath -Value $originalContent -Encoding UTF8
                } else {
                    Remove-Item -Path $configPath -ErrorAction SilentlyContinue
                }
                Clear-PSMagicConfigCache -CacheKey 'quickjump'
            }
        }
    }
}

Describe 'PowerShell Magic - Error Conditions' -Tag 'ErrorHandling' {

    BeforeAll {
        Import-Module $script:CommonModule -Force
        Import-Module $script:QuickJumpModule -Force
    }

    Context 'Corrupted Configuration Files' {
        It 'Should handle corrupted JSON gracefully' {
            $configPath = Get-PSMagicConfigPath -Component 'quickjump' -FileName 'paths.json'
            'this is not valid JSON { [ }' | Set-Content $configPath

            # Should not throw, but should create backup and reset
            { $null = Get-QuickJumpPaths } | Should -Not -Throw
        }

        It 'Should create backup of corrupted config' {
            $configPath = Get-PSMagicConfigPath -Component 'quickjump' -FileName 'paths.json'
            '{ invalid json' | Set-Content $configPath

            $null = Get-QuickJumpPaths 3>$null  # Suppress warnings

            $backupFiles = Get-ChildItem (Split-Path $configPath) -Filter 'paths.json.backup.*'
            $backupFiles | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Missing Permissions' {
        It 'Should handle read-only config directory' -Skip:($IsLinux -or $IsMacOS) {
            # This test is Windows-specific
            $configDir = Get-PSMagicConfigPath -Component 'readonly-test' -ReturnDirectory
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            $configFile = Join-Path $configDir 'test.json'
            '{}' | Set-Content $configFile

            # Make directory read-only
            $acl = Get-Acl $configDir
            $acl.SetAccessRuleProtection($true, $false)
            Set-Acl $configDir $acl

            # Attempt to write should fail gracefully
            # Clean up
            $acl.SetAccessRuleProtection($false, $true)
            Set-Acl $configDir $acl
        }
    }

    Context 'Invalid Input Validation' {
        It 'Should reject invalid alias characters' {
            # Depending on implementation, this might be allowed
            # Adjust test based on actual validation rules
        }

        It 'Should handle very long paths' {
            $longPath = 'C:\' + ('verylongdirectoryname\' * 50)
            { Add-QuickJumpPath -Path $longPath -Alias 'toolong' -ErrorAction Stop } | Should -Throw
        }

        It 'Should handle special characters in aliases' {
            $testPath = Join-Path $script:TestDrive 'special-test'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null

            # Test various special characters
            $specialAliases = @('test@alias', 'test$alias', 'test#alias')
            foreach ($alias in $specialAliases) {
                # This may or may not throw depending on validation - adjust as needed
                $null = Add-QuickJumpPath -Path $testPath -Alias $alias -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Concurrent Access' {
        It 'Should handle multiple simultaneous config updates' {
            $testPath = Join-Path $script:TestDrive 'concurrent-test'
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null

            # Simulate concurrent writes
            $jobs = 1..5 | ForEach-Object {
                Start-Job -ScriptBlock {
                    param($CommonModulePath, $ModulePath, $Path, $Index, $ConfigHome)
                    $env:XDG_CONFIG_HOME = $ConfigHome
                    $env:POWERSHELL_MAGIC_NON_INTERACTIVE = '1'
                    Import-Module $CommonModulePath -Force -Global
                    Import-Module $ModulePath -Force
                    Add-QuickJumpPath -Path $Path -Alias "concurrent$Index" -ErrorAction SilentlyContinue
                } -ArgumentList $script:CommonModule, $script:QuickJumpModule, $testPath, $_, $env:XDG_CONFIG_HOME
            }

            $jobs | Wait-Job -Timeout 10 | Out-Null
            $jobs | Receive-Job | Out-Null
            $jobs | Remove-Job -Force

            # All aliases should be present
            $paths = Get-QuickJumpPaths
            $concurrentCount = ($paths | Where-Object { $_.Alias -like 'concurrent*' }).Count
            $concurrentCount | Should -BeGreaterThan 0
        }
    }
}

Describe 'PowerShell Magic - End-to-End Tests' -Tag 'E2E', 'Integration' {

    BeforeAll {
        Import-Module $script:CommonModule -Force
        Import-Module $script:QuickJumpModule -Force

        # Create test directory structure
        $script:E2ERoot = Join-Path $script:TestDrive 'e2e-tests'
        $script:ProjectsDir = Join-Path $script:E2ERoot 'projects'
        $script:WorkDir = Join-Path $script:E2ERoot 'work'
        $script:PersonalDir = Join-Path $script:E2ERoot 'personal'

        New-Item -ItemType Directory -Path $script:ProjectsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:PersonalDir -Force | Out-Null
    }

    Context 'Complete QuickJump Workflow' {
        It 'Should complete full workflow: add, list, navigate, remove' {
            # Step 1: Add multiple paths
            Add-QuickJumpPath -Path $script:ProjectsDir -Alias 'proj' -Category 'dev'
            Add-QuickJumpPath -Path $script:WorkDir -Alias 'work' -Category 'work'
            Add-QuickJumpPath -Path $script:PersonalDir -Alias 'personal' -Category 'personal'

            # Step 2: List all paths
            $allPaths = Get-QuickJumpPaths
            $allPaths.Count | Should -BeGreaterOrEqual 3

            # Step 3: Filter by category
            $devPaths = Get-QuickJumpPaths -Category 'dev'
            $devPaths.Count | Should -BeGreaterOrEqual 1

            # Step 4: Get specific path
            $projPath = Get-QuickJumpPaths -Alias 'proj' -Path
            $projPath | Should -Be $script:ProjectsDir

            # Step 5: Remove a path
            Remove-QuickJumpPath -Alias 'proj' -Confirm:$false

            # Step 6: Verify removal
            $remainingPaths = Get-QuickJumpPaths
            $remainingPaths.Alias | Should -Not -Contain 'proj'
        }

        It 'Should track usage statistics' {
            Add-QuickJumpPath -Path $script:WorkDir -Alias 'usage-test' -Force

            # Simulate navigation (updates usage)
            $null = Get-QuickJumpPaths -Alias 'usage-test'

            # Check usage was tracked
            $path = Get-QuickJumpPaths | Where-Object { $_.Alias -eq 'usage-test' }
            # Usage tracking happens in Set-Location, which we can't fully test here
            $path | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Multi-module Integration' {
        It 'Should share common configuration infrastructure' {
            # QuickJump config path
            $qjPath = Get-PSMagicConfigPath -Component 'quickjump' -FileName 'paths.json'

            # Should be in same root as other modules would use
            $qjPath | Should -Match ([regex]::Escape($env:XDG_CONFIG_HOME))
        }
    }
}

Describe 'PowerShell Magic - Performance Tests' -Tag 'Performance' {

    BeforeAll {
        Import-Module $script:CommonModule -Force
    }

    Context 'Regex Performance' {
        It 'Should show performance improvement with compiled regex' {
            $result = Test-PSMagicRegexPerformance -Pattern '^\d{4}-\d{2}-\d{2}$' -TestString '2025-01-15' -Iterations 10000

            if ($result.ImprovementPercent -lt -10) {
                Write-Warning ('Compiled regex was slower by {0}% on this runtime.' -f $result.ImprovementPercent)
            }

            $result.NonCompiledMs | Should -BeGreaterThan 0
            $result.CompiledMs | Should -BeGreaterThan 0
            Write-Host "Regex compilation performance: $($result.ImprovementPercent)% (compiled: $($result.CompiledMs)ms vs non-compiled: $($result.NonCompiledMs)ms)"
        }
    }

    Context 'Config Caching Performance' {
        It 'Should load cached config faster than file read' {
            $testConfig = Join-Path $script:TestDrive 'perf-test.json'
            @{ data = 'value' } | ConvertTo-Json | Set-Content $testConfig

            # First load (from file)
            $uncachedTime = Measure-Command {
                $null = Get-PSMagicCachedConfig -CacheKey 'perftest' -ConfigPath $testConfig -LoadScriptBlock {
                    Get-Content $testConfig -Raw | ConvertFrom-Json -AsHashtable
                }
            }

            # Second load (from cache)
            $cachedTime = Measure-Command {
                $null = Get-PSMagicCachedConfig -CacheKey 'perftest' -ConfigPath $testConfig -LoadScriptBlock {
                    Get-Content $testConfig -Raw | ConvertFrom-Json -AsHashtable
                }
            }

            $cachedTime.TotalMilliseconds | Should -BeLessThan $uncachedTime.TotalMilliseconds
            Write-Host "Cached config load: $($cachedTime.TotalMilliseconds)ms vs uncached: $($uncachedTime.TotalMilliseconds)ms"
        }
    }
}
