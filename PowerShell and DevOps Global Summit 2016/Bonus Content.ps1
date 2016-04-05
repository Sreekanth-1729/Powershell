#region Safety

break

#endregion

#region Presentation Prep

<#
Presentation from the PowerShell and DevOps Global Summit 2016
Author:  Mike F Robbins
Website: http://mikefrobbins.com
Twitter: @mikefrobbins
#>

#Functions shown in this file can be downloaded from either my PowerShell repository on Github: https://github.com/mikefrobbins/PowerShell
#or my DSC repository on GitHub: https://github.com/mikefrobbins/DSC

#Set PowerShell ISE Zoom to 150%

$psISE.Options.Zoom = 150

#Import the MrToolkit PowerShell module since it's not in the $env:PSModulePath

Import-Module U:\GitHub\PowerShell\MrToolkit\MrToolkit.psd1

#endregion

#region Bonus Content

#Show the files in the MrDSC module

Get-ChildItem -Path U:\GitHub\DSC\MrDSC | Out-GridView

#Show running the Test-MrFunctionsToExport function. It's a Pester test wrapped in a function to make it dynamic

Test-MrFunctionsToExport -ManifestPath U:\GitHub\DSC\MrDSC\MrDSC.psd1

#Show the Test-MrFunctionsToExport function

psEdit -filenames U:\GitHub\PowerShell\MrToolkit\Test-MrFunctionsToExport.ps1

#Show the module data file and manifest file

'MrDSC.psd1', '\MrDSC.psm1' |
ForEach-Object {
    psEdit -filenames U:\GitHub\DSC\MrDSC\$_
}

#Copy a new function into the MrDSC module folder

Copy-item -Path U:\GitHub-Old\DSC\MrDSC\Invoke-MrDscConfiguration.ps1 -Destination U:\GitHub\DSC\MrDSC

#Test the MrDSC module again

Test-MrFunctionsToExport -ManifestPath U:\GitHub\DSC\MrDSC\MrDSC.psd1

#Retrieve a list of the functions

Get-MrFunctionsToExport -Path U:\GitHub\DSC\MrDSC

#Run that command again, piping the results to the clipboard

Get-MrFunctionsToExport -Path U:\GitHub\DSC\MrDSC | clip.exe

#Unfortunately Update-ModuleManifest is broken in PowerShell version 5 so I'll have to manually paste those results into the manifest file

psEdit -filenames U:\GitHub\DSC\MrDSC\MrDSC.psd1

#Test the module again

Test-MrFunctionsToExport -ManifestPath U:\GitHub\DSC\MrDSC\MrDSC.psd1

#Open the new function and add -Modules PSDesiredStateConfiguration to the first line

psEdit -filenames U:\GitHub\DSC\MrDSC\Invoke-MrDscConfiguration.ps1

#Reload the MrDSC module

Import-Module U:\GitHub\DSC\MrDSC\MrDSC.psd1 -Force

#Show the commands that are now incorrectly being reported as part of my MrDSC module

Get-Command -Module MrDSC

#Test the module again

Test-MrFunctionsToExport -ManifestPath U:\GitHub\DSC\MrDSC\MrDSC.psd1

#The solution is to use the RequiredModules option in the module manifest instead
#An example can be seen in my MrToolkit module

psEdit -filenames U:\GitHub\PowerShell\MrToolkit\MrToolkit.psd1

#endregion


#region Demo cleanup

Set-Location -Path U:\GitHub\DSC

git status
git checkout dev -f

git status
git clean -fd

git status

#endregion