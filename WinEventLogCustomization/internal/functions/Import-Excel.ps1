function Import-Excel {
    <#
    .Synopsis
        Import-Excel

    .DESCRIPTION
        Imports data from Excel

    .PARAMETER ExcelPackage
        The Excel package imported from a file

    .PARAMETER WorksheetName
        Name of the sheet within the Excel package

    .PARAMETER StartRow
        Number of the row where import starts

    .PARAMETER EndRow
        Number of the row where import ends

    .PARAMETER StartColumn
        Number of the column where import starts

    .PARAMETER EndColumn
        Number of the column where import ends

    .EXAMPLE
        PS C:\> Import-Excel -ExcelPackage $excelPackage -WorksheetName "Sheet1" -StartRow 1 -EndRow 10 -StartColumn 1 -EndColumn 5

        Imports data from $excelPackage

    .NOTES
        Derived function from PSModule "ImportExcel" by Douglas Finke

        Due to the fact, that I don't need the whole function of the module and want to avoid module dependencies,
        I've adopted and cut the function down to my own need the WinEventLogCustomization module.

    .LINK
        https://github.com/dfinke/ImportExcel

    #>
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [OfficeOpenXml.ExcelPackage]
        $ExcelPackage,

        [ValidateNotNullOrEmpty()]
        [String]
        $WorksheetName,

        [Int]
        $StartRow = 1,

        [Int]
        $EndRow,

        [Int]
        $StartColumn = 1,

        [Int]
        $EndColumn
    )

    begin {
        # Helper function
        function Get-PropertyNames {
            <#
            .SYNOPSIS
                Create objects containing the column number and the column name for each of the different header types.
            #>
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = "Name would be incorrect, and command is not exported")]
            param(
                [Parameter(Mandatory = $true)]
                $Sheet,

                [Parameter(Mandatory = $true)]
                [Int[]]
                $Columns,

                [Parameter(Mandatory = $true)]
                [Int]
                $StartRow
            )

            if ($StartRow -lt 1) {
                Stop-PSFFunction -Message 'The top row can never be less than 1 when we need to retrieve headers from the worksheet.' -EnableException $true
                return
            }

            try {
                foreach ($column in $Columns) {
                    $Sheet.Cells[$StartRow, $column] | Where-Object { -not [string]::IsNullOrEmpty($_.Value) } | Select-Object @{N = 'Column'; E = { $column } }, Value
                }
            } catch {
                Stop-PSFFunction -Message "Failed creating property names: $_" -EnableException $true
                return
            }
        }
    }

    process {
        try {
            $sheet = $ExcelPackage.Workbook.Worksheets[$WorksheetName]
            if (-not $sheet) {
                Stop-PSFFunction -Message "Worksheet '$WorksheetName' not found" -EnableException
                return
            }


            #region Get rows and columns
            if (-not $EndRow ) { $EndRow = $sheet.Dimension.End.Row }
            if (-not $EndColumn) { $EndColumn = $sheet.Dimension.End.Column }

            $Columns = $StartColumn .. $EndColumn

            if ($StartColumn -gt $EndColumn) {
                Write-PSFMessage -Level Warning -Message "Selecting columns $StartColumn to $EndColumn might give odd results."
            }

            $rows = (1 + $StartRow) .. $EndRow
            if ($StartRow -eq 1 -and $EndRow -eq 1) {
                $rows = 0
            }
            #endregion Get rows and columns


            #region Create property names
            if ((-not $Columns) -or (-not ($PropertyNames = Get-PropertyNames -Sheet $sheet -Columns $Columns -StartRow $StartRow))) {
                Write-PSFMessage -Level Error -Message "No column headers found on top row '$StartRow'."
                return
            }

            if ($Duplicates = $PropertyNames | Group-Object Value | Where-Object Count -GE 2) {
                Stop-PSFFunction -Message "Duplicate column headers found on row '$StartRow' in columns '$($Duplicates.Group.Column)'. Column headers must be unique." -EnableException $true
                return
            }
            #endregion


            if (-not $rows) {
                Write-PSFMessage -Level Warning -Message "Worksheet '$WorksheetName' contains no data in the rows after top row '$StartRow'"
            } else {
                # Create one object per row
                foreach ($row in $rows) {
                    Write-PSFMessage -Level Debug -Message "Import row '$row'"

                    $NewRow = [Ordered]@{}
                    foreach ($propertyName in $PropertyNames) {
                        $NewRow[$propertyName.Value] = $sheet.Cells[$row, $propertyName.Column].Value
                    }

                    $NewRow
                }

            }
        } catch {
            Stop-PSFFunction -Message "Failed importing the Excel workbook. $_" -EnableException $true
            return
        }
    }

    end {
    }
}
