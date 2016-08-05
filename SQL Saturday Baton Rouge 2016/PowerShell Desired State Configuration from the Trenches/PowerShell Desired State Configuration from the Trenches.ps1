#region Safety

break

#endregion

#region Presentation Prep

<#
PowerShell Desired State Configuration from the Trenches
Presentation from SQL Saturday #515 Baton Rouge, LA 2016
Author:  Mike F Robbins
Website: http://mikefrobbins.com
Twitter: @mikefrobbins
#>

#3 VM's are used during this demonstration. 1 running Windows 10 (PC01),
#2 running Windows Server 2012 R2, one DC (DC01), one SQL 2014 Server (SQL01).

#Import my MrToolkit module which can be downloaded from https://github.com/mikefrobbins/PowerShell
Import-Module -Name MrToolkit, SQLPS

#The job cmdlets seem to take a long time to load on this VM, so warm them up
Get-Job

#Set PowerShell ISE Zoom to 175%

$psISE.Options.Zoom = 175

#Set location to the demo folder

Set-Location -Path C:\demo

#Import saved credential from disk

$Cred = Import-CliXml -Path .\cred.ps1.xml

#(Credentials were previously saved to disk using: 'Get-Credential | Export-CliXml -Path .\cred.ps1.xml')

#Clear the screen

Clear-Host

#Show PowerShell version used in this demo (PowerShell version 5)

Invoke-Command -ComputerName PC01, DC01, SQL01 {
    $PSVersionTable.PSVersion
}

#endregion

#region DSC Basics

#DSC Cmdlets
Get-Command -Module PSDesiredStateConfiguration -OutVariable cmdlets |
Sort-Object -Property Name |
Out-GridView

#Show the number pf cmdlets
$cmdlets.count

#endregion

#region Authoring Phase

#Check the state of the .NET Framework 3.5 feature

Invoke-Command -ComputerName DC01, SQL01 {
    Get-WindowsFeature -Name Net-Framework-Core
} | Format-Table -Property PSComputerName, Name, DisplayName, Installed -AutoSize

#Authoring a configuration.

#Define Configuration {} like defining a function

configuration Name {}

#Define Node {}

configuration Name { node ComputerName {} }

#Define Resource {}

configuration Name { node ComputerName { WindowsFeature Name { Name = 'Net-Framework-Core'; Ensure = 'Present' }}}

#As you can see, the names don't matter. Format for readability.

configuration MyConfigurationName {
	
	node SQL01 {
		
        WindowsFeature MyFeatureName {
            Name = 'Net-Framework-Core'
            Ensure = 'Present'
        }
		
    }	
}

#Show the configuration that we have defined

Get-Command -CommandType Configuration

#endregion

#region Staging a Configuration

#Call the configuration to create the MOF (Managed Object Format) file

MyConfigurationName

#Open the MOF file in the ISE and show the audience the format

psEdit -filenames .\MyConfigurationName\SQL01.mof

#endregion

#region Configuration Delivery

#2 modes of configuration delvery: Push and Pull modes

#Show that Push mode is how the LCM on target nodes is configured by default

Get-DscLocalConfigurationManager -CimSession SQL01

#Push mode results in immediate delivery and enacts the configuration

#Open the configuration folder on SQL01 to show the pending MOF in the next step

Start-Process \\SQL01\c$\Windows\System32\Configuration

#Apply the configuration via DSC Push Mode

Start-DscConfiguration -Wait -Path .\MyConfigurationName -Verbose -Force

#Get the current configuration of SQL01

Get-DscConfiguration -CimSession SQL01

#Note: You can only have one configuration MOF file per server

#Test to see if SQL01 is in the desired state

Test-DscConfiguration -CimSession SQL01

#Parameterized configuration

configuration TestEnvironment {
    param (
		[Parameter(Mandatory)]
		[string[]]$ComputerName
	)

    Import-DscResource –ModuleName PSDesiredStateConfiguration

	node $ComputerName {
 
        WindowsFeature netFramework {
            Name = 'Net-Framework-Core'
            Ensure = 'Present'
        }

    }

}

#Generate the MOF file

TestEnvironment -ComputerName SQL01, DC01

#Push the configuration to all nodes with a MOF in .\TestEnvironment
#Specify specific nodes to only apply configuration to them when multiple MOF's exist
#Omiting the Wait parameter causes the configuration to be delivered via a PowerShell Job

Start-DscConfiguration -Path .\TestEnvironment

#Interactive with the PowerShell job that's created as if you would any other PowerShell job

#Display a list of jobs

Get-Job

#Display a list of jobs including child jobs. Note: One child job per node is created.

Get-Job -IncludeChildJob

#Receive the Job (Keeping the Results)

Get-Job | Receive-Job -Keep

#Get, Receive, and Remove job all in one command

Get-Job | Receive-Job -Verbose

Get-Job | Remove-Job

#Check the state of the .NET Framework 3.5 feature

Invoke-Command -ComputerName SQL01, DC01 {
    Get-WindowsFeature -Name Net-Framework-Core
} | Format-Table -Property PSComputerName, Name, DisplayName, Installed -AutoSize

#Location of default resources on your system

Get-ChildItem -Path "$PSHOME\Modules\PSDesiredStateConfiguration\DSCResources"

#Import all DSC Resources using Import-DscResource in your configurations.
#This was only required with modules that weren't in $PSHOME with PowerShell version 4.

#The DSC Resources have to exist on the node you're authoring the configuration
#on and on the node that the configuration is being applied to

#Get a list of DSC resouces on the local machine

Get-DscResource | Format-Table Name, Properties -AutoSize

#Microsoft DSC Resources are now on GitHub. You can contribute.
#Start-Process iexplore https://github.com/PowerShell/DscResources

#Show the details of the WindowsFeature DSC resource

Get-DscResource -Name WindowsFeature |
Select-Object -ExpandProperty Properties |
Format-Table -AutoSize

#Show the syntax of the WindowsFeature DSC resource

Get-DscResource -Name WindowsFeature -Syntax

#Snipets (Cntl + J)

#Where you should store any downloaded DSC resources or ones you create

Get-ChildItem -Path "$env:ProgramFiles\WindowsPowerShell\Modules" -OutVariable Modules

#This is also the default location they will be installed to when deploying
#resources with a DSC pull server

#List the modules in that folder that contain DSC Resources

$Modules |
ForEach-Object {
    (Get-ChildItem -Path "$env:ProgramFiles\WindowsPowerShell\Modules\$_" |
    Where-Object Name -contains 'DSCResources').Parent
}

#Create a SMB file share to be used as a DSC SMB Pull Server

configuration DSCSMB {

    Import-DscResource -Module PSDesiredStateConfiguration, xSmbShare, PowerShellAccessControl

    Node dc01 {

        File CreateFolder {

            DestinationPath = 'C:\DSCSMB'
            Type = 'Directory'
            Ensure = 'Present'

        }

        xSMBShare CreateShare {

            Name = 'DSCSMB'
            Path = 'C:\DSCSMB'
            FullAccess = 'mikefrobbins\domain admins'
            ReadAccess = 'mikefrobbins\domain computers'
            FolderEnumerationMode = 'AccessBased'
            Ensure = 'Present'
            DependsOn = '[File]CreateFolder'

        }

        cAccessControlEntry AssignPermissions {

            Path = 'C:\DSCSMB'
            ObjectType = 'Directory'
            AceType = 'Allow'
            Principal = 'mikefrobbins\domain computers'
            AccessMask = [System.Security.AccessControl.FileSystemRights]::ReadAndExecute
            DependsOn = '[File]CreateFolder'

        }

    }

}

#Discuss the DependsOn property in the previous configuration

#Create the MOF

DSCSMB

#Open the C$ on DC01 in Explorer

Start-Process \\DC01\c$

#Push the configuration

Start-DscConfiguration -Wait -Path .\DSCSMB -Verbose -force

#Separate the Environmental config from the structural config

#The following configuration contains only the Structural config

configuration DSCSMB {

    Import-DscResource -Module PSDesiredStateConfiguration, xSmbShare, PowerShellAccessControl

    Node $AllNodes.NodeName {

        File CreateFolder {

            DestinationPath = $Node.Path
            Type = 'Directory'
            Ensure = 'Present'

        }

        xSMBShare CreateShare {

            Name = $Node.ShareName
            Path = $Node.Path
            FullAccess = $node.FullAccess
            ReadAccess = $node.ReadAccess
            FolderEnumerationMode = 'AccessBased'
            Ensure = 'Present'
            DependsOn = '[File]CreateFolder'

        }

        cAccessControlEntry AssignPermissions {

            Path = $Node.Path
            ObjectType = 'Directory'
            AceType = 'Allow'
            Principal = $Node.ReadAccess
            AccessMask = [System.Security.AccessControl.FileSystemRights]::ReadAndExecute
            DependsOn = '[File]CreateFolder'

        }

    }

}

#Notice that calling the configuration does not create a MOF file

DSCSMB

#Define a hash table for the Environmental config data and store it in a variable

$ConfigData = @{
    AllNodes = @(
        @{
            NodeName = 'DC01'
            ShareName = 'DSCSMB'
            Path = 'C:\DSCSMB'
            FullAccess = 'mikefrobbins\domain admins'
            ReadAccess = 'mikefrobbins\domain computers'
        }
    )
}

#Show what the ConfigData variable contains

$ConfigData
$ConfigData.AllNodes

#Use the ConfigurationData parameter and specify the variable

DSCSMB -ConfigurationData $ConfigData

#There are no differences in how you apply the MOF file

Start-DscConfiguration -Wait -Path .\DSCSMB -Verbose

#You can also store the configuration data in a PSD1 file

New-Item -Path .\configdata-dscsmb.psd1 -ItemType File -Force -Value "
@{
    AllNodes = @(
        @{
            NodeName = 'DC01'
            ShareName = 'DSCSMB'
            Path = 'C:\DSCSMB'
            FullAccess = 'mikefrobbins\domain admins'
            ReadAccess = 'mikefrobbins\domain computers'
        }
    )
}"

psEdit -filenames .\configdata-dscsmb.psd1

#Generate the MOF file using the configuration data stored in the PSD1 file

DSCSMB -ConfigurationData .\configdata-dscsmb.psd1 -Verbose

#Apply the configuration to DC01

Start-DscConfiguration -Wait -Path .\DSCSMB -Verbose

#endregion 

#region SQL Server

#Discuss the DependsOn property in the following configuration

Configuration SqlInstance {

    Import-DscResource -Module PSDesiredStateConfiguration, xSqlPs, xNetworking
 
    Node SQL01 {
 
    xSqlServerInstall InstallSQLEngine {
        InstanceName = 'MSSQLSERVER'
        SourcePath = 'D:'
        Features= 'SQLEngine' 
        DependsOn ='[WindowsFeature]netFramework'
    }

    WindowsFeature netFramework {
        Name = 'Net-Framework-Core'
        Ensure = 'Present'
    }

    Service SQLServer {
        Name = 'MSSQLServer'
        StartupType = 'Automatic'
        State = 'Running'
        DependsOn = '[xSqlServerInstall]InstallSQLEngine'
    }

    Service SQLAgent {
        Name = 'SQLServerAgent'
        StartupType = 'Automatic'
        State = 'Running'
        DependsOn = '[Service]SQLServer'
    }

    xFirewall 1433 {
        Name = 'SQLServer'
        Service = 'MSSQLServer'
        Action = 'Allow'
        Ensure = 'Present'
        DependsOn = '[Service]SQLServer'
    }
 
  }
}

#Create the MOF

SqlInstance

#Push the configuration
    
Start-DscConfiguration -Wait -Path .\SqlInstance -Verbose

#Test to see if SQL01 is in the desired state

Test-DscConfiguration -CimSession SQL01

#Stop the SQL Agent service

Invoke-Command -ComputerName SQL01 {
    Stop-Service -Name SQLServerAgent -PassThru
}

#Specifying the verbose parameter gives you more information
#and will stop checking when an resource returns false

Test-DscConfiguration -CimSession SQL01 -Verbose

#Show the LCM is set to ApplyAndMonitor (the default)

Get-DscLocalConfigurationManager -CimSession SQL01

#ReApply the configuration to correct since the LCM is
#not set to ApplyAndAutoCorrect

Start-DscConfiguration -Wait -Path .\SqlInstance -Verbose

#Show SQL01 is now back in the desired state

Test-DscConfiguration -CimSession SQL01

#Define another hash table that contains a credential object

$ConfigData = @{
    AllNodes = @(
        @{
            NodeName = 'SQL01'
            SourcePath =  'D:'
            SourceFolder = '\'
            Features = 'SQLEngine'
            InstanceName = 'MSSQLSERVER'
            SetupCredential = $Credential
        }
    )
}

Configuration sqltest {

    param (
        [pscredential]$Credential
    )

    Import-DscResource -Module PSDesiredStateConfiguration, xNetworking, xSQLServer

    Node $AllNodes.NodeName {
        xSQLServerSetup installSQL {
            SourcePath = $Node.SourcePath
            Features = $Node.Features
            InstanceName = $Node.InstanceName
            SetupCredential = $Credential
            SourceFolder = $Node.SourceFolder
            UpdateEnabled = 'False'
            UpdateSource = ''
            SQLSysAdminAccounts = 'SQL01\administrators'
            DependsOn ='[WindowsFeature]netFramework'
        }
        xFirewall DBEngine {
            Name = 'SQLServer'
            Service = 'MSSQLServer'
            Action = 'Allow'
            Ensure = 'Present'
            DependsOn ='[xSQLServerSetup]installSQL'
        }
        WindowsFeature netFramework {
            Name = 'Net-Framework-Core'
            Ensure = 'Present'
        }
    }
}

#Use the ConfigurationData parameter and specify the variable

sqltest -ConfigurationData $ConfigData -Credential $Cred -Verbose

#Attempt to create the MOF. Tthis will fail with an error because
#"Converting and storing encrypted passwords as plain text is not recommended"

#Redefine the hash table with the PSDscAllowPlainTextPassword property

$ConfigData = @{
    AllNodes = @(
        @{
            NodeName = 'SQL01'
            SourcePath =  'D:'
            SourceFolder = '\'
            Features = 'SQLEngine'
            InstanceName = 'MSSQLSERVER'
            SetupCredential = $Credential
            PSDscAllowPlainTextPassword = $true
        }
    )
}

#Create the MOF

sqltest -ConfigurationData $ConfigData -Credential $Cred -Verbose

#Show the clear text password is stored in the MOF file

psEdit -filenames .\sqltest\SQL01.mof

#Use PKI. A certificate has been created on SQL01. The public key
#has been exported to a file and the Thumbprint has been noted.
#PowerShell v5 requires: KeyUsage to contain KeyEncipherment and DataEncipherment & EnhancedKeyUsage must specify 'Document Encryption'

#Show the CertificateID property for the LCM on SQL01

Get-DscLocalConfigurationManager -CimSession SQL01

#Create a configuration that will be used to set the CertificateID

Configuration LCMConfig {
        	
	Node SQL01	{
		LocalConfigurationManager {
            CertificateID = '6CBBBDDCDE53731F4B3B71BC2E8629D1A49A8D1E'            	
		}
	}

}

#Create the MetaMOF

LCMConfig

#Apply the MetaMOF

Set-DSCLocalConfigurationManager -Path .\LCMConfig –Verbose

#Show the ConfigurationID was set

Get-DscLocalConfigurationManager -CimSession SQL01

#Redefine the hash table specifying the CertificateFile that contains the public certificate

$ConfigData = @{
    AllNodes = @(
        @{
            NodeName = 'SQL01'
            SourcePath =  'D:'
            SourceFolder = '\'
            Features = 'SQLEngine'
            InstanceName = 'MSSQLSERVER'
            SetupCredential = $Credential
            CertificateFile = 'C:\demo\testcert03.cer'
        }
    )
}

#Create the MOF

sqltest -ConfigurationData $ConfigData -Credential $Cred -Verbose

#Show the password in the MOF is encrypted

psEdit -filenames .\sqltest\SQL01.mof

#Show more than one type of server can be configured with the same configuration

$ConfigData = @{
    AllNodes = @(
        @{
            NodeName = 'SQL01'
            Role = 'SQLServer'
            ServerInstance = 'SQL01'
            Database = 'NorthWind', 'AdventureWorks2012', 'Pubs'
            RecoveryModel = 'Full'
            Services = (Get-MrAutoService -ComputerName SQL01).Name
        }
        @{
            NodeName = 'DC01'
            Role = 'DC'
            Services = (Get-MrAutoService -ComputerName DC01).Name
        }
        @{
            NodeName = '*'
            Feature = 'Server-Gui-Shell'

        }
    )
}

configuration TestEnvironment {

    Import-DscResource -Module PSDesiredStateConfiguration, cMrSQLRecoveryModel, xSmbShare, PowerShellAccessControl
	
	node $AllNodes.Where({$_.Role -eq 'SQLServer'}).NodeName {

        $Node.Services.ForEach({
        
            Service $_ {

                Name = $_
                State = 'Running'

            }

        })

        $Node.Database.ForEach({
        
            cMrSQLRecoveryModel $_ {

                ServerInstance = $Node.ServerInstance
                Database = $_
                RecoveryModel = $Node.RecoveryModel
                DependsOn = '[Service]MSSQLServer'
            }

        })
		
    }

    node $AllNodes.Where({$_.Role -eq 'DC'}).NodeName {

        File DSCSMB {

            Type = 'Directory'
            Ensure = 'Present'
            DestinationPath = 'C:\DSCSMB'

        }

        xSMBShare DSCSMB {

            Name = 'DSCSMB'
            FullAccess = 'mikefrobbins\administrator'
            ReadAccess = 'mikefrobbins\domain computers'
            Path = 'C:\DSCSMB'
            Ensure = 'Present'
            FolderEnumerationMode = 'AccessBased'
            DependsOn = '[File]DSCSMB'

        }

        cAccessControlEntry DSCSMB {

            AceType = 'Allow'
            ObjectType = 'Directory'
            Path = 'C:\DSCSMB'
            Principal = 'mikefrobbins\domain computers'
            AccessMask = [System.Security.AccessControl.FileSystemRights]::ReadAndExecute
            DependsOn = '[File]DSCSMB'

        }

        $Node.Services.ForEach({
        
            Service $_ {

                Name = $_
                State = 'Running'

            }

        })

    }

    node $AllNodes.NodeName {
        
        WindowsFeature NoGUI {

            Name = $Node.Feature
            Ensure = 'Absent'

        }
    }
}

#Create the MOF's

TestEnvironment -ConfigurationData $ConfigData

#Show the MOF documents in the folder

Start-Process .\TestEnvironment

#endregion

#region Pull Mode

#Show the current LCM Config

Get-DscLocalConfigurationManager -CimSession SQL01

#Define a configuration to set the LCM to pull mode

Configuration LCM_SMBPULL {
    param (
        [Parameter(Mandatory)]
        [string[]]$ComputerName,

        [Parameter(Mandatory)]
        [string]$Guid
    )
        	
	Node $ComputerName	{
		LocalConfigurationManager {
			AllowModuleOverwrite = $True
            ConfigurationMode = 'ApplyAndAutoCorrect'
			RefreshMode = 'Pull'
            CertificateID = '6CBBBDDCDE53731F4B3B71BC2E8629D1A49A8D1E'
			ConfigurationID = $Guid
			DownloadManagerName = 'DscFileDownloadManager'
            DownloadManagerCustomData = @{
	        SourcePath = "\\DC01\DSCSMB" }
            	
		}
	}
}

#Create the MetaMOF

LCM_SMBPULL -ComputerName SQL01 -Guid (New-MrGuid)

#Apply the MetaMOF to SQL01

Set-DSCLocalConfigurationManager -Path .\LCM_SMBPULL –Verbose

#Show the LCM on SQL01 is now configured for pull mode

Get-DscLocalConfigurationManager -CimSession SQL01
Get-DscLocalConfigurationManager -CimSession SQL01 | Select-Object -ExpandProperty DownloadManagerCustomData

#Show that it does not exist on SQL01

Start-Process '\\SQL01\c$\Program Files\WindowsPowerShell\Modules'

#Remove the cMRSQLRecoveryModel DSC resource from SQL01

Remove-Item -Path '\\SQL01\c$\Program Files\WindowsPowerShell\Modules\cMrSQLRecoveryModel' -Recurse

#Show no files exist on the file share being used as the SMB pull server

Start-Process \\DC01\DSCSMB

#Define a configuration

$ConfigData = @{
    AllNodes = @(
        @{
            NodeName = 'SQL01'
            Role = 'SQLServer'
            ServerInstance = 'SQL01'
            Database = 'NorthWind', 'AdventureWorks2014', 'Pubs'
            RecoveryModel = 'Simple'
            Services = (Get-MrAutoService -ComputerName SQL01).Name
        }
        @{
            NodeName = '*'
            Feature = 'Server-Gui-Shell'

        }
    )
}

#Create the MOF's and automatically zip, rename, create checksum and copy them to the SMB pull server

TestEnvironment -ConfigurationData $ConfigData | Publish-MrMOFToSMB -Verbose

#Show the file are named with the GUID that is set in the LCM

Get-DscLocalConfigurationManager -CimSession SQL01

#Zip, rename, create a checksum, and copy the cMrRecoveryModel DSC resource to the SMB pull server

Publish-MrDSCResourceToSMB -Name cMrSQLRecoveryModel, xSmbShare -SMBPath '\\DC01\DSCSMB'

#Call the CIM method to check for a new configuration on the pull server

Update-DscConfiguration -ComputerName SQL01 -Wait -Verbose

#Show the event logs where the DSC resource was successfully deployed

Get-MrDscLog -ComputerName SQL01 -MaxEvents 11 | Select-Object -ExpandProperty Message

#endregion

#region Resource Design

#Use the DSC Resource Designer to create the skeleton for a new DSC Resource

New-xDscResource –Name cMrSQLRecoveryModelTmp -Property (
    New-xDscResourceProperty –Name ServerInstance –Type String –Attribute Key), (
    New-xDscResourceProperty –Name Database –Type String –Attribute Key), (
    New-xDscResourceProperty –Name RecoveryModel -Type String –Attribute Write –ValidateSet 'Full', 'BulkLogged', 'Simple'
) -Path "$env:ProgramFiles\WindowsPowerShell\Modules\cMrSQLRecoveryModelTmp"

#Define a hash table with the parameters needed to created a module manifest

$Params = @{
    Path  = "$env:ProgramFiles\WindowsPowerShell\Modules\cMrSQLRecoveryModelTmp\cMrSQLRecoveryModelTmp.psd1"
    Author = 'Mike F Robbins'
    CompanyName = 'mikefrobbins.com'
    RootModule = 'cMrSQLRecoveryModelTmp'
    Description = 'Module to set SQL Server database recovery model'
    PowerShellVersion = '4.0'
    FunctionsToExport = '*.TargetResource'
    Verbose = $true
}

#Create the module manifest

New-ModuleManifest @Params

#Show the files that were created

psEdit -filenames "$env:ProgramFiles\WindowsPowerShell\Modules\cMrSQLRecoveryModelTmp\DSCResources\cMrSQLRecoveryModelTmp\cMrSQLRecoveryModelTmp.psm1",
"$env:ProgramFiles\WindowsPowerShell\Modules\cMrSQLRecoveryModelTmp\DSCResources\cMrSQLRecoveryModelTmp\cMrSQLRecoveryModelTmp.schema.mof",
"$env:ProgramFiles\WindowsPowerShell\Modules\cMrSQLRecoveryModelTmp\cMrSQLRecoveryModelTmp.psd1"

#endregion

#region Completed Resource

psEdit -filenames $env:ProgramFiles\WindowsPowerShell\Modules\cMrSQLRecoveryModel\DSCResources\cMrSQLRecoveryModel\cMrSQLRecoveryModel.psm1

#endregion

#region Cleanup and Reset Demo

$psISE.Options.Zoom = 100

Get-Job | Remove-Job

Invoke-Command -ComputerName SQL01, DC01 {
    Uninstall-WindowsFeature -Name Net-Framework-Core
}

Invoke-Command -ComputerName dc01 {
    Remove-SmbShare -Name DSCSMB -Force -ErrorAction SilentlyContinue
    Remove-Item -Path c:\DSCSMB -Recurse -Force -ErrorAction SilentlyContinue
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
			RefreshMode = 'PUSH'
			ConfigurationID = $guid
			DownloadManagerName = $null
            DownloadManagerCustomData = $null
            	
		}
	}
}

LCM_PUSH -ComputerName DC01, SQL01
Set-DSCLocalConfigurationManager -Path .\LCM_PUSH –Verbose

Get-Command -CommandType Configuration | Foreach {Remove-Item -Path Function:\$_}

Remove-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\cMrSQLRecoveryModelTmp" -Recurse -ErrorAction SilentlyContinue

Remove-Item -Path 'C:\demo\TestEnvironment\*.checksum' -ErrorAction SilentlyContinue

#endregion