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
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [Alias("File", "FileName", "FullName")]
        [String[]]
        $Path,

        [Parameter(Mandatory = $true)]
        [String]
        $DestinationPath,

        [switch]
        $Prepare,

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
                Write-Verbose "Found file '$($pathItem)' as a valid file in path"
                $files = $pathItem | Resolve-Path | Get-ChildItem | Select-Object -ExpandProperty FullName
            } elseif (Test-Path -Path $pathItem -PathType Container) {
                Write-Verbose "Getting files in path '$($pathItem)'"
                $files = Get-ChildItem -Path $pathItem -File -Include ".man" | Select-Object -ExpandProperty FullName
                Write-Verbose "Found $($files.count) file$(if($files.count -gt 1){"s"}) in path "
            } elseif (-not (Test-Path  -Path $pathItem -PathType Any -IsValid)) {
                Write-Error "'$pathItem' is not a valid path or file."
                continue
            } else {
                Write-Error "unable to open '$($pathItem)'"
                continue
            }

            $destfiles = @()
            foreach ($file in $files) {
                # open XML file
                $xmlfile = New-Object XML
                $xmlfile.Load($file)

                if ($xmlfile.instrumentationManifest.win -eq "http://manifests.microsoft.com/win/2004/08/windows/events") {
                    # Gather files and rewrite XML

                    $resourceFileName = $xmlfile.instrumentationManifest.instrumentation.events.provider.resourceFileName
                    if(Test-Path -Path $resourceFileName -PathType Leaf) {
                        if($DestinationPath -like (Split-Path -Path $resourceFileName)) {
                            Write-Warning "Source and destination path of ressource file '$resourceFileName' are the same. Nothing to do"
                        } else {
                            $destResourceFileName = "$($DestinationPath)\$(Split-Path -Path $resourceFileName -Leaf)"
                            $xmlfile.instrumentationManifest.instrumentation.events.provider.resourceFileName = $destResourceFileName
                        }
                    } else {
                        Write-Error "Ressource file '$resourceFileName' not found"
                        break
                    }

                    $messageFileName = $xmlfile.instrumentationManifest.instrumentation.events.provider.messageFileName
                    if(Test-Path -Path $messageFileName -PathType Leaf) {
                        if($DestinationPath -like (Split-Path -Path $messageFileName)) {
                            Write-Warning "Source and destination path of message file '$messageFileName' are the same. Nothing to do"
                        } else {
                            $destMessageFileName = "$($DestinationPath)\$(Split-Path -Path $messageFileName -Leaf)"
                            $xmlfile.instrumentationManifest.instrumentation.events.provider.messageFileName = $destMessageFileName
                        }
                    } else {
                        Write-Error "Message file '$messageFileName' not found"
                        break
                    }

                    $parameterFileName = $xmlfile.instrumentationManifest.instrumentation.events.provider.parameterFileName
                    if(Test-Path -Path $parameterFileName -PathType Leaf) {
                        if($DestinationPath -like (Split-Path -Path $parameterFileName)) {
                            Write-Warning "Source and destination path of parameter file '$parameterFileName' are the same. Nothing to do"
                        } else {
                            $destParameterFileName = "$($DestinationPath)\$(Split-Path -Path $parameterFileName -Leaf)"
                            $xmlfile.instrumentationManifest.instrumentation.events.provider.parameterFileName = $destParameterFileName
                        }
                    } else {
                        Write-Error "Parameter file '$parameterFileName' not found"
                        break
                    }
                } else {
                    Write-Error "$($file) is not a actual manifest file"
                    break
                }

                if ($pscmdlet.ShouldProcess("'$($DestinationPath)' in file '$($file)'", "Set")) {
                    $xmlfile.Save($file)
                }
                if(-not $Prepare) {
                    if ($pscmdlet.ShouldProcess("File manifest '$($file)' to '$($DestinationPath)'", "Move")) {
                        $destfiles += Move-Item -Path $file -Destination $DestinationPath -Force -PassThru
                    }
                    if ($pscmdlet.ShouldProcess("File dll file '$($resourceFileName)' to '$($DestinationPath)'", "Move")) {
                        $destfiles += Move-Item -Path $resourceFileName -Destination $DestinationPath -Force -PassThru
                    }
                    if($messageFileName -notlike $resourceFileName) {
                        if ($pscmdlet.ShouldProcess("File message dll file '$($messageFileName)' to '$($DestinationPath)'", "Move")) {
                            $destfiles += Move-Item -Path $messageFileName -Destination $DestinationPath -Force -PassThru
                        }
                    }
                    if($parameterFileName -notlike $resourceFileName) {
                        if ($pscmdlet.ShouldProcess("File parameter dll file '$($parameterFileName)' to '$($DestinationPath)'", "Move")) {
                            $destfiles += Move-Item -Path $parameterFileName -Destination $DestinationPath -Force -PassThru
                        }
                    }

                    if($PassThru) {
                        $destfiles | Get-Item
                    }
                }
            }
        }
    }

    end {

    }
}