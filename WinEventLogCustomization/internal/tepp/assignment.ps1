# Get-WELCEventChannel
Register-PSFTeppArgumentCompleter -Command Get-WELCEventChannel -Parameter "ChannelFullName" -Name "WinEventLogCustomization.ChannelFullName"

# Set-WELCEventChannel
Register-PSFTeppArgumentCompleter -Command Set-WELCEventChannel -Parameter "ChannelFullName" -Name "WinEventLogCustomization.ChannelFullName"
Register-PSFTeppArgumentCompleter -Command Set-WELCEventChannel -Parameter "Enabled" -Name "WinEventLogCustomization.Bool"
Register-PSFTeppArgumentCompleter -Command Set-WELCEventChannel -Parameter "CompressLogFolder" -Name "WinEventLogCustomization.Bool"
Register-PSFTeppArgumentCompleter -Command Set-WELCEventChannel -Parameter "AllowFileAccessForLocalService" -Name "WinEventLogCustomization.Bool"
Register-PSFTeppArgumentCompleter -Command Set-WELCEventChannel -Parameter "MaxEventLogSize" -Name "WinEventLogCustomization.MaxEventLogSize"

# New-WELCEventChannelManifest
Register-PSFTeppArgumentCompleter -Command New-WELCEventChannelManifest -Parameter "FolderRoot" -Name "WinEventLogCustomization.FolderRoot"
Register-PSFTeppArgumentCompleter -Command New-WELCEventChannelManifest -Parameter "FolderSecondLevel" -Name "WinEventLogCustomization.FolderSecondLevel"
Register-PSFTeppArgumentCompleter -Command New-WELCEventChannelManifest -Parameter "FolderThirdLevel" -Name "WinEventLogCustomization.FolderThirdLevel"
Register-PSFTeppArgumentCompleter -Command New-WELCEventChannelManifest -Parameter "ChannelName" -Name "WinEventLogCustomization.ChannelName"
