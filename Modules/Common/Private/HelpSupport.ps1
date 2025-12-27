# HelpSupport.ps1
# Universal --help flag support for all PowerShell Magic commands

function Enable-PSMagicHelpFlag {
    <#
    .SYNOPSIS
    Enables --help flag support for PowerShell Magic commands.

    .DESCRIPTION
    This function processes command-line arguments to detect --help, -help, -h, or /?
    flags and displays the command's help information when found.

    .PARAMETER BoundParameters
    The $PSBoundParameters automatic variable from the calling function.

    .PARAMETER UnboundArguments
    The $args automatic variable from the calling function.

    .PARAMETER CommandName
    Name of the command to show help for. If not provided, uses the calling function name.

    .EXAMPLE
    function My-Command {
        [CmdletBinding()]
        param([string]$Name)

        # Add at the start of your function
        if (Test-PSMagicHelpRequest -BoundParameters $PSBoundParameters -UnboundArguments $args) {
            Show-PSMagicHelp -CommandName $MyInvocation.MyCommand.Name
            return
        }

        # Rest of function logic
    }
    #>
    [CmdletBinding()]
    param()

    # This is a marker function that indicates help support is enabled
    # Actual implementation is in Test-PSMagicHelpRequest and Show-PSMagicHelp
}

function Test-PSMagicHelpRequest {
    <#
    .SYNOPSIS
    Tests if a help flag was provided in the command arguments.

    .DESCRIPTION
    Checks for common help flags: --help, -help, -h, -?, /?

    .PARAMETER BoundParameters
    The $PSBoundParameters from the calling function.

    .PARAMETER UnboundArguments
    The $args from the calling function.

    .EXAMPLE
    if (Test-PSMagicHelpRequest -BoundParameters $PSBoundParameters -UnboundArguments $args) {
        Show-PSMagicHelp
        return
    }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$BoundParameters = @{},

        [Parameter(Mandatory = $false)]
        [object[]]$UnboundArguments = @()
    )

    # Common help flags
    $helpFlags = @('--help', '-help', '-h', '-?', '/?', 'help')

    # Check bound parameters
    foreach ($key in $BoundParameters.Keys) {
        if ($helpFlags -contains $key.ToLower()) {
            return $true
        }
    }

    # Check unbound arguments
    foreach ($arg in $UnboundArguments) {
        $argStr = $arg.ToString().ToLower()
        if ($helpFlags -contains $argStr) {
            return $true
        }
    }

    return $false
}

function Show-PSMagicHelp {
    <#
    .SYNOPSIS
    Displays help information for a PowerShell Magic command.

    .DESCRIPTION
    Shows the command's help using Get-Help with enhanced formatting
    for PowerShell Magic commands.

    .PARAMETER CommandName
    Name of the command to show help for.

    .PARAMETER Detailed
    Show detailed help including parameter descriptions and examples.

    .PARAMETER Examples
    Show only examples.

    .PARAMETER Full
    Show full help including detailed descriptions, parameters, and examples.

    .PARAMETER Online
    Open online help in browser (if available).

    .EXAMPLE
    Show-PSMagicHelp -CommandName 'Add-QuickJumpPath'

    .EXAMPLE
    Show-PSMagicHelp -CommandName 'Use-Template' -Examples
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$CommandName,

        [switch]$Detailed,

        [switch]$Examples,

        [switch]$Full,

        [switch]$Online
    )

    # Get calling function name if not provided
    if (-not $CommandName) {
        $caller = (Get-PSCallStack)[1]
        $CommandName = $caller.Command
    }

    # Build Get-Help parameters
    $helpParams = @{
        Name = $CommandName
    }

    if ($Online) {
        $helpParams.Online = $true
    } elseif ($Examples) {
        $helpParams.Examples = $true
    } elseif ($Full) {
        $helpParams.Full = $true
    } elseif ($Detailed) {
        $helpParams.Detailed = $true
    }

    # Display help with custom formatting
    Write-Information '' -InformationAction Continue
    Write-Information "PowerShell Magic - $CommandName" -InformationAction Continue
    Write-Information ('=' * 80) -InformationAction Continue
    Write-Information '' -InformationAction Continue

    try {
        Get-Help @helpParams
    } catch {
        Write-Warning "Failed to retrieve help for '$CommandName': $($_.Exception.Message)"
        Write-Information "Try: Get-Help $CommandName" -InformationAction Continue
    }

    Write-Information '' -InformationAction Continue
    Write-Information 'For more information, visit: https://github.com/wallstop/jason-storey-powershell-magic' -InformationAction Continue
    Write-Information '' -InformationAction Continue
}

function Add-PSMagicArgumentCompleter {
    <#
    .SYNOPSIS
    Adds a tab completion completer that includes --help flag.

    .DESCRIPTION
    Wraps existing argument completers to also suggest --help flag.

    .PARAMETER CommandName
    Command to add help flag completion to.

    .PARAMETER ParameterName
    Parameter to add completion for (use '*' for all parameters).

    .EXAMPLE
    Add-PSMagicArgumentCompleter -CommandName 'Add-QuickJumpPath'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$CommandName,

        [string]$ParameterName = '--help'
    )

    # Register a completer that suggests --help
    Register-ArgumentCompleter -CommandName $CommandName -ParameterName $ParameterName -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $helpFlags = @('--help', '-h', '-?')
        $helpFlags | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(
                $_,
                $_,
                'ParameterValue',
                'Display help for this command'
            )
        }
    }
}

function Initialize-PSMagicHelpSystem {
    <#
    .SYNOPSIS
    Initializes the help system for all PowerShell Magic commands.

    .DESCRIPTION
    Sets up help flag support and tab completion for all exported commands
    in PowerShell Magic modules.

    .EXAMPLE
    Initialize-PSMagicHelpSystem
    #>
    [CmdletBinding()]
    param()

    # Get all PowerShell Magic commands
    $modules = @('QuickJump', 'Templater', 'Unitea')

    foreach ($moduleName in $modules) {
        $module = Get-Module $moduleName -ErrorAction SilentlyContinue
        if ($module) {
            $commands = $module.ExportedFunctions.Keys
            if ($commands) {
                Add-PSMagicArgumentCompleter -CommandName $commands
                Write-Verbose "Initialized help system for $($commands.Count) commands in $moduleName"
            }
        }
    }
}

Export-ModuleMember -Function @(
    'Enable-PSMagicHelpFlag',
    'Test-PSMagicHelpRequest',
    'Show-PSMagicHelp',
    'Add-PSMagicArgumentCompleter',
    'Initialize-PSMagicHelpSystem'
)
