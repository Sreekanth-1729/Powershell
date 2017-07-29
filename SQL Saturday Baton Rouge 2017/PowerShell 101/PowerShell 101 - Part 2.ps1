#region Presentation Prep

#Set PowerShell ISE Zoom to 150%
$psISE.Options.Zoom = 150

<#
Multiline Comment Example
PowerShell 101
Presentation from SQL Saturday #628 Baton Rouge 2017
Author:  Mike F Robbins
Website: http://mikefrobbins.com
Twitter: @mikefrobbins
#>

#-- Begin Remove
#5 VM's are used during this demonstration. 2 running Windows 10,
#3 running Windows Server 2012 R2, one DC, one SQL 2014 Server,
#and one SQL 2008 R2.

#Set location to the demo folder
Set-Location -Path C:\demo
#-- End Remove

#endregion

#region Extending PowerShell with Modules and Snapins

#Move to Win10-1703 VM
#Win10-1703 has the SQLPS module and the RSAT tools installed

#Get a list of modules that are currently imported and available for use
Get-Module

#Get a list of modules that exist in the $env:PSModulePath
Get-Module -ListAvailable

#Beginning with PowerShell v3, modules that exist in the $PSModule path
#are automatically imported when one of its cmdlets is used
$env:PSModulePath -split ';'

#Note the warning message and the current location is changed
Import-Module -Name SQLServer

#Unload the SQLPS module
Set-Location -Path C:\Demo

#What commands exist in the SQLServer module?
Get-Command -Module SQLServer

#We'll talk about Snap-ins when we cover remoting

#endregion

#region Remoting

#Deserialized objects

#One-To-One Remoting
Enter-PSSession -ComputerName SQL08
Set-Location -Path C:\

$env:COMPUTERNAME

#Show the snap-in's that are loaded and available for use
Get-PSSnapin

#Show the snap-in's that are installed that are available to be added to the current PowerShell session
Get-PSSnapin -Registered

#Add the SQL snap-in's to the current PowerShell session
Add-PSSnapin -Name SqlServer*

#Determine what commands exist in the SQL snapin's
Get-Command -Module SQLServer*

#Exit the one-to-one remoting session
Exit-PSSession

#One-To-Many Remoting
Invoke-Command -ComputerName DC01, SQL08, SQL16 {
    $PSVersionTable.PSVersion
}

#endregion

#region Running TSQL code and Stored Procedures from PowerShell

#Using the Invoke-Sqlcmd cmdlet to run your existing TSQL code
#is one of the ways for accessing SQL server with Powershell
Invoke-Sqlcmd -ServerInstance sql16 -Database master -Query '
select name, database_id, compatibility_level, recovery_model_desc from sys.databases'

#Filtering

Invoke-Sqlcmd -ServerInstance SQL16 -Database AdventureWorks2014 -Query '
select * from Person.Person' |
Where-Object LastName -eq 'Browning' |
Select-Object -Property BusinessEntityID, FirstName, MiddleName, LastName

Invoke-Sqlcmd -ServerInstance SQL16 -Database AdventureWorks2014 -Query "
select BusinessEntityID, FirstName, MiddleName, LastName from Person.Person where LastName = 'Browning'"

Measure-Command {
    Invoke-Sqlcmd -ServerInstance SQL16 -Database AdventureWorks2014 -Query '
    select * from Person.Person' |
    Where-Object LastName -eq 'Browning' |
    Select-Object -Property BusinessEntityID, FirstName, MiddleName, LastName
} -OutVariable Opt1

Measure-Command {
    Invoke-Sqlcmd -ServerInstance SQL16 -Database AdventureWorks2014 -Query "
    select BusinessEntityID, FirstName, MiddleName, LastName from Person.Person where LastName = 'Browning'"
} -OutVariable Opt2

$Opt1.Milliseconds / $Opt2.Milliseconds -as [int]

#Run a stored procedure from PowerShell
Invoke-Sqlcmd -ServerInstance sql16 -Database master -Query 'EXEC sp_databases'

#This will generate an error because there are 2 columns with the name SPID
Invoke-Sqlcmd -ServerInstance sql16 -Database master -Query 'EXEC sp_who2'

#endregion

#region Working with SQL Server thorugh the use of SMO (SQL Management Objects)

$SQL = New-Object –TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList 'sql16'

$SQL.EnumProcesses() |
Select-Object -Property Name, Spid, Command, Status, Login, Database, BlockingSpid |
Format-Table –Auto

#endregion

#region Providers

Get-PSProvider
Get-PSDrive
Get-ChildItem -Path SQLServer:\SQL\SQL16\Default\Databases
Get-ChildItem Env:
dir Variable:

#endregion

#region SQL cmdlets

Get-SqlDatabase -ServerInstance SQL16

#endregion

#region .NET Framework

Invoke-MrSqlDataReader -ServerInstance sql16 -Database msdb -Query "
    SELECT backupset.backup_set_id, backupset.last_family_number, backupset.database_name, backupset.recovery_model, backupset.type,
    backupset.position, backupmediafamily.physical_device_name, backupset.backup_start_date, backupset.backup_finish_date
    FROM backupset
    INNER JOIN backupmediafamily
    ON backupset.media_set_id = backupmediafamily.media_set_id
    WHERE database_name = 'pubs'
    ORDER BY backup_start_date"

#endregion

#region Create AD User from SQL Database

Import-Module ActiveDirectory, SQLServer

#Query the AdventureWorks2014 database on SQL16
Invoke-Sqlcmd -ServerInstance sql16 -Database AdventureWorks2014 -Query '
select Employee.LoginID,
       Person.FirstName as givenname,
       Person.LastName as surname,
       Employee.JobTitle as title,
       Address.AddressLine1 as streetaddress,
       Address.City,
       Address.PostalCode,
       PersonPhone.PhoneNumber as officephone
from HumanResources.Employee
    join Person.Person
    on Employee.BusinessEntityID = Person.BusinessEntityID
    join Person.PersonPhone
    on Person.BusinessEntityID = PersonPhone.BusinessEntityID
    join Person.BusinessEntityAddress
    on PersonPhone.BusinessEntityID = BusinessEntityAddress.BusinessEntityID
    join Person.Address
    on BusinessEntityAddress.AddressID = Address.AddressID' | 
Select-Object -Property @{label='Name';expression={"$($_.givenname) $($_.surname)"}},
                        @{label='SamAccountName';expression={$_.loginid.tolower() -replace '^.*\\'}},
                        @{label='UserPrincipalName';expression={"$($_.loginid.tolower() -replace '^.*\\')@mikefrobbins.com"}},
                        @{label='DisplayName';expression={"$($_.givenname) $($_.surname)"}},
                        title,
                        givenname,
                        surname,
                        officephone,
                        streetaddress,
                        postalcode,
                        city |
Format-Table -AutoSize

#Return the number of users in the AdventureWorks OU in Active Directory
(Get-ADUser -Filter * -SearchBase 'OU=AdventureWorks Users,OU=Users,OU=Test,DC=mikefrobbins,DC=com').count

#Create 290 Active Directory users based on infomation in the  SQL AdventureWorks2014 database
Measure-Command {Invoke-Sqlcmd -ServerInstance sql16 -Database AdventureWorks2014 -Query '
select Employee.LoginID,
       Person.FirstName as givenname,
       Person.LastName as surname,
       Employee.JobTitle as title,
       Address.AddressLine1 as streetaddress,
       Address.City,
       Address.PostalCode,
       PersonPhone.PhoneNumber as officephone
from HumanResources.Employee
    join Person.Person
    on Employee.BusinessEntityID = Person.BusinessEntityID
    join Person.PersonPhone
    on Person.BusinessEntityID = PersonPhone.BusinessEntityID
    join Person.BusinessEntityAddress
    on PersonPhone.BusinessEntityID = BusinessEntityAddress.BusinessEntityID
    join Person.Address
    on BusinessEntityAddress.AddressID = Address.AddressID' | 
Select-Object -Property @{label='Name';expression={"$($_.givenname) $($_.surname)"}},
                        @{label='SamAccountName';expression={$_.loginid.tolower() -replace '^.*\\'}},
                        @{label='UserPrincipalName';expression={"$($_.loginid.tolower() -replace '^.*\\')@mikefrobbins.com"}},
                        @{label='DisplayName';expression={"$($_.givenname) $($_.surname)"}},
                        title,
                        givenname,
                        surname,
                        officephone,
                        streetaddress,
                        postalcode,
                        city | 
New-ADUser -Path 'OU=AdventureWorks Users,OU=Users,OU=Test,DC=mikefrobbins,DC=com'}

#Return a list of users in the AdventureWorks OU in Active Directory
(Get-ADUser -Filter * -SearchBase 'OU=AdventureWorks Users,OU=Users,OU=Test,DC=mikefrobbins,DC=com').Count

#endregion