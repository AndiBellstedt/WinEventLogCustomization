function New-WELCEventChannelManifest {
    <#
    .SYNOPSIS
        New-WELCEventChannelManifest
        Creates Manifest- and DLL-file for register custom Windows EventLog Channels

    .DESCRIPTION
        Creates Manifest- and DLL-file for register custom Windows EventLog Channels

        Once compiled, the files can be registered into a Windows EventLog system to
        allow custom logs.

    .PARAMETER InputObject
        The input csv file for creating the xml manifest and the dll

    .PARAMETER DestinationPath
        Output path for xml manifest file (.man file) and the dll-file for the eventlog viewer

    .NOTES
        Author: Andreas Bellstedt

        Adopted from Russell Tomkins "Project Sauron"
            Author: Russell Tomkins
            Github: https://www.github.com/russelltomkins/ProjectSauron

            Originbal description:
            ---------------------
            Name: Create-Manifest.ps1
            Version: 1.1
            Author: Russell Tomkins - Microsoft Premier Field Engineer
            Blog: https://aka.ms/russellt
            Refer to this blog series for more details
            http://blogs.technet.microsoft.com/russellt/2017/03/23/project-sauron-part-1


    .LINK
        https://github.com/AndiBellstedt/WinEventLogCustomization

    .EXAMPLE
        PS C:\> New-WELCEventChannelManifest -InputObject $ChannelDefinition

        Creates the manfifest- and DLL-file to register a custom EventLog channel in Windows
        Output depend on content in Excel file. Each root channel will be a manifest- (,man) and a DLL-file.

        Assuming that the variable $ChannelDefinition contains a WELC.ChannelDefinition object(list)
        PS C:\> $ChannelDefinition = Import-WELCChannelDefinition -Path CustomEventLogChannel.xlsx

    .EXAMPLE
        PS C:\> Import-WELCChannelDefinition -Path CustomEventLogChannel.xlsx | New-WELCEventChannelManifest

        Creates the Manfifest file and compile dll file(s) from the content of 'CustomEventLogChannel.xlsx'

    .EXAMPLE
        PS C:\> New-WELCEventChannelManifest -ChannelFullName "ChannelFolder/ChannelName"

        Creates a manifest (ChannelFolder.man) and compile a dll file (ChannelFolder.dll) with a single EventLogChannel "ChannelName" and a folder "ChannelFolder"

    .EXAMPLE
        PS C:\> "MyFolder/MyChannel1", "MyFolder/MyChannel2", "MyFolder/MyChannel3", "MyFolder/MyChannel4" | New-WELCEventChannelManifest

        Creates a manifest (MyChannel.man) and compile a dll file (MyChannel.dll) with 4 EventLogChannels MyChannel1-4 in the folder "MyFolder"
    #>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        PositionalBinding = $true,
        ConfirmImpact = 'Medium',
        DefaultParameterSetName = 'ManualDefinition'
    )]
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "InputObject",
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [Alias("Object", "In", "ChannelDefinition")]
        [WELC.ChannelDefinition[]]
        $InputObject,

        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "ManualFullChannelName",
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [Alias("FullName")]
        [String]
        $ChannelFullName,

        [Parameter(ParameterSetName = "ManualFullChannelName")]
        [String]
        $ChannelSymbol,

        [Parameter(ParameterSetName = "ManualFullChannelName")]
        [String]
        $ProviderName,

        [Parameter(ParameterSetName = "ManualFullChannelName")]
        [String]
        $ProviderSymbol,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "ManualDefinition",
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [Alias("Root", "FolderNameRoot", "RootFolderName")]
        [String]
        $FolderRoot,

        [Parameter(
            Mandatory = $false,
            ParameterSetName = "ManualDefinition",
            Position = 1
        )]
        [ValidateNotNullOrEmpty()]
        [Alias("SecondLevel", "FolderNameSecondLevel", "SecondLevelFolderName")]
        [String]
        $FolderSecondLevel,

        [Parameter(
            Mandatory = $false,
            ParameterSetName = "ManualDefinition",
            Position = 2
        )]
        [ValidateNotNullOrEmpty()]
        [Alias("ThirdLevel", "FolderNameThirdLevel", "ThirdLevelFolderName")]
        [String]
        $FolderThirdLevel,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "ManualDefinition",
            Position = 3
        )]
        [ValidateNotNullOrEmpty()]
        [String]
        $ChannelName,

        [Alias("FileName")]
        [String]
        $OutputFile,

        [ValidateNotNullOrEmpty()]
        [Alias("OutputPath")]
        [String]
        $DestinationPath = ".\"
    )

    Begin {
        #region Constants
        Write-PSFMessage -Level Debug -Message "Initalizing constants"
        # Path to csc.exe in windows
        [String]$WindowsCSCPath = "$($env:windir)\Microsoft.NET\Framework64\v4.0.30319"
        Write-PSFMessage -Level Debug -Message ".NET Framework in '$($WindowsCSCPath)'"

        # Compilation tools from the windows SDK. The required executables are "mc.exe", "rc.exe" and "rcdll.dll". There is another tool "ecmangen.exe" (EventChannel ManifestGenerator) which is usefull to check and maintain the manifest files.
        [String]$CompilationToolPath = "$($MyInvocation.MyCommand.Module.ModuleBase)\bin"
        Write-PSFMessage -Level Debug -Message "Binary CompilationTool is in '$($CompilationToolPath)'"

        # Path where the output files, and some other temp files from the compilation process are stored.
        [String]$TempPath = "$($env:TEMP)\WELC_$([guid]::NewGuid().guid)"
        Write-PSFMessage -Level Debug -Message "Operating in temporary path '$($TempPath)'"
        #endregion Constants


        #region Variables
        $channelDefinitions = @()
        #endregion Variables


        #region Validity checks
        Write-PSFMessage -Level Debug -Message "Initial parameter validation"
        # Check for required resscoures und compilation folder
        if ($DestinationPath.EndsWith('\')) { $DestinationPath = $DestinationPath.TrimEnd('\') }
        $DestinationPath = Resolve-Path $DestinationPath -ErrorAction Stop | Select-Object -ExpandProperty Path

        # Check for temp folder
        if ($TempPath.EndsWith('\')) { $TempPath = $TempPath.TrimEnd('\') }
        if (Test-Path -Path $TempPath -IsValid) {
            if (-not (Test-Path -Path $TempPath -PathType Container)) {
                Write-PSFMessage -Level Debug -Message "Creating temporary directory '$($TempPath)'"
                New-Item -Path $TempPath -ItemType Directory -Force | Out-Null
                $TempPath = Resolve-Path $TempPath -ErrorAction Stop | Select-Object -ExpandProperty Path
            }
        } else {
            throw "$($TempPath) is not a valid path"
        }

        # Check for required resscoures und compilation folder
        if ($CompilationToolPath.EndsWith('\')) { $CompilationToolPath = $CompilationToolPath.TrimEnd('\') }
        Resolve-Path $CompilationToolPath -ErrorAction Stop | Out-Null
        Test-Path -Path "$($CompilationToolPath)\mc.exe" -ErrorAction Stop | Out-Null
        Test-Path -Path "$($CompilationToolPath)\rc.exe" -ErrorAction Stop | Out-Null
        Test-Path -Path "$($CompilationToolPath)\rcdll.dll" -ErrorAction Stop | Out-Null
        Write-PSFMessage -Level Debug -Message "Binary tools found in CompilationTool path '$($CompilationToolPath)'"
        #endregion Validity checks
    }

    Process {
        Write-PSFMessage -Level Debug -Message "ParameterNameSet: $($PsCmdlet.ParameterSetName)"
        switch ($pscmdlet.ParameterSetName) {
            "InputObject" {
                $channelDefinitions += foreach ($item in $InputObject) {
                    $item
                }
            }

            "ManualFullChannelName" {
                $channelDefinitions += foreach ($_channelFullName in $ChannelFullName) {
                    # Validate the parameters - if SecondLevel is specified, ThirdLevel has to be present also
                    Write-PSFMessage -Level Debug -Message "Validating ChannelFullName '$($_channelFullName)'"
                    if ($_channelFullName -match (Get-PSFConfigValue -FullName WinEventLogCustomization.MatchString.ChannelName)) {
                        $_channelName = $_channelFullName
                    } else {
                        Stop-PSFFunction -Message "Invalid format on ChannelFullName '$($_channelFullName)'. Valid format for ChannelFullName must be somthing like 'FolderRoot-FolderSecondLevel-FolderThirdLevel/ChannelName' or 'FolderRoot/ChannelName'" -EnableException $true
                    }

                    if (-not $ChannelSymbol) {
                        $_channelSymbol = [String]::Join("_", $_channelFullName.Split("-").Split("/").ToUpper())
                        Write-PSFMessage -Level Debug -Message "ChannelSymbol not specified. Derive value '$($_channelSymbol)' from ChannelFullName"
                    } else {
                        if ($ChannelSymbol -match (Get-PSFConfigValue -FullName WinEventLogCustomization.MatchString.ChannelSymbol)) {
                            $_channelSymbol = $ChannelSymbol.ToUpper()
                        } else {
                            Stop-PSFFunction -Message "Invalid format on ChannelSymbol '$($ChannelSymbol)'. Valid format for ChannelSymbol must be somthing like 'FolderRoot_FolderSecondLevel_FolderThirdLevel_ChannelName' or 'FolderRoot_ChannelName'" -EnableException $true
                        }
                    }

                    if (-not $ProviderName) {
                        $_providerName = $_channelFullName.Replace( "/$($_channelFullName.Split("/")[-1])", "")
                        Write-PSFMessage -Level Debug -Message "ProviderName not specified. Derive value '$($_providerName)' from ChannelFullName"
                    } else {
                        if ($ProviderName -match (Get-PSFConfigValue -FullName WinEventLogCustomization.MatchString.ProviderName)) {
                            $_providerName = $ProviderName
                        } else {
                            Stop-PSFFunction -Message "Invalid format on ProviderName '$($ProviderName)'. Valid format for ProviderName must be somthing like 'FolderRoot-FolderSecondLevel-FolderThirdLevel' or 'FolderRoot'" -EnableException $true
                        }
                    }

                    if (-not $ProviderSymbol) {
                        $_providerSymbol = [String]::Join("_", ($_channelFullName.Replace( "/$($_channelFullName.Split("/")[-1])", "")).Split("-").ToUpper())
                        Write-PSFMessage -Level Debug -Message "ChannelSymbol not specified. Derive value '$($_providerSymbol)' from ChannelFullName"
                    } else {
                        if ($ProviderSymbol -match (Get-PSFConfigValue -FullName WinEventLogCustomization.MatchString.ProviderSymbol)) {
                            $_providerSymbol = $ProviderSymbol.ToUpper()
                        } else {
                            Stop-PSFFunction -Message "Invalid format on ProviderSymbol '$($ProviderSymbol)'. Valid Format for ProviderSymbol must be somthing like 'FolderRoot-FolderSecondLevel-FolderThirdLevel' or 'FolderRoot'" -EnableException $true
                        }

                    }

                    # Create custom "WEC.ChannelDefinition" object
                    Write-PSFMessage -Level Verbose -Message "Create ChannelDefinition object from '$($_channelFullName)'"
                    [PSCustomObject]@{
                        ProviderSymbol = $_providerSymbol
                        ProviderName   = $_providerName
                        ChannelName    = $_channelName
                        ChannelSymbol  = $_channelSymbol
                    }

                    # Cleanup the mess of variables
                    Write-PSFMessage -Level Debug -Message "Cleanup variables"
                    Remove-Variable _channelSymbol, _channelName, _providerSymbol, _providerName -Force -ErrorAction Ignore -WarningAction Ignore -Verbose:$false -Confirm:$false -WhatIf:$false -Debug:$false
                }
            }

            "ManualDefinition" {
                # Validate the parameters - if SecondLevel is specified, ThirdLevel has to be present also
                if ($FolderSecondLevel -and ($null -eq $FolderThirdLevel)) {
                    Write-PSFMessage -Level Warning -Message "Parameter 'FolderSecondLevel' was specified, but 'FolderThirdLevel' is missing."
                    Write-PSFMessage -Level Warning -Message "By design, only 'FolderRoot' or all the FolderPaths has to be specified."
                    Stop-PSFFunction -Message "Aborting creation."
                }

                # Build variables for custom ChannelDefinition object
                Write-PSFMessage -Level Debug -Message "Arranging data for ChannelDefinition object"
                [Array]$_folderNames = $FolderRoot, $FolderSecondLevel, $FolderThirdLevel | ForEach-Object { if ($_) { $_ } }
                [Array]$_providerSymbols = $FolderRoot.toupper(), $FolderSecondLevel.toupper(), $FolderThirdLevel.toupper() | ForEach-Object { if ($_) { $_ } }
                [Array]$_channelSymbols = $_providerSymbols + $ChannelName.toupper()

                $_providerName = [String]::Join("-", $_folderNames)
                $_providerSymbol = [String]::Join("_", $_providerSymbols)
                $_channelName = [String]::Join("-", $_folderNames) + "/" + $ChannelName
                $_channelSymbol = [String]::Join("_", $_channelSymbols)

                # Create custom "WEC.ChannelDefinition" object
                Write-PSFMessage -Level Verbose -Message "Create ChannelDefinition object for '$($_channelName)'"
                $channelDefinitions = [PSCustomObject]@{
                    ProviderSymbol = $_providerSymbol
                    ProviderName   = $_providerName
                    ChannelName    = $_channelName
                    ChannelSymbol  = $_channelSymbol
                }

                # Cleanup the mess of variables
                Write-PSFMessage -Level Debug -Message "Cleanup variables"
                Remove-Variable _channelSymbol, _channelName, _providerSymbol, _providerName, _channelSymbols, _providerSymbols, _folderNames -Force -ErrorAction Ignore -Confirm:$false -WhatIf:$false -Debug:$false
            }

            Default {
                throw "Undefined ParameterSet. Developers mistake."
            }
        }
    }

    End {
        Write-PSFMessage -Level Verbose -Message "Collected $($channelDefinitions.Count) channel definition$(if($channelDefinitions.Count -gt 1){"s"})"

        [array]$baseNames = $channelDefinitions | Select-Object -ExpandProperty ProviderName | Foreach-Object { $_.split("-")[0] } | Sort-Object -Unique
        Write-PSFMessage -Level Verbose -Message "Going to create $($baseNames.Count) manifest file$(if($baseNames.Count -gt 1){"s"}) from collected channel definition$(if($channelDefinitions.Count -gt 1){"s"})"
        foreach ($baseName in $baseNames) {
            # Shorten Name for file
            if ($pscmdlet.ParameterSetName -like "InputObject") {
                if ($OutputFile) {
                    $OutputFile = $OutputFile.Replace( ".$($OutputFile.Split(".")[-1])", "")
                    $fileName = $OutputFile + "_" + $baseName.Replace(" ", "")
                } else {
                    $fileName = $baseName.Replace(" ", "")
                }
            } else {
                if ($OutputFile) {
                    $fileName = $OutputFile.Replace( ".$($OutputFile.Split(".")[-1])", "")
                } else {
                    $fileName = $baseName.Replace(" ", "")
                }
            }

            # The Resource and Message DLL that will be referenced in the manifest
            $fileNameDLL = $fileName + ".dll"
            $fullNameDLLTemp = $TempPath + "\" + $fileNameDLL
            $fullNameDLLDestination = $DestinationPath + "\" + $fileNameDLL

            # The Manifest file
            $fileNameManifest = $fileName + ".man"
            $fullNameManifestTemp = $TempPath + "\" + $fileNameManifest

            Write-PSFMessage -Level Verbose -Message "Arraging manifest: $($fileName) ('$($DestinationPath + "\" + $fileNameManifest)', '$($fullNameDLLDestination)')"

            # Filter down the the full channel list
            $channelSelection = $channelDefinitions | Where-Object ProviderName -like "$($baseName)*"

            # Extract the provider information from input
            $providers = $channelSelection | Select-Object -Property ProviderSymbol, ProviderName -Unique | Foreach-Object { $_ | Select-Object *, @{n = "ProviderGuid"; e = { ([guid]::NewGuid()).Guid } } }

            #region Create the manifest XML document
            Write-PSFMessage -Level Verbose -Message "Working on group '$($baseName)' with $(([array]$channelSelection).Count) channel definitions in $(([array]$providers).count) folders"

            #region Basic XML object definition
            Write-PSFMessage -Level Debug -Message "Start building manifest XML document"
            # Create the manifest XML document
            $XmlWriter = [System.XMl.XmlTextWriter]::new($fullNameManifestTemp, $null)

            # Set the formatting
            $xmlWriter.Formatting = "Indented"
            $xmlWriter.Indentation = "4"

            # Write the XML decleration
            $xmlWriter.WriteStartDocument()

            # Create instrumentation manifest
            $xmlWriter.WriteStartElement("instrumentationManifest")
            $xmlWriter.WriteAttributeString("xsi:schemaLocation", "http://schemas.microsoft.com/win/2004/08/events eventman.xsd")
            $xmlWriter.WriteAttributeString("xmlns", "http://schemas.microsoft.com/win/2004/08/events")
            $xmlWriter.WriteAttributeString("xmlns:win", "http://manifests.microsoft.com/win/2004/08/windows/events")
            $xmlWriter.WriteAttributeString("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance")
            $xmlWriter.WriteAttributeString("xmlns:xs", "http://www.w3.org/2001/XMLSchema")
            $xmlWriter.WriteAttributeString("xmlns:trace", "http://schemas.microsoft.com/win/2004/08/events/trace")

            # Create instrumentation, events and provider elements
            $xmlWriter.WriteStartElement("instrumentation")
            $xmlWriter.WriteStartElement("events")
            #endregion Basic XML object definition

            foreach ($provider in $providers) {
                Write-PSFMessage -Level Verbose -Message "Writing provider '$($provider.ProviderName)' (GUID:$($provider.ProviderGUID))"
                # Start the provider
                $xmlWriter.WriteStartElement("provider")

                $xmlWriter.WriteAttributeString("name", $provider.ProviderName)
                $xmlWriter.WriteAttributeString("guid", "{$($provider.ProviderGUID)}")
                $xmlWriter.WriteAttributeString("symbol", $provider.ProviderSymbol)
                $xmlWriter.WriteAttributeString("resourceFileName", $fullNameDLLDestination)
                $xmlWriter.WriteAttributeString("messageFileName", $fullNameDLLDestination)
                $xmlWriter.WriteAttributeString("parameterFileName", $fullNameDLLDestination)

                # Start channels collection
                $xmlWriter.WriteStartElement("channels")

                [array]$channels = $channelSelection | Where-Object ProviderSymbol -eq $provider.ProviderSymbol | Select-Object -Property ChannelName, ChannelSymbol
                ForEach ($channelItem in $channels) {
                    Write-PSFMessage -Level Verbose -Message "Writing channel '$($channelItem.ChannelName)'"
                    # Start the channel
                    $xmlWriter.WriteStartElement("channel")

                    $xmlWriter.WriteAttributeString("name", $channelItem.ChannelName)
                    $xmlWriter.WriteAttributeString("chid", ($channelItem.ChannelName).Replace(' ', ''))
                    $xmlWriter.WriteAttributeString("symbol", $channelItem.ChannelSymbol)
                    $xmlWriter.WriteAttributeString("type", "Admin")
                    $xmlWriter.WriteAttributeString("enabled", "false")

                    # Closing the channel
                    $xmlWriter.WriteEndElement()
                }

                # Closing the channels
                $xmlWriter.WriteEndElement()

                # Closing the provider
                $xmlWriter.WriteEndElement()
            }

            #region Basic XML object definition
            $xmlWriter.WriteEndElement() # Closing events
            $xmlWriter.WriteEndElement() # Closing Instrumentation
            $xmlWriter.WriteEndElement() # Closing instrumentationManifest

            # End the XML Document
            $xmlWriter.WriteEndDocument()

            # Finish The Document
            $xmlWriter.Finalize
            $xmlWriter.Flush()
            $xmlWriter.Close()
            #endregion Basic XML object definition

            Write-PSFMessage -Level Verbose -Message "Manifest file '$($fileNameManifest)' has been generated ($( [math]::Round( ((Get-ChildItem -Path $fullNameManifestTemp).length / 1KB),1))KB)"
            #endregion Create The Manifest XML Document


            #region Compile the manifest to DLL
            Write-PSFMessage -Level Verbose -Message "Starting the compilation process on '$($fileNameDLL)'"
            $tempFilesExisting = @()
            $finalFilesExisting = @()
            $finalFilesExpected = @($fullNameManifestTemp, $fullNameDLLTemp)

            #region generates "**.h", "**.rc" and "**TEMP.BIN" file from xml manifest
            Write-PSFMessage -Level Debug -Message "Generate '$($fileName).h', '$($fileName).rc' and '$($fileName)TEMP.BIN' files from xml manifest"
            $tempFilesExpected = @("$($TempPath)\$($fileName).h", "$($TempPath)\$($fileName).rc", "$($TempPath)\$($fileName)TEMP.BIN")
            $tempFilesExpected | Get-ChildItem -ErrorAction SilentlyContinue | Remove-Item -Force -Confirm:$false
            Start-Process `
                -FilePath "$($CompilationToolPath)\mc.exe" `
                -ArgumentList $fullNameManifestTemp `
                -WorkingDirectory $TempPath `
                -NoNewWindow `
                -Wait

            Write-PSFMessage -Level Debug -Message "Validating generated files"
            foreach ($tempFile in $tempFilesExpected) {
                if (Test-Path -Path $tempFile -NewerThan (Get-Date).AddSeconds(-5)) {
                    $tempFilesExisting += Get-ChildItem $tempFile -ErrorAction Stop
                } else {
                    Stop-PSFFunction -Message "Expected temp file '$($tempFile)' is present, but has a too old timestamp. Something went wrong. Aborting process" -EnableException $true
                }
            }
            Write-PSFMessage -Level Debug -Message "File generated: $([string]::Join(", ", $tempFilesExpected))"
            #endregion generates "**.h", "**.rc" and "**TEMP.BIN" file from xml manifest

            #region generates "**.cs" file from xml manifest
            Write-PSFMessage -Level Debug -Message "Generate '$($fileName).cs' file from xml manifest"
            $tempFilesExpected = @( "$($TempPath)\$($fileName).cs" )
            $tempFilesExpected | Get-ChildItem -ErrorAction SilentlyContinue | Remove-Item -Force -Confirm:$false
            Start-Process `
                -FilePath "$($CompilationToolPath)\mc.exe" `
                -ArgumentList "-css NameSpace $($fullNameManifestTemp)" `
                -WorkingDirectory $TempPath `
                -NoNewWindow `
                -Wait

            Write-PSFMessage -Level Debug -Message "Validating generated '$($fileName).cs' file"
            foreach ($tempFile in $tempFilesExpected) {
                if (Test-Path -Path $tempFile -NewerThan (Get-Date).AddSeconds(-5)) {
                    $tempFilesExisting += Get-ChildItem $tempFile -ErrorAction Stop
                } else {
                    Stop-PSFFunction -Message "Expected temp file '$($tempFile)' is present, but has a too old timestamp. Something went wrong. Aborting process" -EnableException $true
                }
            }
            Write-PSFMessage -Level Debug -Message "CS file generated: $([string]::Join(", ", $tempFilesExpected)) "
            #endregion generates "**.cs" file from xml manifest

            #region generates "**.res" file from xml manifest
            Write-PSFMessage -Level Debug -Message "Generate '$fileName).res' file from '$($fileName).rc' file"
            $tempFilesExpected = @("$($TempPath)\$($fileName).res")
            $tempFilesExpected | Get-ChildItem -ErrorAction SilentlyContinue | Remove-Item -Force -Confirm:$false
            Start-Process `
                -FilePath "$($CompilationToolPath)\rc.exe" `
                -ArgumentList "$($fileName).rc" `
                -WorkingDirectory $TempPath `
                -Wait `
                -WindowStyle Hidden

            Write-PSFMessage -Level Debug -Message "Validating generated '$($fileName).res' file"
            foreach ($tempFile in $tempFilesExpected) {
                if (Test-Path -Path $tempFile -NewerThan (Get-Date).AddSeconds(-5)) {
                    $tempFilesExisting += Get-ChildItem $tempFile -ErrorAction Stop
                } else {
                    Stop-PSFFunction -Message "Expected temp file '$($tempFile)' is present, but has a too old timestamp. Something went wrong. Aborting process" -EnableException $true
                }
            }
            Write-PSFMessage -Level Debug -Message "Res file generated: $([string]::Join(", ", $tempFilesExpected)) "
            #endregion generates "**.res" file from xml manifest

            #region final compilation of the dll file
            Write-PSFMessage -Level Debug -Message "Finally compiling '$fileName).dll' file from generated meta files"
            Start-Process `
                -FilePath "$($WindowsCSCPath)\csc.exe" `
                -ArgumentList "/win32res:$($TempPath)\$($fileName).res /unsafe /target:library /out:$($TempPath)\$($fileName).dll $($TempPath)\$($fileName).cs" `
                -WorkingDirectory $TempPath `
                -Wait `
                -WindowStyle Hidden

            Write-PSFMessage -Level Debug -Message "Validating generated '$($fileName).dll' file"
            foreach ($FinalFile in $finalFilesExpected) {
                if (Test-Path -Path $FinalFile -NewerThan (Get-Date).AddSeconds(-15)) {
                    $finalFilesExisting += Get-ChildItem $FinalFile -ErrorAction Stop
                } else {
                    Stop-PSFFunction -Message "Expected temp file '$($FinalFile)' is present, but has a too old timestamp. Something went wrong. Aborting process" -EnableException $true
                }
            }
            Write-PSFMessage -Level Debug -Message "DLL file generated: $($TempPath)\$($fileName).dll"

            if ($pscmdlet.ShouldProcess("'$($fileNameManifest)' and '$($fileNameDLL)' in '$($DestinationPath)'", "Create")) {
                Write-PSFMessage -Level Verbose -Message "Writing final $($finalFilesExisting.Count) files to '$($DestinationPath)'"
                $finalFilesExisting | Copy-Item -Destination $DestinationPath -Force -ErrorAction Stop
            }
            #endregion final compilation of the dll file

            Write-PSFMessage -Level Verbose -Message "Finished process group '$($baseName)'"
            #endregion Compile the manifest to DLL
        }


        #region Cleanup
        Write-PSFMessage -Level Verbose -Message "Cleaning up temporary path '$($TempPath)'"
        Remove-Item -Path $TempPath -Force -Recurse -ErrorAction SilentlyContinue
        #endregion Cleanup
    }
}