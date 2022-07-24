# ![logo][] WinEventLogCustomization


| Plattform | Information |
| --------- | ----------- |
| PowerShell gallery | [![PowerShell Gallery](https://img.shields.io/powershellgallery/v/WinEventLogCustomization?label=psgallery)](https://www.powershellgallery.com/packages/WinEventLogCustomization) [![PowerShell Gallery](https://img.shields.io/powershellgallery/p/WinEventLogCustomization)](https://www.powershellgallery.com/packages/WinEventLogCustomization) [![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/WinEventLogCustomization?style=plastic)](https://www.powershellgallery.com/packages/WinEventLogCustomization) |
| GitHub  | [![GitHub release](https://img.shields.io/github/release/AndiBellstedt/WinEventLogCustomization.svg)](https://github.com/AndiBellstedt/WinEventLogCustomization/releases/latest) ![GitHub](https://img.shields.io/github/license/AndiBellstedt/WinEventLogCustomization?style=plastic) <br> ![GitHub issues](https://img.shields.io/github/issues-raw/AndiBellstedt/WinEventLogCustomization?style=plastic) <br> ![GitHub last commit (branch)](https://img.shields.io/github/last-commit/AndiBellstedt/WinEventLogCustomization/main?label=last%20commit%3A%20master&style=plastic) <br> ![GitHub last commit (branch)](https://img.shields.io/github/last-commit/AndiBellstedt/WinEventLogCustomization/Development?label=last%20commit%3A%20development&style=plastic) |
<br><br>

## Description

A PowerShell module helping you build custom eventlog channels and registering them into Windows Event Viewer.
The build logs appear under "Application and Services", even like the "Windows PowerShell"  or the "PowerShellCore/Operational" EventLog.<br>
<br>
All cmdlets are build with
- powershell regular verbs
- pipeline availabilities wherever it makes sense
- comprehensive logging on verbose and debug channel by the logging system of PSFramework<br>
<br>

## Prerequisites

- Windows PowerShell 5.1
- PowerShell 6 or 7
- Administrative Priviledges are required for registering or unregistering EventChannels<br>
<br>

## Installation

Install the module from the PowerShell Gallery (systemwide):
```PowerShell
Install-Module WinEventLogCustomization
```
<br>

## Quick start
### Creating a manifest for a EventChannel
For a quick start you can just execute:
```PowerShell
New-WELCEventChannelManifest -ChannelFullName "AndiBellstedt/MyPersonalLog"
```
another way is the following command style, if you are not familiar with the notation on ChannelFullNames:
```PowerShell
New-WELCEventChannelManifest -RootFolderName "AndiBellstedt" -FolderSecondLevel "PowerShell" -FolderThirdLevel "Tasks" -ChannelName "Operational"
```
This will create a manifest- and a dll file (*AndiBellstedt.man & AndiBellstedt.dll*) within you current directory.<br>
With the manifest file, the dll file can be registered to Windows EventLog system. <br>
**Attention**, the manifest file contains the paths to the dll and should not be moved in the Windows Explorer.  *There is a command in the module to move the manifest with it's dll file consistently.* <br>
<br>
### Register the EventChannel
Registering a manifest and its dll file is also easy:
```PowerShell
Register-WELCEventChannelManifest -Path .\AndiBellstedt.man
```
**Attention, executing this command will require admninistrative priviledges.** <br>
Due to the fact, that changes on the Windows EventLog system are a administrative task. <br>
<br>
Following this, results in a new folder "AndiBellstedt" with two subfolders ("PowerShell" & "Tasks") and a EventLog "Operational" under "Application and Services Logs" withing the Event Viewer.<br>

![EventChannel][]
<br>
<br>
### Remove the EventChannel
If the EventChannel is no longer needed, it can be removed by unregistering the manifest:
```PowerShell
UnRegister-WELCEventChannelManifest -Path .\AndiBellstedt.man
```
<br>

### Show registered EventChannels
After registering a manifest, the defined EventChannel can be queried<br>
To query a EventChannel you can use:
```PowerShell
Get-WELCEventChannel -ChannelFullName "AndiBellstedt-PowerShell-Tasks/Operational"
```
This will output something like this, showing you the details and the config of the EventChannel:
```
PS C:\> Get-WELCEventChannel -ChannelFullName "AndiBellstedt-PowerShell-Tasks/Operational" | Format-List

ComputerName      : MyComputer
Name              : AndiBellstedt-PowerShell-Tasks/Operational
Enabled           : False
LogMode           : Circular
LogType           : Administrative
LogFullName       : C:\WINDOWS\System32\Winevt\Logs\AndiBellstedt-PowerShell-Tasks%4Operational.evtx
MaxEventLogSize   : 1052672
FileSize          :
RecordCount       :
IsFull            :
LastWriteTime     :
LastAccessTime    :
ProviderName      : AndiBellstedt-PowerShell-Tasks
ProviderId        : 43b94bbe-2d97-4f04-96b4-c254483b53f4
MessageFilePath   : C:\EventLogs\AndiBellstedt.dll
ResourceFilePath  : C:\EventLogs\AndiBellstedt.dll
ParameterFilePath : C:\EventLogs\AndiBellstedt.dll
Owner             : Administrators
Access            : {NT AUTORITY\BATCH: AccessAllowed (ListDirectory, WriteData), NT AUTORITY\INTERACTIVE: AccessAllowed (ListDirectory, WriteData), NT AUTORITY\SERVICE: AccessAllowed (ListDirectory, WriteData), NT AUTORITY\SYSTEM: AccessAllowed (ChangePermissions, CreateDirectories, Delete, GenericExecute, ListDirectory, ReadPermissions, TakeOwnership, WriteData, WriteKey)…}
```
### Configuration on EventChannels
There are multiple ways to configure a EventChannel.<br>
The first, and explicit one is: <br>
```PowerShell
Set-WELCEventChannel -ChannelFullName "AndiBellstedt-PowerShell-Tasks/Operational" -Enabled $true -MaxEventLogSize 1GB -LogMode Circular -LogFilePath "C:\EventLogs\AB-PS-T-Ops.evtx"
```

Another way is to pipe in the result of a `Get-WELCEventChannel` command:
```PowerShell
$channel = Get-WELCEventChannel "AndiBellstedt*"

$channel | Set-WELCEventChannel -Enabled $true -MaxEventLogSize 1GB -LogMode AutoBackup -LogFilePath "C:\EventLogs"
```
Doing it this way, `$channel` can contain more than one EventChannel to configure.<br>
<br>

## Practical usage - Managing, creating and configuring multiple custom EventChannel
<< more to come >>
<br>


[logo]: assets/WinEventLogCustomization_128x128.png
[EventChannel]: assets/pictures/EventChannel.png