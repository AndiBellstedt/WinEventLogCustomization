Register-PSFTeppScriptblock -Name "WinEventLogCustomization.ChannelFullName" -ScriptBlock {
    Get-WinEvent -ListLog * -ErrorAction Ignore | Select-Object -ExpandProperty LogName
}

Register-PSFTeppScriptblock -Name "WinEventLogCustomization.Bool" -ScriptBlock {
    @(
        '$true',
        '$false'
    )
}

Register-PSFTeppScriptblock -Name "WinEventLogCustomization.MaxEventLogSize" -ScriptBlock {
    @(
        '16MB',
        '64MB',
        '128MB',
        '512MB',
        '1GB',
        '2GB',
        '5GB',
        '10GB'
    )
}

Register-PSFTeppScriptblock -Name "WinEventLogCustomization.FolderRoot" -ScriptBlock {
    Get-WinEvent -ListLog *-* -ErrorAction Ignore | Select-Object -ExpandProperty LogName | ForEach-Object { $_.split("-")[0] } | Sort-Object -Unique
}

Register-PSFTeppScriptblock -Name "WinEventLogCustomization.FolderSecondLevel" -ScriptBlock {
    Get-WinEvent -ListLog *-*-* -ErrorAction Ignore | Select-Object -ExpandProperty LogName | ForEach-Object { $_.split("-")[1] } | Sort-Object -Unique
}

Register-PSFTeppScriptblock -Name "WinEventLogCustomization.FolderThirdLevel" -ScriptBlock {
    Get-WinEvent -ListLog *-*-* -ErrorAction Ignore | Select-Object -ExpandProperty LogName | ForEach-Object { $_.split("-")[2].split("/")[0] } | Sort-Object -Unique
}

Register-PSFTeppScriptblock -Name "WinEventLogCustomization.ChannelName" -ScriptBlock {
    Get-WinEvent -ListLog */* -ErrorAction Ignore | Select-Object -ExpandProperty LogName | ForEach-Object { $_.split("/")[1] } | Sort-Object -Unique
}
