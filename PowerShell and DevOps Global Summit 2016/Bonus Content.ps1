#region Bonus Content

Import-Module U:\GitHub\PowerShell\MrToolkit\MrToolkit.psd1

#Things to show:

Test-MrFunctionsToExport -ManifestPath U:\GitHub\DSC\MrDSC\MrDSC.psd1

'MrToolkit.psd1', '\MrToolkit.psm1', 'Test-MrFunctionsToExport.ps1' |
ForEach-Object {
    psEdit -filenames U:\GitHub\PowerShell\MrToolkit\$_
}

Copy-item -Path U:\GitHub-Old\DSC\MrDSC\Invoke-MrDscConfiguration.ps1 -Destination U:\GitHub\DSC\MrDSC

Test-MrFunctionsToExport -ManifestPath U:\GitHub\DSC\MrDSC\MrDSC.psd1

Get-MrFunctionsToExport -Path U:\GitHub\DSC\MrDSC

psEdit -filenames U:\GitHub\DSC\MrDSC\Invoke-MrDscConfiguration.ps1

#Both are part of my MrToolkit module that can be downloaded from my PowerShell repository on Github: https://github.com/mikefrobbins/PowerShell

#endregion