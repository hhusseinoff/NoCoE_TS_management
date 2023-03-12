###################################################################################################################################################
##
##        Script to automatically manage Dedicated machines, once they finish executing their BFS Task sequence
##
##        Created by: Hyusein Hyuseinov (SERVER-RSRVPXT)
##
##        Last Update: Jan 10th, 2023
##
##        Intended to run periodically as a scheduled task
##
###################################################################################################################################################

##
##------------------Input Parameters (must be supplied from the TS)--------------------------------------------------------------------------------
param(
[string]$Region,
[string]$SequenceType,
[string]$DeviceEnvironment,
[string]$ReleaseName,
[string]$IsSAC,
[string]$RemoveFromCollection
)
##-------------------------------------------------------------------------------------------------------------------------------------------------


function DashboardEntryOps([string]$DashboardPath,[string]$Time,[string]$Name,[string]$OSVer,[string]$FailedStep,[string]$ReturnCode,[string]$PostOps)
{
    debug "Dashboard File entry operations engaged."
    
    $lineobj  = (Get-Content -Path $DashboardPath) | Select-String -Pattern $Name

    if($null -eq $lineobj)
    {
        debug "No previous entries for the machine detected. Proceeding to append a new entry..."

        Add-Content -Path $DashboardPath -Value "$Time`t$Name`t$OSVer`t$FailedStep`t$ReturnCode`t$PostOps`t$($(Get-Date).ToUniversalTime())" -Force -Confirm:$false

        debug "Entry Added."
    }
    else
    {
        debug "Dashboard file already contains an entry for $Name. Updating..." 

        $OldEntry = $lineobj.Line

        $NewEntry = "$Time`t$Name`t$OSVer`t$FailedStep`t$ReturnCode`t$PostOps`t$($(Get-Date).ToUniversalTime())"

        (Get-Content -Path $DashboardPath) -replace $OldEntry,$NewEntry | Set-Content -Path $DashboardPath

        debug "Entry Updated."
    }
}

##
##------------------Function for Logging-----------------------------------------------------------------------------------------------------------

function debug($message)
{
    write-host "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message"
    Add-Content -Path "$PSScriptRoot\ServersideLogs\Main_TSManagerLog.log" -Value "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message" 
}
##-------------------------------------------------------------------------------------------------------------------------------------------------

##
##------------------Function for Logging Remote registy branding failures--------------------------------------------------------------------------

function debug_FailSkip([string]$DCName,[string]$Type,[string]$SequenceType,[string]$Reason)
{
    $FileExists = Test-Path -Path "$PSScriptRoot\ServersideLogs\ShortLogs\RemoteRegBrandingFails.txt" -PathType Leaf

    if($false -eq $FileExists)
    {
        Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\RemoteRegBrandingFails.txt" -Value "--Timestamp(UTC)--`tMachineName`tType`tSequence Type`tReason" 
    }

    Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\RemoteRegBrandingFails.txt" -Value "$($(Get-Date).ToUniversalTime())`t$DCName`t$Type`t$SequenceType`t$Reason" 
}
##-------------------------------------------------------------------------------------------------------------------------------------------------

#
##------------------Create Log Folders at the script root if they don't exist----------------------------------------------------------------------
$ServersideLogsFolderExists = Test-path -Path "$PSScriptRoot\ServersideLogs" -PathType Container

if($false -eq $ServersideLogsFolderExists)
{
    New-Item -Path "$PSScriptRoot" -Name "ServersideLogs" -ItemType Directory -Force -Confirm:$false -ErrorAction Stop | Out-Null
}

$ShortLogsFolderExists = Test-path -Path "$PSScriptRoot\ServersideLogs\ShortLogs" -PathType Container

if($false -eq $ShortLogsFolderExists)
{
    New-Item -Path "$PSScriptRoot\ServersideLogs\ShortLogs" -Name "ServersideLogs" -ItemType Directory -Force -Confirm:$false -ErrorAction Stop | Out-Null
}
##-------------------------------------------------------------------------------------------------------------------------------------------------


#
##------------------Construct the Dashboard file path based on the Input Parameters----------------------------------------------------------------

$DashboardFilePath = "$PSScriptRoot\$SequenceType\$DeviceEnvironment\$ReleaseName\Dashboard.txt"

##-------------------------------------------------------------------------------------------------------------------------------------------------


#
##------------------Main Script Body---------------------------------------------------------------------------------------------------------------

debug "----- Script initiated -----"
debug "Region: $Region"
debug "Sequence Type: $SequenceType"
debug "Device Environment: $DeviceEnvironment"
debug "Release Name: $ReleaseName"
debug "SAC Modifier: $IsSAC"
debug "Remove Sucessfully built devices from NewBuild Collections: $RemoveFromCollection"

debug "Assumed Dashboard file path: $DashboardFilePath"

debug "Proceeding to load the dashboard input..."

$DashboardInput = (Get-Content -Path $DashboardFilePath)

if($null -eq $DashboardInput)
{
    debug "Failed to load the Dashboard input at $DashboardFilePath"

    debug "Script wil not run. Exiting with error code 1..."

    exit 1
}

debug "Dashboard input at $DashboardFilePath loaded."

#
##------------------Define Registry on the client used for Branding--------------------------------------------------------------------------------

$RegistryPath = "HKLM:\SOFTWARE\AVC\DedicatedTaskSequenceManagement"

debug "Machine Registry Path used for local branding: $RegistryPath"
##-------------------------------------------------------------------------------------------------------------------------------------------------

#
##-------------------------------------------------BFS Logic---------------------------------------------------------------------------------------

if(("BFS" -eq $SequenceType) -or ("SAC_BFS" -eq $SequenceType))
{
    :MainLoop foreach($line in $DashboardInput)
    {
        $type = $line.GetType()

        debug "$type"
        
        if($line -like "*Machine Name*")
        {
            debug "Skipping Dashboard header line $line"

            continue MainLoop
        }

        $EntryArray = $line.Split("`t")

        $ExtractedTimestamp = $EntryArray[0]

        $ExtractedMachineName = $EntryArray[1]

        $ExtractedOSType = $EntryArray[2]

        $ExtractedFStepName = $EntryArray[3]

        $ExtractedFStepReturnCode = $EntryArray[4]

        $ExtractedPostOps = $EntryArray[5]

        $ExtractedPostOpsTime = $EntryArray[6]

        debug "Extracted Entry Data:"

        debug "Timestamp: $ExtractedTimestamp"

        debug "Machine Name: $ExtractedMachineName"

        debug "OS Type: $ExtractedOSType"

        debug "Failed Step Name: $ExtractedFStepName"

        debug "Post Operations Performed: $ExtractedPostOps"

        debug "Post Operations Perform Time: $ExtractedPostOpsTime"

        $EntryArray = $null

        #
        ##-------------------------------------------------BFS Scenarios (add additional ones here)-------------------------------------------------------------------

        if(("Successful Execution" -eq $ExtractedFStepName) -and ("No" -eq $ExtractedPostOps))
        {
            debug "Scenario: Successful Execution, engaged."

            if("Yes" -eq $RemoveFromCollection)
            {
                if($SequenceType -like "SAC*")
                {
                   debug "Calling script to remove $ExtractedMachineName from it's Newbuild Collection..."

                   & "$PSScriptRoot\SCCM_CollectionDeviceRemover.ps1" -MachineName $ExtractedMachineName -IsSAC "Yes" -ErrorAction Ignore
                }
                else
                {
                    debug "Calling script to remove $ExtractedMachineName from it's Newbuild Collection..."

                    & "$PSScriptRoot\SCCM_CollectionDeviceRemover.ps1" -MachineName $ExtractedMachineName -IsSAC "No" -ErrorAction Ignore
                }
            }
            
            debug "Calling script to set Maintenace Mode off for $ExtractedMachineName..."

            & "$PSScriptRoot\XD_DisableMaintenanceMode.ps1" -ComputerName $ExtractedMachineName -ErrorAction Ignore

            debug "Calling script to tag $ExtractedMachineName with an ImgVer XD Tag for $ReleaseName..."

            & "$PSScriptRoot\XD_TagImageVersion.ps1" -ImageVersion $ReleaseName -ComputerName $ExtractedMachineName -ErrorAction Ignore

            debug "Calling script to tag $ExtractedMachineName with Build Success XD Tag..."

            & "$PSScriptRoot\XD_TagSuccessFail.ps1" -ComputerName $ExtractedMachineName -Mode "Success" -SequenceType $SequenceType -ErrorAction Ignore

            debug "Post Operations Complete for Scenario: Successful Exection"

            debug "Proceeding to remotely brand the machine's registry at $RegistryPath (Actual Path used by the Invoke-Command cmdlet is hardcoded)"

            $PostOpsPerformedBrand = Invoke-Command -ComputerName $ExtractedMachineName -ScriptBlock {New-ItemProperty -Path "HKLM:\SOFTWARE\AVC\DedicatedTaskSequenceManagement" -Name "PostOperationsPerformed" -PropertyType String -Value "YES" -Force -ErrorAction SilentlyContinue}

            $PostOpsPerformedBrandString = $PostOpsPerformedBrand.PostOperationsPerformed

            if($null -eq $PostOpsPerformedBrandString)
            {
                debug "Failed to Brand $ExtractedMachineName with the PostOperationsPerformed Reg property"

                $FailReason = "Failed to brand the PostOperationsPerformed registry property."

                debug_FailSkip -DCName $ExtractedMachineName -Type "Fail" -SequenceType $SequenceType -Reason $FailReason
            }

            $PostOpsPerformedTimeBrand = Invoke-Command -ComputerName $ExtractedMachineName -ScriptBlock {New-ItemProperty -Path "HKLM:\SOFTWARE\AVC\DedicatedTaskSequenceManagement" -Name "PostOperationsPerformedTimeUTC" -PropertyType String -Value "$($(Get-Date).ToUniversalTime())" -Force -ErrorAction SilentlyContinue}

            $PostOpsPerformedTimeBrandString = $PostOpsPerformedBrand.PostOperationsPerformedTimeUTC

            if($null -eq $PostOpsPerformedTimeBrandString)
            {
                debug "Failed to Brand $ExtractedMachineName with the PostOperationsPerformedTimeUTC Reg property"

                $FailReason = "Failed to brand the PostOperationsPerformedTimeUTC registry property."

                debug_FailSkip -DCName $ExtractedMachineName -Type "Fail" -SequenceType $SequenceType -Reason $FailReason
            }

            debug "Branding complete, Updating the Dashboard file..."

            $ExtractedPostOps = "Yes"

            $ExtractedPostOpsTime = "$($(Get-Date).ToUniversalTime())"

            $OutputArray = @($ExtractedTimestamp,$ExtractedMachineName,$ExtractedOSType,$ExtractedFStepName,$ExtractedFStepReturnCode,$ExtractedPostOps,$ExtractedPostOpsTime)

            $UpdatedLine = $OutputArray -join "`t"

            (Get-Content -Path $DashboardFilePath) -replace $line,$UpdatedLine  | Set-Content -Path $DashboardFilePath

            debug "Dashboard File update complete."

            debug "Scenario: Successful Execution, complete."
        }
        if(("Successful Execution" -ne $ExtractedFStepName) -and ("No" -eq $ExtractedPostOps))
        {
            debug "Scenario: Generic Failure, engaged."
            
            debug "Calling script to ensure that Maintenace Mode is ON for $ExtractedMachineName..."

            & "$PSScriptRoot\XD_EnableMaintenanceMode.ps1" -ComputerName $ExtractedMachineName -ErrorAction Ignore

            debug "Calling script to tag $ExtractedMachineName with Build Fail XD Tag..."

            & "$PSScriptRoot\XD_TagSuccessFail.ps1" -ComputerName $ExtractedMachineName -Mode "Fail" -SequenceType $SequenceType -ErrorAction Ignore

            debug "Calling script to Clear Required PXE Deployments for $ExtractedMachineName..."

            & "$PSScriptRoot\SCCM_ClearReqPXEDeployment.ps1" -MachineName $ExtractedMachineName -SequenceType $SequenceType -ErrorAction Ignore

            debug "Calling script to force restart $ExtractedMachineName in VMWare..."

            & "$PSScriptRoot\VMWare_Restart.ps1" -Region $Region -MachineName $ExtractedMachineName -Action "Hard" -ErrorAction Ignore

            debug "Post Operations Complete for Scenario: Generic Failure"

            debug "Remotely branding the machine's registry at $RegistryPath will be SKIPPED since the executing scenario is a Generic Failure"

            debug "Branding complete, Updating the Dashboard file..."

            $ExtractedPostOps = "Yes"

            $ExtractedPostOpsTime = "$($(Get-Date).ToUniversalTime())"

            $OutputArray = @($ExtractedTimestamp,$ExtractedMachineName,$ExtractedOSType,$ExtractedFStepName,$ExtractedFStepReturnCode,$ExtractedPostOps,$ExtractedPostOpsTime)

            $UpdatedLine = $OutputArray -join "`t"

            (Get-Content -Path $DashboardFilePath) -replace $line,$UpdatedLine  | Set-Content -Path $DashboardFilePath

            debug "Dashboard File update complete."

            debug "Scenario: Successful Execution, complete."
        }
    }
}

#
##-------------------------------------------------Upgrade Logic-----------------------------------------------------------------------------------

if(("Upgrade" -eq $SequenceType) -or ("SAC_Upgrade" -eq $SequenceType))
{
        if($line -like "*Machine Name*")
        {
            debug "Skipping Dashboard header line $line"

            continue MainLoop
        }

        $EntryArray = $line.Split("`t")

        $ExtractedTimestamp = $EntryArray[0]

        $ExtractedMachineName = $EntryArray[1]

        $ExtractedOSType = $EntryArray[2]

        $ExtractedFStepName = $EntryArray[3]

        $ExtractedPostOps = $EntryArray[4]

        $ExtractedPostOpsTime = $EntryArray[5]

        debug "Extracted Entry Data:"

        debug "Timestamp: $ExtractedTimestamp"

        debug "Machine Name: $ExtractedMachineName"

        debug "OS Type: $ExtractedOSType"

        debug "Failed Step Name: $ExtractedFStepName"

        debug "Post Operations Performed: $ExtractedPostOps"

        debug "Post Operations Perform Time: $ExtractedPostOpsTime"

        $EntryArray = $null

        #
        ##-------------------------------------------------Upgrade Scenarios (add additional ones here)-------------------------------------------------------------------

        if(("Successful Execution" -eq $ExtractedFStepName) -and ("No" -eq $ExtractedPostOps))
        {
            debug "Scenario: Successful Execution, engaged."

            debug "Calling script to tag $ExtractedMachineName with Upgrade Success XD Tag..."

            & "$PSScriptRoot\XD_TagSuccessFail.ps1" -ComputerName $ExtractedMachineName -Mode "Success" -SequenceType $SequenceType -ErrorAction Ignore

            debug "Post Operations Complete for Scenario: Successful Execution"

            debug "Proceeding to remotely brand the machine's registry at $RegistryPath (Actual Path used by the Invoke-Command cmdlet is hardcoded)"

            $PostOpsPerformedBrand = Invoke-Command -ComputerName $ExtractedMachineName -ScriptBlock {New-ItemProperty -Path "HKLM:\SOFTWARE\AVC\DedicatedTaskSequenceManagement" -Name "PostOperationsPerformed" -PropertyType String -Value "YES" -Force -ErrorAction SilentlyContinue}

            $PostOpsPerformedBrandString = $PostOpsPerformedBrand.PostOperationsPerformed

            if($null -eq $PostOpsPerformedBrandString)
            {
                debug "Failed to Brand $ExtractedMachineName with the PostOperationsPerformed Reg property"

                $FailReason = "Failed to brand the PostOperationsPerformed registry property."

                debug_FailSkip -DCName $ExtractedMachineName -Type "Fail" -SequenceType $SequenceType -Reason $FailReason
            }

            $PostOpsPerformedTimeBrand = Invoke-Command -ComputerName $ExtractedMachineName -ScriptBlock {New-ItemProperty -Path "HKLM:\SOFTWARE\AVC\DedicatedTaskSequenceManagement" -Name "PostOperationsPerformedTimeUTC" -PropertyType String -Value "$($(Get-Date).ToUniversalTime())" -Force -ErrorAction SilentlyContinue}

            $PostOpsPerformedTimeBrandString = $PostOpsPerformedBrand.PostOperationsPerformedTimeUTC

            if($null -eq $PostOpsPerformedTimeBrandString)
            {
                debug "Failed to Brand $ExtractedMachineName with the PostOperationsPerformedTimeUTC Reg property"

                $FailReason = "Failed to brand the PostOperationsPerformedTimeUTC registry property."

                debug_FailSkip -DCName $ExtractedMachineName -Type "Fail" -SequenceType $SequenceType -Reason $FailReason
            }

            debug "Branding complete, Updating the Dashboard file..."

            $ExtractedPostOps = "Yes"

            $ExtractedPostOpsTime = "$($(Get-Date).ToUniversalTime())"

            $OutputArray = @($ExtractedTimestamp,$ExtractedMachineName,$ExtractedOSType,$ExtractedFStepName,$ExtractedFCode,$ExtractedPostOps,$ExtractedPostOpsTime)

            $UpdatedLine = $OutputArray -join "`t"

            (Get-Content -Path $DashboardFilePath) -replace $line,$UpdatedLine  | Set-Content -Path $DashboardFilePath

            debug "Dashboard File update complete."

            debug "Scenario: Successful Execution, complete."
        }
        if(("Successful Execution" -ne $ExtractedFStepName) -and ("No" -eq $ExtractedPostOps))
        {
            debug "Scenario: Generic Failure, engaged."
            
            debug "Calling script to ensure that Maintenace Mode is ON for $ExtractedMachineName..."

            & "$PSScriptRoot\XD_EnableMaintenanceMode.ps1" -ComputerName $ExtractedMachineName -ErrorAction Ignore

            debug "Calling script to tag $ExtractedMachineName with Upgrade Fail XD Tag..."

            & "$PSScriptRoot\XD_TagSuccessFail.ps1" -ComputerName $ExtractedMachineName -Mode "Fail" -SequenceType $SequenceType -ErrorAction Ignore

            debug "Post Operations Complete for Scenario: Generic Failure"

            debug "Remotely branding the machine's registry at $RegistryPath will be SKIPPED since the executing scenario is a Generic Failure"

            debug "Proceeding to update the Dashboard file..."

            $ExtractedPostOps = "Yes"

            $ExtractedPostOpsTime = "$($(Get-Date).ToUniversalTime())"

            $OutputArray = @($ExtractedTimestamp,$ExtractedMachineName,$ExtractedOSType,$ExtractedFStepName,$ExtractedFCode,$ExtractedPostOps,$ExtractedPostOpsTime)

            $UpdatedLine = $OutputArray -join "`t"

            ##DashboardEntryOps -DashboardPath $DashboardFilePath -Time $ExtractedPostOpsTime -Name $ExtractedMachineName -OSVer $ExtractedOSType -FailedStep $ExtractedFStepName -ReturnCode $ExtractedFCode -PostOps "Yes"

            (Get-Content -Path $DashboardFilePath -Force) -replace "$line","$UpdatedLine"  | Set-Content -Path $DashboardFilePath -Force -Confirm:$false

            debug "Dashboard File update complete."

            debug "Scenario: Generic Failure, complete."
        }
}


#
##-------------------------------------------------Update collections-----------------------------------------------------------------------------------

if($RemoveFromCollection -eq "Yes")
{
    debug "Input Parameter RemoveFromCollection was passed as $RemoveFromCollection."

    debug "Calling script to update memberships of the Build collections, based on tha passed Region parameter and SAC Modifier."

    & "$PSScriptRoot\SCCM_CollectionUpdater.ps1" -Region $Region -IsSAC $IsSAC -ErrorAction Ignore

    debug "Update membership call executed. Some time will need to pass in order for the changes to reflect in the SCCM Console."

    debug "Script Execution finished. Exiting..."

    exit 0
}


debug "Input Parameter RemoveFromCollection was passed as $RemoveFromCollection."

debug "The script to update collections memberships will NOT execute."

debug "Script Execution finished. Exiting..."

exit 0
