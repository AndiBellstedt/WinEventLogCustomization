@{
    # Script module or binary module file associated with this manifest
    RootModule           = 'WinEventLogCustomization.psm1'

    # Version number of this module.
    ModuleVersion        = '1.0.0'

    # ID used to uniquely identify this module
    GUID                 = '9268705a-75d5-401c-b13d-4d1a8f380b17'

    # Author of this module
    Author               = 'Andreas Bellstedt'

    # Company or vendor of this module
    CompanyName          = ''

    # Copyright statement for this module
    Copyright            = 'Copyright (c) 2022 Andreas Bellstedt'

    # Description of the functionality provided by this module
    Description          = 'Module for creating and managing custom Windows EventLog channels'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion    = '5.1'

    # Supported PSEditions
    CompatiblePSEditions = 'Desktop'

    # Modules that must be imported into the global environment prior to importing
    # this module
    RequiredModules      = @(
        @{
            ModuleName    = 'PSFramework';
            ModuleVersion = '1.7.227'
        }
    )

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies   = @(
        'bin\EPPlus.Net40.dll'
        'bin\WinEventLogCustomization.dll'
    )

    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess       = @('xml\WinEventLogCustomization.Types.ps1xml')

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess     = @('xml\WinEventLogCustomization.Format.ps1xml')

    # Functions to export from this module
    FunctionsToExport    = @(
        'Import-WELCChannelDefinition',
        'New-WELCEventChannelManifest',
        'Register-WELCEventChannelManifest',
        'Move-WELCEventChannelManifest',
        'Test-WELCEventChannelManifest',
        'Unregister-WELCEventChannelManifest',
        'Open-WELCExcelTemplate',
        'Get-WELCEventChannel',
        'Set-WELCEventChannel'
    )

    # Cmdlets to export from this module
    CmdletsToExport      = ''

    # Variables to export from this module
    VariablesToExport    = ''

    # Aliases to export from this module
    AliasesToExport      = ''

    # List of all modules packaged with this module
    ModuleList           = @()

    # List of all files packaged with this module
    FileList             = @()

    # Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData          = @{
        #Support for PowerShellGet galleries.
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @(
                'EventLog',
                'WindowsEvent',
                'WindowsEventLog',
                'EventLogChannel',
                'EventLogChannels',
                'EventChannel',
                'EventChannels',
                'CustomEventChannel',
                'CustomEventLog',
                'CustomEventLogChannel',
                'CustomEventLogFile',
                'CustomEventLogFiles',
                'EventLogManifest',
                'LogFile',
                'LogFiles',
                'Automation',
                'Logging',
                'PSEdition_Desktop',
                'Windows'
            )

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/AndiBellstedt/WinEventLogCustomization/blob/main/license'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/AndiBellstedt/WinEventLogCustomization'

            # A URL to an icon representing this module.
            IconUri      = 'https://github.com/AndiBellstedt/WinEventLogCustomization/raw/main/assets/WinEventLogCustomization_128x128.png'

            # ReleaseNotes of this module
            ReleaseNotes = 'https://github.com/AndiBellstedt/WinEventLogCustomization/blob/main/WinEventLogCustomization/changelog.md'

        } # End of PSData hashtable

    } # End of PrivateData hashtable
}