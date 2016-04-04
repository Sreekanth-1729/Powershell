#region Safety

break

#endregion


#region Presentation Prep

<#
Creating a Custom PowerShell Toolkit to Demystify the Intricacies of Desired State Configuration
Presentation from the PowerShell and DevOps Global Summit 2016
Author:  Mike F Robbins
Website: http://mikefrobbins.com
Twitter: @mikefrobbins
#>

#The functions shown in this session are part of my MrDSC module which can be downloaded from GitHub: https://github.com/mikefrobbins/DSC

#4 VM's are used during this demonstration. 1 running Windows 10 (PC01),
#3 running Windows Server 2012 R2, one DC (DC01), one SQL 2014 Server (SQL01), and one Web Server (WEB01).
#All of these VM's are running PowerShell version 5

#Set PowerShell ISE Zoom to 175%

$psISE.Options.Zoom = 175

#Set location to the demo folder

Set-Location -Path C:\demo

#Show PowerShell version used in this demo (PowerShell version 4)

Invoke-Command -ComputerName PC01, DC01, SQL01, WEB01 {
    $PSVersionTable.PSVersion
}

#endregion


#region Build SMB Pull Server

#2 modes of configuration delvery: Push and Pull modes
#Push mode results in immediate delivery and enacts the configuration

#Create two additional SMB file shares to be used for DSC SMB Pull Servers
#In this scenario, different teams manage the DC's, SQL Servers, and Web Servers

#Open the C$ on DC01 in Explorer

Start-Process \\DC01\c$

#Separate the environmental config from the structural config

#To learn more about separating the environmental config from the structural config see my PowerShell Magazine article:
#Eliminating Redundant Code by Writing Reusable DSC Configurations: http://www.powershellmagazine.com/2015/07/07/eliminating-redundant-code-by-writing-reusable-dsc-configurations/

#Setting up a DSC SMB pull server: https://github.com/PowerShell/PowerShell-Docs/blob/master/dsc/pullServerSMB.md
#xSmbShare DSC Resource: https://github.com/PowerShell/xSmbShare
#PowerShellAccessControl DSC Resource: https://github.com/rohnedwards/PowerShellAccessControl

#The following configuration contains only the structural config (the logic)

configuration DSCSMB {

    Import-DscResource -Module PSDesiredStateConfiguration, xSmbShare, PowerShellAccessControl

    Node $AllNodes.NodeName {

        $Node.Shares.ForEach({
            File $_.ShareName {
                DestinationPath = $_.Path
                Type = 'Directory'
                Ensure = 'Present'
            }
            xSMBShare $_.ShareName {
                Name = $_.ShareName
                Path = $_.Path
                FullAccess = $_.FullAccess
                ReadAccess = $_.ReadAccess
                FolderEnumerationMode = 'AccessBased'
                Ensure = 'Present'
                DependsOn = $_.DependsOn
            }
            cAccessControlEntry "$($_.ShareName)Read" {
                Path = $_.Path
                ObjectType = 'Directory'
                AceType = 'Allow'
                Principal = $_.ReadAccess
                AccessMask = [System.Security.AccessControl.FileSystemRights]::ReadAndExecute
                DependsOn = $_.DependsOn
            }
            cAccessControlEntry "$($_.ShareName)Full" {
                Path = $_.Path
                ObjectType = 'Directory'
                AceType = 'Allow'
                Principal = $_.FullAccess
                AccessMask = [System.Security.AccessControl.FileSystemRights]::FullControl
                DependsOn = $_.DependsOn
            }

        })

    }

}

#Store the environmental portion of the configuration data in a PSD1 file (the data)

New-Item -Path .\configdata-dscsmb.psd1 -ItemType File -Force -Value "
@{
    AllNodes = @(
        @{
            NodeName = 'DC01'
            Shares = @(
                @{
                    ShareName = 'DSCSMB-DC'
                    Path = 'C:\DSCSMB-DC'
                    FullAccess = 'mikefrobbins\domain admins'
                    ReadAccess = 'mikefrobbins\domain controllers'
                    DependsOn = '[File]DSCSMB-DC'
                }
                @{
                    ShareName = 'DSCSMB-SQL'
                    Path = 'C:\DSCSMB-SQL'
                    FullAccess = 'mikefrobbins\sql admins'
                    ReadAccess = 'mikefrobbins\sql servers'
                    DependsOn = '[File]DSCSMB-SQL'
                }
                @{
                    ShareName = 'DSCSMB-WEB'
                    Path = 'C:\DSCSMB-WEB'
                    FullAccess = 'mikefrobbins\web admins'
                    ReadAccess = 'mikefrobbins\web servers'
                    DependsOn = '[File]DSCSMB-WEB'
                }
            )
        }
    )
}"

#Take a moment to notice how my code is formated. Format for readability.
#Your co-workers and future self will thank you

#Show the PSD1 file that contains the environmental portion of the configuration data

psedit -filenames .\configdata-dscsmb.psd1

#Generate the MOF file using the configuration data stored in the PSD1 file

DSCSMB -ConfigurationData .\configdata-dscsmb.psd1 -Verbose

#Apply the configuration to DC01 (push and immediately enact the configuration)

Start-DscConfiguration -ComputerName DC01 -Wait -Path .\DSCSMB -Verbose -Force

#Why was an error generated?

#Show what modules exist in the all users modules path on DC01

Start-Process '\\DC01\C$\Program Files\WindowsPowerShell\Modules'

#How can the necessary DSC resources be deployed to DC01?

#endregion 


#region Push Mode

#Show the LCM Config for DC01

Get-DscLocalConfigurationManager -CimSession DC01

#Remove the pending configuration document from DC01

Remove-DscConfigurationDocument -CimSession DC01 -Stage Pending

#PowerShell version 5 allows for the automated distribution of DSC resouces even when the LCM uses Push mode

[DscLocalConfigurationManager()]
configuration LCM_PushSMBPullResourcev5 {
    param (
        [Parameter(Mandatory)]
        [string[]]$ComputerName,

        [Parameter(Mandatory)]
        [string]$Guid,

        [Parameter(Mandatory)]
        [string]$SourcePath
    )
    Node $ComputerName	{
        Settings {
            RefreshMode = 'Push'
            ConfigurationID = $Guid
        }

        ResourceRepositoryShare ($SMBPath -replace '^.*\\') {
            Sourcepath = $SourcePath
        }
    }
}

#Create the MetaMOF

LCM_PushSMBPullResourcev5 -ComputerName DC01 -Guid (New-Guid) -SourcePath '\\DC01\DSCSMB-DC'

#Apply the MetaMOF to DC01

Set-DSCLocalConfigurationManager -Path .\LCM_PushSMBPullResourcev5 –Verbose

#Show the LCM Config for DC01

Get-DscLocalConfigurationManager -CimSession DC01

#Show the specific LCM property where the resource download information is stored

Get-DscLocalConfigurationManager -CimSession DC01 |
Select-Object -ExpandProperty ResourceModuleManagers 

#Show the LCM configuration

Get-DscLocalConfigurationManager -CimSession DC01 |
Format-Table -Property PSComputerName,
                       ConfigurationID,
                       @{l='ResourceShare';e={$_.ResourceModuleManagers.SourcePath}},
                       RefreshMode

#Design a tool to automate the deployment of the DSC resources to an SMB share
#1. Module containing the DSC resource needs to be zipped.

#Where are the DSC resources located? On the machine used for authoring the configurations.

Get-DscResource -Name cAccessControlEntry, xSmbShare
Get-Module -Name PowerShellAccessControl, xSmbShare -ListAvailable

#Modules containing the DSC Resources: xSmbShare, PowerShellAccessControl

#Compress-Archive is included with PowerShell v5 otherwise write a function to use the .NET framework or use a Com object
#Contrary to popular belief, the .NET Framework can be used for zipping the resources used with PowerShell version 4

psedit -filenames $env:ProgramFiles\WindowsPowerShell\Modules\MrDSC\New-MrZipFile.ps1

#2. Zip filename must be in the following format: ModuleName_ModuleVersion.zip

'cAccessControlEntry', 'xSmbShare' |
ForEach-Object {
    "$((Get-DscResource -Name $_) | Select-Object -ExpandProperty ModuleName -OutVariable module)_$((Get-Module -Name $module -ListAvailable).Version).zip"
}

#3. A checksum for the zip file must be created with filename: ModuleName_ModuleVersion.zip.checksum

#The checksum is created using the New-DscChecksum cmdlet

#4. Upload the files to the SMB share specified in the LCM settings 

'Get-MrDSCResourceModulePath.ps1',
'Publish-MrDSCResourceToSMB.ps1' |
ForEach-Object {
    psedit -filenames "$env:ProgramFiles\WindowsPowerShell\Modules\MrDSC\$_"
}

#PowerShell version 5 contains a cmdlet for creating GUID's (New-Guid) and creating zip file (Compress-Archive).

Get-Command -Name New-Guid

#My New-MrGuid and New-MrZipFile functions do the same thing, but they're version agnostic so they can be used with PowerShell v4 or v5.

psedit -filenames $env:ProgramFiles\WindowsPowerShell\Modules\MrDSC\New-MrGuid.ps1

#Simce the New-Guid command in PowerShell version 5 is a function and not a compiled cmdlet, we can see their code:

(Get-Command -Name New-Guid).Definition

#Open (and pin) the SMB file share where resouces for DC01 where specified to be downloaded from

Start-Process \\DC01\DSCSMB-DC

#Upload the necessary DSC resouces to the file share

Publish-MrDSCResourceToSMB -Name xSmbShare, cAccessControlEntry -SMBPath '\\DC01\DSCSMB-DC'

#Open (and pin) the all users module folder on DC01

Start-Process '\\DC01\c$\Program Files\WindowsPowerShell\Modules'

#Push the DSC configuration to DC01 and watch the missing DSC resources be installed

Start-DscConfiguration -ComputerName DC01 -Wait -Path .\DSCSMB -Verbose -Force

#Show the event logs where the DSC resources were installed

Get-MrDscLog -ComputerName DC01 -MaxEvents 12 |
Select-Object -ExpandProperty Message | Out-GridView

#Show the temp files on DC01

Start-Process \\DC01\c$\Windows\Temp

#Show the SMB file shares were created and the specified permissions were set

Start-Process \\DC01\c$

#endregion


#region Pull Mode

#Show the current LCM Config for SQL01

Get-DscLocalConfigurationManager -CimSession SQL01

#Define a configuration to set the LCM to pull mode.
#This example is compatible with PowerShell v4 and higher.

Configuration LCM_SMBPULL {
    param (
        [Parameter(Mandatory)]
        [string[]]$ComputerName,

        [Parameter(Mandatory)]
        [string]$Guid,

        [Parameter(Mandatory)]
        [string]$SourcePath
    )
        	
	Node $ComputerName	{
		LocalConfigurationManager {
			AllowModuleOverwrite = $True
            ConfigurationMode = 'ApplyAndAutoCorrect'
			RefreshMode = 'Pull'
			ConfigurationID = $Guid
			DownloadManagerName = 'DscFileDownloadManager'
            DownloadManagerCustomData = @{
	        SourcePath = $SourcePath }
            	
		}
	}
}

#Create the MetaMOF

LCM_SMBPULL -ComputerName SQL01 -Guid (New-Guid) -SourcePath '\\DC01\DSCSMB-SQL'

#Apply the MetaMOF to SQL01

Set-DSCLocalConfigurationManager -ComputerName SQL01 -Path .\LCM_SMBPULL –Verbose

#Show the LCM on SQL01 is now configured for pull mode

Get-DscLocalConfigurationManager -CimSession SQL01

#Notice where the SMB share is specified in the LCM

Get-DscLocalConfigurationManager -CimSession SQL01 |
Select-Object -ExpandProperty DownloadManagerCustomData

#Show (and pin) the all users modules folder on SQL01

Start-Process '\\SQL01\c$\Program Files\WindowsPowerShell\Modules'

#Remove the cMRSQLRecoveryModel DSC resource from SQL01

Remove-Item -Path '\\SQL01\c$\Program Files\WindowsPowerShell\Modules\cMrSQLRecoveryModel' -Recurse -ErrorAction SilentlyContinue

#Define a structural configuration for both DC01 and SQL01

configuration TestEnvironment {

    Import-DscResource -Module PSDesiredStateConfiguration, cMrSQLRecoveryModel, xSmbShare, PowerShellAccessControl
	
	node $AllNodes.Where({$_.Role -eq 'SQLServer'}).NodeName {

        $Node.Database.ForEach({
        
            cMrSQLRecoveryModel $_ {
                ServerInstance = $Node.ServerInstance
                Database = $_
                RecoveryModel = $Node.RecoveryModel
            }

        })
		
    }
    node $AllNodes.Where({$_.Role -eq 'DC'}).NodeName {

        $Node.Shares.ForEach({
            File $_.ShareName {
                DestinationPath = $_.Path
                Type = 'Directory'
                Ensure = 'Present'
            }
            xSMBShare $_.ShareName {
                Name = $_.ShareName
                Path = $_.Path
                FullAccess = $_.FullAccess
                ReadAccess = $_.ReadAccess
                FolderEnumerationMode = 'AccessBased'
                Ensure = 'Present'
                DependsOn = $_.DependsOn
            }
            cAccessControlEntry "$($_.ShareName)Read" {
                Path = $_.Path
                ObjectType = 'Directory'
                AceType = 'Allow'
                Principal = $_.ReadAccess
                AccessMask = [System.Security.AccessControl.FileSystemRights]::ReadAndExecute
                DependsOn = $_.DependsOn
            }
            cAccessControlEntry "$($_.ShareName)Full" {
                Path = $_.Path
                ObjectType = 'Directory'
                AceType = 'Allow'
                Principal = $_.FullAccess
                AccessMask = [System.Security.AccessControl.FileSystemRights]::FullControl
                DependsOn = $_.DependsOn
            }

        })

    }
}

#Save the environmental config to a PSD1 file

New-Item -Path .\configdata-dscdemo.psd1 -ItemType File -Force -Value "
@{
    AllNodes = @(
        @{
            NodeName = 'SQL01'
            Role = 'SQLServer'
            ServerInstance = 'SQL01'
            Database = 'NorthWind', 'AdventureWorks2012', 'Pubs'
            RecoveryModel = 'Full'
        }
        @{
            NodeName = 'DC01'
            Role = 'DC'
            Shares = @(
                @{
                    ShareName = 'DSCSMB-DC'
                    Path = 'C:\DSCSMB-DC'
                    FullAccess = 'mikefrobbins\domain admins'
                    ReadAccess = 'mikefrobbins\domain controllers'
                    DependsOn = '[File]DSCSMB-DC'
                }
                @{
                    ShareName = 'DSCSMB-SQL'
                    Path = 'C:\DSCSMB-SQL'
                    FullAccess = 'mikefrobbins\sql admins'
                    ReadAccess = 'mikefrobbins\sql servers'
                    DependsOn = '[File]DSCSMB-SQL'
                }
                @{
                    ShareName = 'DSCSMB-WEB'
                    Path = 'C:\DSCSMB-WEB'
                    FullAccess = 'mikefrobbins\web admins'
                    ReadAccess = 'mikefrobbins\web servers'
                    DependsOn = '[File]DSCSMB-WEB'
                }
            )            
        }
    )
}"

#What's needed to deploy the mof files to the nodes via the SMB Pull server?
#The mof file needs to be placed on the SMB share where it's specified in the LCM settings for the target node
#The mof file must be named guid.mof where the guid is the configurationID specified in the LCM setting of the target node
#A checksum must be created for the mof and the checksum file must be named guid.mof.checksum

#Are you considering the use of Active Directory GUID's for the DSC ConfigurationID? Don't and here's why not:
#Securely allocating GUIDs in PowerShell Desired State Configuration Pull Mode https://blogs.msdn.microsoft.com/powershell/2014/12/31/securely-allocating-guids-in-powershell-desired-state-configuration-pull-mode/

#Show the LCM settings for SQL01

Get-DscLocalConfigurationManager -CimSession SQL01 |
Format-Table -Property PSComputerName,
                       ConfigurationID,
                       @{l='SMBPath';e={$_.DownloadManagerCustomData.Value}},
                       RefreshMode

#Design a tool to automate the deployment of the MOF configuration files to the SMB shares
#1. Rename the MOF file to Guid.mof based on the Guid specified in the LCM settings for the configuration ID
#2. A checksum for the MOF file must be created with filename: Guid.zip.checksum
#3. Upload the files to the SMB share specified in the LCM settings

psedit -filenames "$env:ProgramFiles\WindowsPowerShell\Modules\MrDSC\Publish-MrMOFToSMB.ps1"

#Show no files exist on the file share being used as the SMB pull server (pin the folder)

Start-Process \\DC01\DSCSMB-SQL

#Create the MOF's and automatically zip, rename, create checksum and copy them to the SMB pull server

TestEnvironment -ConfigurationData .\configdata-dscdemo.psd1 |
Publish-MrMOFToSMB -Verbose

#Zip, rename, create a checksum, and copy the cMrRecoveryModel DSC resource to the SMB pull server

Publish-MrDSCResourceToSMB -Name cMrSQLRecoveryModel -SMBPath '\\DC01\DSCSMB-SQL'

#Show (and pin) the modules that are installed on SQL01.
#Show the files are named using the Guid that's set for the ConfigurationID in the LCM settings

Start-Process '\\SQL01\c$\Program Files\WindowsPowerShell\Modules'

#Show (and pin) the configuration folder on SQL01

Start-Process '\\SQL01\c$\Windows\System32\Configuration'

#Force the LCM on SQL01 to check for a new configuration on the pull server

Update-DscConfiguration -ComputerName SQL01 -Wait -Verbose

#Show the event logs where the DSC resource was successfully deployed

Get-MrDscLog -ComputerName SQL01 -MaxEvents 12 |
Select-Object -ExpandProperty Message | Out-GridView

#A new way to define the SMB Pull Server in PowerShell version 5

[DSCLocalconfigurationManager()]
Configuration LCM_SMBPULLv5 {
    param (
        [Parameter(Mandatory)]
        [string[]]$ComputerName,

        [Parameter(Mandatory)]
        [string]$Guid,

        [Parameter(Mandatory)]
        [string]$SourcePath
    )
        	
	Node $ComputerName	{
		Settings {
			AllowModuleOverwrite = $True
            ConfigurationMode = 'ApplyAndAutoCorrect'
			RefreshMode = 'Pull'
			ConfigurationID = $Guid
        }
           
            ConfigurationRepositoryShare ($SMBPath -replace '^.*\\') {
                Sourcepath = $SourcePath
            }   
	}
}

#Create the MetaMOF

LCM_SMBPULLv5 -ComputerName WEB01 -Guid (New-Guid) -SourcePath '\\DC01\DSCSMB-WEB'

#Apply the MetaMOF to WEB01 to configure its LCM

Set-DSCLocalConfigurationManager -Path .\LCM_SMBPULLv5 –Verbose

#Query the new property (ConfigurationDownloadManagers) where the SMB pull server information is stored

Get-DscLocalConfigurationManager -CimSession WEB01 |
Select-Object -ExpandProperty ConfigurationDownloadManagers

#Query DC01, SQL01, and WEB01 to show the differences in the LCM configuration

Get-DscLocalConfigurationManager -CimSession DC01, SQL01, WEB01 |
Format-Table -Property PSComputerName,
                       ConfigurationID,
                       @{l='SMBPath';e={$_.DownloadManagerCustomData.Value}},
                       @{l='SMBPathv5';e={$_.ConfigurationDownloadManagers.SourcePath}},
                       @{l='ResourceShare';e={$_.ResourceModuleManagers.SourcePath}},
                       RefreshMode,
                       ConfigurationModeFrequencyMins,
                       RefreshFrequencyMins

#endregion


#region Cleanup and Reset Demo

$psISE.Options.Zoom = 100

Invoke-Command -ComputerName dc01 {
    'DSCSMB-SQL', 'DSCSMB-WEB' |
    ForEach-Object {
        Remove-SmbShare -Name $_ -Force -ErrorAction SilentlyContinue
        Remove-Item -Path c:\$_ -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Configuration LCM_PUSH {
    param (
        [Parameter(Mandatory)]
        [string[]]$ComputerName,

        [string]$guid
    )
        	
	Node $ComputerName	{
		LocalConfigurationManager {
			AllowModuleOverwrite = $false
            ConfigurationMode = 'ApplyAndMonitor'
			RefreshMode = 'Push'
			ConfigurationID = $null
			DownloadManagerName = $null
            DownloadManagerCustomData = $null
            	
		}
	}
}

LCM_PUSH -ComputerName SQL01, DC01, WEB01
Set-DSCLocalConfigurationManager -Path .\LCM_PUSH –Verbose

Get-Command -CommandType Configuration |
Foreach {Remove-Item -Path Function:\$_}

Remove-Item -Path 'C:\demo\TestEnvironment\*.checksum' -ErrorAction SilentlyContinue

#Remove the xSmbShare and PowerShellAccessControl DSC resources from DC01

Remove-Item -Path '\\DC01\c$\Program Files\WindowsPowerShell\Modules\xSmbShare' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path '\\DC01\c$\Program Files\WindowsPowerShell\Modules\PowerShellAccessControl' -Recurse -Force -ErrorAction SilentlyContinue

Remove-Item -Path '\\DC01\c$\DSCSMB-DC\*.*' -Force -ErrorAction SilentlyContinue

#endregion