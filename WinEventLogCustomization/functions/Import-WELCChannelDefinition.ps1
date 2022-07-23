function Import-WELCChannelDefinition {
    <#
    .Synopsis
        Import-WELCChannelDefinition

    .DESCRIPTION
        Import definition data for creating custom Windows EventLog Channels from a Excel file
        The Excel file acts as a definition database and provide easy handling and definition for custom eventlog channels and there structure

        Additionally in the excel file, there is the possibility to manage XPath-Queries for Windows Event Forwading queries

    .PARAMETER Path
        The Excel file or a folder with Excel files to import

    .PARAMETER Sheet
        The Name of the sheet within the Excel file

    .PARAMETER Table
        The table containing the definition data within the sheet of the Excel file

    .PARAMETER FileExtension
        A list of file extensions indicating Excel files
        Only needed/used if a folder is specified as a Path

    .PARAMETER Recursive
        The specified path will be parsed recursivly
        Only needed/used if a folder is specified as a Path

    .PARAMETER OutputChannelDefinition
        If specified the function will output a WELC.ChannelDefinition object, instead of WELC.TemplateRecord data

    .PARAMETER OutputChannelConfig
        If specified the function will output a WELC.ChannelDefinition object, instead of WELC.TemplateRecord data


    .PARAMETER WhatIf
        If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

    .PARAMETER Confirm
        If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

    .EXAMPLE
        PS C:\> Import-WELCChannelDefinition -Path C:\WELC\MyFile.xls

        Import the excel file 'C:\WELC\MyFile.xls' with the default expected parametersettings
        (Excel file has to contain a Sheet 'CustomEventLogChannels' and a  table 'T_Channel')

    .EXAMPLE
        PS C:\> Import-WELCChannelDefinition -Path C:\WELC

        Import all excel files in path 'C:\WELC' with the default expected parametersettings
        (sheet and table settings like in first example. Files  have to have an extension with ".xlsx", ".xlsm", ".xls")

    .EXAMPLE
        PS C:\> Import-WELCChannelDefinition -Path C:\WELC -Recursive -FileExtension "xlsx", "xlsm", "xls"

        Import all excel files in path 'C:\WELC' and in all subfolders with the specified extensions "xlsx", "xlsm", "xls"
        (sheet and table settings like in first example)

    .EXAMPLE
        PS C:\> Import-WELCChannelDefinition -Path C:\WELC\MyFile.xls -Sheet "CustomEventLogChannels" -Table "T_Channel"

        Import the excel file 'C:\WELC\MyFile.xls' with the explicit parameter settings on sheet and table

    .NOTES
        Author: Andreas Bellstedt

    .LINK
        https://github.com/AndiBellstedt/WinEventLogCustomization
    #>
    [CmdLetBinding(
        DefaultParameterSetName = "OutputTemplateRecord",
        SupportsShouldProcess = $true,
        PositionalBinding = $true,
        ConfirmImpact = 'Low'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Intentional')]
    [OutputType("WELC.ChannelDefinition", "WELC.ChannelConfig", "WELC.TemplateRecord", "PSObject")]
    param(
        [parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [Alias("FullName", "FilePath", "Folder", "File")]
        [string[]]
        $Path,

        [ValidateNotNullOrEmpty()]
        [Alias("ExcelSheet", "SheetName")]
        [string]
        $Sheet = "CustomEventLogChannels",

        [ValidateNotNullOrEmpty()]
        [Alias("ExcelTable", "TableName")]
        [string]
        $Table = "T_Channel",

        [string[]]
        $FileExtension = @("xlsx", "xlsm", "xls"),

        [switch]
        $Recursive,

        [Parameter(ParameterSetName = "OutputChannelDefinition" )]
        [switch]
        $OutputChannelDefinition,

        [Parameter(ParameterSetName = "OutputChannelConfig" )]
        [switch]
        $OutputChannelConfig
    )

    begin {
        # ensure correct format for specified extensions
        if ($FileExtension) {
            $FileExtension = foreach ($item in $FileExtension) {
                $item = $item.Trim(".")
                ".$($item)"
            }
        }
    }

    process {
        Write-PSFMessage -Level Debug -Message "ParameterNameSet: $($PsCmdlet.ParameterSetName)"

        # working trough the specified path(s)
        foreach ($pathItem in $Path) {

            # File and folder validity tests
            if (Test-Path -Path $pathItem -PathType Leaf) {
                Write-PSFMessage -Level Verbose -Message "Found file '$($pathItem)' as a valid file in path"
                $files = $pathItem | Resolve-Path | Get-ChildItem | Select-Object -ExpandProperty FullName
            } elseif (Test-Path -Path $pathItem -PathType Container) {
                Write-PSFMessage -Level Verbose -Message "Getting files in path '$($pathItem)'"
                $param = @{
                    Path   = $pathItem
                    "File" = $true
                }
                if ($Recursive) { $param["Recursive"] = $true }
                $files = Get-ChildItem @param | Where-Object Extension -in $FileExtension | Select-Object -ExpandProperty FullName
                Write-PSFMessage -Level Verbose -Message "Found $($files.count) file$(if($files.count -gt 1){"s"}) in path "
            } elseif (-not (Test-Path  -Path $pathItem -PathType Any -IsValid)) {
                Write-PSFMessage -Level Error -Message "'$pathItem' is not a valid path or file."
                continue
            } else {
                Write-PSFMessage -Level Error -Message "Unable to open '$($pathItem)'"
                continue
            }

            # Working trough the actual found file(s)
            foreach ($file in $files) {
                Write-PSFMessage -Level Verbose -Message "Open file '$($file)' as Excel file"

                # Open the file
                #$excelDocument = Get-ExcelDocument -Path $file
                $excelDocument = New-Object -TypeName OfficeOpenXml.ExcelPackage -ArgumentList $file
                if (-not $excelDocument) { continue }

                # Select the specified sheet
                $excelSheet = $excelDocument.Workbook.Worksheets | Where-Object name -like $Sheet
                if (-not $excelSheet) {
                    Write-PSFMessage -Level Error -Message "Excel file '$($file.split("\")[-1])' contains no sheet '$($Sheet)'"
                    continue
                }

                # Select the specified table
                $excelTable = $excelSheet.Tables | Where-Object name -like $Table
                if (-not $table) {
                    Write-PSFMessage -Level Error -Message "Unable to find table '$($Table)' in sheet '$($file.split("\")[-1])' "
                    continue
                }

                # Prepare importing the table as powershell object
                $param = @{
                    ExcelPackage  = $excelDocument
                    WorksheetName = $excelSheet.name
                    StartRow      = $excelTable.Address.Start.Row
                    StartColumn   = $excelTable.Address.Start.Column
                    EndRow        = $excelTable.Address.End.Row
                    EndColumn     = $excelTable.Address.End.Column
                }

                if ($pscmdlet.ShouldProcess("table '$($Table)' in sheet '$($Sheet)' from file '$($file)'", "Import")) {
                    Write-PSFMessage -Level Debug -Message "Import Excel file"
                    # Import and filter data from excel table into powershell
                    $tableData = Import-Excel @param
                    $data = $tableData | Where-Object LogFullName
                    Write-PSFMessage -Level Verbose -Message "Found $(([array]$data).Count) usable records in $($tableData.Count) records from table '$($Table)' in worksheet '$($Sheet)'"

                    # Output result
                    foreach ($item in $data) {
                        switch ($pscmdlet.ParameterSetName) {
                            "OutputChannelDefinition" {
                                if ($OutputChannelDefinition) {
                                    $output = [WELC.ChannelDefinition]@{
                                        ChannelName    = $item.ChannelName
                                        ChannelSymbol  = $item.ChannelSymbol
                                        ProviderName   = $item.ProviderName
                                        ProviderSymbol = $item.ProviderSymbol
                                    }
                                    $output
                                }
                            }
                            "OutputChannelConfig" {
                                if ($OutputChannelConfig) {
                                    $output = [WELC.ChannelConfig]@{
                                        ChannelName     = $item.ChannelName
                                        LogFullName     = $item.LogFullName
                                        LogMode         = $item.LogMode
                                        Enabled         = [bool]::Parse($item.Enabled)
                                        MaxEventLogSize = $item.MaxEventLogSize / 1
                                    }
                                    $output
                                }
                            }
                            "OutputTemplateRecord" {
                                $item.psobject.TypeNames.Insert(0, "WELC.TemplateRecord")
                                $item
                            }

                            Default {
                                Stop-PSFFunction -Message "Unhandeled ParameterSetName. Developers mistake." -EnableException $true
                                throw
                            }
                        }
                    }
                }

                # Data/variable cleanup
                Write-PSFMessage -Level Debug -Message "Close Excel file and cleanup variables"
                $excelSheet.Dispose()
                $excelDocument.Dispose()
                Remove-Variable excelDocument, excelSheet, excelTable, tableData, data, param, item -Force -Confirm:$false -ErrorAction:Ignore
            }
            Remove-Variable file, files -Force -Confirm:$false -ErrorAction Ignore
        }
        Remove-Variable pathItem -Force -Confirm:$false -ErrorAction Ignore
    }

    end {
    }
}