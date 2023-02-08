###################################################################################################################################################
##
##        Script to automatically remove machines from the default NewBuild collections (hardcoded)
##
##        Created by: Hyusein Hyuseinov (SERVER-RSRVPXT)
##
##        Last Update: Feb 3rd, 2023
##
##        Added mandatory new PSDrive Creation to combat the bug where service accounts P36 (APAC P45) can't change working dir to $SCCMDir | Special Permission from SCCM Also granted for them, Read + basic Required
##
##        Intended to run periodically as a scheduled task on the Scripting servers (AALWSHFRKxxx, AALWSHPARxxx, AALSCRPHXxxx. AALSCREDSxxx,)
##
##        Intended to run when called by the Main TS Manager Script
##
###################################################################################################################################################

##
##------------------Input Parameters---------------------------------------------------------------------------------------------------------------

param(
[string]$MachineName,
[string]$IsSAC
)

##-------------------------------------------------------------------------------------------------------------------------------------------------

##
##------------------Function for Verbose Logging---------------------------------------------------------------------------------------------------

function debug($message)
{
    write-host "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message"
    Add-Content -Path "$BeginningScriptRoot\ServersideLogs\SCCM_CollectionRemover.log" -Value "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message" 
}

##-------------------------------------------------------------------------------------------------------------------------------------------------

##
##------------------Function for Fails Logging-----------------------------------------------------------------------------------------------------

function debug_FailSkip([string]$DCName,[string]$Type,[string]$Reason)
{
    $FileExists = Test-Path -Path "$BeginningScriptRoot\ServersideLogs\ShortLogs\SCCM_CollectionRemover_FailSkip.txt" -PathType Leaf

    if($false -eq $FileExists)
    {
        Add-Content -Path "$BeginningScriptRoot\ServersideLogs\ShortLogs\SCCM_CollectionRemover_FailSkip.txt" -Value "--Timestamp(UTC)--`tMachineName`tType`tReason" 
    }

    Add-Content -Path "$BeginningScriptRoot\ServersideLogs\ShortLogs\SCCM_CollectionRemover_FailSkip.txt" -Value "$($(Get-Date).ToUniversalTime())`t$DCName`t$Type`t$Reason" 
}

##-------------------------------------------------------------------------------------------------------------------------------------------------

##
##------------------Function for Success Logging---------------------------------------------------------------------------------------------------

function debug_Success([string]$DCName,[string]$SAC,[string]$CollectionName)
{
    $FileExists = Test-Path -Path "$BeginningScriptRoot\ServersideLogs\ShortLogs\SCCM_CollectionRemover_Success.txt" -PathType Leaf

    if($false -eq $FileExists)
    {
        Add-Content -Path "$BeginningScriptRoot\ServersideLogs\ShortLogs\SCCM_CollectionRemover_Success.txt" -Value "--Timestamp(UTC)--`tMachineName`tSAC`tRemoved from collection" 
    }

    Add-Content -Path "$BeginningScriptRoot\ServersideLogs\ShortLogs\SCCM_CollectionRemover_Success.txt" -Value "$($(Get-Date).ToUniversalTime())`t$DCName`t$SAC`t$CollectionName" 
}

##-------------------------------------------------------------------------------------------------------------------------------------------------

##------------------Setting Default SCCM Drive Letters (for use with the SCCM Powershell cmdlets)--------------------------------------------------

$SCCMDir_E1 = "CA1:\"
$SCCMDir_E2 = "CA1:\"
$SCCMDir_AP1 = "CA1:\"
$SCCMDir_AP2 = "CA1:\"
$SCCMDir_NA1 = "NA1:\"
$SCCMDir_NA2 = "NA2:\"

##-------------------------------------------------------------------------------------------------------------------------------------------------


##
##------------------Set constants for the default Newbuild Collections-----------------------------------------------------------------------------

$DefaultNewBuildCollection_AP1 = "(GLOBAL) AVC New DC BUILD 001/002-STD-AP1"
$DefaultNewBuildCollection_AP2 = "(GLOBAL) AVC New DC BUILD 001/002-STD-AP2"
$DefaultNewBuildCollection_NA1 = "(GLOBAL) AVC New DC BUILD 001/002-STD-NA1"
$DefaultNewBuildCollection_NA2 = "(GLOBAL) AVC New DC BUILD 001/002-STD-NA2"
$DefaultNewBuildCollection_E1 = "(GLOBAL) AVC New DC BUILD 011/012-STD-E1"
$DefaultNewBuildCollection_E2 = "(GLOBAL) AVC New DC BUILD 007/008-STD-E2"

##-------------------------------------------------------------------------------------------------------------------------------------------------

##
##------------------Set constants for the default Newbuild SAC Collections-------------------------------------------------------------------------

$Default_SAC_NewBuildCollection_APAC = "(GLOBAL) AVC3 INT Dedicated Clients NA APAC Builds"
$Default_SAC_NewBuildCollection_EU = "(GLOBAL) AVC3 INT Dedicated Clients EU SAC Builds"
$Default_SAC_NewBuildCollection_NA = "(GLOBAL) AVC3 INT Dedicated Clients NA SAC Builds"

##-------------------------------------------------------------------------------------------------------------------------------------------------


##
##------------------Capture the beginning script root, since SCCM Powershell cmdlets require to be executed from a different working dir-----------

$BeginningScriptRoot = $PSScriptRoot

##-------------------------------------------------------------------------------------------------------------------------------------------------

##------------------Set template variables for storing the SCCM Drive and NewBuild collection name-------------------------------------------------

$SCCMDir = "Blank"
$BuildCollection = "Blank"

##-------------------------------------------------------------------------------------------------------------------------------------------------


##
##------------------Main Script Body---------------------------------------------------------------------------------------------------------------
##

debug "------------------Script initiated. Working on: $MachineName-------------------------------"

debug "Proceeding to Load the SCCM PowerShell Module..."

Import-Module ConfigurationManager

debug "Verifying if the SCCM Powershell Module has been loaded..."

$ModuleCheck = Get-Module -Name ConfigurationManager

if($null -eq $ModuleCheck)
{
    debug "SCCM Powershell Module FAILED to be imported."

    $FailSkipReason = "SCCM Powershell Module FAILED to be imported."

    debug_FailSkip -DCName $MachineName -Type "FAIL" -Reason $FailSkipReason

    debug "Script execution finished. Exiting..."

    exit 0
}

debug "SCCM Powershell Module loaded. Proceeding to determine directory..."

switch -Wildcard ($MachineName)
    {
        "X*E1-D*"
        {
            $SCCMDir = $SCCMDir_E1
        }

        "X*E2-D*"
        {
            $SCCMDir = $SCCMDir_E2
        }

        "X*AP1-D*"
        {
            $SCCMDir = $SCCMDir_AP1
        }

        "X*AP2-D*"
        {
            $SCCMDir = $SCCMDir_AP2
        }

        "X*NA1-D*"
        {
            $SCCMDir = $SCCMDir_NA1
        }

        "X*NA2-D*"
        {
            $SCCMDir = $SCCMDir_NA2
        }

        Default
        {
            $SCCMDir = "Error"
        }
    }

if(("Error" -eq $SCCMDir) -or ("Blank" -eq $SCCMDir))
{
    debug "Could not determine the appropriate SCCM Drive Letter for $MachineName"

    $FailSkipReason = "Could not determine the appropriate SCCM Drive Letter."

    debug_FailSkip -DCName $MachineName -Type "FAIL" -Reason $FailSkipReason

    exit 0
}

debug "SCCM Drive Letter for $MachineName found: $SCCMDir. Checking If a PSDrive for it has already been loaded..."

$DriveCheckString = $SCCMDir.Split(":")

debug "DriveCheckString 1 is $DriveCheckString"

$DriveCheckString2 = $DriveCheckString[0]

debug "DriveCheckString 2 is $DriveCheckString2. Attempting Get-PSdrive with it"

$DriveCheck = Get-PSDrive -Name $DriveCheckString2 -PSProvider CMSite -ErrorAction SilentlyContinue

if($null -eq $DriveCheck)
{
    debug "PSDrive for $DriveCheckString2 not mounted. Attempting to mount..."

    $AttemptToMount = New-PSDrive -Name $DriveCheckString2 -PSProvider CMSite -Root "aalmcspar001.wwg00m.rootdom.net" -Description "Primary Management Site - NA1" -ErrorAction SilentlyContinue

    if($null -eq $AttemptToMount)
    {
        debug "Failed to mount the PSDrive for $SCCMDir."

        $FailSkipReason = "Failed to mount the PSDrive for $SCCMDir."

        debug_FailSkip -DCName $MachineName -Type "FAIL" -Reason $FailSkipReason

        debug "Script Execution Finished. Exiting..."

        exit 0
    }

    debug "PSDrive for $SCCMDir successfully mounted."
}
else
{
    debug "PSDrive for $SCCMDir already found mounted."
}

cd $SCCMDir

$CurrentScriptRoot = Get-Location

debug "Current Script root: $CurrentScriptRoot"

if($SCCMDir -ne $CurrentScriptRoot)
{
    debug "Failed to change working directory to $SCCMDir"

    $FailSkipReason = "Failed to change working directory to $SCCMDir"

    debug_FailSkip -DCName $MachineName -Type "FAIL" -Reason $FailSkipReason

    debug "Script execution finished. Exiting..."

    exit 0
}

debug "Working dir successfully changed to $SCCMDir"

debug "Determining SCCM Collection Name to remove from, based on Machine name: $MachineName"

if($IsSAC -eq "Yes")
{
    switch -Wildcard ($MachineName)
    {
        "X*E1-D*"
        {
            $BuildCollection = $Default_SAC_NewBuildCollection_EU
        }

        "X*E2-D*"
        {
            $BuildCollection = $Default_SAC_NewBuildCollection_EU
        }

        "X*AP1-D*"
        {
            $BuildCollection = $Default_SAC_NewBuildCollection_APAC
        }

        "X*AP2-D*"
        {
            $BuildCollection = $Default_SAC_NewBuildCollection_APAC
        }

        "X*NA1-D*"
        {
            $BuildCollection = $Default_SAC_NewBuildCollection_NA
        }

        "X*NA2-D*"
        {
            $BuildCollection = $Default_SAC_NewBuildCollection_NA
        }

        Default
        {
            $BuildCollection = "Error"
        }
    }
}
if($IsSAC -eq "No")
{
    switch -Wildcard ($MachineName)
    {
        "X*E1-D*"
        {
            $BuildCollection = $DefaultNewBuildCollection_E1
        }

        "X*E2-D*"
        {
            $BuildCollection = $DefaultNewBuildCollection_E2
        }

        "X*AP1-D*"
        {
            $BuildCollection = $DefaultNewBuildCollection_AP1
        }

        "X*AP2-D*"
        {
            $BuildCollection = $DefaultNewBuildCollection_AP2
        }

        "X*NA1-D*"
        {
            $BuildCollection = $DefaultNewBuildCollection_NA1
        }

        "X*NA2-D*"
        {
            $BuildCollection = $DefaultNewBuildCollection_NA2
        }

        Default
        {
            $BuildCollection = "Error"
        }
    }
}

if(("Error" -eq $BuildCollection) -or ("Blank" -eq $BuildCollection))
{
    debug "Could not determine the Newbuild collection name to remove from for $MachineName"

    $FailSkipReason = "Could not determine the Newbuild collection name to remove from."

    debug_FailSkip -DCName $MachineName -Type "FAIL" -Reason $FailSkipReason

    exit 0
}

debug "Newbuild Collection to remove from resolved to: $BuildCollection"

debug "Proceeding to remove $MachineName from $BuildCollection..."


try
{
    Remove-CMDeviceCollectionDirectMembershipRule -CollectionName $BuildCollection -ResourceName $MachineName -Confirm:$false -Force
}
catch
{
    debug "FAILED to remove $MachineName from $BuildCollection."

    $FailSkipReason = "Failed to remove from collection $BuildCollection."

    debug_FailSkip -DCName $MachineName -Type "FAIL" -Reason $FailSkipReason

    debug "Reverting working directory back to $BeginningScriptRoot and exiting..."

    cd $BeginningScriptRoot

    exit 0
}

debug "Successfully removed $MachineName from $BuildCollection."

debug "Appending to the succeess log at $BeginningScriptRoot\ServersideLogs\ShortLogs\SCCM_CollectionRemover_Success.txt"

debug_Success -DCName $MachineName -SAC $IsSAC -CollectionName $BuildCollection

debug "Reverting working directory back to $BeginningScriptRoot and exiting..."

cd $BeginningScriptRoot

exit 0


