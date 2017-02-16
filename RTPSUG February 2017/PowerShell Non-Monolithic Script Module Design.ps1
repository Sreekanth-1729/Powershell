#region Presentation Prep

<#
PowerShell Non-Monolithic Script Module Design
Presentation for the Research Triangle PowerShell Users Group - February 15th, 2017
Author:  Mike F Robbins
Website: http://mikefrobbins.com
Twitter: @mikefrobbins
#>

#Safety in case the entire script is run instead of a selection

Start-Sleep -Seconds 1800

#Set PowerShell ISE Zoom to 150%

$psISE.Options.Zoom = 150
$Path = 'C:\Demo'

#Create the C:\Demo older if it doesn't already exist
If (-not(Test-Path -Path $Path -PathType Container)) {
    New-Item -Path $Path -ItemType Directory
}

#Change into the C:\Demo folder
Set-Location -Path $Path

#endregion


#region Dot-Sourcing functions

#Show creating and dot-sourcing a function
$psISE.CurrentPowerShellTab.Files.Add((New-Item -Path $Path\Get-MrPSVersion.ps1 -ItemType File))

#Add code for the Get-MrPSVersion function to the ps1 file
Set-Content -Path "$Path\Get-MrPSVersion.ps1" -Value @'
function Get-MrPSVersion {
    $PSVersionTable
}
'@

#Demonstrate running the the script. Why doesn't anything happen?
.\Get-MrPSVersion.ps1

#Try to call the function
Get-MrPSVersion

#Check to see if the function exists on the Function PSDrive
Get-ChildItem -Path Function:\Get-MrPSVersion

#The function needs to be dot-sourced to load it into the global scope
#The relative path can be used
. .\Get-MrPSVersion.ps1

#The fully qualified path can also be used
. C:\Demo\Get-MrPSVersion.ps1

#The variable containing the path to the demo folder along with the filename can also be used
. $Path\Get-MrPSVersion.ps1

#Try to call the function again
Get-MrPSVersion

#Show that the function exists on the Function PS Drive
Get-ChildItem -Path Function:\Get-MrPSVersion

#endregion


#region File Encoding

#Show that New-Item doesn't have a parameter to control the file encoding
(Get-Command -Name New-Item).Parameters.Keys

#Show the file encoding type when a file is created with New-Item
Get-FileEncoding -Path $Path\Get-MrPSVersion.ps1

#Create another PS1 file in the GUI named Get-MrComputerName.ps1 and save it in the C:\Demo folder
$psISE.CurrentPowerShellTab.Files.Add()

#Copy and paste the following code into the Get-MrComputerName.ps1 file and save it
function Get-MrComputerName {
    $env:COMPUTERNAME
}

#Show the file encoding for the file created using the GUI
Get-FileEncoding -Path $Path\Get-MrComputerName.ps1

#Set-Content has a -Encoding parameter
(Get-Command -Name Set-Content).Parameters.Keys
help Set-Content -Parameter Encoding

#Add code for the Get-MrPSVersion function to the ps1 file except this time specify the Encoding parameter
Set-Content -Path "$Path\Get-MrPSVersion.ps1" -Encoding UTF8 -Value @'
function Get-MrPSVersion {
    $PSVersionTable
}
'@

#Show the file encoding type
Get-FileEncoding -Path $Path\Get-MrPSVersion.ps1

#Show the file encoding for one of the built-in modules
Get-FileEncoding -Path $PSHOME\Modules\Microsoft.PowerShell.Archive\Microsoft.PowerShell.Archive.psm1

#Remove the functions from the function PSDrive
Get-ChildItem -Path Function:\Get-Mr*
Get-ChildItem -Path Function:\Get-Mr* | Remove-Item
Get-ChildItem -Path Function:\Get-Mr*

#endregion


#region Monolithic Script Module

#A script module in PowerShell is simply a file containing one or more functions that's saved as a PSM1 file instead of a PS1 file.

#Be sure to use approved verbs for your functions otherwise a warning will be generated when your module is imported

#Use Get-Verb to find a list of approved verbs
Get-Verb | Sort-Object -Property Verb

#Approved Verbs for Windows PowerShell Commands https://msdn.microsoft.com/en-us/library/windows/desktop/ms714428%28v=vs.85%29.aspx

#How do you create a script module file? Not with the New-Module cmdlet
help New-Module

#Create a dynamic PowerShell module with an unapproved verb
New-Module -Name MyModule -ScriptBlock {

    function Return-MrOsVersion {
        Get-CimInstance -ClassName Win32_OperatingSystem |
        Select-Object -Property @{label='OperatingSystem';expression={$_.Caption}}
    }

    Export-ModuleMember -Function Return-MrOsVersion

} | Import-Module

#Remove the module from memory
Remove-Module -Name MyModule

#Create a directory for the script module
New-Item -Path $Path -Name MyModule -ItemType Directory

#Create the script module (PSM1 file) using the Out-File cmdlet
Out-File -FilePath $Path\MyModule\MyModule.psm1

#Show the default file encoding type when using Out-File to create files
Get-FileEncoding -Path $Path\MyModule\MyModule.psm1

#Out-File has a -Encoding parameter
(Get-Command -Name Out-File).Parameters.Keys
help Out-File -Parameter Encoding

#Create a script module file specifying the same type of encoding when a script module is created using the GUI
Out-File -FilePath $Path\MyModule\MyModule.psm1 -Encoding utf8 -Force

#Show that the script module file now uses the UTF-8 encoding
Get-FileEncoding -Path $Path\MyModule\MyModule.psm1

#Open the new script module file in the ISE
psEdit -filenames $Path\MyModule\MyModule.psm1

#Add the two previously used functions to our script module
Set-Content -Path "$Path\MyModule\MyModule.psm1" -Value @'
function Get-MrPSVersion {
    $PSVersionTable
}

function Get-MrComputerName {
    $env:COMPUTERNAME
}
'@

#Try to call one of the functions
Get-MrComputerName

#In order to take advantage of module autoloading, a script module needs to be saved in a folder with the same base name as the PSM1
#file and in a location specified in $env:PSModulePath 

#Show where the module currently resides at
explorer.exe $Path\MyModule

#Show the PSModulePath on my computer
$env:PSModulePath -split ';'

#Show the default locations that exist in the PSModulePath
($env:PSModulePath -split ';').Where({$_ -like '*WindowsPowerShell*'})

#Current user path
($env:PSModulePath -split ';').Where({$_ -like "*WindowsPowerShell*"})[0]

#All user path (added in PowerShell verison 4.0)
($env:PSModulePath -split ';').Where({$_ -like "*WindowsPowerShell*"})[1]

#No user modules should be placed in the Windows\System32 path. Only Microsot should place modules there.
($env:PSModulePath -split ';').Where({$_ -like "*WindowsPowerShell*"})[2]

#If the PSModuleAutoLoadingPreference has been changed from the default, it can impact module autoloading.
$PSModuleAutoloadingPreference

help about_Preference_Variables
<##
$PSModuleAutoloadingPreference
------------------------------
      Enables and disables automatic importing of modules in the session. 
      "All" is the default. Regardless of the value of this variable, you
      can use the Import-Module cmdlet to import a module.

      Valid values are:

        All    Modules are imported automatically on first-use. To import a
               module, get (Get-Command) or use any command in the module. 

        ModuleQualified
               Modules are imported automatically only when a user uses the
               module-qualified name of a command in the module. For example,
               if the user types "MyModule\MyCommand", Windows PowerShell
               imports the MyModule module.

        None   Automatic importing of modules is disabled in the session. To
               import a module, use the Import-Module cmdlet.       

      For more information about automatic importing of modules, see about_Modules
      (http://go.microsoft.com/fwlink/?LinkID=144311).
##>

#Close out of all open script and/or module files

#Move our newly created module to a location that exist in $env:PSModulePath
Move-Item -Path $Path\MyModule -Destination $env:ProgramFiles\WindowsPowerShell\Modules

#Try to call one of the functions
Get-MrComputerName

#endregion


#region Module Manifests

#All script modules should have a module manifest which is a PSD1 file and contains meta data about the module
#New-ModuleManifest is used to create a module manifest
#Path is the only value that's required. However, the module won't work if root module is not specified.
#It's a good idea to specify Author and Description in case you decide to upload your module to a Nuget repository with PowerShellGet 

#The version of a module without a manifest is 0.0 (This is a dead givaway that the module doesn't have a manifest).
Get-Module -Name MyModule

#Create a module manifest only specifying the required path parameter
New-ModuleManifest -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule\MyModule.psd1

#Open the module manifest
psEdit -filenames $env:ProgramFiles\WindowsPowerShell\Modules\MyModule\MyModule.psd1

#Reimport the module
Remove-Module -Name MyModule

#Determine what commands are exported (none are exported because root module was not specified in the module manifest)
Get-Command -Module MyModule

#Even after manually importing the module, no commands are exported
Import-Module -Name MyModule
Get-Command -Module MyModule
Get-Module -Name MyModule

#Add the RootModule information to the module manifest
Update-ModuleManifest -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule\MyModule.psd1 -RootModule MyModule

#Add an author and description to the manifest so the module could be uploaded to a Nuget repository with PowerShellGet
Update-ModuleManifest -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule\MyModule.psd1 -Author 'Mike F Robbins' -Description 'MyModule'

#Add a company name to the module manifest
Update-ModuleManifest -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule\MyModule.psd1 -CompanyName 'mikefrobbins.com'

#The module manifest can be initially created with all this information instead of updating it. You don't really want to recreate the manifest once it's created because the GUID will change
New-ModuleManifest -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule\MyModule.psd1 -RootModule MyModule -Author 'Mike F Robbins' -Description 'MyModule' -CompanyName 'mikefrobbins.com'

#How to Create PowerShell Script Modules and Module Manifests
#http://mikefrobbins.com/2013/07/04/how-to-create-powershell-script-modules-and-module-manifests/

#endregion


#region Built-in Modules


#You want to package your commands just like the built-in functions and cmdlets
Get-Module -Name Microsoft.PowerShell.Archive -ListAvailable
Get-Command -Module Microsoft.PowerShell.Archive

#Show the Microsoft.PowerShell.Archive script module and manifest
psEdit -filenames $PSHOME\Modules\Microsoft.PowerShell.Archive\Microsoft.PowerShell.Archive.psm1
psEdit -filenames $PSHOME\Modules\Microsoft.PowerShell.Archive\Microsoft.PowerShell.Archive.psd1

#Show how many functions are contained in the Microsoft.PowerShell.Archive script module
(Get-Content -Path $PSHOME\Modules\Microsoft.PowerShell.Archive\Microsoft.PowerShell.Archive.psm1 |
Select-String -Pattern '^function\s.*$') -replace 'function ' |
Select-Object -Property @{label='Function';expression={$_}},
                        @{label='Scope';expression={
                            if ((Compare-Object -ReferenceObject $_ -DifferenceObject (Get-Command -Module Microsoft.PowerShell.Archive).Name -IncludeEqual).SideIndicator -eq '==') {
                                'Public'
                            }
                            else {
                                'Private'
                            }
                        }} |
Sort-Object -Property Function

#Side by side versioning of modules was introduced with Powershell version 5
Get-Module -Name PSScriptAnalyzer -ListAvailable
Get-ChildItem -Path $env:ProgramFiles\WindowsPowerShell\Modules\PSScriptAnalyzer
Get-ChildItem -Path $env:ProgramFiles\WindowsPowerShell\Modules\PSScriptAnalyzer -Recurse -Depth 1

#endregion


#region Defining Public and Private Functions

#Unload our script module
Remove-Module -Name MyModule

#Remove the module manifest
Remove-Item $env:ProgramFiles\WindowsPowerShell\Modules\MyModule\MyModule.psd1

#Specific commands can be exported in the module using Export-ModuleMember or via the FunctionsToExport section of the module manifest

Set-Content -Path "$env:ProgramFiles\WindowsPowerShell\Modules\MyModule\MyModule.psm1" -Value @'
function Get-MrPSVersion {
    $PSVersionTable
}

function Get-MrComputerName {
    $env:COMPUTERNAME
}

Export-ModuleMember -Function Get-MrPSVersion
'@

psEdit -filenames "$env:ProgramFiles\WindowsPowerShell\Modules\MyModule\MyModule.psm1"

#Show the exported commands
Get-Command -Module MyModule

#Recreate the module manifest
New-ModuleManifest -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule\MyModule.psd1 -RootModule MyModule -Author 'Mike F Robbins' -Description 'MyModule' -CompanyName 'mikefrobbins.com'

psEdit -filenames $env:ProgramFiles\WindowsPowerShell\Modules\MyModule\MyModule.psd1

#Remove Export-ModuleMember
Set-Content -Path "$env:ProgramFiles\WindowsPowerShell\Modules\MyModule\MyModule.psm1" -Value @'

function Get-MrPSVersion {
    $PSVersionTable
}

function Get-MrComputerName {
    $env:COMPUTERNAME
}
'@

#Show the exported commands
Get-Command -Module MyModule

#Reimport the module
Import-Module -Name MyModule -Force

#Show the exported commands
Get-Command -Module MyModule

#Replace * in the FunctionsToExport section of the module manifest to specific functions
Update-ModuleManifest -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule\MyModule.psd1 -FunctionsToExport Get-MrComputerName

#Reimport the module
Import-Module -Name MyModule -Force

#Show the exported commands
Get-Command -Module MyModule

#endregion


#region Non-Monolithic Script Module

#Unload the script module
Remove-Module -Name MyModule

#Remove the script module
Remove-Item -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule -Recurse -Confirm:$false -ErrorAction SilentlyContinue

#Import my MrToolkit module which can be downloaded from my PowerShell repo on GitHub: https://github.com/mikefrobbins/PowerShell
Import-Module U:\GitHub\PowerShell\MrToolkit\MrToolkit.psd1

#PowerShell function for creating a script module template
#http://mikefrobbins.com/2016/06/30/powershell-function-for-creating-a-script-module-template/

#Create a new non-monolithic script module using my template function
New-MrScriptModule -Name MyModule -Path $env:ProgramFiles\WindowsPowerShell\Modules -Author 'Mike F Robbins' -CompanyName 'mikefrobbins.com' -Description 'MyModule' -PowerShellVersion 3.0

#Open the script module and module manifest
Get-ChildItem -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule\*.* | ForEach-Object {psEdit -filenames $_.FullName}

#PowerShell function for creating a PowerShell function template
#http://mikefrobbins.com/2016/07/14/powershell-function-for-creating-a-powershell-function-template/

#Create the two functions using my function template
New-MrFunction -Name Get-MrPSVersion -Path "$env:ProgramFiles\WindowsPowerShell\Modules\MyModule"
New-MrFunction -Name Get-MrComputerName -Path "$env:ProgramFiles\WindowsPowerShell\Modules\MyModule"

#Open the two PS1 files that contain the functions and the Pester tests for each one
Get-ChildItem -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule\*.ps1 | ForEach-Object {psEdit -filenames $_.FullName}

#Update the content for both functions
Set-Content -Path "$env:ProgramFiles\WindowsPowerShell\Modules\MyModule\Get-MrPSVersion.ps1" -Value @'
function Get-MrPSVersion {
    $PSVersionTable
}
'@
Set-Content -Path "$env:ProgramFiles\WindowsPowerShell\Modules\MyModule\Get-MrComputerName.ps1" -Value @'
function Get-MrComputerName {
    $env:COMPUTERNAME
}
'@

#Show the commands that are part of MyModule
Get-Command -Module MyModule
Get-Module -Name MyModule

#Add a requires statement that specifies a module
Set-Content -Path "$env:ProgramFiles\WindowsPowerShell\Modules\MyModule\Get-MrComputerName.ps1" -Value @'
#Requires -Modules AWSPowerShell
function Get-MrComputerName {
    $env:COMPUTERNAME
}
'@

#Reimport MyModule
Import-Module -Name MyModule -Force

#Verify that one of the functions does indeed exist
Get-MrComputerName

#Show the commands that are part of MyModule
Get-Command -Module MyModule
Get-Module -Name MyModule

#Show the count of the commands that are part of MyModule
(Get-Command -Module MyModule).count

#Demonstrate using a function that's written as a Pester test to verify the proper commands are exported
Test-MrFunctionsToExport -ManifestPath $env:ProgramFiles\WindowsPowerShell\Modules\MyModule\MyModule.psd1

#Demostrate using a function that returns a list of the function names as a comma separated list
Get-MrFunctionsToExport -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule

#The previous command can be piped to clip.exe to semi-automate updating the functions to export list in the module manifest
Get-MrFunctionsToExport -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule | clip.exe

#[Bug] Update-ModuleManifest fails if TypesToProcess or FormatsToProcess have values
#https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/12479136--bug-update-modulemanifest-fails-if-typestoproces

#Demostrate using the simple parameter
Get-MrFunctionsToExport -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule -Simple

#Update the module manifest and show the problems that it creates
Update-ModuleManifest -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule\MyModule.psd1 -FunctionsToExport (
    Get-MrFunctionsToExport -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule -Simple)

#Beware of the PowerShell Update-ModuleManifest Function
#http://mikefrobbins.com/2017/01/12/beware-of-the-powershell-update-modulemanifest-function/

Update-ModuleManifest -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule\MyModule.psd1 -FunctionsToExport (
    Get-MrFunctionsToExport -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule -Simple) -CmdletsToExport '@()'-VariablesToExport '@()' -AliasesToExport '@()'

#Don’t use Default Manifest Settings when Dot-Sourcing Functions in PS1 Files from a PowerShell Script Module
#http://mikefrobbins.com/2016/05/05/dont-use-default-manifest-settings-when-dot-sourcing-functions-in-ps1-files-from-a-powershell-script-module/

#Attempt to use one of the commands
Get-MrPSVersion

#Verify that the proper commands are now exported
Test-MrFunctionsToExport -ManifestPath $env:ProgramFiles\WindowsPowerShell\Modules\MyModule\MyModule.psd1

#Keeping Track of PowerShell Functions in Script Modules when Dot-Sourcing PS1 Files
#http://mikefrobbins.com/2016/04/21/keeping-track-of-powershell-functions-in-script-modules-when-dot-sourcing-ps1-files/

#PowerShell Script Module Design: Placing functions directly in the PSM1 file versus dot-sourcing separate PS1 files
#http://mikefrobbins.com/2016/01/14/powershell-script-module-design-placing-functions-directly-in-the-psm1-file-versus-dot-sourcing-separate-ps1-files/

#endregion


#region Cleanup

$psISE.Options.Zoom = 100
Set-Location -Path C:\
$Path = 'C:\Demo'
Remove-Module -Name MyModule -ErrorAction SilentlyContinue
Remove-Item -Path "$Path\Get-MrPSVersion.ps1", "$Path\Get-MrComputerName.ps1" -ErrorAction SilentlyContinue
Remove-Item -Path $env:ProgramFiles\WindowsPowerShell\Modules\MyModule -Recurse -Confirm:$false -ErrorAction SilentlyContinue
Remove-Module -Name MrToolkit -ErrorAction SilentlyContinue
#endregion