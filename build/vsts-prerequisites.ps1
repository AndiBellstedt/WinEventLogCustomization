param (
    [string]
    $Repository = 'PSGallery'
)

$modules = @("PSFramework", "PSModuleDevelopment", "PSScriptAnalyzer")

# Automatically add missing dependencies
$data = Import-PowerShellDataFile -Path "$PSScriptRoot\..\WinEventLogCustomization\WinEventLogCustomization.psd1"
foreach ($dependency in $data.RequiredModules) {
    if ($dependency -is [string]) {
        if ($modules -contains $dependency) { continue }
        $modules += $dependency
    }
    else {
        if ($modules -contains $dependency.ModuleName) { continue }
        $modules += $dependency.ModuleName
    }
}

foreach ($module in $modules) {
    Write-Host "Installing $module" -ForegroundColor Cyan
    Install-Module $module -Force -SkipPublisherCheck -Repository $Repository
    Import-Module $module -Force -PassThru
}

Write-Host "Installing Pester v5.3.1" -ForegroundColor Cyan
Install-Module -Name "Pester" -RequiredVersion 5.3.1 -Force -SkipPublisherCheck -Repository $Repository
Import-Module "Pester" -Force -PassThru
