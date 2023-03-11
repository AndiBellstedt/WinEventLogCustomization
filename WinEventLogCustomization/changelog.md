# Changelog
## 1.0.3.0 (2023-03-11)
- New: ---
- Upd: ---
- Fix:
    - Register-WELCEventChannelManifest: Fix bug with session handling for registering manifests on remote systems
    - General: Fix integer overflow on WELC.ChannelConfig objects to allow Excel import of eventlog channel configurations with size attribute larger than 1 GB

## 1.0.2.2 (2023-02-11)
- New: ---
- Upd: ---
- Fix:
    - (Un)Register-WELCEventChannelManifest: Fix minor bug with (un)registering on remote systems and console output encoding.

## 1.0.2.1 (2022-09-29)
- New: ---
- Upd: ---
- Fix:
    - New-WELCEventChannelManifest: Fix bug on Windows PowerShell (5.1) with creating manifest. Compiling manifest files into DLLs is possible, now.

## 1.0.2 (2022-09-24)
 - New: ---
 - Upd:
   - Unregister-WELCEventChannelManifest: Extend deregistration process with scanning registry for provider/ event source artifacts on channels from manifest that is going to unregister
 - Fix:
   - New-WELCEventChannelManifest: make WhatIf switch effective on command
   - Set-WELCEventChannel: bugfix hashtable value mistake, that prevent you from using the function

## 1.0.0 (2022-07-24)
First official release.
 - New: Introducing functions within the module
    - Get-WELCEventChannel
    - Import-WELCChannelDefinition
    - Move-WELCEventChannelManifest
    - New-WELCEventChannelManifest
    - Open-WELCExcelTemplate
    - Register-WELCEventChannelManifest
    - Set-WELCEventChannel
    - Test-WELCEventChannelManifest
    - Unregister-WELCEventChannelManifest
 - Upd: ---
 - Fix: ---