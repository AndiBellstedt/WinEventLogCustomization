function Register-WELCEventChannelManifest {
    <#
    .SYNOPSIS
        Register-WELCEventChannelManifest

    .DESCRIPTION
        Register a compiled DLL and the manifest file to windows EventLog sytem
        The content of the registered manifest appears in EventLog reader unter Application and Services Logs

    .PARAMETER Path
        The path to the manifest (and the dll) file

    .PARAMETER ComputerName
        The computer where to register the manifest file

    .PARAMETER Session
        PowerShell Session object where to register the manifest file

    .PARAMETER DestinationPath
        The path where to store the manifest and DLL file

        By default, this is the same as "Path", as long, as you do not specify something else.
        If you use remoting to register the manifest on a remote computer the files will be
        copied over locally into DestinationPath on the remote computer

    .PARAMETER Credential
        The credentials to use on remote calls

    .NOTES
        Author: Andreas Bellstedt

    .LINK
        https://github.com/AndiBellstedt/WinEventLogCustomization

    .EXAMPLE
        PS C:\> Register-WELCEventChannelManifest -Path C:\CustomDLLPath\MyChannel.man

        Register the manfifest-file to Windows EventLog System, so it appears in Application and Services Logs.
        Next to the MyChannel.man file, there has to be a MyChannel.dll.

        The manifest and DLL file will be registered from the path C:\CustomDLLPath and has to remain there.

    .EXAMPLE
        PS C:\> Register-WELCEventChannelManifest -Path C:\CustomDLLPath\MyChannel.man -DestinationPath $env:WinDir\System32

        Register the manfifest-file to Windows EventLog System, so it appears in Application and Services Logs.
        Next to the MyChannel.man file, there has to be a MyChannel.dll.

        The manifest and DLL file will be copied to the system32 directory of the current windows installation.
        From there it is registered and has to remain in that folder.

    .EXAMPLE
        PS C:\> Register-WELCEventChannelManifest -Path C:\CustomDLLPath\MyChannel.man -ComputerName SRV01

        Register the manfifest-file to Windows EventLog System on the remote computer "SRV01".

        The manifest and DLL file will be registered from the the local path "C:\CustomDLLPath" on "SRV01" and has to remain there.

    .EXAMPLE
        PS C:\> Register-WELCEventChannelManifest -Path C:\CustomDLLPath\MyChannel.man -Sesion $PSSession

        Register the manfifest-file to Windows EventLog System on all connections within the $PSSession variable

        Assuming $PSSession variable is created something like this:
        $PSSession = New-PSSession -ComputerName SRV01

#>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        PositionalBinding = $true,
        ConfirmImpact = 'Medium',
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
        [String[]]
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
        $Credential,

        [String]
        $DestinationPath
    )

    begin {
        # If session parameter is used -> transfer it to ComputerName,
        # The class "PSFComputer" from PSFramework can handle it. This simplifies the handling in the further process block
        if ($Session) { $ComputerName = $Session.ComputerName }
        $DestinationPath = $DestinationPath.TrimEnd("\")

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
        foreach ($pathItem in $Path) {
            # File and folder validity tests
            if (Test-Path -Path $pathItem -PathType Leaf) {
                Write-PSFMessage -Level Verbose -Message "Found file '$($pathItem)' as a valid file in path" -Target $env:COMPUTERNAME
                $files = $pathItem | Resolve-Path | Get-ChildItem | Select-Object -ExpandProperty FullName
            } elseif (Test-Path -Path $pathItem -PathType Container) {
                Write-PSFMessage -Level Verbose -Message "Getting files in path '$($pathItem)'" -Target $env:COMPUTERNAME
                $files = Get-ChildItem -Path $pathItem -File -Filter "*.man" | Select-Object -ExpandProperty FullName
                Write-PSFMessage -Level Verbose -Message "Found $($files.count) file$(if($files.count -gt 1){"s"}) in path" -Target $env:COMPUTERNAME
                if (-not $files) { Write-Warning "No manifest files found in path '$($pathItem)'" }
            } elseif (-not (Test-Path  -Path $pathItem -PathType Any -IsValid)) {
                Write-PSFMessage -Level Error -Message"'$pathItem' is not a valid path or file." -Target $env:COMPUTERNAME
                continue
            } else {
                Write-PSFMessage -Level Error -Message "unable to open '$($pathItem)'" -Target $env:COMPUTERNAME
                continue
            }

            foreach ($file in $files) {
                if (-not $DestinationPath) { $DestinationPath = Split-Path -Path $file }

                # Check for dll paths in manifest / prepare dll paths in manifest for different destination path
                if (
                    (-not (Test-WELCEventChannelManifest -Path $file -OnlyDLLPath)) -or
                    ((split-path $file) -notlike $DestinationPath)
                ) {
                    [String]$tempPath = "$($env:TEMP)\WELC_$([guid]::NewGuid().guid)"
                    if (Test-Path -Path $tempPath -IsValid) {
                        if (-not (Test-Path -Path $tempPath -PathType Container)) {
                            New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
                            $tempPath = Resolve-Path $tempPath -ErrorAction Stop | Select-Object -ExpandProperty Path
                        }
                    }

                    $tempFile = Move-WELCEventChannelManifest -Path $file -DestinationPath $tempPath -CopyMode -PassThru -ErrorAction Stop | Select-Object -ExpandProperty FullName

                    $file = Move-WELCEventChannelManifest -Path $tempFile -DestinationPath $DestinationPath -Prepare -PassThru | Select-Object -ExpandProperty FullName
                }

                $xmlfile = New-Object XML
                $xmlfile.Load($file)

                $dllFiles = @()
                $dllFile = $xmlfile.instrumentationManifest.instrumentation.events.provider.resourceFileName
                if((Test-Path -Path $dllFile -PathType Leaf) -and ((Split-Path -Path $dllFile) -notlike $DestinationPath)) {
                    $dllFiles += $dllFile
                } else {
                    $dllFile = "$(split-path $file)\$(Split-Path -Path $xmlfile.instrumentationManifest.instrumentation.events.provider.resourceFileName -Leaf)"
                    if(Test-Path -Path $dllFile -PathType Leaf) {
                        $dllFiles += $dllFile
                    } else {
                        Stop-PSFFunction -Message "Unexpected behavior while locating ressource dll file"
                    }
                }

                $dllFile = $xmlfile.instrumentationManifest.instrumentation.events.provider.messageFileName
                if((Test-Path -Path $dllFile -PathType Leaf) -and ((Split-Path -Path $dllFile) -notlike $DestinationPath)) {
                    $dllFiles += $dllFile
                } else {
                    $dllFile = "$(split-path $file)\$(Split-Path -Path $xmlfile.instrumentationManifest.instrumentation.events.provider.messageFileName -Leaf)"
                    if(Test-Path -Path $dllFile -PathType Leaf) {
                        $dllFiles += $dllFile
                    } else {
                        Stop-PSFFunction -Message "Unexpected behavior while locating message dll file"
                    }
                }

                $dllFile = $xmlfile.instrumentationManifest.instrumentation.events.provider.parameterFileName
                if((Test-Path -Path $dllFile -PathType Leaf) -and ((Split-Path -Path $dllFile) -notlike $DestinationPath)) {
                    $dllFiles += $dllFile
                } else {
                    $dllFile = "$(split-path $file)\$(Split-Path -Path $xmlfile.instrumentationManifest.instrumentation.events.provider.parameterFileName -Leaf)"
                    if(Test-Path -Path $dllFile -PathType Leaf) {
                        $dllFiles += $dllFile
                    } else {
                        Stop-PSFFunction -Message "Unexpected behavior while locating parameter dll file"
                    }
                }

                $dllFiles = $dllFiles | Sort-Object -Unique


                # Process computers
                foreach ($computer in $ComputerName) {

                    # When remoting is used, transfer files first
                    if (($PSCmdlet.ParameterSetName -eq "Session") -or (-not $computer.IsLocalhost)) {
                        if ($pscmdlet.ShouldProcess("Manifest '$($file)' and dll to computer '$($computer)'", "Transfer")) {
                            # Create PS remoting session
                            if ($PSCmdlet.ParameterSetName -ne "Session") {
                                $paramSession = @{
                                    "ComputerName" = $computer.ToString()
                                    "ErrorAction"  = "Stop"
                                }
                                if ($Credential) { $paramSession.Add("Credential", $Credential) }
                                try {
                                    $Session = New-PSSession @paramSession
                                } catch {
                                    Write-PSFMessage -Level Error -Message "Error creating remoting session to computer '$($computer)'" -Target $computer -ErrorRecord $_
                                    break
                                }
                            }

                            # Transfer files
                            Copy-Item -ToSession $Session -Destination $DestinationPath -Force -Path $file
                            Copy-Item -ToSession $Session -Destination $DestinationPath -Force -Path $dllFiles
                        }
                    } elseif ((split-path $file) -notlike $DestinationPath) {
                        Copy-Item -Destination $DestinationPath -Force -Path $file
                        Copy-Item -Destination $DestinationPath -Force -Path $dllFiles
                    }

                    # Register manifest
                    if ($pscmdlet.ShouldProcess("Manifest '$($Path)' on computer '$($computer)'", "Register")) {
                        $destFileName = "$($DestinationPath)\$(split-path $file -Leaf)"
                        $paramInvokeCmd = [ordered]@{
                            "ComputerName" = $computer.ToString()
                            "ErrorAction"  = "Stop"
                            ErrorVariable  = "ErrorReturn"
                            "ArgumentList" = $destFileName
                        }
                        if ($PSCmdlet.ParameterSetName -eq "Session") { $paramInvokeCmd['ComputerName'] = $Session }
                        if ($Credential) { $paramInvokeCmd.Add("Credential", $Credential) }

                        Write-PSFMessage -Level Verbose -Message "Registering manifest '$($destFileName)' on computer '$($computer)'" -Target $computer
                        try {
                            $null = Invoke-PSFCommand @paramInvokeCmd -ScriptBlock {
                                try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { Write-Information -MessageData "Exception while setting UTF8 OutputEncoding. Continue script." }
                                $output = . "$($env:windir)\system32\wevtutil.exe" "install-manifest" "$($args[0])" *>&1
                                $output = $output | Where-Object { $_.InvocationInfo.MyCommand.Name -like 'wevtutil.exe' } *>&1
                                if ($output) { Write-Error -Message "$([string]::Join(" ", $output.Exception.Message.Replace("`r`n"," ")))" -ErrorAction Stop }
                            }
                            if ($ErrorReturn) { Write-Error "Error registering manifest" -ErrorAction Stop }
                        } catch {
                            Stop-PSFFunction -Message "Unable to register manifest '$($destFileName)' on computer '$($computer)'" -Target $computer -ErrorRecord $_
                        }

                    }
                }

                if($tempPath) {
                    Remove-Item -Path $tempPath -Recurse -Force -Confirm:$false -WhatIf:$false -Verbose:$false -Debug:$false -ErrorAction:Ignore
                }
            }
        }

    }

    end {

    }
}