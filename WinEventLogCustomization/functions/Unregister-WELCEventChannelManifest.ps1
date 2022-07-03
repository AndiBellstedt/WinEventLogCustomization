function Unregister-WELCEventChannelManifest {
    <#
    .SYNOPSIS
        Unregister-WELCEventChannelManifest

    .DESCRIPTION
        Unregister a manifest and its compiled DLL file from windows EventLog sytem

    .PARAMETER Path
        The path to the manifest (and the dll) file

    .PARAMETER ComputerName
        The computer where to register the manifest file

    .PARAMETER Session
        PowerShell Session object where to unregister the manifest file

    .PARAMETER Credential
        The credentials to use on remote calls

    .PARAMETER WhatIf
        If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

    .PARAMETER Confirm
        If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

    .NOTES
        Author: Andreas Bellstedt

    .LINK
        https://github.com/AndiBellstedt/WinEventLogCustomization

    .EXAMPLE
        PS C:\> Unregister-WELCEventChannelManifest -Path C:\CustomDLLPath\MyChannel.man

        Unregister the manfifest-file from Windows EventLog System, so it no longer appears in Application and Services Logs.

    .EXAMPLE
        PS C:\> Unregister-WELCEventChannelManifest -Path C:\CustomDLLPath\MyChannel.man -ComputerName SRV01

        Unregister the manfifest-file from Windows EventLog System on the remote computer "SRV01".

    .EXAMPLE
        PS C:\> Unregister-WELCEventChannelManifest -Path C:\CustomDLLPath\MyChannel.man -Sesion $PSSession

        Unregister the manfifest-file from Windows EventLog System from all connections within the $PSSession variable

        Assuming $PSSession variable is created something like this:
        $PSSession = New-PSSession -ComputerName SRV01

    #>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        PositionalBinding = $true,
        ConfirmImpact = 'High',
        DefaultParameterSetName = 'ComputerName'
    )]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [Alias("File", "FileName", "FullName")]
        [String]
        $Path,

        [Parameter(
            ParameterSetName = "ComputerName",
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias("Host", "Hostname", "Computer", "DNSHostName")]
        [PSFComputer[]]
        $ComputerName = $env:COMPUTERNAME,

        [Parameter(ParameterSetName = "Session")]
        [System.Management.Automation.Runspaces.PSSession[]]
        $Session,

        [Parameter(ParameterSetName = "ComputerName")]
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
            if ($ComputerName.InputObject -is [string]) { $ComputerName = $env:ComputerName } else { $Path = "" }
        }
        #endregion parameterset workarround

        #region Processing Events
        foreach ($file in $Path) {
            # File/path validation
            if (-not (Test-Path -Path $file -PathType Leaf -IsValid)) {
                Write-PSFMessage -Level Error -Message"'$($file)' is not a valid path or file."
                continue
            } else {
                Write-PSFMessage -Level Debug -Message "Working on file '$($file)'"
            }

            # Process computers
            foreach ($computer in $ComputerName) {
                Write-PSFMessage -Level Verbose -Message "Processing file '$($file)' on computer '$($computer)'"

                # When remoting is used, transfer files first
                if (($PSCmdlet.ParameterSetName -eq "Session") -or (-not $computer.IsLocalhost)) {

                    # Create PS remoting session, if no session exists
                    if ($PSCmdlet.ParameterSetName -ne "Session") {

                        $paramSession = @{
                            "ComputerName" = $computer.ToString()
                            "ErrorAction"  = "Stop"
                        }
                        if ($Credential) { $paramSession.Add("Credential", $Credential) }

                        try {
                            $Session = New-PSSession @paramSession
                            Write-PSFMessage -Level Debug -Message "New remoting session created to '$($Session.ComputerName)'"
                        } catch {
                            Write-PSFMessage -Level Error -Message "Error creating remoting session to computer '$($computer)'" -Target $computer -ErrorRecord $_
                            break
                        }
                    }
                }

                # Register manifest
                if ($pscmdlet.ShouldProcess("Manifest '$($Path)' from computer '$($computer)'", "Unregister")) {

                    $paramInvokeCmd = [ordered]@{
                        "ComputerName" = $computer.ToString()
                        "ErrorAction"  = "Stop"
                        ErrorVariable  = "ErrorReturn"
                        "ArgumentList" = $file
                    }
                    if ($PSCmdlet.ParameterSetName -eq "Session") { $paramInvokeCmd['ComputerName'] = $Session }
                    if ($Credential) { $paramInvokeCmd.Add("Credential", $Credential) }

                    Write-PSFMessage -Level Verbose -Message "Unregistering manifest '$($file)' from computer '$($computer)'" -Target $computer
                    try {
                        $null = Invoke-PSFCommand @paramInvokeCmd -ScriptBlock {
                            try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { Write-Information -MessageData "Exception while setting UTF8 OutputEncoding. Continue script." }
                            $output = . "$($env:windir)\system32\wevtutil.exe" "uninstall-manifest" "$($args[0])" *>&1
                            $output = $output | Where-Object { $_.InvocationInfo.MyCommand.Name -like 'wevtutil.exe' } *>&1
                            if ($output) { Write-Error -Message "$([string]::Join(" ", $output.Exception.Message.Replace("`r`n"," ")))" -ErrorAction Stop }
                        }
                        if ($ErrorReturn) { Write-Error "Error registering manifest" -ErrorAction Stop }
                    } catch {
                        Stop-PSFFunction -Message "Error unregistering manifest '$($file)' on computer '$($computer)'" -Target $computer -ErrorRecord $_
                    }
                }
            }
        }
    }

    end {
    }
}