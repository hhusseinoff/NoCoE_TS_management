###################################################################################################################################################
##
##        Script to automatically Clear Required PXE Deployments for dedicated machines, so that they can retry executing the BFS
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
[string]$SequenceType
)

##-------------------------------------------------------------------------------------------------------------------------------------------------

Function Sleep-Progress($Seconds) {
    $s = 0;
    Do {
        $p = [math]::Round(100 - (($Seconds - $s) / $seconds * 100));
        Write-Progress -Activity "Waiting..." -Status "$p% Complete:" -SecondsRemaining ($Seconds - $s) -PercentComplete $p;
        [System.Threading.Thread]::Sleep(1000)
        $s++;
    }
    While($s -lt $Seconds);
    
}

##
##------------------Function for Verbose Logging---------------------------------------------------------------------------------------------------

function debug($message)
{
    write-host "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message"
    Add-Content -Path "$BeginningScriptRoot\ServersideLogs\SCCM_ClearReqPXE.log" -Value "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message" 
}

##-------------------------------------------------------------------------------------------------------------------------------------------------

##
##------------------Function for Fails Logging-----------------------------------------------------------------------------------------------------

function debug_FailSkip([string]$DCName,[string]$Type,[string]$Reason)
{
    $FileExists = Test-Path -Path "$BeginningScriptRoot\ServersideLogs\ShortLogs\SCCM_ClearReqPXE_FailSkip.txt" -PathType Leaf

    if($false -eq $FileExists)
    {
        Add-Content -Path "$BeginningScriptRoot\ServersideLogs\ShortLogs\SCCM_ClearReqPXE_FailSkip.txt" -Value "--Timestamp(UTC)--`tMachineName`tType`tReason" 
    }

    Add-Content -Path "$BeginningScriptRoot\ServersideLogs\ShortLogs\SCCM_ClearReqPXE_FailSkip.txt" -Value "$($(Get-Date).ToUniversalTime())`t$DCName`t$Type`t$Reason" 
}

##-------------------------------------------------------------------------------------------------------------------------------------------------

##
##------------------Function for Success Logging---------------------------------------------------------------------------------------------------

function debug_Success([string]$DCName,[string]$SeqType,[string]$Cleared)
{
    $FileExists = Test-Path -Path "$BeginningScriptRoot\ServersideLogs\ShortLogs\SCCM_ClearReqPXE_Success.txt" -PathType Leaf

    if($false -eq $FileExists)
    {
        Add-Content -Path "$BeginningScriptRoot\ServersideLogs\ShortLogs\SCCM_ClearReqPXE_Success.txt" -Value "--Timestamp(UTC)--`tMachineName`tSequence Type`tCleared Required PXE Deployments?" 
    }

    Add-Content -Path "$BeginningScriptRoot\ServersideLogs\ShortLogs\SCCM_ClearReqPXE_Success.txt" -Value "$($(Get-Date).ToUniversalTime())`t$DCName`t$SeqType`t$Cleared" 
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
##------------------Capture the beginning script root, since SCCM Powershell cmdlets require to be executed from a different working dir-----------

$BeginningScriptRoot = $PSScriptRoot

##-------------------------------------------------------------------------------------------------------------------------------------------------


##
##------------------Set the interval in seconds for how long after clearing ReqPXE deployments, can the machine be restarted to retry the BFS------

$CooldownInterval = 90

##-------------------------------------------------------------------------------------------------------------------------------------------------



##
##------------------Main Script Body---------------------------------------------------------------------------------------------------------------
##

debug "--------------------Script initiated. Working on: $MachineName-----------------------------"

$SCCMDir = "Blank"

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

debug "Proceeding to clear Required PXE Deployments for $MachineName..."

Clear-CMPxeDeployment -DeviceName $MachineName -Confirm:$false -ErrorAction Ignore

debug "Clearing complete. Entering 90 secons of downtime..."

Sleep-Progress -Seconds $CooldownInterval

debug "Appending data to the success log..."

debug_Success -DCName $MachineName -SAC $SequenceType -Cleared "Yes"

debug "Script execution finished. Exiting with error code 0..."

debug "$BeginningScriptRoot"

cd $BeginningScriptRoot

exit 0