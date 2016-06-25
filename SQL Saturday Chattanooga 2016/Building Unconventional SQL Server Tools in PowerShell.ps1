#region Safety

break

#endregion

#region Presentation Prep

<#
Building Unconventional SQL Server Tools in PowerShell
Presentation from SQL Saturday #498 Chattanooga 2016
Author:  Mike F Robbins
Website: http://mikefrobbins.com
Twitter: @mikefrobbins
#>

#The functions shown in this session are part of my MrSQL module which can be downloaded from GitHub: https://github.com/mikefrobbins/SQL

#6 VM's are used during this demonstration. 1 running Windows 10 (PC01), 1 running Windows 8.1 (PC02),
#3 running Windows Server 2012 R2, one DC (DC01), one SQL 2014 Server (SQL01), and one running SQL 2008 R2 (SQL02),
#1 running Windows Server 2008 and SQL Server 2005(SQL03).

#Warm things up that seem to take a while on my demo VM

Import-Module ActiveDirectory, SQLPS, MrSQL
Get-PSDrive

#Set PowerShell ISE Zoom to 130%

$psISE.Options.Zoom = 130

#Set location to the demo folder

Set-Location -Path C:\Demo

#Change error message color to yellow so errors are easier to read

$host.PrivateData.ErrorForegroundColor = 'Yellow'

#Show PowerShell version used in this demo (PowerShell version 4 and 5)

Invoke-Command -ComputerName PC01, DC01, SQL01, SQL02, SQL03 {
    $PSVersionTable.PSVersion
}

#endregion

#region Intro

#Enter a 1:1 remoting session on SQL02 which is running Windows Server 2012 R2 and SQL Server 2008 R2

Enter-PSSession -ComputerName SQL02

#Import the SQL Server snap-ins

Get-PSSnapin -Name SQLServer* -Registered | Add-PSSnapin

#Show SQL Server 2008 R2 Cmdlets

Get-Command -Module SQLServer*

#Exit the remoting session

Exit-PSSession

#Show that installing the SQL Management Tools modifies the PSModulePath

$env:PSModulePath -split ';'

#Note the warning message and the current location is changed

Import-Module -Name SQLPS

#This is because Encode-SqlName and Decode-SqlName use unapproved verbs (run the previous command with the -Verbose parameter to see the details)
#Did you notice how slow importing the module was? And that it changed the current location to the SQLServer PS drive?
#These issues are fixed in SQL Server Management Studio March 2016 preview refresh: https://msdn.microsoft.com/en-us/library/mt238290.aspx

psEdit -filenames "${env:ProgramFiles(x86)}\Microsoft SQL Server\120\Tools\PowerShell\Modules\SQLPS\SqlPsPostScript.PS1"

#Set the location back to the demo folder

Set-Location -Path C:\Demo

#Show what PowerShell cmdlets exist in SQL Server 2014

Get-Command -Module SQL* -OutVariable SQL2014Cmdlets

$SQL2014Cmdlets.Count

#endregion

#region Running TSQL code and Stored Procedures from PowerShell

#Using existing or writing new TSQL code and calling it with #PowerShell is one
#of the best ways to create tools for working with SQL Server from PowerShell

#This example requires the SQLPS module or SQL Snapin depending on what version of SQL you're using

Invoke-Sqlcmd -ServerInstance SQL01 -Database master -Query '
select name, database_id, compatibility_level, recovery_model_desc from sys.databases'

#Filter at the source with TSQL if at all possible

Invoke-Sqlcmd -ServerInstance SQL01 -Database AdventureWorks2014 -Query '
select * from Person.Person' |
Where-Object LastName -eq Browning |
Select-Object -Property BusinessEntityID, FirstName, MiddleName, LastName

Invoke-Sqlcmd -ServerInstance SQL01 -Database AdventureWorks2014 -Query "
select BusinessEntityID, FirstName, MiddleName, LastName from Person.Person where LastName = 'Browning'"

Measure-Command {
    Invoke-Sqlcmd -ServerInstance SQL01 -Database AdventureWorks2014 -Query '
    select * from Person.Person' |
    Where-Object LastName -eq Browning |
    Select-Object -Property BusinessEntityID, FirstName, MiddleName, LastName
} -OutVariable Opt1

Measure-Command {
    Invoke-Sqlcmd -ServerInstance SQL01 -Database AdventureWorks2014 -Query "
    select BusinessEntityID, FirstName, MiddleName, LastName from Person.Person where LastName = 'Browning'"
} -OutVariable Opt2

$Opt1.Milliseconds / $Opt2.Milliseconds -as [int]

#Running a stored procedure from PowerShell is no different than running TSQL code

Invoke-Sqlcmd -ServerInstance SQL01 -Database master -Query 'EXEC sp_databases'

#The one exception is in TSQL, multiple columns with the same name from different tables can be
#returned which will generate an error in PowerShell because two objects cannot have the same name

#This will generate an error because there are 2 columns with the name SPID

Invoke-Sqlcmd -ServerInstance SQL01 -Database master -Query 'EXEC sp_who2'

#endregion

#region Working with SQL Server through the use of SMO (SQL Management Objects)

#SMO can be used to query SQL server that don't have any version of PowerShell installed
#SMO does require the SQL manageemnt tools to be installed on the machine running the commands

$SQL = New-Object –TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList 'SQL03'

$SQL.EnumProcesses() |
Select-Object -Property Name, Spid, Command, Status, Login, Database, BlockingSpid |
Format-Table –Auto

#Use SMO to query a SQL 2014 server

$SQL = New-Object –TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList 'SQL01'

$SQL.EnumProcesses() |
Select-Object -Property Name, Spid, Command, Status, Login, Database, BlockingSpid |
Format-Table –Auto


#endregion

#region Providers

Get-PSProvider
Get-PSDrive
Get-ChildItem -Path SQLServer:\SQL\SQL01\Default\Databases

#Notice that the previous output using the SQL PS Provider is very similar to the output when using SMO

$SQL.Databases

#Look at the object type returned by that previous command:
($SQL.Databases | Get-Member).TypeName[0]

#It's the same object type as what the SQL PowerShell provider returns

(Get-ChildItem -Path SQLServer:\SQL\SQL01\Default\Databases | Get-Member).TypeName[0]

#Why was the output different between the two?
#Because the SQL Provider is filtering out the system databases until the Force parameter is used

Get-ChildItem -Path SQLServer:\SQL\SQL01\Default\Databases -Force

#endregion

#region SQL cmdlets

Get-SqlDatabase -ServerInstance SQL01

#That cmdlet also returns the same type of object

(Get-SqlDatabase -ServerInstance SQL01 | Get-Member).TypeName[0]

#endregion

#region Create AD User from SQL Database

Import-Module ActiveDirectory, SQLPS -DisableNameChecking

#Query the AdventureWorks2014 database on SQL01

Invoke-Sqlcmd -ServerInstance SQL01 -Database AdventureWorks2014 -Query '
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

#Create 290 Active Directory users based on infomation in the  SQL AdventureWorks2012 database
Measure-Command {Invoke-Sqlcmd -ServerInstance SQL01 -Database AdventureWorks2014 -Query '
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

#region .NET Framework

#Query SQL Server from PowerShell without the SQL module or snapin: http://mikefrobbins.com/2015/07/09/query-sql-server-from-powershell-without-the-sql-module-or-snapin/

#Show my SQL data reader function

psEdit -filenames "$env:ProgramFiles\WindowsPowerShell\Modules\MrSQL\Invoke-MrSqlDataReader.ps1"

#Query SQL01 using the .NET framework

Invoke-MrSqlDataReader -ServerInstance SQL01 -Database msdb -Query "
    SELECT backupset.backup_set_id, backupset.last_family_number, backupset.database_name, backupset.recovery_model, backupset.type,
    backupset.position, backupmediafamily.physical_device_name, backupset.backup_start_date, backupset.backup_finish_date
    FROM backupset
    INNER JOIN backupmediafamily
    ON backupset.media_set_id = backupmediafamily.media_set_id
    WHERE database_name = 'pubs'
    ORDER BY backup_start_date"

#Run the following commands on PC02

Import-Module -Name MrSQL

$psISE.Options.Zoom = 130

Get-Module -Name *sql* -ListAvailable

Invoke-MrSqlDataReader -ServerInstance SQL01 -Database msdb -Query "
    SELECT backupset.backup_set_id, backupset.last_family_number, backupset.database_name, backupset.recovery_model, backupset.type,
    backupset.position, backupmediafamily.physical_device_name, backupset.backup_start_date, backupset.backup_finish_date
    FROM backupset
    INNER JOIN backupmediafamily
    ON backupset.media_set_id = backupmediafamily.media_set_id
    WHERE database_name = 'pubs'
    ORDER BY backup_start_date"

function Get-DatabaseList {
    [CmdletBinding()]
    param (
        [string]$ComputerName
    )
    Invoke-MrSqlDataReader -ServerInstance $ComputerName -Database msdb -Query "
        select name from sys.databases
    "
}

Get-DatabaseList -ComputerName sql03

#Not interested in writing your own code to leverage the .NET Framework?
#Try Invoke-SqlCmd2 which can be found in my SQL repo on GitHub

Invoke-Sqlcmd2 -ServerInstance SQL01 -Database msdb -Query "
    SELECT backupset.backup_set_id, backupset.last_family_number, backupset.database_name, backupset.recovery_model, backupset.type,
    backupset.position, backupmediafamily.physical_device_name, backupset.backup_start_date, backupset.backup_finish_date
    FROM backupset
    INNER JOIN backupmediafamily
    ON backupset.media_set_id = backupmediafamily.media_set_id
    WHERE database_name = 'pubs'
    ORDER BY backup_start_date"

#endregion

#region Search Transaction Logs

#Move back to PC01

#Determine who deleted SQL Server database records by querying the transaction log with PowerShell: http://mikefrobbins.com/2015/07/16/determine-who-deleted-sql-server-database-records-by-querying-the-transaction-log-with-powershell/

#Show my find database change function which can be used to find insert, update, or delete operations in transaction log backups of the active transaction log

psEdit -filenames "$env:ProgramFiles\WindowsPowerShell\Modules\MrSQL\Find-MrSqlDatabaseChange.ps1"

#Find delete operations that occured in the pubs database since March 28th

Find-MrSqlDatabaseChange -ServerInstance SQL01 -Database pubs -StartTime (Get-Date -Date '03/28/2016 14:55 PM')

#We received a report that the follwoing record is missing from the database and no one has owned up to deleting the record

Invoke-Sqlcmd -ServerInstance SQL01 -Database pubs -Query "
select * from employee where emp_id ='VPA30890F'"

#endregion

#region Writing dynamic TSQL Code

#Example of a static function using some code shown previously in the demo

function Get-AdventureWorksPerson {

    Invoke-Sqlcmd -ServerInstance SQL01 -Database AdventureWorks2014 -Query "
    select BusinessEntityID, FirstName, MiddleName, LastName from Person.Person where LastName = 'Browning'"
}

Get-AdventureWorksPerson

#Parameterize the function and use the parameterized value to generate dynamic SQL

function Get-AdventureWorksPerson {
    [CmdletBinding()]
    param (
        [string]$LastName
    )

    Invoke-Sqlcmd -ServerInstance SQL01 -Database AdventureWorks2014 -Query "
    select BusinessEntityID, FirstName, MiddleName, LastName from Person.Person where LastName = '$LastName'"
}

Get-AdventureWorksPerson -LastName Browning
Get-AdventureWorksPerson -LastName Smith

#Show the dynamic TSQL that my find database change function creates

psEdit -filenames $env:ProgramFiles\WindowsPowerShell\Modules\MrSQL\Find-MrSqlDatabaseChange.ps1

#Show the queries and run them in SSMS

Find-MrSqlDatabaseChange -ServerInstance SQL01 -Database pubs -StartTime (Get-Date -Date '03/28/2016 14:55 PM') -Verbose

Find-MrSqlDatabaseChange -ServerInstance SQL01 -Database northwind -StartTime (Get-Date -Date '04/06/2016 09:23 AM') -Verbose

#endregion

#region SQL Backup Chain

#Determine the chain of SQL backups since March 28th

Get-MrSqlDbRestoreInfo -ServerInstance SQL01 -Database pubs -RestoreTime (Get-Date -Date '03/28/2016 14:55 PM')

#endregion

#region Restore Database

#Determine the logical and physical files names for the database backups

Get-MrSqlDbRestoreInfo -ServerInstance SQL01 -Database pubs -RestoreTime (Get-Date -Date '03/28/2016 14:55 PM') | Where-Object type -eq D |
Get-MrSqlDbRestoreFileList -ServerInstance SQL01

#Attempt to perform a restore to an alternate database using the previously determined log sequence number

Get-MrSqlDbRestoreInfo -ServerInstance SQL01 -Database pubs -RestoreTime (Get-Date -Date '03/28/2016 14:55 PM') |
Restore-MrSqlDatabase -ServerInstance SQL01 -Database pubstestrestore -Verbose -StopAtLSN '0000002e:00000158:0001'

#The previous command generates an error message because the LSN is not in the correct format

psEdit -filenames $env:ProgramFiles\WindowsPowerShell\Modules\MrSQL\Convert-MrSqlLogSequenceNumber.ps1

#The log sequence number

Convert-MrSqlLogSequenceNumber -LogSequenceNumber 0000002e:00000158:0001

#Make you tools modular so the output of one command is accepted as input of another

Find-MrSqlDatabaseChange -ServerInstance SQL01 -Database pubs -StartTime (Get-Date -Date '03/28/2016 14:55 PM') |
Convert-MrSqlLogSequenceNumber

#Attempt to perform the restore again using LSN obtained in the previous results

Get-MrSqlDbRestoreInfo -ServerInstance SQL01 -Database pubs -RestoreTime (Get-Date -Date '03/28/2016 14:55 PM') |
Restore-MrSqlDatabase -ServerInstance SQL01 -Database pubstestrestore -Verbose -StopAtLSN '46000000034400001'

#Show the delete operation does not exist in the restored copy of the database

Find-MrSqlDatabaseChange -ServerInstance SQL01 -Database pubstestrestore -StartTime (Get-Date -Date '03/28/2016 14:55 PM')

#The previous results are not valid since that tool reads the transaction log and backups which don't exist for the restored database.

#Query the actual data that was missing to determine if the restore worked

Invoke-Sqlcmd -ServerInstance SQL01 -Database pubstestrestore -Query "
select * from employee where emp_id ='VPA30890F'"

#endregion

#region Cleanup and Reset Demo

Get-ADUser -Filter * -SearchBase 'OU=AdventureWorks Users,OU=Users,OU=Test,DC=mikefrobbins,DC=com' | Remove-ADUser -Confirm:$false
Invoke-Sqlcmd2 -ServerInstance SQL01 -Database master -Query 'Drop Database pubsrestoretest' -ErrorAction SilentlyContinue

$host.PrivateData.ErrorForegroundColor = '#FFFF0000'

#endregion