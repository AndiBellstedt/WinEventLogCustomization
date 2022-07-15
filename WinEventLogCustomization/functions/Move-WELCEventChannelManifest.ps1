function Move-WELCEventChannelManifest {
    <#
    .SYNOPSIS
        Move-WELCEventChannelManifest

    .DESCRIPTION
        Move a manifest with the compiled DLL file from a source to destination directory

        The manifest has to be rewritten to fit the destination path otherwise,
        there will be errors when registering/usering it

    .PARAMETER Path
        The path to the manifest file

        You can specify the fullname of the manifest-file (.man), or just the directory

        In case of a directory, all the manifest files in the directory will be processed

    .PARAMETER DestinationPath
        The path where to store the manifest and DLL file

    .PARAMETER Prepare
        The rewrite of the manifest will be done, but the files will not be moved

    .PARAMETER CopyMode
        Copy the files from the source to the destination, instead of moving them

    .PARAMETER PassThru
        The moved files will be parsed to the pipeline for further processing.

    .NOTES
        Author: Andreas Bellstedt

    .LINK
        https://github.com/AndiBellstedt/WinEventLogCustomization

    .EXAMPLE
        PS C:\> Move-WELCEventChannelManifest -Path C:\CustomDLLPath\MyChannel.man -DestinationPath $env:WinDir\System32

        The manifest and its DLL file will be copied to the system32 directory of the current windows installation

    .EXAMPLE
        PS C:\> Move-WELCEventChannelManifest -Path C:\CustomDLLPath -DestinationPath $env:WinDir\System32

        All manifest files will copied over to the system32 directory.

    .EXAMPLE
        PS C:\> Move-WELCEventChannelManifest -Path C:\CustomDLLPath\MyChannel.dll -DestinationPath $env:WinDir\System32 -Prepare

        The manifest will rewritten to the destination folder, but the actual file will not be moved
    #>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        PositionalBinding = $true,
        ConfirmImpact = 'Medium'
    )]
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

        [Parameter(
            Mandatory = $true,
            Position = 1
        )]
        [String]
        $DestinationPath,

        [switch]
        $Prepare,

        [switch]
        $CopyMode,

        [switch]
        $PassThru
    )

    begin {
        $DestinationPath = $DestinationPath.TrimEnd("\")
        $DestinationPath = $DestinationPath | Resolve-Path | Get-Item | Select-Object -ExpandProperty FullName
    }

    process {
        $files = @()
        foreach ($pathItem in $Path) {
            # File and folder validity tests
            if (Test-Path -Path $pathItem -PathType Leaf) {
                Write-PSFMessage -Level Verbose -Message "Found file '$($pathItem)' as a valid file in path" -Target $env:COMPUTERNAME
                $files = $pathItem | Resolve-Path | Get-ChildItem | Select-Object -ExpandProperty FullName
            } elseif (Test-Path -Path $pathItem -PathType Container) {
                Write-PSFMessage -Level Verbose -Message "Getting files in path '$($pathItem)'" -Target $env:COMPUTERNAME
                $files = Get-ChildItem -Path $pathItem -File -Filter "*.man" | Select-Object -ExpandProperty FullName
                Write-PSFMessage -Level Verbose -Message "Found $($files.count) file$(if($files.count -gt 1){"s"}) in path" -Target $env:COMPUTERNAME
                if (-not $files) { Write-PSFMessage -Level Warning -Message "No manifest files found in path '$($pathItem)'" -Target $env:COMPUTERNAME }
            } elseif (-not (Test-Path  -Path $pathItem -PathType Any -IsValid)) {
                Write-PSFMessage -Level Error -Message "'$pathItem' is not a valid path or file." -Target $env:COMPUTERNAME
                continue
            } else {
                Write-PSFMessage -Level Error -Message "unable to open '$($pathItem)'" -Target $env:COMPUTERNAME
                continue
            }

            foreach ($file in $files) {

                # open XML file
                Write-PSFMessage -Level Verbose -Message "Opening XML manifest file '$($file)' to gather DLL information"
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
                    # Gather files and rewrite XML
                    $manifestFolder = Split-Path -Parent $file

                    Write-PSFMessage -Level Debug -Message "Gather path of resourceFileName DLL"
                    $resourceFileNameFullName = $xmlfile.instrumentationManifest.instrumentation.events.provider.resourceFileName
                    $resourceFileNamePath = Split-Path -Path $resourceFileNameFullName
                    $resourceFileNameFile = Split-Path -Path $resourceFileNameFullName -Leaf
                    if ($DestinationPath -like $resourceFileNamePath) {
                        Write-PSFMessage -Level Significant -Message "Source and destination path of ressource file '$resourceFileNameFullName' are the same. Nothing to do"
                    } else {
                        $destResourceFileName = "$($DestinationPath)\$($resourceFileNameFile)"
                        $xmlfile.instrumentationManifest.instrumentation.events.provider.resourceFileName = $destResourceFileName
                        Write-PSFMessage -Level Verbose -Message "Rewrite path of messageFileName DLL from '$($resourceFileNameFullName)' to '$($destResourceFileName)'"

                        if (Test-Path -Path $destResourceFileName -PathType Leaf) {
                            # DLL is already present in destination directory
                            $resourceFileNameFullName = $destResourceFileName
                        } elseif (Test-Path -Path "$($manifestFolder)\$($resourceFileNameFile)" -PathType Leaf) {
                            # DLL path in XML is wrong, but DLL is next to manifest file
                            $resourceFileNameFullName = "$($manifestFolder)\$($resourceFileNameFile)"
                        } elseif (Test-Path -Path $resourceFileNameFullName -PathType Leaf) {
                            # nothing to do, DLL is in path from xml file, but has to be mnoved somewhere different
                        } else {
                            Stop-PSFFunction -Message "Ressource file '$($resourceFileNameFile)' not found. Searched in folders: '$($resourceFileNamePath)', '$($manifestFolder)', '$($DestinationPath)'" -EnableException $true
                        }
                    }

                    Write-PSFMessage -Level Debug -Message "Gather path of messageFileName DLL"
                    $messageFileNameFullName = $xmlfile.instrumentationManifest.instrumentation.events.provider.messageFileName
                    $messageFileNamePath = Split-Path -Path $messageFileNameFullName
                    $messageFileNameFile = Split-Path -Path $messageFileNameFullName -Leaf
                    if ($DestinationPath -like $messageFileNamePath) {
                        Write-PSFMessage -Level Verbose -Message "Source and destination path of message file '$($messageFileNameFullName)' are the same. Nothing to do"
                    } else {
                        $destMessageFileName = "$($DestinationPath)\$($messageFileNameFile)"
                        $xmlfile.instrumentationManifest.instrumentation.events.provider.messageFileName = $destMessageFileName
                        Write-PSFMessage -Level Verbose -Message "Rewrite path of messageFileName DLL from '$($messageFileNameFullName)' to '$($destMessageFileName)'"

                        if (Test-Path -Path $destMessageFileName -PathType Leaf) {
                            # DLL is already present in destination directory
                            $messageFileNameFullName = $destMessageFileName
                        } elseif (Test-Path -Path "$($manifestFolder)\$($messageFileNameFile)" -PathType Leaf) {
                            # DLL path in XML is wrong, but DLL is next to manifest file
                            $messageFileNameFullName = "$($manifestFolder)\$($messageFileNameFile)"
                        } elseif (Test-Path -Path $messageFileNameFullName -PathType Leaf) {
                            # nothing to do, DLL is in path from xml file, but has to be mnoved somewhere different
                        } else {
                            Stop-PSFFunction -Message "Message file '$($messageFileNameFile)' not found. Searched in folders: '$($messageFileNamePath)', '$($manifestFolder)', '$($DestinationPath)'" -EnableException $true
                        }
                    }

                    Write-PSFMessage -Level Debug -Message "Gather path of parameterFileName DLL"
                    $parameterFileNameFullName = $xmlfile.instrumentationManifest.instrumentation.events.provider.parameterFileName
                    $parameterFileNamePath = Split-Path -Path $parameterFileNameFullName
                    $parameterFileNameFile = Split-Path -Path $parameterFileNameFullName -Leaf
                    if ($DestinationPath -like $parameterFileNamePath) {
                        Write-PSFMessage -Level Verbose -Message "Source and destination path of parameter file '$($parameterFileNameFullName)' are the same. Nothing to do"
                    } else {
                        $destParameterFileName = "$($DestinationPath)\$($parameterFileNameFile)"
                        $xmlfile.instrumentationManifest.instrumentation.events.provider.parameterFileName = $destParameterFileName
                        Write-PSFMessage -Level Verbose -Message "Rewrite path of parameterFileName DLL from '$($parameterFileNameFullName)' to '$($destParameterFileName)'"

                        if (Test-Path -Path $destParameterFileName -PathType Leaf) {
                            # DLL is already present in destination directory
                            $parameterFileNameFullName = $destParameterFileName
                        } elseif (Test-Path -Path "$($manifestFolder)\$($parameterFileNameFile)" -PathType Leaf) {
                            # DLL path in XML is wrong, but DLL is next to manifest file
                            $parameterFileNameFullName = "$($manifestFolder)\$($parameterFileNameFile)"
                        } elseif (Test-Path -Path $parameterFileNameFullName -PathType Leaf) {
                            # nothing to do, DLL is in path from xml file, but has to be mnoved somewhere different
                        } else {
                            Stop-PSFFunction -Message "Parameter file '$($parameterFileNameFile)' not found. Searched in folders: '$($parameterFileNamePath)', '$($manifestFolder)', '$($DestinationPath)'" -EnableException $true
                        }
                    }
                } else {
                    Stop-PSFFunction -Message "$($file) is not a actual manifest file" -EnableException $true
                }

                if ($pscmdlet.ShouldProcess("file '$($file)' with directory '$($DestinationPath)'", "Set")) {
                    $xmlfile.Save($file)
                    Write-PSFMessage -Level Verbose -Message "Save file '$($file)' in directory '$($DestinationPath)'"
                }

                if (-not $Prepare -or $CopyMode) {
                    Write-PSFMessage -Level Verbose -Message "Copy/Move manifest and DLL files into directory '$($DestinationPath)'"

                    if ($pscmdlet.ShouldProcess("File manifest '$($file)' to '$($DestinationPath)'$(if($CopyMode){"in CopyMode"})", "Move")) {
                        if ($CopyMode) {
                            Write-PSFMessage -Level Debug -Message "Copy manifest file"
                            $destfile = Copy-Item -Path $file -Destination $DestinationPath -Force -PassThru
                        } else {
                            Write-PSFMessage -Level Debug -Message "Move manifest file"
                            $destfile = Move-Item -Path $file -Destination $DestinationPath -Force -PassThru
                        }
                    }

                    if ($pscmdlet.ShouldProcess("Dll file '$($resourceFileNameFullName)' to '$($DestinationPath)'$(if($CopyMode){"in CopyMode"})", "Move")) {
                        if ($CopyMode) {
                            Write-PSFMessage -Level Debug -Message "Copy resourceFileName dll file"
                            Copy-Item -Path $resourceFileNameFullName -Destination $DestinationPath -Force
                        } else {
                            Write-PSFMessage -Level Debug -Message "Move resourceFileName dll file"
                            Move-Item -Path $resourceFileNameFullName -Destination $DestinationPath -Force
                        }
                    }

                    if ($messageFileNameFullName -notlike $resourceFileNameFullName) {
                        if ($pscmdlet.ShouldProcess("File message dll file '$($messageFileNameFullName)' to '$($DestinationPath)'$(if($CopyMode){"in CopyMode"})", "Move")) {
                            if ($CopyMode) {
                                Write-PSFMessage -Level Debug -Message "Copy messageFileName dll file"
                                Copy-Item -Path $messageFileNameFullName -Destination $DestinationPath -Force
                            } else {
                                Write-PSFMessage -Level Debug -Message "Move messageFileName dll file"
                                Move-Item -Path $messageFileNameFullName -Destination $DestinationPath -Force

                            }
                        }
                    }

                    if ($parameterFileNameFullName -notlike $resourceFileNameFullName) {
                        if ($pscmdlet.ShouldProcess("File parameter dll file '$($parameterFileNameFullName)' to '$($DestinationPath)'$(if($CopyMode){"in CopyMode"})", "Move")) {
                            if ($CopyMode) {
                                Write-PSFMessage -Level Debug -Message "Copy parameterFileName dll file"
                                Copy-Item -Path $parameterFileNameFullName -Destination $DestinationPath -Force
                            } else {
                                Write-PSFMessage -Level Debug -Message "Move parameterFileName dll file"
                                Move-Item -Path $parameterFileNameFullName -Destination $DestinationPath -Force
                            }
                        }
                    }

                    if ($PassThru) {
                        Write-PSFMessage -Level Verbose -Message "PassThru mode, outputting manifest file"
                        $destfile
                    }
                } else {
                    if ($PassThru) {
                        Write-PSFMessage -Level Verbose -Message "PassThru mode, outputting manifest file"
                        $file | Get-Item
                    }
                }
            }
        }
    }

    end {
    }
}