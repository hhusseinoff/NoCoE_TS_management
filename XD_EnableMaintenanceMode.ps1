###################################################################################################################################################
##
##        Script to automatically Set Maintenance mode ON for dedicated machines
##
##        Created by: Hyusein Hyuseinov (SERVER-RSRVPXT)
##
##        Last Update: Feb 5th, 2023 | Fixed a typo in the condition for E2E XDController identification
##
##        Intended to run periodically as a scheduled task on the Scripting servers (AALWSHFRKxxx, AALWSHPARxxx, AALSCRPHXxxx. AALSCREDSxxx,)
##
##        Intended to run when called by the Main TS Manager Script
##
###################################################################################################################################################

##
##------------------Input Parameters---------------------------------------------------------------------------------------------------------------

param(
[string]$ComputerName
)

##-------------------------------------------------------------------------------------------------------------------------------------------------

##
##------------------Function for Verbose Logging---------------------------------------------------------------------------------------------------

function debug($message)
{
    write-host "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message"
    Add-Content -Path "$PSScriptRoot\ServersideLogs\XD_MaintModeOff.log" -Value "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message" 
}

##-------------------------------------------------------------------------------------------------------------------------------------------------


##
##------------------Function for Fails Logging-----------------------------------------------------------------------------------------------------

function debug_FailSkip([string]$DCName,[string]$Type,[string]$Reason,[string]$Controller)
{
    $FileExists = Test-Path -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_MM_on_FailSkip.txt" -PathType Leaf

    if($false -eq $FileExists)
    {
        Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_MM_on_FailSkip.txt" -Value "--Timestamp(UTC)--`tMachine Name`tType`tReason`tController" 
    }

    Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_MM_on_FailSkip.txt" -Value "$($(Get-Date).ToUniversalTime())`t$DCName`t$Type`t$Reason`t$Controller" 
}

##-------------------------------------------------------------------------------------------------------------------------------------------------

##
##------------------Function for Success Logging---------------------------------------------------------------------------------------------------

function debug_Success([string]$DCName,[string]$Controller,[string]$MaintenanceMode)
{
    $FileExists = Test-Path -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_MM_on_Success.txt" -PathType Leaf

    if($false -eq $FileExists)
    {
        Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_MM_on_Success.txt" -Value "--Timestamp(UTC)--`tMachine Name`tController`tMaintenance Mode" 
    }

    Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_MM_on_Success.txt" -Value "$($(Get-Date).ToUniversalTime())`t$DCName`t$Controller`t$MaintenanceMode" 
}

##-------------------------------------------------------------------------------------------------------------------------------------------------

##
##------------------Setting Default XD Controllers and Machine AD Domains (for use with the Get-BrokerMachine XD cmdlet)---------------------------

$XDController_E1 = "XD_DDC1"
$XDController_E2 = "XD_DDC2"
$XDController_E2E = "XD_DDC3"
$XDController_AP1 = "XD_DDC4"
$XDController_AP2 = "XD_DDC5"
$XDController_NA1 = "XD_DDC6"
$XDController_NA2 = "XD_DDC7"

$DomainNameEU = "DomainName1"
$DomainNameAPAC = "DomainName2"
$DomainNameNA = "DomainName3"

##-------------------------------------------------------------------------------------------------------------------------------------------------


##
##------------------Setting Template variables for XD Controller and Domain Name-------------------------------------------------------------------

$XDController = "Blank"
$DomainName = "Blank"

##-------------------------------------------------------------------------------------------------------------------------------------------------


##
##------------------Main Script Body---------------------------------------------------------------------------------------------------------------
##

debug "----------------------------Script initiated-----------------------------"

debug "Working on $ComputerName..."

debug "Proceeding to load the Citrix Broker Snapin..."

Add-PSSnapin Citrix.Broker.Admin.V2

debug "Checking if the Broker snapin has been loaded..."

$SnapinCheck = Get-PSSnapin -Name "Citrix.Broker.Admin.V2"

if($null -eq $SnapinCheck)
{
    debug "Failed to load the Broker Snapin. Exiting script..."

    $FailSkipReason = "Failed to load the Citrix Broker Snapin."

    debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller "Invalid"

    exit 0
}

debug "Citrix Snapin loaded successfully. Determining the servicing XD Controller for $ComputerName..."

switch -Wildcard ($ComputerName)
{
        'X*E1-D*'
        {
            $XDController = $XDController_E1
        }

        "X*E2-D*"
        {
            $MachineNameWithDomain = "DomainName1\$ComputerName"
            
            $XDObj = Get-BrokerMachine -MachineName $MachineNameWithDomain -AdminAddress $XDController_E2

            if($null -eq $XDObj)
            {
                $XDObj = Get-BrokerMachine -MachineName $MachineNameWithDomain -AdminAddress $XDController_E2E

                if($null -eq $XDObj)
                {
                    $XDController = "Error"
                }
                
                $XDController = $XDController_E2E
            }
            else
            {
                $XDController = $XDController_E2
            }
        }

        "X*AP1-D*"
        {
            $XDController = $XDController_AP1
        }

        "X*AP2-D*"
        {
            $XDController = $XDController_AP2
        }

        "X*NA1-D*"
        {
            $XDController = $XDController_NA1
        }

        "X*NA2-D*"
        {
            $XDController = $XDController_NA2
        }

        Default
        {
            $XDController = "Error"
        }
}

if(("Error" -eq $XDController) -or ("Blank" -eq $XDController))
{
    debug "Could not determine the servicing XD Controller for $ComputerName"

    $FailSkipReason = "Could not determine the servicing XD Controller."

    debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller "Invalid"

    exit 0
}

debug "Successfully found XD Controller $XDController servicing $ComputerName."

debug "Proceeding to determine Domain Name for $ComputerName..."

switch -Wildcard ($ComputerName)
    {
        "X*E1-D*"
        {
            $DomainName = $DomainNameEU
        }

        "X*E2-D*"
        {
            $DomainName = $DomainNameEU
        }

        "X*AP1-D*"
        {
            $DomainName = $DomainNameAPAC
        }

        "X*AP2-D*"
        {
            $DomainName = $DomainNameAPAC
        }

        "X*NA1-D*"
        {
            $DomainName = $DomainNameNA
        }

        "X*NA2-D*"
        {
            $DomainName = $DomainNameNA
        }

        Default
        {
            $DomainName = "Error"
        }
    }

if(("Error" -eq $DomainName) -or ("Blank" -eq $DomainName))
{
    debug "Could not determine the Domain name for $ComputerName"

    $FailSkipReason = "Could not determine the Domain name."

    debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController

    exit 0
}

debug "Successfully resolved the domain name of $DomainName for $ComputerName."

debug "Proceeding to retrieve data for $ComputerName on $XDController..."

$XD_Object = Get-BrokerMachine -MachineName "$DomainName\$ComputerName" -AdminAddress $XDController

if($null -eq $XD_Object)
{
    debug "Could not retrieve machine data for $ComputerName"

    $FailSkipReason = "Could not retrieve machine data."

    debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController
}

debug "Successfully retrieved machine data for $ComputerName. Proceeding to set MM ON..."

Set-BrokerPrivateDesktop -MachineName "$DomainName\$ComputerName" -InMaintenanceMode:$true -AdminAddress $XDController

$XD_Object = Get-BrokerMachine -MachineName "$DomainName\$ComputerName" -AdminAddress $XDController

$MM_OnCheck = $XD_Object.InMaintenanceMode

if($false -eq $MM_OnCheck)
{
    debug "Failed to set Maintenance Mode ON for $ComputerName"

    $FailSkipReason = "Failed to set Maintenance Mode ON."

    debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController

    exit 0
}

debug "Successfully set Maintenance Mode ON for $ComputerName."

debug "Appending Data to the success file..."

debug_Success -DCName $ComputerName -Controller $XDController -MaintenanceMode $MM_OnCheck

debug "Script execution finished. Exiting..."

exit 0

