function Test-WELCEventChannelManifest {
    <#
    .SYNOPSIS
        Test-WELCEventChannelManifest

    .DESCRIPTION
        Test a man file for valid path with the compiled DLL file belonging to manifest file

        The manifest has to contain the fullname of the path where the dll file is stored,
        otherwise there will be errors when registering/usering it

    .PARAMETER Path
        The path to the manifest file

    .PARAMETER OnlyDLLPath
        Only verify path of DLL files in Manifest and skip validation of properties

    .PARAMETER Property
        Explicitly validate only the specified property

    .PARAMETER PassThru
        The moved files will be parsed to the pipeline for further processing.

    .NOTES
        Author: Andreas Bellstedt

    .LINK
        https://github.com/AndiBellstedt/WinEventLogCustomization

    .EXAMPLE
        PS C:\> Test-WELCEventChannelManifest -Path C:\CustomDLLPath\MyChannel.man

        Test the manifest. Show $true, if the manifest is a valid EventLogChannelManifest and the compiled  DLL file ist in the expected directory
        Otherwise $false will be the result of the test.

    .EXAMPLE
        PS C:\> Test-WELCEventChannelManifest -Path C:\CustomDLLPath\MyChannel.man -OnlyDLLPath

        Same like first example, but skip structure and name checks. In fact, it only checks on reference path for DLL file.

    .EXAMPLE
        PS C:\> Test-WELCEventChannelManifest -Path C:\CustomDLLPath\MyChannel.man -PassThru

        Test the manifest. If the manifest is a valid EventLogChannelManifest and the compiled  DLL file ist in the expected directory,
        the path (fullname) of the Manifest file will be the output

    #>
    [CmdletBinding(
        SupportsShouldProcess = $false,
        PositionalBinding = $true,
        ConfirmImpact = 'Low',
        DefaultParameterSetName = "General"
    )]
    [OutputType("System.Boolean")]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [Alias("File", "FileName", "FullName")]
        [String[]]
        $Path,

        [Parameter(ParameterSetName = "General")]
        [switch]
        $OnlyDLLPath,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "ExplicitProperty"
        )]
        [ValidateSet("ProviderName", "ProviderGUID", "ProviderSymbol", "ResourceFileName", "MessageFileName", "ParameterFileName", "ChannelName", "ChannelSymbol", "Type", "Enabled")]
        [String[]]
        $Property,

        [switch]
        $PassThru
    )

    begin {

    }

    process {
        foreach ($pathItem in $Path) {
            $isOK = $true
            # File and folder validity tests
            if ((Test-Path -Path $pathItem -PathType Leaf) -and ($pathItem.Split(".")[-1] -like "man")) {
                $file = $pathItem | Resolve-Path | Get-ChildItem | Select-Object -ExpandProperty FullName
                Write-PSFMessage -Level Verbose -Message "Found file '$($file )' as a valid file"
            } elseif (Test-Path -Path $pathItem -PathType Container) {
                Write-PSFMessage -Level Error -Message "'$pathItem' is a folder. Please specify a manifest file."
                continue
            } elseif (-not (Test-Path  -Path $pathItem -PathType Any -IsValid)) {
                Write-PSFMessage -Level Error -Message "'$pathItem' is not a valid path or file."
                continue
            } else {
                Write-PSFMessage -Level Error -Message "Unable to open '$($pathItem)'"
                continue
            }

            # open XML file
            $xmlfile = New-Object XML
            $xmlfile.Load($file)

            if (
                $xmlfile.instrumentationManifest.schemaLocation -eq "http://schemas.microsoft.com/win/2004/08/events eventman.xsd" -and
                $xmlfile.instrumentationManifest.xmlns -eq "http://schemas.microsoft.com/win/2004/08/events" -and
                $xmlfile.instrumentationManifest.win -eq "http://manifests.microsoft.com/win/2004/08/windows/events" -and
                $xmlfile.instrumentationManifest.xsi -eq "http://www.w3.org/2001/XMLSchema-instance" -and
                $xmlfile.instrumentationManifest.xs -eq "http://www.w3.org/2001/XMLSchema" -and
                $xmlfile.instrumentationManifest.trace -eq "http://schemas.microsoft.com/win/2004/08/events/trace"
            ) {
                # Loop through existing providers
                foreach ($provider in $xmlfile.instrumentationManifest.instrumentation.events.provider) {
                    # Check Provider info
                    if (-not $OnlyDLLPath -or $pscmdlet.ParameterSetName -like "ExplicitProperty") {
                        if ($pscmdlet.ParameterSetName -like "General" -or "ProviderGUID" -in $Property) {
                            if ([guid]::new($provider.guid)) {
                                Write-PSFMessage -Level Debug -Message "GUID '$($provider.guid)' for provider '$($provider.name)' is valid"
                            } else {
                                Write-PSFMessage -Level Verbose -Message "Failed testing GUID '$($provider.guid)' for provider '$($provider.name)'"
                                $isOK = $false
                            }
                        }

                        if ($pscmdlet.ParameterSetName -like "General" -or "ProviderName" -in $Property) {
                            if ($provider.name -match (Get-PSFConfigValue -FullName WinEventLogCustomization.MatchString.ProviderName)) {
                                Write-PSFMessage -Level Debug -Message "Name for provider '$($provider.name)' is valid"
                            } else {
                                Write-PSFMessage -Level Verbose -Message "Failed testing provider name '$($provider.name)'. Name did not match '$(Get-PSFConfigValue -FullName WinEventLogCustomization.MatchString.ProviderName)'"
                                $isOK = $false
                            }
                        }

                        if ($pscmdlet.ParameterSetName -like "General" -or "ProviderSymbol" -in $Property) {
                            if ($provider.symbol -match (Get-PSFConfigValue -FullName WinEventLogCustomization.MatchString.ProviderSymbol)) {
                                Write-PSFMessage -Level Debug -Message "Providersymbol '$($provider.symbol)' is valid"
                            } else {
                                Write-PSFMessage -Level Verbose -Message "Failed testing provider symbol '$($provider.symbol)'. Name did not match '$(Get-PSFConfigValue -FullName WinEventLogCustomization.MatchString.ProviderSymbol)'"
                                $isOK = $false
                            }
                        }
                    }

                    if ($pscmdlet.ParameterSetName -like "General" -or "ResourceFileName" -in $Property) {
                        if (Test-Path -Path $provider.resourceFileName -PathType Leaf) {
                            Write-PSFMessage -Level Debug -Message "Ressource file '$($provider.resourceFileName)' for provider '$($provider.name)' GUID:$($provider.guid) is valid"
                        } else {
                            Write-PSFMessage -Level Verbose -Message "Failed testing ressource file '$($provider.resourceFileName)' for provider '$($provider.name)' GUID:$($provider.guid)"
                            $isOK = $false
                        }
                    }

                    if ($pscmdlet.ParameterSetName -like "General" -or "MessageFileName" -in $Property) {
                        if (Test-Path -Path $provider.messageFileName -PathType Leaf) {
                            Write-PSFMessage -Level Debug -Message "Message file '$($provider.messageFileName)' for provider '$($provider.name)' GUID:$($provider.guid) is valid"
                        } else {
                            Write-PSFMessage -Level Verbose -Message "Failed testing message file '$($provider.messageFileName)' for provider '$($provider.name)' GUID:$($provider.guid)"
                            $isOK = $false
                        }
                    }

                    if ($pscmdlet.ParameterSetName -like "General" -or "ParameterFileName" -in $Property) {
                        if (Test-Path -Path $provider.parameterFileName -PathType Leaf) {
                            Write-PSFMessage -Level Debug -Message "Parameter file '$($provider.parameterFileName)' for provider '$($provider.name)' GUID:$($provider.guid) is valid"
                        } else {
                            Write-PSFMessage -Level Verbose -Message "Failed testing parameter file '$($provider.parameterFileName)' for provider '$($provider.name)' GUID:$($provider.guid)"
                            $isOK = $false
                        }
                    }

                    if (-not $OnlyDLLPath -or $pscmdlet.ParameterSetName -like "ExplicitProperty") {
                        # Loop through channels within provider
                        foreach ($channel in $provider.channels.channel) {
                            # Check Channel info
                            if ($pscmdlet.ParameterSetName -like "General" -or "ChannelName" -in $Property) {
                                if ($channel.name -match (Get-PSFConfigValue -FullName WinEventLogCustomization.MatchString.ChannelName)) {
                                    Write-PSFMessage -Level Debug -Message "Name for ChannelName '$($channel.name)' in provider '$($provider.name)' is valid"
                                } else {
                                    Write-PSFMessage -Level Verbose -Message "Failed testing ChannelName '$($channel.name)' in provider '$($provider.name)'. Name did not match '$(Get-PSFConfigValue -FullName WinEventLogCustomization.MatchString.ChannelName)'"
                                    $isOK = $false
                                }
                            }

                            if ($pscmdlet.ParameterSetName -like "General" -or "ChannelSymbol" -in $Property) {
                                if ($channel.symbol -match (Get-PSFConfigValue -FullName WinEventLogCustomization.MatchString.ChannelSymbol)) {
                                    Write-PSFMessage -Level Debug -Message "Name for ChannelSymbol '$($channel.symbol)' in provider '$($provider.name)' is valid"
                                } else {
                                    Write-PSFMessage -Level Verbose -Message "Failed testing ChannelSymbol '$($channel.symbol)' in provider '$($provider.name)'. Name did not match '$(Get-PSFConfigValue -FullName WinEventLogCustomization.MatchString.ChannelSymbol)'"
                                    $isOK = $false
                                }
                            }

                            if ($pscmdlet.ParameterSetName -like "General" -or "Enabled" -in $Property) {
                                if (($channel.enabled -like [bool]::TrueString) -or ($channel.enabled -like [bool]::FalseString)) {
                                    Write-PSFMessage -Level Debug -Message "Value Enabled:'$($channel.enabled)' on channel '$($channel.name)' in provider '$($provider.name)' is valid"
                                } else {
                                    Write-PSFMessage -Level Verbose -Message "Failed testing value '$($channel.enabled)' on channel '$($channel.name)' in provider '$($provider.name)'."
                                    $isOK = $false
                                }
                            }

                            if ($pscmdlet.ParameterSetName -like "General" -or "Type" -in $Property) {
                                if ($channel.type -in (Get-PSFConfigValue -FullName WinEventLogCustomization.MatchString.ChannelTypes)) {
                                    Write-PSFMessage -Level Debug -Message "Type '$($channel.type)' on channel '$($channel.name)' in provider '$($provider.name)' is valid"
                                } else {
                                    Write-PSFMessage -Level Verbose -Message "Failed testing type '$($channel.type)' on channel '$($channel.name)' in provider '$($provider.name)'."
                                    $isOK = $false
                                }
                            }
                        }
                    }
                }
            } else {
                Write-PSFMessage -Level Error -Message "'$($file)' seeams like not being a Windows EventLog Channel XML manifest file"
                $isOK = $false
            }

            # Output result
            if ($PassThru -and $isOK) {
                $file
            } else {
                $isOK
            }
        }
    }

    end {
    }
}