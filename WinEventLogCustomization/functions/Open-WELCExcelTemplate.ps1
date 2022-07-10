function Open-WELCExcelTemplate {
    <#
        .Synopsis
            Open-WELCExcelTemplate

        .DESCRIPTION-
            Open Excel template file for managing custom EventLog channel definition

            For obvious reason, Excel or equivalent tools needs to be present on the machine

        .EXAMPLE
            PS C:\> Open-WELCExcelTemplate

            Open a new Excel file from a template file within the module WindowsEventLogCustomization

        .NOTES
            Author: Andreas Bellstedt

        .LINK
            https://github.com/AndiBellstedt/WinEventLogCustomization
    #>
    [CmdLetBinding(
        SupportsShouldProcess = $false,
        ConfirmImpact = 'Low'
    )]
    param(
    )

    begin {
    }

    process {
    }

    end {
        $path = "$($ModuleRoot)\bin\WinEventLogCustomization.xltx"
        $pathExtension = $path.Split(".")[-1]

        Write-PSFMessage -Level Debug -Message "Looking for application to open '$($pathExtension)' files"
        # parse registry for file extension
        $registryFileLinkInfo = Get-Item "HKCR:\.$($pathExtension)" -ErrorAction SilentlyContinue
        if ($registryFileLinkInfo) {
            # parse registry for linked appliaction info to open/ create new file from template
            $registryAppLinkInfo = Get-Item "HKCR:\$($registryFileLinkInfo.GetValue(''))\shell\new\command" -ErrorAction SilentlyContinue
            if (-not $registryAppLinkInfo) {
                Write-PSFMessage -Level Debug -Message "No 'create new' shell info found. Try to query 'shell open' info"
                $registryAppLinkInfo = Get-Item "HKCR:\$($registryFileLinkInfo.GetValue(''))\shell\Open\command" -ErrorAction SilentlyContinue
            }
        }

        if ($registryAppLinkInfo) {
            Write-PSFMessage -Level Debug -Message "Found application info '$($registryFileLinkInfo.GetValue(''))'. Parsing shell command '$($registryAppLinkInfo.GetValue(''))'"
            $invokeCmd = $registryAppLinkInfo.GetValue('') -replace "%1", $path
            $invokeCmd = ($invokeCmd -split '"') | Where-Object { $_ -and $_ -notlike " " } | ForEach-Object { $_.trim() }
        }

        if ($invokeCmd.Count -ge 2) {
            Write-PSFMessage -Level Debug -Message "Found application link '$($registryFileLinkInfo.GetValue(''))' in registry to open template file. Going to invoke '$($invokeCmd[0])' $($invokeCmd[-1])"

            if (Test-Path -Path $path) {
                Write-PSFMessage -Level Verbose -Message "Opening '$($path)'"
                Start-Process -FilePath $invokeCmd[0] -ArgumentList $invokeCmd[1 .. ($invokeCmd.count - 1)]
            } else {
                Write-PSFMessage -Level Error -Message "Missing template file in module. Unable to find '$($path)'"
            }
        } else {
            if ($registryFileLinkInfo) {
                Write-PSFMessage -Level Debug -Message "Unable parse shell command to open template file from registry, but file extension info is present in registry. Try to blindly invoke the template file item as a fallback"
                Invoke-Item -Path $path
            } else {
                Write-PSFMessage -Level Error -Message "Unable to open template file, due to no application for opening '$($pathExtension)-files' seems to be installed"
            }
        }
    }
}