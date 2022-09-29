# Changelog
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