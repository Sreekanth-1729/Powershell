#region Presentation Prep

<#
Automate Operational Readiness and Validation Testing of SQL Server with PowerShell and Pester
Presentation from the PowerShell Virtual Chapter of SQL Pass - November 16th, 2016
Author:  Mike F Robbins
Website: http://mikefrobbins.com
Twitter: @mikefrobbins
#>

#Safety in case the entire script is run instead of a selection

Start-Sleep -Seconds 1800

#Set PowerShell ISE Zoom to 175%

$psISE.Options.Zoom = 175
$Path = 'C:\Demo'

#endregion

#region Pester

#Pester is a unit testing framework for PowerShell
#It's an opensource PowerShell module that ships with Windows 10.
#It can be installed or updated via the PowerShell Gallery 

#Install or update Pester to the most recent version available in the PowerShell Gallery
Install-Module -Name Pester -Force

#Show the different versions of Pester installed on my machine
Get-Module -Name Pester -ListAvailable

#Show the commands in the Pester PowerShell module
Get-Command -Module Pester

#Using Pester for Test Driven Development in PowerShell
Start-Process http://mikefrobbins.com/2014/10/09/using-pester-for-test-driven-development-in-powershell/

#Create folder to store Pester tests
New-Item -Path "$Path\Pester" -ItemType Directory -Force

#Create Pester test and function
New-Fixture -Name Get-NumberParity -Path "$Path\Pester\NumberParity"

#Show the files that were created
Get-ChildItem -Path "$Path\Pester\NumberParity"

#Change the location to the newly created folder
Set-Location -Path "$Path\Pester\NumberParity"

#Open the Pester test and function
psedit -filenames (Get-ChildItem -Path "$Path\Pester\NumberParity")

#Run the Pester test
Invoke-Pester

#Run Invoke-MrTDDWorkflow from the PowerShell Console

#Invoke-MrTDDWorkflow can be downloaded from my PowerShell repository on GitHub
Start-Process https://github.com/mikefrobbins/PowerShell

#Why isn’t Test Driven Development more widely adopted and accepted by the PowerShell community?
Start-Process http://mikefrobbins.com/2016/05/12/why-isnt-test-driven-development-more-widely-adopted-and-accepted-by-the-powershell-community/

#Write a single failing test
Set-Content -Path "$Path\Pester\NumberParity\Get-NumberParity.Tests.ps1" -Value @'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Get-NumberParity" {
    It "Should determine 1 is Odd" {
        Get-NumberParity -Number 1 | Should Be Odd
    }
}
'@

#Run the Pester test
Invoke-Pester

#Write code until unit test: 'Should determine 1 is Odd' passes
Set-Content -PassThru "$Path\Pester\NumberParity\Get-NumberParity.ps1" -Value @'
function Get-NumberParity {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [int]$Number
    )
    switch ($Number % 2) {
        1 {[string]'Odd'; break}
    }
}
'@

#Run the Pester test
Invoke-Pester

#Write another failing test and add it to the existing one. This way you'll know newly added code to make the new test pass doesn't break existing code 
Set-Content -Path "$Path\Pester\NumberParity\Get-NumberParity.Tests.ps1" -Value @'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Get-NumberParity" {
    It "Should determine 1 is Odd" {
        Get-NumberParity -Number 1 | Should Be Odd
    }
    It "Should determine 2 is Even" {
        Get-NumberParity -Number 2 | Should Be Even
    }
}
'@

#Run the Pester test
Invoke-Pester -PassThru

#Write code until unit test: 'Should determine 2 is Even' passes
Set-Content -PassThru "$Path\Pester\NumberParity\Get-NumberParity.ps1" -Value @'
function Get-NumberParity {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [int]$Number
    )
    switch ($Number % 2) {
        0 {[string]'Even'; break}
        1 {[string]'Odd'; break}
    }
}
'@

#Run the Pester test
Invoke-Pester -Quiet -PassThru

#Write another failing test. Add it to the existing tests.
Set-Content -Path "$Path\Pester\NumberParity\Get-NumberParity.Tests.ps1" -Value @'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Get-NumberParity" {
    It "Should determine 1 is Odd" {
        Get-NumberParity -Number 1 | Should Be Odd
    }
    It "Should determine 2 is Even" {
        Get-NumberParity -Number 2 | Should Be Even
    }
    It "Should determine -1 is Odd" {
        Get-NumberParity -Number -1 | Should Be Odd
    }
}
'@

#Run the Pester test
Invoke-Pester

#Write code until unit test: 'Should determine -1 is Odd' passes
Set-Content -Path "$Path\Pester\NumberParity\Get-NumberParity.ps1" -Value @'
function Get-NumberParity {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [int]$Number
    )
    switch ($Number / 2) {
        {$_ -is [int]} {[string]'Even'; break}
        {$_ -isnot [int]} {[string]'Odd'; break}
    }
}
'@

#Run the Pester test
Invoke-Pester -Quiet -PassThru | Select-Object -Property TotalCount, PassedCount, FailedCount, SkippedCount

#Write a test that makes sure the function can accept more than one integer. Add it to the existing test.
Set-Content -Path "$Path\Pester\NumberParity\Get-NumberParity.Tests.ps1" -Value @'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Get-NumberParity" {
    It "Should determine 1 is Odd" {
        Get-NumberParity -Number 1 | Should Be Odd
    }
    It "Should determine 2 is Even" {
        Get-NumberParity -Number 2 | Should Be Even
    }
    It "Should determine -1 is Odd" {
        Get-NumberParity -Number -1 | Should Be Odd
    }
    It "Should accept more than one number via parameter input" {
        (Get-NumberParity -Number 1,2,3).Length | Should Be 3
    }
}
'@

#Run the Pester test
Invoke-Pester

#Write code until unit test: 'Should accept more than one number via parameter input' passes
Set-Content -Path "$Path\Pester\NumberParity\Get-NumberParity.ps1" -Value @'
function Get-NumberParity {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [int[]]$Number
    )
    foreach ($n in $Number) {
        switch ($n / 2) {
            {$_ -is [int]} {[string]'Even'; break}
            {$_ -isnot [int]} {[string]'Odd'; break}
        }
    }
}
'@

#Run the Pester test
Invoke-Pester

#Write a test for pipeline input of integers. Add it to the existing tests.
Set-Content -Path "$Path\Pester\NumberParity\Get-NumberParity.Tests.ps1" -Value @'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Get-NumberParity with Positive Numbers" {
    It "Should determine 1 is Odd" {
        Get-NumberParity -Number 1 | Should Be Odd
    }
    It "Should determine 2 is Even" {
        Get-NumberParity -Number 2 | Should Be Even
    }
    It "Should determine -1 is Odd" {
        Get-NumberParity -Number -1 | Should Be Odd
    }
    It "Should accept more than one number via parameter input" {
        (Get-NumberParity -Number 1,2,3).Length | Should Be 3
    }
    It "Should accept more than one number via pipeline input" {
        (1..5 | Get-NumberParity).Length | Should Be 5
    }
}
'@

#Run the Pester test
Invoke-Pester

#Run PowerShell non-interactive to test pipeline input. Notice the colorized output doesn't display because it writes to the screen
powershell.exe -NoProfile -NonInteractive -Command "Invoke-Pester C:\Demo\Pester\NumberParity"

#Write code until unit test: 'Should accept more than one number via pipeline input' passes
Set-Content -PassThru "$Path\Pester\NumberParity\Get-NumberParity.ps1" -Value @'
function Get-NumberParity {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [int[]]$Number
    )
    PROCESS {
        foreach ($n in $Number) {
            switch ($n % 2) {
                0 {[string]'Even'; break}
                1 {[string]'Odd'; break}
            }
        }
    }
}
'@

#Run the Pester test
Invoke-Pester

#Break tests up into different describe blocks to show they can be run separately.
Set-Content -Path "$Path\Pester\NumberParity\Get-NumberParity.Tests.ps1" -Value @'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Get-NumberParity with Positive Numbers" {
    It "Should determine 1 is Odd" {
        Get-NumberParity -Number 1 | Should Be Odd
    }
    It "Should determine 2 is Even" {
        Get-NumberParity -Number 2 | Should Be Even
    }
}

Describe "Get-NumberParity with Negative Numbers" {
    It "Should determine -1 is Odd" {
        Get-NumberParity -Number -1 | Should Be Odd
    }
}

Describe "Get-NumberParity with Multiple Numbers" {
    It "Should accept more than one number via parameter input" {
        (Get-NumberParity -Number 1,2,3).Length | Should Be 3
    }
    It "Should accept more than one number via pipeline input" {
        (1..5 | Get-NumberParity).Length | Should Be 5
    }
}
'@

#Run the Pester test
Invoke-Pester

#Run a specific describe block in the Pester test
Invoke-Pester -TestName 'Get-NumberParity with Negative Numbers'

Clear-Host

#Run multiple describe blocks in the Pester test
Invoke-Pester -TestName 'Get-NumberParity with Positive Numbers', 'Get-NumberParity with Multiple Numbers'

#Determine what broke the negative numbers test and refactor the code to resolve the problem
Set-Content -Path "$Path\Pester\NumberParity\Get-NumberParity.ps1" -Value @'
function Get-NumberParity {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [int[]]$Number
    )
    PROCESS {
        foreach ($n in $Number) {
            switch ($n / 2) {
                {$_ -is [int]} {[string]'Even'; break}
                {$_ -isnot [int]} {[string]'Odd'; break}
            }
        }
    }
}
'@

#Run the Pester test
Invoke-Pester

#Refactor the code as desired. Rerun the test to make sure nothing is broken due to the refactoring
Set-Content -Path "$Path\Pester\NumberParity\Get-NumberParity.ps1" -Value @'
function Get-NumberParity {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [int[]]$Number
    )
    PROCESS {
        foreach ($n in $Number) {
            switch ($n -band 1) {
                0 {[string]'Even'; break}
                1 {[string]'Odd'; break}
            }
        }
    }
}
'@

#Run the Pester test
Invoke-Pester

#To learn more about Pester, see the Wiki
Start-Process https://github.com/pester/Pester/wiki

#endregion

#region Using Pester and the Operation Validation Framework to Verify a System is Working
Start-Process http://mikefrobbins.com/2015/11/12/powershell-using-pester-tests-and-the-operation-validation-framework-to-verify-a-system-is-operational/

#Create Pester test file to be used for operational validation of a SQL Server
New-Item -Path "$Path\Test\sqlserver.tests.ps1" -ItemType File -Force

#Change to the previously created directory
Set-Location -Path "$Path\Test"

#Write the code for the test itself
Set-Content -Path "$Path\Test\sqlserver.tests.ps1" -Value @'
Describe "Simple Validation of a SQL Server" {
    $ServerName = 'SQL011'
    $Session = New-PSSession -ComputerName $ServerName
    It "The SQL Server service should be running" {
        (Invoke-Command -Session $Session {Get-Service -Name MSSQLSERVER}).status |
        Should be 'Running'
    }
    It "The SQL Server agent service should be running" {
        (Invoke-Command -Session $Session {Get-Service -Name SQLSERVERAGENT}).status  |
        Should be 'Running'
    }
    It "Should be listening on port 1433" {
        Test-NetConnection -ComputerName $ServerName -Port 1433 -InformationLevel Quiet |
        Should be $true
    }
    It "Should be able to query information from the SQL Server" {
        (Invoke-MrSqlDataReader -ServerInstance $ServerName -Database Master -Query "select name from sys.databases where name = 'master'").name |
        Should be 'master'
    }
    Remove-PSSession -Session $Session
}
'@

#Open the test file
psedit -filenames "$Path\Test\sqlserver.tests.ps1"

#Run the Pester test
Invoke-Pester

#Stop the SQL Server service
Invoke-Command -ComputerName SQL011 {Stop-Service -Name SQLServerAgent -Force}

#Run the Pester test
Invoke-Pester

#Stop the SQL Server service
Invoke-Command -ComputerName SQL011 {Start-Service -Name SQLServerAgent}

#Run the Pester test
Invoke-Pester

#Use the operational validation framework to run the pester test
Invoke-OperationValidation -testFilePath "$Path\Test\sqlserver.tests.ps1" -IncludePesterOutput

#Create a function for performing operational validation of SQL Server
New-Item -Path "$Path\Test\Validate-SQLServer.ps1" -Force

#Write the code for the function
Set-Content -PassThru "$Path\Test\Validate-SQLServer.ps1" -Value @'
#Requires -Version 3.0 -Modules Pester, MrToolkit
function Test-MrSQLServer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [string[]]$ComputerName,

        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    PROCESS {
        foreach ($Computer in $ComputerName) {

            Describe "Validation of a SQL Server: $Computer" {

                $Params = @()
                if ($PSBoundParameters.Credential) {
                    $Params.Credential = $Credential
                }
    
                try {
                    $Session = New-PSSession -ComputerName $Computer @Params -ErrorAction Stop
                }
                catch {
                    Write-Warning -Message "Unable to connect. Aborting Pester tests for computer: '$Computer'."
                    Continue
                }                

                It 'The SQL Server service should be running' {
                    (Invoke-Command -Session $Session {Get-Service -Name MSSQLSERVER}).status |
                    Should be 'Running'
                }

                It 'The SQL Server agent service should be running' {
                    (Invoke-Command -Session $Session {Get-Service -Name SQLSERVERAGENT}).status  |
                    Should be 'Running'
                }

                It 'The SQL Server service should be listening on port 1433' {
                    (Test-Port -Computer $Computer -Port 1433).Open |
                    Should be 'True'
                }

                It 'Should be able to query information from the SQL Server' {(
                    Invoke-Command -Session $Session {
                        if (Get-PSSnapin -Name SqlServerCmdletSnapin* -Registered -ErrorAction SilentlyContinue) {
                            Add-PSSnapin -Name SqlServerCmdletSnapin*
                        }
                        elseif (Get-Module -Name SQLPS -ListAvailable){
                            Import-Module -Name SQLPS -DisableNameChecking -Function Invoke-Sqlcmd
                        }
                        else {
                            Throw 'SQL PowerShell Snapin or Module not found'
                        }
                        Invoke-SqlCmd -Database Master -Query "select name from sys.databases where name = 'master'"
                    }
                ).name |
                    Should be 'master'
                }

                Remove-PSSession -Session $Session

            }

        }
    }

}
'@

#Open the function
psEdit -filenames "$Path\Test\Validate-SQLServer.ps1"

#Dot-source the PS1 file to load the function into memory
. "$Path\Test\Validate-SQLServer.ps1"

#Run the test against 2 different SQL servers
Test-MrSQLServer -ComputerName SQL011, SQL02

#Loop through a collection of items with the Pester TestCases parameter instead of using a foreach loop
Describe "Simple Validation of a SQL Server" {
    $Servers = @{Server = 'sql011'}, @{Server = 'sql02'}
    It "The SQL Server Service on <Server> Should Be Running" -TestCases $Servers {
        param($Server)
        Get-Service -ComputerName $Server -Name MSSQLServer | Select-Object -ExpandProperty status | Should Be 'Running'
    }
}

#endregion

#region Bonus Content

#Using Pester to Test PowerShell Code with Other Cultures
Start-Process http://mikefrobbins.com/2015/10/22/using-pester-to-test-powershell-code-with-other-cultures/

function Test-ToUpper {
    [CmdletBinding()]
    param (
        [string]$Text
    )
    $Text.ToUpper()
}

Describe 'Test-ToUpper' {
    It 'Converts to Upper Case' {
        Test-ToUpper -Text 'SQLEngine' | Should BeExactly 'SQLENGINE'
    }
    It 'Converts to Upper Case using Turkish Culture' {
        Use-Culture -Culture tr-TR -ScriptBlock {
            Test-ToUpper -Text 'SQLEngine'
        } | Should BeExactly 'SQLENGINE'
    }
}

#Write Dynamic Unit Tests for your PowerShell Code with Pester
Start-Process http://mikefrobbins.com/2016/04/14/write-dynamic-unit-tests-for-your-powershell-code-with-pester/

#Be Mindful of Object Types when Writing Unit Tests and Performing Operational Validation in PowerShell with Pester
Start-Process http://mikefrobbins.com/2016/04/28/be-mindful-of-object-types-when-writing-unit-tests-and-performing-operational-validation-in-powershell-with-pester/

$true -eq 'false'

#Use PowerShell and Pester for Operational Readiness Testing of Altaro VM Backup
Start-Process http://mikefrobbins.com/2016/09/01/use-powershell-and-pester-for-operational-readiness-testing-of-altaro-vm-backup/

#Requires -Version 3.0 -Modules Pester
function Test-MrVMBackupRequirement {

<#
.SYNOPSIS
    Tests the requirements for live backups of a Hyper-V Guest VM for use with Altaro VM Backup.
 
.DESCRIPTION
    Test the requirements for live backups of a Hyper-V Guest VM as defined in this Altaro support article:
    http://support.altaro.com/customer/portal/articles/808575-what-are-the-requirements-for-live-backups-of-a-hyper-v-guest-vm-.
 
.PARAMETER ComputerName
    Name of the Hyper-V host virtualization server that the specified VM's are running on.

.PARAMETER VMHost
    Name of the VM (Guest) server to test the requirements for.

.PARAMETER Credential
    Specifies a user account that has permission to perform this action. The default is the current user.
 
.EXAMPLE
     Test-MrVMBackupRequirement -ComputerName HyperVServer01 -VMName VM01, VCM02 -Credential (Get-Credential)

.INPUTS
    String
 
.OUTPUTS
    None
 
.NOTES
    Author:  Mike F Robbins
    Website: http://mikefrobbins.com
    Twitter: @mikefrobbins
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Alias('VMHost')]
        [string]$ComputerName,

        [Parameter(ValueFromPipeline)]
        [string[]]$VMName,

        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        try {
            $HostSession = New-PSSession -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop
        }
        catch {
            Throw "Unable to connect to Hyper-V host '$ComputerName'. Aborting Pester tests."
        }

        $VMs = (Invoke-Command -Session $HostSession {
            Get-VM | Select-Object -Property Name
        }).Name
        
        if (-not($PSBoundParameters.VMName)) {
            $VMName = $VMs
        }

    }
    
    PROCESS {
        foreach ($VM in $VMName) {
            Describe "Validation of Altaro VM Backup Requirements for Live Backups of Hyper-V Guest VM: '$VM'" {

                if ($VM -notin $VMs) {
                    Write-Warning -Message "The VM: '$VM' does not exist on the Hyper-V host: '$ComputerName'"
                    Continue
                }

                try {
                    $GuestSession = New-PSSession -ComputerName $VM -Credential $Credential -ErrorAction Stop
                }
                catch {
                    Write-Warning -Message "Unable to connect. Aborting Pester tests for computer: '$VM'."
                    Continue
                }
        
                $SupportedGuestOS = '2008 R2', 'Server 2012', 'Server 2012 R2'

                It "Should be running one of the supported guest OS's ($($SupportedGuestOS -join ', '))" {
                    $OS = (Invoke-Command -Session $GuestSession {
                        Get-WmiObject -Class Win32_OperatingSystem -Property Caption
                    }).caption

                    ($SupportedGuestOS | ForEach-Object {$OS -like "*$_*"}) -contains $true |
                    Should Be $true
                }
                
                $VMInfo = Invoke-Command -Session $HostSession {
                    Get-VM -Name $Using:VM | Select-Object -Property IntegrationServicesState, State
                }

                It 'Should have the latest Integration Services version installed' {
                    $VMInfo.IntegrationServicesState -eq 'Up to date' |
                    Should Be $true
                }

                It 'Should have Backup (volume snapshot) enabled in the Hyper-V settings' {
                    (Invoke-Command -Session $HostSession {
                        Get-VM -Name $Using:VM | Get-VMIntegrationService -Name VSS | Select-Object -Property Enabled
                    }).enabled |
                    Should Be $true
                }

                It 'Should be running' {
                    $VMInfo.State.Value |
                    Should Be 'Running'
                }

                $GuestDiskInfo = Invoke-Command -Session $GuestSession {
                    Get-WMIObject -Class Win32_Volume -Filter 'DriveType = 3' -Property Capacity, FileSystem, FreeSpace, Label
                }

                It 'Should have at least 10% free disk space on all disks' {
                    $GuestDiskInfo | ForEach-Object {$_.FreeSpace / $_.Capacity * 100} |
                    Should BeGreaterThan 10
                }
        
                $GuestServiceInfo = Invoke-Command -Session $GuestSession {
                    Get-Service -DisplayName 'Hyper-V Volume Shadow Copy Requestor', 'Volume Shadow Copy', 'COM+ Event System',
                                             'Distributed Transaction Coordinator', 'Remote Procedure Call (RPC)', 'System Event Notification Service'
                }

                It 'Should be running the "Hyper-V Volume Shadow Copy Requestor" service on the guest' {
                    ($GuestServiceInfo |
                     Where-Object DisplayName -eq 'Hyper-V Volume Shadow Copy Requestor'
                    ).status |
                    Should Be 'Running'
                }
        
                It 'Should have snapshot file location for VM set to same location as VM VHD file' {
                    #Hyper-V on Windows Server 2008 R2 and higher: The .AVHD file is always created in the same location as its parent virtual hard disk.
                    $HostOS = (Invoke-Command -Session $HostSession {
                        Get-WmiObject -Class Win32_OperatingSystem -Property Version
                    }).version
            
                    [Version]$HostOS -gt [Version]'6.1.7600' |
                    Should Be $true
                }

                It 'Should be running VSS in the guest OS' {
                    ($GuestServiceInfo |
                     Where-Object Name -eq VSS
                    ).status |
                    Should Be 'Running'
                }
        
                It 'Should have a SCSI controller attached in the VM settings' {
                    Invoke-Command -Session $HostSession {
                        Get-VM -Name $Using:VM | Get-VMScsiController
                    } |
                    Should Be $true
                }
        
                It 'Should not have an explicit shadow storage assignment of a volume other than itself' {
                    Invoke-Command -Session $GuestSession {
                        $Results = vssadmin.exe list shadowstorage | Select-String -SimpleMatch 'For Volume', 'Shadow Copy Storage volume'
                        if ($Results) {
                            for ($i = 0; $i -lt $Results.Count; $i+=2){
                                ($Results[$i] -split 'volume:')[1].trim() -eq ($Results[$i+1] -split 'volume:')[1].trim() 
                            }                                                   
                        }
                        else {
                            $true
                        }                 
                    } |
                    Should Be $true                    
                }

                It 'Should not have any App-V drives installed on the VM' {
                    #App-V drives installed on the VM creates a non-NTFS volume.
                    $GuestDiskInfo.filesystem |
                    Should Be 'NTFS'
                }

                It 'Should have at least 45MB of free space on system reserved partition if one exists in the guest OS' {
                    ($GuestDiskInfo |
                    Where-Object Label -eq 'System Reserved').freespace / 1MB |
                    Should BeGreaterThan 45 
                }
        
                It 'Should have all volumes formated with NTFS in the guest OS' {
                    $GuestDiskInfo.filesystem |
                    Should Be 'NTFS'
                }        

                It 'Should have volume containing VHD files formated with NTFS' {
                    $HostDiskLetter = (Invoke-Command -Session $HostSession {
                        Get-VM -Name $Using:VM | Get-VMHardDiskDrive
                    }).path -replace '\\.*$'

                    $HostDiskInfo = Invoke-Command -Session $HostSession {
                        Get-WMIObject -Class Win32_Volume -Filter 'DriveType = 3' -Property DriveLetter, FileSystem            
                    }

                    ($HostDiskLetter | ForEach-Object {$HostDiskInfo | Where-Object DriveLetter -eq $_}).filesystem |
                    Should Be 'NTFS'
                }

                It 'Should only contain basic and not dynamic disks in the guest OS' {
                    Invoke-Command -Session $GuestSession {
                        $DynamicDisk = 'Logical Disk Manager', 'GPT: Logical Disk Manager Data' 
                        Get-WmiObject -Class Win32_DiskPartition -Property Type |
                        ForEach-Object {$DynamicDisk -contains $_.Type}
                    } |
                    Should Be $false
                }

                It 'Should be running specific services within the VM' {
                    $RunningServices = 'COM+ Event System', 'Distributed Transaction Coordinator', 'Remote Procedure Call (RPC)', 'System Event Notification Service'
                    ($GuestServiceInfo | Where-Object DisplayName -in $RunningServices).status |
                    Should Be 'Running'
                }

                It 'Should have specific services set to manual or automatic within the VM' {
                    $StartMode = (Invoke-Command -Session $GuestSession {
                            Get-WmiObject -Class Win32_Service -Filter "DisplayName = 'COM+ System Application' or DisplayName = 'Microsoft Software Shadow Copy Provider' or DisplayName = 'Volume Shadow Copy'"
                    }).StartMode
                    
                    $StartMode | ForEach-Object {$_ -eq 'Manual' -or $_ -eq 'Automatic'} |
                    Should Be $true
                    
                }

                Remove-PSSession -Session $GuestSession
    
            }
        
        }
            
    }

    END {
        Remove-PSSession -Session $HostSession
    }

}

#Separating Environmental Code from Structural Code in PowerShell Operational Validation Tests
Start-Process http://mikefrobbins.com/2016/09/08/separating-environmental-code-from-structural-code-in-powershell-operational-validation-tests/

#Store and Retrieve PowerShell Hash Tables in a SQL Server Database with Write-SqlTableData and Read-SqlTableData
Start-Process http://mikefrobbins.com/2016/09/22/store-and-retrieve-powershell-hash-tables-in-a-sql-server-database-with-write-sqltabledata-and-read-sqltabledata/

#endregion

#region Cleanup

$psISE.Options.Zoom = 100
Set-Location -Path C:\
$Path = 'C:\Demo'
Remove-Item -Path "$Path\Test" -Recurse -Confirm:$false -ErrorAction SilentlyContinue

#endregion