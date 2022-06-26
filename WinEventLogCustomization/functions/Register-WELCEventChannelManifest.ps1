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

    #>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        PositionalBinding = $true,
        ConfirmImpact = 'Medium',
        DefaultParameterSetName = 'Local'
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

        [Parameter(
            ParameterSetName = "ComputerName"
        )]
        [PSCredential]
        $Credential,

        [String]
        $DestinationPath
    )

    begin {

    }

    process {
        # Checking
        if (-not $DestinationPath) { $DestinationPath = $Path }

        Write-Warning "Not supportet yet"
        break

        #  man + dll
        [XML]$xml
        $XMLfile = New-Object XML
        $XMLfile = $XMLFile.Load($path)
        $XMLFile.property.otherproperty = ”Gibberish”
        $XMLFile.Save($path)


        #remoting

        # registration
        Write-Verbose "Starting to register custom event log from file '$($Path)'"
        Start-Process `
            -FilePath "$($env:windir)\system32\wevtutil.exe" `
            -ArgumentList "install-manifest $($Path)" `
            -WorkingDirectory $TempPath `
            -Wait `
            -NoNewWindow
    }

    end {

    }
}