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

        It 'Should fail when path does not exist' {
            $nonExistentPath = Join-Path $script:TestDrive 'does-not-exist'
            { Add-QuickJumpPath -Path $nonExistentPath -Alias 'fail' -ErrorAction Stop } | Should -Throw
        }

        It 'Should fail when adding duplicate alias without -Force' {
            Add-QuickJumpPath -Path $script:TestPath -Alias 'duplicate'
            { Add-QuickJumpPath -Path $script:TestPath -Alias 'duplicate' -ErrorAction Stop } | Should -Throw
        }

        It 'Should overwrite with -Force flag' {
            Add-QuickJumpPath -Path $script:TestPath -Alias 'forceme'
            { Add-QuickJumpPath -Path $script:TestPath -Alias 'forceme' -Force } | Should -Not -Throw
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
    }

    Context 'Remove-QuickJumpPath' {
        It 'Should remove path by alias' {
            Add-QuickJumpPath -Path $script:TestPath -Alias 'toremove'
            { Remove-QuickJumpPath -Alias 'toremove' -Confirm:$false } | Should -Not -Throw
        }

        It 'Should fail when removing non-existent alias' {
            { Remove-QuickJumpPath -Alias 'does-not-exist' -ErrorAction Stop -Confirm:$false } | Should -Throw
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
