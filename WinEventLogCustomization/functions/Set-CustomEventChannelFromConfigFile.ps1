function Set-CustomEventChannelFromConfigFile {
    <#
    .SYNOPSIS
        Name: Set-CustomEventChannelFromConfigFile.ps1
        Version: 0.1
        This is a modified version from Project Sauron fork.


        Name: Prep-EventChannels.ps1
        Version: 1.1
        Author: Russell Tomkins - Microsoft Premier Field Engineer
        Blog: https://aka.ms/russellt

        Preparation of event channels to receive event collection subscriptions from an input CSV
        Source: https://www.github.com/russelltomkins/ProjectSauron

    .DESCRIPTION
        Leverages an input CSV file to prepare the custom event channels created by Create-Manifest.ps1

        Refer to this blog series for more details
        http://blogs.technet.microsoft.com/russellt/2017/03/23/project-sauron-part-1

    .EXAMPLE
        Prepare the Event Chanenls using the Input CSV file.
        Create-Subscriptions.ps1 -InputFile DCEvents.csv

    .PARAMETER InputFile
        A CSV file which must include a ChannelName, ChannelSymbol, QueryPath and the xPath Query itself

    .PARAMETER LogRootPath
        The location of .evtx event log files. Defaults to "D:\Logs"

        LEGAL DISCLAIMER
        This Sample Code is provided for the purpose of illustration only and is not
        intended to be used in a production environment.  THIS SAMPLE CODE AND ANY
        RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
        EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF
        MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  We grant You a
        nonexclusive, royalty-free right to use and modify the Sample Code and to
        reproduce and distribute the object code form of the Sample Code, provided
        that You agree: (i) to not use Our name, logo, or trademarks to market Your
        software product in which the Sample Code is embedded; (ii) to include a valid
        copyright notice on Your software product in which the Sample Code is embedded;
        and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and
        against any claims or lawsuits, including attorneys fees, that arise or result
        from the use or distribution of the Sample Code.

        This posting is provided "AS IS" with no warranties, and confers no rights. Use
        of included script samples are subject to the terms specified
        at http://www.microsoft.com/info/cpyright.htm.
    #>
    [CmdletBinding(
        SupportsShouldProcess = $false,
        PositionalBinding = $true,
        ConfirmImpact = 'Medium'
    )]
    Param(
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias("FullName", "In")]
        [String[]]$InputFile = "C:\Administration\WEC-DCEvents.csv",

        # The Import delimiter for the csv file
        [Parameter(Mandatory = $false)]
        [String]$ImportDelimiter = ";",

        # Encoding of csv file to import
        [Parameter(Mandatory = $false)]
        [String]$ImportEncoding = "Default",

        # Specifies if the folder with the log files get compressed
        [Parameter(Mandatory = $false)]
        [bool]$CompressLogFolder = $true,

        # The status of the logfile. By default the logfiles are enabled after execution.
        [Parameter(Mandatory = $false)]
        [bool]$EventChannelEnabled = $true
    )

    Begin {

    }

    Process {
        foreach ($FilePath in $InputFile) {
            # Import our Custom Events
            try {
                $CustomChannels = Import-CSV -Path $FilePath -Delimiter $ImportDelimiter -Encoding $ImportEncoding -ErrorAction Stop | Where-Object ProviderSymbol
            } catch {
                Write-Error -Message "Error while importing csv file ($($FilePath)). Maybe wrong file format. Please go and check the csv file."
                break
            }

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
                $EventChannel.IsEnabled = $EventChannelEnabled
                $EventChannel.SaveChanges()
            }
        }
    }

    End {

    }
}
