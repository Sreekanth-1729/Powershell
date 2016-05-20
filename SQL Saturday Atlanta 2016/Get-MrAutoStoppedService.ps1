#We're going to create a function to retrieve a list of services that are set to automatic, not running, and
#not set to automatic with delayed start.

#Requires -Version 3.0
function Get-MrAutoStoppedService {

<#
.SYNOPSIS
    Returns a list of services that are set to start automatically, are not
    currently running, excluding the services that are set to delayed start.
 
.DESCRIPTION
    Get-MrAutoStoppedService is a function that returns a list of services from
    the specified remote computer(s) that are set to start automatically, are not
    currently running, and it excludes the services that are set to start automatically
    with a delayed startup.
 
.PARAMETER ComputerName
    The remote computer(s) to check the status of the services on.

.PARAMETER Credential
    Specifies a user account that has permission to perform this action. The default
    is the current user.
 
.EXAMPLE
     Get-MrAutoStoppedService -ComputerName 'Server1', 'Server2'

.EXAMPLE
     'Server1', 'Server2' | Get-MrAutoStoppedService

.EXAMPLE
     Get-MrAutoStoppedService -ComputerName 'Server1', 'Server2' -Credential (Get-Credential)
 
.INPUTS
    String
 
.OUTPUTS
    PSCustomObject
 
.NOTES
    Author:  Mike F Robbins
    Website: http://mikefrobbins.com
    Twitter: @mikefrobbins
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ValueFromPipelineByPropertyName)]
        [string[]]$ComputerName,

        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $Opt = New-CimSessionOption -Protocol Dcom

        $SessionParams = @{
            ErrorAction = 'Stop'
            Verbose = $false
        }

        If ($PSBoundParameters['Credential']) {
            $SessionParams.Credential = $Credential
        }
    }

    PROCESS {
        foreach ($Computer in $ComputerName) {
            $SessionParams.ComputerName  = $Computer
            $SessionParams.Remove('SessionOption')

            if ((Test-WSMan -ComputerName $Computer -ErrorAction SilentlyContinue).ProductVersion -match 'Stack: ([3-9]|[1-9][0-9]+)\.[0-9]+') {
                try {
                    Write-Verbose -Message "Attempting to connect to $Computer using the WSMAN protocol."
                    $CimSession = New-CimSession @SessionParams
                    Write-Verbose -Message "Successfully connected to $($CimSession.ComputerName) using the $($CimSession.Protocol) protocol"
                }
                catch {
                    Write-Warning -Message "Unable to connect to $Computer using the WSMAN protocol. Verify your credentials and try again."
                    Continue
                }
            }
 
            else {
                $SessionParams.SessionOption = $Opt

                try {
                    Write-Verbose -Message "Attempting to connect to $Computer using the DCOM protocol."
                    $CimSession = New-CimSession @SessionParams
                    Write-Verbose -Message "Successfully connected to $($CimSession.ComputerName) using the $($CimSession.Protocol) protocol"
                }
                catch {
                    Write-Warning -Message "Unable to connect to $Computer using the WSMAN or DCOM protocol. Verify $Computer is online and try again."
                    Continue
                }

            }
            
            $Services = Get-CimInstance -CimSession $CimSession -ClassName Win32_Service -Filter "State != 'Running' and StartMode = 'Auto'" -Verbose:$false

            foreach ($Service in $Services) {
                if ((Invoke-CimMethod -CimSession $CimSession -Namespace root/DEFAULT -ClassName StdRegProv -MethodName GetDWORDValue -Arguments @{
                    hDefKey=[uint32]2147483650; sSubKeyName="SYSTEM\CurrentControlSet\Services\$($Service.Name)"; sValueName='Start'} -Verbose:$false).uValue -eq 2 -and
                    (Invoke-CimMethod -CimSession $CimSession -Namespace root/DEFAULT -ClassName StdRegProv -MethodName GetDWORDValue -Arguments @{
                    hDefKey=[uint32]2147483650; sSubKeyName="SYSTEM\CurrentControlSet\Services\$($Service.Name)"; sValueName='DelayedAutoStart'} -Verbose:$false).uValue -ne 1) {
                        
                    [pscustomobject]@{
                        ComputerName = $CimSession.ComputerName
                        Status = $Service.State
                        Name = $Service.Name
                        DisplayName = $Service.DisplayName
                    }

                }

            }

            Remove-CimSession -CimSession $CimSession

        }

    }

}

Get-MrAutoStoppedService -ComputerName DC01, PC01, SQL01 | Format-Table -AutoSize