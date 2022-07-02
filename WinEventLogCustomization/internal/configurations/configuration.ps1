<#
This is an example configuration file

By default, it is enough to have a single one of them,
however if you have enough configuration settings to justify having multiple copies of it,
feel totally free to split them into multiple files.
#>

<#
# Example Configuration
Set-PSFConfig -Module 'WinEventLogCustomization' -Name 'Example.Setting' -Value 10 -Initialize -Validation 'integer' -Handler { } -Description "Example configuration setting. Your module can then use the setting using 'Get-PSFConfigValue'"
#>

Set-PSFConfig -Module 'WinEventLogCustomization' -Name 'Import.DoDotSource' -Value $false -Validation 'bool' -Description "Whether the module files should be dotsourced on import. By default, the files of this module are read as string value and invoked, which is faster but worse on debugging." -Initialize
Set-PSFConfig -Module 'WinEventLogCustomization' -Name 'Import.IndividualFiles' -Value $false -Validation 'bool' -Description "Whether the module files should be imported individually. During the module build, all module code is compiled into few files, which are imported instead by default. Loading the compiled versions is faster, using the individual files is easier for debugging and testing out adjustments." -Initialize


Set-PSFConfig -Module 'WinEventLogCustomization' -Name 'MatchString.ProviderName' -Value '(^([a-zA-Z]| |[0-9]|\(|\))*$)|(^([a-zA-Z]| |[0-9]|\(|\))*-([a-zA-Z]| |[0-9]|\(|\))*-([a-zA-Z]| |[0-9]|\(|\))*$)' -Description "Regex to validate name of ProviderName within a manifest file" -Initialize
Set-PSFConfig -Module 'WinEventLogCustomization' -Name 'MatchString.ProviderSymbol' -Value '(^([a-zA-Z]| |[0-9]|\(|\))*$)|(^([a-zA-Z]| |[0-9]|\(|\))*_([a-zA-Z]| |[0-9]|\(|\))*_([a-zA-Z]| |[0-9]|\(|\))*$)|(^([a-zA-Z]| |[0-9]|\(|\))*_([a-zA-Z]| |[0-9]|\(|\))*_([a-zA-Z]| |[0-9]|\(|\))*_([a-zA-Z]| |[0-9]|\(|\))*$)'-Description "Regex to validate name of ProviderSymbol within a manifest file" -Initialize

Set-PSFConfig -Module 'WinEventLogCustomization' -Name 'MatchString.ChannelName' -Value '(^(\w| )*\/(\w| |\(|\))*$)|(^(\w| )*-(\w| )*-(\w| )*\/(\w| |\(|\))*$)'-Description "Regex to validate name of ChannelName within a manifest file" -Initialize
Set-PSFConfig -Module 'WinEventLogCustomization' -Name 'MatchString.ChannelSymbol' -Value '(^([a-zA-Z]|[0-9]|\(|\))*_([a-zA-Z]|[0-9]|\(|\))*$)|(^([a-zA-Z]|[0-9]|\(|\))*_([a-zA-Z]|[0-9]|\(|\))*_([a-zA-Z]|[0-9]|\(|\))*_([a-zA-Z]|[0-9]|\(|\))*$)' -Description "Regex to validate name of ChannelSymbol within a manifest file" -Initialize
Set-PSFConfig -Module 'WinEventLogCustomization' -Name 'MatchString.ChannelTypes' -Value @("Admin", "Operational", "Analytic", "Debug") -Validation stringarray -Description "Name-array of possible ChannelTypes" -Initialize
