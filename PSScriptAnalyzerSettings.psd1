@{
    # PSScriptAnalyzer settings for PowerShell Magic
    # This file defines the formatting and linting rules for all PowerShell code

    # Include default rules
    IncludeDefaultRules = $true

    # Severity levels to check
    Severity = @('Error', 'Warning', 'Information')

    # Rules to exclude (customize as needed)
    ExcludeRules = @(
        # Allow long lines for readability in some cases
        # 'PSAvoidLongLines',

        # Allow Write-Host for user interaction scripts
        'PSAvoidUsingWriteHost'
    )

    # Custom rules configuration
    Rules = @{
        # Enforce consistent indentation (4 spaces)
        PSUseConsistentIndentation = @{
            Enable = $true
            Kind = 'space'
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }

        # Enforce consistent whitespace
        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckPipe = $true
            CheckSeparator = $true
            CheckParameter = $false
        }

        # Enforce proper casing for cmdlets and functions
        PSUseCorrectCasing = @{
            Enable = $true
        }

        # Avoid using aliases in scripts
        PSAvoidUsingCmdletAliases = @{
            Enable = $true
            # Allow common aliases in interactive contexts
            allowlist = @('cd', 'ls', 'cat', 'rm', 'cp', 'mv')
        }

        # Require #Requires statements
        PSUseUsingScopeModifierInNewRunspaces = @{
            Enable = $true
        }

        # Enforce parameter validation
        PSUseDeclaredVarsMoreThanAssignments = @{
            Enable = $true
        }

        # Enforce proper string quotes
        PSAvoidUsingDoubleQuotesForConstantString = @{
            Enable = $true
        }


        # Brace placement
        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
        }

        PSPlaceCloseBrace = @{
            Enable = $true
            NewLineAfter = $false
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore = $false
        }

        # Enforce CmdletBinding for advanced functions
        PSUseCmdletCorrectly = @{
            Enable = $true
        }

        # Security rules
        PSAvoidUsingPlainTextForPassword = @{
            Enable = $true
        }

        PSAvoidUsingConvertToSecureStringWithPlainText = @{
            Enable = $true
        }
    }
}