function Set-WELCEventChannel {
    <#
    .SYNOPSIS
        Set-WELCEventChannel

    .DESCRIPTION
        Set various properties on a EventChannel

    .PARAMETER ChannelConfig
        InputObject (WELC.ChannelConfig) from Excel Template file

        Can be created by
            Import-WELCChannelDefinition -Path ".\MyTemplate.xls" -OutputChannelConfig

    .PARAMETER EventChannel
        InputObject from Get-WELCEventChannel

        Available Alias on the parameter: EventLogChannel

    .PARAMETER ChannelFullName
        The name of the channel to be set

    .PARAMETER ComputerName
        The computer where to set the configuration

    .PARAMETER Enabled
        The status of the logfile. By default the logfiles are enabled after execution

    .PARAMETER LogMode
        Specifies how events in the EventChannel are treated, if the EventChannel reaches the maximum.

        Possilibilites:
            "AutoBackup" = File from EventChannel will be renamed and a newly file will be created
            "Circular" = Oldest event will be overwritten
            "Retain" = Newly events will be refused

    .PARAMETER LogFilePath
        The path in the filesystem for the EventChannel EVTX file

        This can be a full qualified filename - if only ONE EventChannel is to be set/ piped in.
        Effectivly this means a rename of the file for the EventChannel.

        If multiple configurations should be set/ piped in, the value on this parameter
        should be a FOLDER, not a file!

    .PARAMETER CompressLogFolder
        Specifies if the folder with the log files get compressed

    .PARAMETER MaxEventLogSize
        The maximum size in bytes for the EventChannel

    .PARAMETER AllowFileAccessForLocalService
        The WellKnownPrincipal 'Local Service' will add in the NTFS ACL to gain access to the logfile

        If the channel is planned to be used in "Windows Event Forwarding" this should probably set to true

    .PARAMETER EventChannelSDDL
        SDDL string to set access on the eventlog within the WinodwsEventLog system itself

        This access object controls who can view events in the EventLog for this channel
        So it's not on the filesystem, it's in MMC, WMI or PowerShell

    .PARAMETER PassThru
        The moved files will be parsed to the pipeline for further processing.

    .PARAMETER WhatIf
            If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

    .PARAMETER Confirm
            If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

    .NOTES
        Author: Andreas Bellstedt

        This a is quite far modified version from Project Sauron fork.
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
        PS C:\> Set-WELCEventChannel -ChannelFullName "App1/MyLog" -LogMode Circular -LogFilePath "C:\EventLogs\App1-MyLog.evtx"

        Set the 'MyLog' EventLog in the EventFolder 'App1' to circular logging and the path of the logfile to 'C:\EventLogs\App1-MyLog.evtx'

    .EXAMPLE
        PS C:\> $channels | Set-WELCEventChannel -Enabled $true -MaxEventLogSize 1GB

        Enables the EventChannels from the $channels variable and set maximum size to 1GB.

        Assuming the $channels variable is filled with something like
        $channels = Get-WELCEventChannel -ChannelFullName "App1/MyLog", "App2/MyLog"

    .EXAMPLE
        PS C:\> $ChannelConfig | Set-WELCEventChannel -Enabled $true -CompressLogFolder $true -AllowFileAccessForLocalService $true

        Enables the EventChannels from the $ChannelConfig variable and set all the properties within the $ChannelConfig variable.
        Additionally, the logfile/logfolder for the EventLogs will be compressed (except if it is a folder in Windows\System32),
        and the SID for "Local Service" gain Read/Write-Access.

        Assuming the $channels variable is filled with something like
        $ChannelConfig = Import-WELCChannelDefinition -Path C:\EventLogs\WinEventLogCustomization.xlsx -OutputChannelConfig

        Excel template file can be created/opened with Open-WELCExcelTemplate

    #>
    [CmdletBinding(
        DefaultParameterSetName = "ChannelName",
        SupportsShouldProcess = $true,
        PositionalBinding = $true,
        ConfirmImpact = 'Medium'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", '', Justification = "Intentional, Pester not covering the usage correct")]
    Param(
        [Parameter(
            ParameterSetName = "TemplateChannelConfig",
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
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
        $CompressLogFolder,

        [bool]
        $AllowFileAccessForLocalService,

        [String]
        $EventChannelSDDL,

        [switch]
        $PassThru
    )

    Begin {
        $channelFullNameBound = Test-PSFParameterBinding -ParameterName ChannelFullName
        $computerBound = Test-PSFParameterBinding -ParameterName ComputerName^

        $configList = New-Object System.Collections.ArrayList

        # validation on parameter LogFilePath
        if ($LogFilePath) {
            $LogFilePath = $LogFilePath.TrimEnd("\")

            if ($LogFilePath -like '%SystemRoot%*') { $LogFilePath = $LogFilePath.Replace('%SystemRoot%', $env:SystemRoot) }

            if ($LogFilePath.EndsWith(".evtx")) {
                $logFileFolder = Split-Path -Path $LogFilePath
                $logFileFullName = $LogFilePath
            } else {
                $logFileFolder = $LogFilePath
                $logFileFullName = "ToBeCalculated"
            }
        }

        # if compression is set and windows-folder is specified as LogFilePath -> abort, to avoid 'unhealthy' system modification
        if ($LogFilePath -like "$($env:SystemRoot)\System32\*" -and $CompressLogFolder -eq $true) {
            Stop-PSFFunction -Message "Hardcoded exception, not going to set compression within windows-System32-folder. Aborting function" -EnableException $true
            break
        }
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
                            foreach ($eventChannelItem in $eventChannel) {
                                Write-PSFMessage -Level Debug -Message "Collecting config object for '$($eventChannelItem.Name)' on '$($computer)'"
                                $null = $configList.Add(
                                    [PSCustomObject]@{
                                        EventChannel                   = $eventChannelItem
                                        Enabled                        = $channelConfigItem.Enabled
                                        MaxEventLogSize                = $channelConfigItem.MaxEventLogSize
                                        LogMode                        = $channelConfigItem.LogMode
                                        LogFileFullName                = $channelConfigItem.LogFullName
                                        LogFilePath                    = (Split-Path -Path $channelConfigItem.LogFullName)
                                        CompressLogFolder              = $CompressLogFolder
                                        AllowFileAccessForLocalService = $AllowFileAccessForLocalService
                                        EventChannelSDDL               = $EventChannelSDDL
                                    }
                                )
                            }
                        } else {
                            Write-PSFMessage -Level Warning -Message "Skipping '$($channelConfigItem.ChannelName)' on '$($computer)'"
                            continue
                        }
                    }
                }
            }

            "EventChannel" {
                foreach ($eventChannelItem in $EventChannel) {
                    Write-PSFMessage -Level Debug -Message "Collecting config object for '$($eventChannelItem.ChannelFullName)' on '$($eventChannelItem.ComputerName)'"
                    $null = $configList.Add(
                        [PSCustomObject]@{
                            EventChannel                   = $eventChannelItem
                            Enabled                        = (.{ if (Test-PSFParameterBinding -ParameterName Enabled) { $Enabled } })
                            MaxEventLogSize                = (.{ if (Test-PSFParameterBinding -ParameterName MaxEventLogSize) { $MaxEventLogSize } })
                            LogMode                        = (.{ if (Test-PSFParameterBinding -ParameterName LogMode) { $LogMode } })
                            LogFileFullName                = (.{ if ($logFileFullName -like "ToBeCalculated") { "$($logFileFolder)\$($eventChannelItem.LogFile)" } elseif (Test-PSFParameterBinding -ParameterName LogFilePath) { $logFileFullName } })
                            LogFilePath                    = (.{ if (Test-PSFParameterBinding -ParameterName LogFilePath) { $logFileFolder } })
                            CompressLogFolder              = (.{ if (Test-PSFParameterBinding -ParameterName CompressLogFolder) { $CompressLogFolder } })
                            AllowFileAccessForLocalService = (.{ if (Test-PSFParameterBinding -ParameterName AllowFileAccessForLocalService) { $AllowFileAccessForLocalService } })
                            EventChannelSDDL               = (.{ if (Test-PSFParameterBinding -ParameterName EventChannelSDDL) { $EventChannelSDDL } })
                        }
                    )
                }
            }

            "ChannelName" {
                foreach ($channelNameItem in $ChannelFullName) {
                    foreach ($computer in $ComputerName) {
                        $eventChannel = $null
                        $eventChannel = Get-WELCEventChannel -ChannelFullName $channelNameItem -ComputerName $computer -ErrorAction SilentlyContinue
                        if ($eventChannel) {
                            foreach ($eventChannelItem in $eventChannel) {
                                Write-PSFMessage -Level Debug -Message "Collecting config object for '$($eventChannelItem.Name)' on '$($computer)'"
                                $null = $configList.Add(
                                    [PSCustomObject]@{
                                        EventChannel                   = $eventChannelItem
                                        Enabled                        = ( if (Test-PSFParameterBinding -ParameterName Enabled) { $Enabled } )
                                        MaxEventLogSize                = ( if (Test-PSFParameterBinding -ParameterName MaxEventLogSize) { $MaxEventLogSize } )
                                        LogMode                        = ( if (Test-PSFParameterBinding -ParameterName LogMode) { $LogMode } )
                                        LogFileFullName                = ( if ($logFileFullName -like "ToBeCalculated") { "$($logFileFolder)\$($eventChannelItem.LogFile)" } elseif (Test-PSFParameterBinding -ParameterName LogFilePath) { $logFileFullName } )
                                        LogFilePath                    = ( if (Test-PSFParameterBinding -ParameterName LogFilePath) { $logFileFolder } )
                                        CompressLogFolder              = ( if (Test-PSFParameterBinding -ParameterName CompressLogFolder) { $CompressLogFolder } )
                                        AllowFileAccessForLocalService = ( if (Test-PSFParameterBinding -ParameterName AllowFileAccessForLocalService) { $AllowFileAccessForLocalService } )
                                        EventChannelSDDL               = ( if (Test-PSFParameterBinding -ParameterName EventChannelSDDL) { $EventChannelSDDL } )
                                    }
                                )
                            }
                        } else {
                            Write-PSFMessage -Level Warning -Message "Skipping '$($channelNameItem)' on '$($computer)'"
                            continue
                        }
                    }
                }
            }

            Default {
                Stop-PSFFunction -Message "Unhandeled ParameterSetName. Developers mistake." -EnableException $true
                throw
            }
        }

    }

    End {
        # invalid configuration attempt - Parameter 'LogFilePath' specified as file and multiple channels should be configured
        if ($pscmdlet.ParameterSetName -notlike "TemplateChannelConfig" -and $LogFilePath -and $logFileFullName -notlike "ToBeCalculated" -and $configList.count -gt 1) {
            Stop-PSFFunction -Message "Parameter 'LogFilePath' was specified as a file, but more than one EventChannels where specified/piped. This leads to unvalid configuration. Each EventChannel has to have it's own LogFile. Please specify a folder on parameter 'LogFilePath'. Aborting..." -EnableException $true
            throw
        }

        Write-PSFMessage -Level Verbose -Message "Working trough list of $($configList.Count) collected EventChannel$(if($configList.Count -gt 1){"s"}) to configure"
        foreach ($configItem in $configList) {
            Write-PSFMessage -Level Verbose -Message "Processing '$($configItem.EventChannel.Name)' on '$($configItem.EventChannel.PSComputerName)'"

            # Get current folder for EventLogFile
            $eventLogFolderCurrent = Invoke-PSFCommand -ComputerName $configItem.EventChannel.PSComputerName -ArgumentList $configItem.EventChannel.LogFolder -ScriptBlock {
                $_query = "select * from CIM_Directory where name = `"$($args[0].Replace('\','\\'))`""
                Get-CimInstance -Query $_query -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false
            }

            # Check if FilePath for EventChannel should be modified
            if ($configItem.LogFilePath -and ($eventLogFolderCurrent.Name -notlike $configItem.LogFilePath)) {
                Write-PSFMessage -Level Verbose -Message "Set new path '$($configItem.LogFilePath)' for EventChannel"

                # First, check if destination folder is already present
                Write-PSFMessage -Level Debug -Message "Test new path: $($configItem.LogFilePath)"
                $destinationFolder = Invoke-PSFCommand -ComputerName $configItem.EventChannel.PSComputerName -ArgumentList $configItem.LogFilePath -ErrorVariable invokeErrors -ScriptBlock {
                    $_query = "select * from CIM_Directory where name = `"$($args[0].Replace('\','\\'))`""
                    $_result = Get-CimInstance -Query $_query -ErrorAction Ignore -Verbose:$false -Debug:$false

                    # if folder is not present, try to query root folder, to check if drive is valid
                    if (-not $_result) { $null = Get-Item -Path "$($args[0].split("\")[0])\" -ErrorAction SilentlyContinue } else { $_result }
                }

                # if error occured = drive is not present/valid
                if ($invokeErrors.Exception) {
                    Write-PSFMessage -Level Error -Message "Invalid path '$($configItem.LogFilePath)' on system '$($configItem.EventChannel.PSComputerName)'! Possibly inaccessable drive/volume" -EnableException $true -Exception $invokeErrors.Exception -ErrorRecord $invokeErrors -Target $configItem.EventChannel.PSComputerName
                    continue
                }
                Remove-Variable -Name invokeErrors -Force -Confirm:$false -WhatIf:$false -Verbose:$false -Debug:$false -ErrorAction Ignore

                # if folder is not available, create it
                If (-not $destinationFolder) {
                    if ($pscmdlet.ShouldProcess("EventChannel '$($configItem.EventChannel.Name)' on computer '$($configItem.EventChannel.PSComputerName)'", "Create folder '$($configItem.LogFilePath)'")) {
                        Write-PSFMessage -Level Verbose -Message "Create folder '$($configItem.LogFilePath)' for EventChannel"

                        try {
                            $destinationFolder = Invoke-PSFCommand -ComputerName $configItem.EventChannel.PSComputerName -ArgumentList $configItem.LogFilePath -ErrorAction Stop -ErrorVariable invokeErrors -ScriptBlock {
                                $_folder = New-Item -Type Directory -Path $args[0] -Force -ErrorAction Stop
                                $_query = "select * from CIM_Directory where name = `"$($_folder.FullName.Replace('\','\\'))`""
                                Get-CimInstance -Query $_query -ErrorAction SilentlyContinue -Verbose:$false -Debug:$false
                            }
                        } catch {
                            Write-PSFMessage -Level Error -Message "Unable to create folder '$($configItem.LogFilePath)' on '$($configItem.EventChannel.PSComputerName)'" -EnableException $true -Exception $_.Exception -ErrorRecord $_ -Target $configItem.EventChannel.PSComputerName
                            continue
                        }
                    }
                }

                # Set new folder to EventChannel
                if ($pscmdlet.ShouldProcess("EventChannel '$($configItem.EventChannel.Name)' on computer '$($configItem.EventChannel.PSComputerName)'", "Set new destination '$($configItem.LogFileFullName)'")) {
                    Write-PSFMessage -Level Verbose -Message "Set new destination '$($configItem.LogFileFullName)' for EventChannel '$($configItem.EventChannel.Name)' on computer '$($configItem.EventChannel.PSComputerName)'"

                    $invokeParam = @{
                        "ComputerName"  = $configItem.EventChannel.PSComputerName
                        "ArgumentList"  = ($configItem.EventChannel.Name , $configItem.LogFileFullName)
                        "ErrorAction"   = "Stop"
                        "ErrorVariable" = "invokeErrors"
                    }
                    try {
                        Invoke-PSFCommand @invokeParam -ScriptBlock {
                            $_eventChannelName = $args[0]
                            $_logFileFullName = $args[1]

                            $_channel = Get-WinEvent -ListLog $_eventChannelName -Force -ErrorAction Stop
                            $error.Clear()

                            # backup current status
                            $_currentIsEnabled = $_channel.IsEnabled

                            # Disable to change settings
                            $_channel.IsEnabled = $false
                            $_channel.SaveChanges()

                            # Set path on channel
                            $_channel.LogFilePath = $_logFileFullName
                            $_channel.IsEnabled = $_currentIsEnabled
                            $_channel.SaveChanges()
                            if ($error.Exception) { Write-Error "" -ErrorAction Stop }
                        }
                    } catch {
                        Write-PSFMessage -Level Error -Message "Unable to set new destination '$($configItem.LogFileFullName)' on '$($configItem.EventChannel.PSComputerName)'" -EnableException $true -Exception $_.Exception -ErrorRecord $_ -Target $configItem.EventChannel.PSComputerName
                    }
                }
            } else {
                $destinationFolder = $eventLogFolderCurrent
            }
            Remove-Variable -Name invokeErrors -Force -Confirm:$false -WhatIf:$false -Verbose:$false -Debug:$false -ErrorAction Ignore


            # Add an ACE to allow LOCAL SERVICE to modify the folder
            if ($configItem.AllowFileAccessForLocalService) {
                if ($pscmdlet.ShouldProcess("EventChannel '$($configItem.EventChannel.Name)' on computer '$($configItem.EventChannel.PSComputerName)'", "Add ACE for 'localSystem' on folder '$($configItem.LogFilePath)'")) {
                    Write-PSFMessage -Level Verbose -Message "Set ntfs permission for 'local service' to folder '$($destinationFolder.name)' on '$($configItem.EventChannel.PSComputerName)'"

                    $invokeParam = @{
                        "ComputerName"  = $configItem.EventChannel.PSComputerName
                        "ArgumentList"  = ($destinationFolder.name)
                        "ErrorAction"   = "Stop"
                        "ErrorVariable" = "invokeErrors"
                    }
                    try {
                        Invoke-PSFCommand @invokeParam -ScriptBlock {
                            $_destinationFolderName = $args[0]
                            $ace = New-Object System.Security.AccessControl.FileSystemAccessRule(
                                [System.Security.Principal.SecurityIdentifier]::new("S-1-5-19").Translate([System.Security.Principal.NTAccount]).Value,
                                'Modify',
                                'ContainerInherit,ObjectInherit',
                                'None',
                                'Allow'
                            )

                            $logPathACL = $_destinationFolderName | Get-Item -ErrorAction Stop | Get-ACL -ErrorAction Stop
                            if (-not ($logPathACL.Access | Where-Object { $_.IdentityReference -like $ace.IdentityReference -and $_.FileSystemRights -like $ace.FileSystemRights -and $_.AccessControlType -like $ace.AccessControlType })) {
                                $logPathACL.AddAccessRule($ace)
                                $logPathACL | Set-ACL -ErrorAction Stop
                            }
                        }
                    } catch {
                        Write-PSFMessage -Level Error -Message "Unable to set ntfs permission for 'local service' to folder '$($destinationFolder.name)' on '$($configItem.EventChannel.PSComputerName)'. Message: $($_.Exception.Message)" -EnableException $true -Exception $_.Exception -ErrorRecord $_ -Target $configItem.EventChannel.PSComputerName
                        continue
                    }
                    Remove-Variable -Name invokeErrors -Force -Confirm:$false -WhatIf:$false -Verbose:$false -Debug:$false -ErrorAction Ignore
                }
            }

            # Set compression on folder
            if ($configItem.CompressLogFolder) {
                if ($pscmdlet.ShouldProcess("EventChannel '$($configItem.EventChannel.Name)' on computer '$($configItem.EventChannel.PSComputerName)'", "Set compression '$($configItem.CompressLogFolder)' on folder '$($configItem.LogFilePath)'")) {
                    Write-PSFMessage -Level Verbose -Message "Set compression '$($configItem.CompressLogFolder)' to folder '$($destinationFolder)' on '$($configItem.EventChannel.PSComputerName)'"

                    $invokeParam = @{
                        "ComputerName"    = $configItem.EventChannel.PSComputerName
                        "ArgumentList"    = ($destinationFolder, $configItem.CompressLogFolder)
                        "ErrorAction"     = "Stop"
                        "ErrorVariable"   = "invokeErrors"
                        "WarningAction"   = "SilentlyContinue"
                        "WarningVariable" = "invokeWarnings"
                    }
                    try {
                        Invoke-PSFCommand @invokeParam -ScriptBlock {
                            $_destinationFolder = $args[0]
                            $_Compression = $args[1]
                            $_query = "select * from CIM_Directory where name = `"$($_destinationFolder.Name.Replace('\','\\'))`""
                            $_cimResult = $null
                            $returnCodes = [ordered]@{
                                0  = "Success"
                                2  = "Access denied"
                                8  = "Unspecified failure"
                                9  = "Invalid object"
                                10 = "Object already exists"
                                11 = "File system not NTFS"
                                12 = "Platform not Windows"
                                13 = "Drive not the same"
                                14 = "Directory not empty"
                                15 = "Sharing violation"
                                16 = "Invalid start file"
                                17 = "Privilege not held"
                                21 = "Invalid parameter"
                            }

                            if ($_Compression -eq $true -and $_destinationFolder.Compressed -eq $false) {
                                $_cimResult = Invoke-CimMethod -Query $_query -MethodName Compress -ErrorAction Stop -Verbose:$false
                            } elseif ($_Compression -eq $false -and $_destinationFolder.Compressed -eq $true) {
                                $_cimResult = Invoke-CimMethod -Query $_query -MethodName Uncompress -ErrorAction Stop -Verbose:$false
                            } else {
                                Write-Warning "Noting to do  on '$($_destinationFolder.Name)'" -WarningAction SilentlyContinue
                            }

                            if ($_cimResult) {
                                if ($_cimResult.ReturnValue -notin (0, 15)) {
                                    Write-Error "Error '$($_cimResult.ReturnValue) ($($returnCodes[$_cimResult.ReturnValue]))' occured while set compression attribute '$($_Compression)'" -ErrorAction Stop
                                } elseif ($_cimResult.ReturnValue -eq 15) {
                                    Write-Warning "Compression attribute set, but with sharing violation. Means, attribute could not be applied on all files in folder" -WarningAction SilentlyContinue
                                }
                            }
                        }
                    } catch {
                        Write-PSFMessage -Level Error -Message "Unable to set compression to folder '$($destinationFolder.name)' on '$($configItem.EventChannel.PSComputerName)'. Message: $($_.Exception.Message)" -EnableException $true -Exception $_.Exception -ErrorRecord $_ -Target $configItem.EventChannel.PSComputerName
                    }
                    if ($invokeWarnings) { $invokeWarnings | ForEach-Object { Write-PSFMessage -Level Warning -Message $_ } }
                    Remove-Variable -Name invokeErrors, invokeWarnings -Force -Confirm:$false -WhatIf:$false -Verbose:$false -Debug:$false -ErrorAction Ignore
                }
            }

            # Set all the other possible EventChannel configs, including "Enabled" as the last setting
            $valueToSet = $configItem.psobject.Properties | Where-Object Name -in ("Enabled", "MaxEventLogSize", "LogMode", "EventChannelSDDL") | Where-Object { $_.Value -is $_.TypeNameOfValue }
            if ($valueToSet) {
                $valueToSetText = [string]::Join(', ', ($valueToSet | ForEach-Object { "$($_.Name)=$($_.Value)" }))
                if ($pscmdlet.ShouldProcess("EventChannel '$($configItem.EventChannel.Name)' on computer '$($configItem.EventChannel.PSComputerName)'", "Set '$($valueToSetText)'")) {
                    Write-PSFMessage -Level Verbose -Message "Set '$($valueToSetText)' to EventChannel '$($configItem.EventChannel.Name)' on '$($configItem.EventChannel.PSComputerName)'"

                    $invokeParam = @{
                        "ComputerName"  = $configItem.EventChannel.PSComputerName
                        "ArgumentList"  = ($configItem.EventChannel.Name, ($valueToSet | Select-Object Name, Value))
                        "ErrorAction"   = "Stop"
                        "ErrorVariable" = "invokeErrors"
                    }
                    try {
                        Invoke-PSFCommand @invokeParam -ScriptBlock {
                            $_eventChannelName = $args[0]
                            $_valueToSet = $args[1]
                            $_translateSettingToProperty = @{
                                "Enabled"          = "IsEnabled"
                                "MaxEventLogSize"  = "MaximumSizeInBytes"
                                "LogMode"          = "LogMode"
                                "EventChannelSDDL" = "SecurityDescriptor"
                            }

                            $_channel = Get-WinEvent -ListLog $_eventChannelName -Force -ErrorAction Stop
                            $error.Clear()

                            # backup current status
                            $_currentIsEnabled = $_channel.IsEnabled

                            # Disable to change settings
                            $_channel.IsEnabled = $false
                            $_channel.SaveChanges()

                            # Set properties on channel
                            foreach ($setting in ($_valueToSet | Where-Object name -NotLike "Enabled")) {
                                $_channel.($_translateSettingToProperty[$setting.Name]) = $setting.Value
                            }

                            $_desiredChannelStatus = $_valueToSet | Where-Object name -Like "Enabled"
                            if ($_desiredChannelStatus) {
                                $_channel.IsEnabled = $_desiredChannelStatus.Value
                            } else {
                                $_channel.IsEnabled = $_currentIsEnabled
                            }
                            $_channel.SaveChanges()
                            if ($error.Exception) { Write-Error "" -ErrorAction Stop }
                        }
                    } catch {
                        Write-PSFMessage -Level Error -Message "Unable to set '$($valueToSetText)' to EventChannel '$($configItem.EventChannel.Name)' on '$($configItem.EventChannel.PSComputerName)'. Message: $($_.Exception.Message)" -EnableException $true -Exception $_.Exception -ErrorRecord $_ -Target $configItem.EventChannel.PSComputerName
                        continue
                    }
                    Remove-Variable -Name invokeErrors -Force -Confirm:$false -WhatIf:$false -Verbose:$false -Debug:$false -ErrorAction Ignore
                }
            }

            # Output if specified
            if ($PassThru) {
                Get-WELCEventChannel -ChannelFullName $configItem.EventChannel.Name -ComputerName $configItem.EventChannel.PSComputerName -ErrorAction SilentlyContinue
            }
        }
    }
}
