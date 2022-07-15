function Set-WELCEventChannel {
    <#
    .SYNOPSIS
    Set-WELCEventChannel

    .DESCRIPTION
    Leverages an input CSV file to prepare the custom event channels created by Create-Manifest.ps1

    .PARAMETER ChannelConfig


    .PARAMETER EventChannel


    .PARAMETER ChannelFullName
        The name of the channel to be set.

    .PARAMETER CompressLogFolder
        Specifies if the folder with the log files get compressed

    .PARAMETER Enabled
        The status of the logfile. By default the logfiles are enabled after execution.

    .PARAMETER MaxEventLogSize


    .PARAMETER AllowFileAccessForLocalService


    .PARAMETER EventChannelSDDL


    .NOTES
        Author: Andreas Bellstedt

        This is a modified version from Project Sauron fork.
        Name: Prep-EventChannels.ps1
        Version: 1.1
        Author: Russell Tomkins - Microsoft Premier Field Engineer
        Blog: https://aka.ms/russellt

        Preparation of event channels to receive event collection subscriptions from an input CSV
        Source: https://www.github.com/russelltomkins/ProjectSauron

        Refer to this blog series for more details
        http://blogs.technet.microsoft.com/russellt/2017/03/23/project-sauron-part-1


    .LINK
        https://github.com/AndiBellstedt/WinEventLogCustomization


    .EXAMPLE
        PS C:\> Set-WELCEventChannel

    #>
    [CmdletBinding(
        DefaultParameterSetName = "ChannelName",
        SupportsShouldProcess = $true,
        PositionalBinding = $true,
        ConfirmImpact = 'Medium'
    )]
    Param(
        [Parameter(
            ParameterSetName = "TemplateChannelConfig",
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [Alias("In", "InputObject")]
        [WELC.ChannelConfig[]]
        $ChannelConfig,

        [Parameter(
            ParameterSetName = "EventChannel",
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [Alias("EventLogChannel")]
        [WELC.EventLogChannel[]]
        $EventChannel,

        [Parameter(
            ParameterSetName = "ChannelName",
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [Alias("ChannelName")]
        [String[]]
        $ChannelFullName,

        [Parameter(
            ParameterSetName = "TemplateChannelConfig",
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [Parameter(
            ParameterSetName = "ChannelName",
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [Alias("Host", "Hostname", "Computer", "DNSHostName")]
        [PSFComputer[]]
        $ComputerName = $env:COMPUTERNAME,

        [Parameter(ParameterSetName = "EventChannel")]
        [Parameter(ParameterSetName = "ChannelName")]
        [bool]
        $Enabled,

        [Parameter(ParameterSetName = "EventChannel")]
        [Parameter(ParameterSetName = "ChannelName")]
        [int]
        $MaxEventLogSize,

        [Parameter(ParameterSetName = "EventChannel")]
        [Parameter(ParameterSetName = "ChannelName")]
        [ValidateSet("AutoBackup", "Circular", "Retain")]
        [string]
        $LogMode,

        [Parameter(ParameterSetName = "EventChannel")]
        [Parameter(ParameterSetName = "ChannelName")]
        [String]
        $LogFilePath,

        [Parameter(ParameterSetName = "EventChannel")]
        [Parameter(ParameterSetName = "ChannelName")]
        [Alias("Compress")]
        [bool]
        $CompressLogFolder = $true,

        [bool]
        $AllowFileAccessForLocalService = $true,

        [String]
        $EventChannelSDDL
    )

    Begin {
        $channelFullNameBound = Test-PSFParameterBinding -ParameterName ChannelFullName
        $computerBound = Test-PSFParameterBinding -ParameterName ComputerName^

        $configList = New-Object System.Collections.ArrayList
    }

    Process {
        #region parameterset workarround
        Write-PSFMessage -Level Debug -Message "ParameterNameSet: $($PsCmdlet.ParameterSetName)"

        #ToDo: Check if this behaves right. What is if ComputerName "foo" is piped in and Channelfullname is specified, and vice versa
        # Workarround parameter binding behaviour of powershell in combination with ComputerName Piping
        if (-not ($channelFullNameBound -or $computerBound) -and $ComputerName.InputObject) {
            if ($ComputerName.InputObject -is [string]) { $ComputerName = $env:ComputerName } else { $ChannelFullName = "" }
        }
        #endregion parameterset workarround


        switch ($pscmdlet.ParameterSetName) {
            "TemplateChannelConfig" {
                Write-PSFMessage -Level Verbose -Message "Gathering $(([array]$ChannelConfig).count) channel configurations"
                foreach ($channelConfigItem in $ChannelConfig) {
                    foreach ($computer in $ComputerName) {
                        $eventChannel = $null
                        $eventChannel = Get-WELCEventChannel -ChannelFullName $channelConfigItem.ChannelName -ComputerName $computer -ErrorAction SilentlyContinue
                        if ($eventChannel) {
                            Write-PSFMessage -Level Debug -Message "Collecting config object for '$($channelConfigItem.ChannelName)' on '$($computer)'"
                            $null = $configList.Add(
                                [PSCustomObject]@{
                                    EventChannel                   = $eventChannel
                                    Enabled                        = $channelConfigItem.Enabled
                                    MaxEventLogSize                = $channelConfigItem.MaxEventLogSize
                                    LogMode                        = $channelConfigItem.LogMode
                                    LogFilePath                    = $channelConfigItem.LogFullName
                                    CompressLogFolder              = $CompressLogFolder
                                    AllowFileAccessForLocalService = $AllowFileAccessForLocalService
                                    EventChannelSDDL               = $EventChannelSDDL
                                }
                            )
                        } else {
                            Write-PSFMessage -Level Warning -Message "Skipping '$($channelConfigItem.ChannelName)' on '$($computer)'"
                            continue
                        }
                    }
                }
            }

            "EventChannel" {

            }

            "ChannelName" {

            }

            Default {
                Stop-PSFFunction -Message "Unhandeled ParameterSetName. Developers mistake." -EnableException $true
                throw
            }
        }

    }

    End {
        foreach ($configItem in $configList) {


            # Check Log Folders
            foreach ($Folder in ($CustomChannels | Group-Object logfolder | Select-Object -ExpandProperty Name)) {
                # Get or Create The Folder
                If (-not (Test-Path $Folder)) {
                    $LogFolder = New-Item -Type Directory -Path $Folder -Force -ErrorAction Continue
                } else {
                    $LogFolder = Get-Item $Folder -Force -ErrorAction Continue
                }
                if (-not $LogFolder) { continue }

                # Add an ACE to allow LOCAL SERVICE to modify the folder
                Write-Verbose "Set ntfs permissions folder '$($LogFolder)' for 'local service'."
                $LogRootPathACL = $LogFolder | Get-ACL
                $ACE = New-Object System.Security.AccessControl.FileSystemAccessRule("LOCAL SERVICE", 'Modify', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
                $LogRootPathACL.AddAccessRule($ACE)
                $LogRootPathACL | Set-ACL

                if ($CompressLogFolder) {
                    # Enable NTFS compression to save disk space
                    Write-Verbose "Set compression flag on folder '$($LogFolder)'."
                    $Query = "select * from CIM_Directory where name = `"$($LogFolder.FullName.Replace('\','\\'))`""
                    try {
                        $CIMResult = Invoke-CimMethod -Query $Query -MethodName Compress -ErrorAction Stop -Verbose:$false
                    } catch {
                        Write-Warning "Setting compression on folder '$($LogFolder)' failed. Return value is $($CIMResult.ReturnValue)"
                    }
                } else {
                    Write-Verbose "Skipping compression flag on folder '$($LogFolder)'."
                }
            }

            # Loop through Chanell form the InputCSV
            ForEach ($Channel in $CustomChannels) {
                # --- Setup the Event Channels ---
                # Bind to the Event Channel
                try {
                    $EventChannel = Get-WinEvent -ListLog $Channel.ChannelName -ErrorAction Stop
                } catch {
                    Write-Error -Message "Event channel not loaded: '$($Channel.ChannelName)'! Ensure the manifest and dll has been created and loaded with 'Initialize-CustomEventChannel'-script or wevutil.exe."
                    Continue
                }

                # Disable the channel to allow changes
                If ($EventChannel.IsEnabled) {
                    $EventChannel.IsEnabled = $False
                    $EventChannel.SaveChanges()
                }

                # Update the channel to our requried Values
                $EventChannel.LogFilePath = $Channel.LogFullName
                $EventChannel.LogMode = $Channel.LogMode
                $EventChannel.MaximumSizeInBytes = $Channel.MaxEventLogSize / 1
                $EventChannel.SaveChanges()

                # Enable the Log
                $EventChannel.IsEnabled = $Enabled
                $EventChannel.SaveChanges()
            }
        }
    }
}
