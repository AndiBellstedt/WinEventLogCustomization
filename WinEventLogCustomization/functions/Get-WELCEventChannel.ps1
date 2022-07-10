function Get-WELCEventChannel {
    <#
    .Synopsis
        Get-WELCEventChannel

    .DESCRIPTION
        Query Windows Eventlog Channel(s) and their provider information.

    .PARAMETER ComputerName
        The computer(s) to connect to.
        Supports PSSession objects also.

    .PARAMETER Session
        A PSSession object for remote connection to another machine

    .PARAMETER Credential
        The credentials to use on remote calls

    .PARAMETER ChannelFullName
        The name of the EventChannel to query

        Default is every channel

    .EXAMPLE
        PS C:\> Get-WELCEventChannel

        Display all available subscription

    .EXAMPLE
        PS C:\> Get-WELCEventChannel -ChannelFullName MyChannel

        Display Channel "MyChannel"

    .EXAMPLE
        PS C:\> Get-WELCEventChannel -ChannelFullName MyChannel -ComputerName SRV01

        Display Channel "MyChannel" from remote computer "SRV01".

    .EXAMPLE
        PS C:\> Get-WELCEventChannel -ChannelFullName MyChannel -Sesion $PSSession

        Display Channel "MyChannel" from all connections within the $PSSession variable

        Assuming $PSSession variable is created something like this:
        $PSSession = New-PSSession -ComputerName SRV01

    .NOTES
        Author: Andreas Bellstedt

    .LINK
        https://github.com/AndiBellstedt/WinEventLogCustomization

    #>
    [CmdletBinding(
        DefaultParameterSetName = 'ComputerName',
        ConfirmImpact = 'low'
    )]
    Param(
        [Parameter( ValueFromPipeline = $true )]
        [Alias("Name", "ChannelName", "LogName")]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ChannelFullName = "*",

        [Parameter(
            ParameterSetName = "ComputerName",
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias("Host", "Hostname", "Computer", "DNSHostName")]
        [PSFComputer[]]
        $ComputerName = $env:COMPUTERNAME,

        [Parameter( ParameterSetName = "Session" )]
        [System.Management.Automation.Runspaces.PSSession[]]
        $Session,

        [Parameter( ParameterSetName = "ComputerName" )]
        [PSCredential]
        $Credential
    )

    begin {
        # If session parameter is used -> transfer it to ComputerName,
        # The class "PSFComputer" from PSFramework can handle it. This simplifies the handling in the further process block
        if ($Session) { $ComputerName = $Session.ComputerName }

        $pathBound = Test-PSFParameterBinding -ParameterName Path
        $computerBound = Test-PSFParameterBinding -ParameterName ComputerName

    }

    process {
        #region parameterset workarround
        Write-PSFMessage -Level Debug -Message "ParameterNameSet: $($PsCmdlet.ParameterSetName)"

        # Workarround parameter binding behaviour of powershell in combination with ComputerName Piping
        if (-not ($pathBound -or $computerBound) -and $ComputerName.InputObject -and $PSCmdlet.ParameterSetName -ne "Session") {
            if ($ComputerName.InputObject -is [string]) { $ComputerName = $env:ComputerName } else { $ChannelFullName = "" }
        }
        #endregion parameterset workarround

        #region Processing Channels
        foreach ($computer in $ComputerName) {
            $winEventProviders = @()
            $errorChannel = @()

            foreach ($channel in $ChannelFullName) {

                $ErrorReturn = $null
                $paramInvokeCmd = [ordered]@{
                    "ComputerName" = $computer
                    "ErrorAction"  = "Stop"
                    ErrorVariable  = "ErrorReturn"
                    "ArgumentList" = $channel
                }
                if ($PSCmdlet.ParameterSetName -eq "Session") { $paramInvokeCmd['ComputerName'] = $Session }
                if ($Credential) { $paramInvokeCmd.Add("Credential", $Credential) }

                Write-PSFMessage -Level Verbose -Message "Query EventLog channel '$($channel)' on computer '$($computer)'" -Target $computer
                try {
                    $winEventChannels = Invoke-PSFCommand @paramInvokeCmd -ScriptBlock { Get-WinEvent -ListLog $args[0] }
                } catch {
                    Stop-PSFFunction -Message "Unable to query EventLog channel '$($channel)' on computer '$($computer)'. ErrorMessage: $($ErrorReturn.Exception.Message | Select-Object -Unique)" -Target $computer -ErrorRecord $_
                }

                [array]$providerNames = $winEventChannels.ProviderNames | Select-Object -Unique
                Write-PSFMessage -Level Verbose -Message "Query $($providerNames.count) provider from EventLog channel '$($winEventChannels.LogName)'" -Target $computer

                $errorMessages = @()
                $providerNames = $providerNames | Where-Object { $_ -notin $winEventProviders.name -and $_ -notin $errorChannel }
                $winEventProviders += foreach ($providerName in $providerNames) {
                    $ErrorReturn = $null
                    $paramInvokeCmd['ArgumentList'] = $providerName
                    try {
                        Invoke-PSFCommand @paramInvokeCmd -ScriptBlock {
                            Get-WinEvent -ListProvider $args -ErrorAction SilentlyContinue -ErrorVariable ErrorOccured
                            if ($ErrorOccured) { Write-Error -Message ([string]::Join(" " , ($ErrorOccured.Exception.Message | Select-Object -Unique))) -ErrorAction Stop }
                        } -Verbose:$false
                    } catch {
                        Write-PSFMessage -Level Debug -Message "Unable to query provider '$($providerName)' from computer '$($computer)'. ErrorMessage: $($ErrorReturn.Exception | Select-Object -ExpandProperty Message -Unique)" -Target $computer -ErrorRecord $_
                        $errorChannel += $providerName
                        $errorMessages += $ErrorReturn.Exception[-1].Message
                    }
                }

                if ($errorMessages) {
                    Write-PSFMessage -Level Error -Message "Error query provider ($([string]::Join(", ", $providerNames))) from EventLog Channel '$($winEventChannels.LogName)' on computer '$($computer)'. ErrorMessage: $([string]::join(" ", $errorMessages))" -Target $computer
                }

                # Output result
                foreach ($winEventChannel in $winEventChannels) {
                    $winEventChannel | Add-Member -MemberType NoteProperty -Name "Provider" -Value ( $winEventChannel.ProviderNames | ForEach-Object { $_name = $_; $winEventProviders | Where-Object ProviderName -like $_name } )
                    $winEventChannel.psobject.TypeNames.Insert(0, "WELC.EventLogChannel")

                    $winEventChannel
                }

            }

        }
        #endregion Processing Events

    }

    end {
    }
}
