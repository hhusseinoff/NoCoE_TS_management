## Author: Hyusein Hyuseinov / Server-RSRPVXT, aka José
## Revision: Jan 4th, 2023
##
## Description:
##
## Checks if the executing TS is a BFS or not, then if it is a BFS variant
## Creates \\<ShareArchiveUNC>\BFS, if it doesn't already exist
## Creates \\<ShareArchiveUNC>\BFS\<ReleaseVersion>, if it doesn't already exist
## Creates \\<ShareArchiveUNC>\BFS\<ReleaseVersion>\Dashboard.txt, if it doesn't already exist
## Checks if the TS execution was a success, then adds an entry for the machine in the Dashboard.txt file
## If a step in the TS failed
## --Creates \\<ShareArchiveUNC>\BFS\<ReleaseVersion>\<MachineName>, if it doesn't already exist
## --If the \\<ShareArchiveUNC>\BFS\<ReleaseVersion>\<MachineName> folder exists, deletes it's content to preserve only the most recent smsts.log for the machine
## --Copies the local smsts.log from the machine to \\<ShareArchiveUNC>\BFS\<ReleaseVersion>\<MachineName>
##
## If the executing TS is not a BFS one, does the same operations, but creates a Release folder at the share, to differentiate between the two types of TS-es
## e.g. \\<ShareArchiveUNC>\Releases\<ReleaseVersion>\Dashboard.txt
##
## Also creates local logs on the machine, detailing the steps of the script's execution for troubleshooting purposes
## Local Log location for the script: C:\Windows\AVC\Logging\Dedicated_TS_Management.log
##
## Recommended to be run under an engineer Server-Bensl acc to reduce the possibility of permissions, preventing folder/file creation.
##
## Edit Oct 23rd: Replaced the local logging dir, since it was observed that permission to C:\Windows\AVC\Logging is denied even to SERVER-BENSL acc execution in BFS sequences
## Also changed the type of the IsBFS param to string, since boolean params can't be passed within a TS it seems
##
## Also reworked the code so that existing entries in the Dashboard.txt get Replaced -> ensures only one entry per machine
## Also reowrked the code so that existing logs and folders for the machine are deleted when a successful TS run happenns
##
## V7 Edits: Now also checks for SAC variants of Upgrade/BFS Sequences, and also INT/PROD differentiation is introduced
## Standardized functions have been made for 3 main operations: Directory Creation, Dashboard Entry management and Log Retrieval
## Local branding of the passed Execution results are introduced via registries at HKLM:\SOFTWARE\AVC\DedicatedTaskSequenceManagement
##
## V8 Edits: Now also captures and recored info in the Dashboard about the OS version (21H2, 22H2, etc)

##
##------------------Input Parameters (must be supplied from the TS)--------------------------------------------------------------------------------
param(
[string]$ReportingLocation,
[string]$DeviceEnvironment,
[string]$IsBFS,
[string]$IsSAC,
[string]$ComputerName,
[string]$ReleaseVersion,
[string]$FailedStepName,
[string]$FailedStepReturnCode,
[string]$LocalSMSTSLogPath
)
##-------------------------------------------------------------------------------------------------------------------------------------------------

##
##------------------Function for Logging-----------------------------------------------------------------------------------------------------------

function debug($message)
{
    write-host "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message"
    add-content -path "C:\Temp\TS_Management\Dedicated_TS_Management.log" -Value "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message" 
}
##-------------------------------------------------------------------------------------------------------------------------------------------------

##
##------------------Function for Creating Directories at the Reporting Location--------------------------------------------------------------------

function DirectoryOps([string]$Location,[string]$Environment,[string]$BFS,[string]$SAC,[string]$ImgVer)
{
    if(("No" -eq $BFS) -and ("No" -eq $SAC))
    {
        $Keyword = "Upgrade"
    }

    if(("Yes" -eq $BFS) -and ("No" -eq $SAC))
    {
        $Keyword = "BFS"
    }

    if(("No" -eq $BFS) -and ("Yes" -eq $SAC))
    {
        $Keyword = "SAC_Upgrade"
    }

    if(("Yes" -eq $BFS) -and ("Yes" -eq $SAC))
    {
        $Keyword = "SAC_BFS"
    }

    debug "Checking if a $Keyword directory exists at $Location..."

    $DirCheck = Test-Path -Path "$Location\$Keyword" -PathType Container

    if($false -eq $DirCheck)
    {
        debug "A '$Keyword' directory at $ReportingLocation doesn't exist. Proceeding to create..."

        New-Item -Path "$Location" -Name "$Keyword" -ItemType Directory -Force -Confirm:$false | Out-Null

        debug "'$Keyword' Directory at $Location created."
    }
    else
    {
        debug "A '$Keyword' directory at $Location already exists."
    }

    debug "Checking for $Environment directory at $Location\$Keyword..."

    $DirCheck = Test-Path -Path "$Location\$Keyword\$Environment" -PathType Container

    if($false -eq $DirCheck)
    {
        debug "A '$Environment' directory at $Location\$Keyword doesn't exist. Proceeding to create..."

        New-Item -Path "$Location\$Keyword" -Name "$Environment" -ItemType Directory -Force -Confirm:$false | Out-Null

        debug "'$Environment' Directory at $Location\$Keyword created."
    }
    else
    {
        debug "A '$Environment' directory at $Location\$Keyword already exists."
    }

    debug "Checking for $ImgVer directory at $Location\$Keyword\$Environment..."

    $DirCheck = Test-Path -Path "$Location\$Keyword\$Environment\$ImgVer" -PathType Container

    if($false -eq $DirCheck)
    {
        debug "A '$ImgVer' directory at $Location\$Keyword\$Environment doesn't exist. Proceeding to create..."

        New-Item -Path "$Location\$Keyword\$Environment" -Name "$ImgVer" -ItemType Directory -Force -Confirm:$false | Out-Null

        debug "'$ImgVer' Directory at $Location\$Keyword\$Environment created."
    }
    else
    {
        debug "A '$ImgVer' directory at $Location\$Keyword\$Environment already exists."
    }

    debug "Checking for a Dashboard.txt File at $Location\$Keyword\$Environment\$ImgVer..."

    $DirCheck = Test-Path -Path "$Location\$Keyword\$Environment\$ImgVer\Dashboard.txt" -PathType Leaf

    if($false -eq $DirCheck)
    {
        debug "A Dashboard.txt file at $Location\$Keyword\$Environment\$ImgVer doesn't exist. Proceeding to create..."

        Add-Content -Path "$Location\$Keyword\$Environment\$ImgVer\Dashboard.txt" -Value "--Timestamp (UTC)--`tMachine Name`tOS Type`tFailed Step Name`tFailed Step Return Code`tPostOps Performed`tPostOps Time" -Force -Confirm:$false

        debug "Dashboard.txt file at $Location\$Keyword\$Environment\$ImgVer created."
    }
    else
    {
        debug "Dashboard.txt file at $Location\$Keyword\$Environment\$ImgVer already exists."
    }
}
##-------------------------------------------------------------------------------------------------------------------------------------------------


##
##------------------Function for Entering Device Data in the Dashboard file------------------------------------------------------------------------

function DashboardEntryOps([string]$DashboardPath,[string]$Name,[string]$OSVer,[string]$FailedStep,[string]$ReturnCode,[string]$PostOps,[string]$PostOpsTime)
{
    debug "Dashboard File entry operations engaged."
    
    $lineobj  = (Get-Content -Path $DashboardPath) | Select-String -Pattern $Name

    if($null -eq $lineobj)
    {
        debug "No previous entries for the machine detected. Proceeding to append a new entry..."

        Add-Content -Path $DashboardPath -Value "$($(Get-Date).ToUniversalTime())`t$Name`t$OSVer`t$FailedStep`t$ReturnCode`t$PostOps`tNULL" -Force -Confirm:$false

        debug "Entry Added."
    }
    else
    {
        debug "Dashboard file already contains an entry for $Name. Updating..." 

        $OldEntry = $lineobj.Line

        $NewEntry = "$($(Get-Date).ToUniversalTime())`t$Name`t$OSVer`t$FailedStep`t$ReturnCode`t$PostOps`tNULL"

        (Get-Content -Path $DashboardPath) -replace $OldEntry,$NewEntry | Set-Content -Path $DashboardPath

        debug "Entry Updated."
    }
}
##-------------------------------------------------------------------------------------------------------------------------------------------------

##
##------------------Function for uploading local SMSTS logs to the Reporting Location--------------------------------------------------------------

function LogRetrievalOps([string]$MachineName,[string]$SharePath,[string]$LocalLogPath,[string]$Mode)
{
    switch -Exact ($Mode)
    {
        "Clear"
        {
            debug "Log retrieval operations engaged, mode: $Mode"
            
            debug "Checking if a directory for the machine exists at the Log Archive Network share..."

            $MachineDirCheck = Test-Path -Path "$SharePath\$MachineName" -PathType Container

            if($false -eq $MachineDirCheck)
            {
                debug "No directory for $MachineName exists at $SharePath. Therefore, no logs to clear."
            }
            else
            {
                debug "Directory for the $MachineName at the $SharePath exists. Proceeding to delete its current contents..."

                Remove-Item -Path "$SharePath\$MachineName\*" -Force -Confirm:$false

                debug "Content deleted. Proceeding to delete the folder itself..."

                Remove-Item -Path "$SharePath\$MachineName" -Force -Confirm:$false

                debug "Folder deleted."
            }
        }

        "Replace"
        {
            debug "Log retrieval operations engaged, mode: $Mode"

            debug "Checking if a directory for the machine exists at the Log Archive Network share..."

            $MachineDirCheck = Test-Path -Path "$SharePath\$MachineName" -PathType Container

            if($false -eq $MachineDirCheck)
            {
                debug "No directory for $MachineName exists at $SharePath. Proceeding to create..."

                New-Item -Path "$SharePath" -Name "$MachineName" -ItemType Directory -Force -Confirm:$false | Out-Null

                debug "Directory for $MachineName created. Proceeding to copy the local smsts.log to it..."

                Copy-Item -Path "$LocalLogPath\*" -Destination "$SharePath\$MachineName" -Force -Confirm:$false

                debug "smsts.log copied."
            }
            else
            {
                debug "Directory for the $MachineName at the $SharePath exists. Proceeding to delete its current contents..."

                Remove-Item -Path "$SharePath\$MachineName\*" -Force -Confirm:$false

                debug "Content deleted. Proceeding to copy the local smsts.log to it..."

                Copy-Item -Path "$LocalLogPath\*" -Destination "$SharePath\$MachineName" -Force -Confirm:$false

                debug "smsts.log copied."
        }
    }
}
}
##-------------------------------------------------------------------------------------------------------------------------------------------------

##------------------Function for Branding the local machine via registry keys----------------------------------------------------------------------

function RegBrandOps([string]$RegPath,[string]$SequenceType,[string]$Result,[string]$PostOpsPerformed,[string]$PostOpsTime)
{
    debug "Local Registry Branding operations engaged."

    debug "Checking if $RegPath\DedicatedTaskSequenceManagement exists..."

    $RegCheck = Test-Path -Path "$RegPath\DedicatedTaskSequenceManagement" -PathType Container

    if($false -eq $RegCheck)
    {
        debug "$RegPath\DedicatedTaskSequenceManagement doesn't exist. Creating..."
        
        New-Item -Path $RegPath -Name "DedicatedTaskSequenceManagement" -Force -Confirm:$false | Out-Null

        debug "Created."
    }

    debug "Proceeding to brand the following regstry values at $RegPath\DedicatedTaskSequenceManagement:"

    debug "LastRunSequenceType : $SequenceType"
    debug "LastRunSequenceResult : $Result"
    debug "LastRunSequenceResultTimeUTC"
    debug "PostOperationsPerformed : $PostOpsPerformed"
    debug "PostOperationsPerformedTimeUTC"

    New-ItemProperty -Path "$RegPath\DedicatedTaskSequenceManagement" -Name "LastRunSequenceType" -PropertyType String -Value "$SequenceType" -Force -Confirm:$false -ErrorAction Ignore | Out-Null

    New-ItemProperty -Path "$RegPath\DedicatedTaskSequenceManagement" -Name "LastRunSequenceResult" -PropertyType String -Value "$Result" -Force -Confirm:$false -ErrorAction Ignore | Out-Null

    New-ItemProperty -Path "$RegPath\DedicatedTaskSequenceManagement" -Name "LastRunSequenceResultTimeUTC" -PropertyType String -Value "$($(Get-Date).ToUniversalTime())" -Force -Confirm:$false -ErrorAction Ignore | Out-Null

    New-ItemProperty -Path "$RegPath\DedicatedTaskSequenceManagement" -Name "PostOperationsPerformed" -PropertyType String -Value "$PostOpsPerformed" -Force -Confirm:$false -ErrorAction Ignore | Out-Null

    New-ItemProperty -Path "$RegPath\DedicatedTaskSequenceManagement" -Name "PostOperationsPerformedTimeUTC" -PropertyType String -Value "$PostOpsTime" -Force -Confirm:$false -ErrorAction Ignore | Out-Null

    debug "Registry branding complete."


}
##-------------------------------------------------------------------------------------------------------------------------------------------------

##
##------------------Create local logging folder----------------------------------------------------------------------------------------------------
New-Item -Path "C:\Temp" -Name "TS_Management" -ItemType Directory -Force
##-------------------------------------------------------------------------------------------------------------------------------------------------


##------------------Setting Success Marker keyword and local registry location for branding--------------------------------------------------------

$SuccessMarker = "NoStepsFailed"

$RegistryPath = "HKLM:\SOFTWARE\CompanyName"

##-------------------------------------------------------------------------------------------------------------------------------------------------


##------------------Main Script Body---------------------------------------------------------------------------------------------------------------

debug "----------------------------Script initiated-----------------------------"

debug "Passed parameters:"
debug "Reporting Location: $ReportingLocation"
debug "Device Environment: $DeviceEnvironment"
debug "BFS Marker: $IsBFS"
debug "SAC Marker: $IsSAC"
debug "Computer name: $ComputerName"
debug "Release Version: $ReleaseVersion"
debug "Failed Step Name: $FailedStepName"
debug "Failed Step Return Code: $FailedStepReturnCode"
debug "Local smsts.log path: $LocalSMSTSLogPath"

if(("No" -eq $IsBFS) -and ("No" -eq $IsSAC))
{
    debug "Executing Task Sequence is a regular Release upgrade sequence."

    $SequenceIs = "Upgrade"

    DirectoryOps -Location $ReportingLocation -Environment $DeviceEnvironment -BFS $IsBFS -SAC $IsSAC -ImgVer $ReleaseVersion

    $DashboardPath = "$ReportingLocation\$SequenceIs\$DeviceEnvironment\$ReleaseVersion\Dashboard.txt"

    $DashboardLocation = "$ReportingLocation\$SequenceIs\$DeviceEnvironment\$ReleaseVersion"

    $WinBuild = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "CurrentBuild" -ErrorAction Ignore

    $WinDisplayVersion = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "DisplayVersion" -ErrorAction Ignore

    $WinEdition = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "EditionID" -ErrorAction Ignore

    $WinType = $WinBuild + ", " + $WinDisplayVersion + " " + $WinEdition

    if($SuccessMarker -eq $FailedStepName)
    {
        debug "Execution Result is a SUCCESS"

        debug "Performing Dashboard file operations..."

        DashboardEntryOps -DashboardPath $DashboardPath -Name $ComputerName -OSVer $WinType -FailedStep "Successful Execution" -ReturnCode "None" -PostOps "No" -PostOpsTime "NULL"

        debug "Performing log retrieval operations..."

        LogRetrievalOps -MachineName $ComputerName -SharePath $DashboardLocation -LocalLogPath $LocalSMSTSLogPath -Mode "Clear"

        debug "Performing registry values branding..."

        RegBrandOps -RegPath $RegistryPath -SequenceType $SequenceIs -Result "SuccessfulExecution" -PostOpsPerformed "No" -PostOpsTime "NULL"

        debug "Script Execution finished. Exiting..."

        exit 0
    }
    else
    {
        debug "Execution Result is a FAILURE"

        DashboardEntryOps -DashboardPath $DashboardPath -Name $ComputerName -OSVer $WinType -FailedStep $FailedStepName -ReturnCode $FailedStepReturnCode -PostOps "No" -PostOpsTime "NULL"

        debug "Performing log retrieval operations..."

        LogRetrievalOps -MachineName $ComputerName -SharePath $DashboardLocation -LocalLogPath $LocalSMSTSLogPath -Mode "Replace"

        debug "Performing registry values branding..."

        RegBrandOps -RegPath $RegistryPath -SequenceType $SequenceIs -Result "Failed_$FailedStepName" -PostOpsPerformed "No" -PostOpsTime "NULL"

        debug "Script Execution finished. Exiting..."

        exit 0

    }

}

if(("Yes" -eq $IsBFS) -and ("No" -eq $IsSAC))
{
    debug "Executing Task Sequence is a regular BFS sequence."

    $SequenceIs = "BFS"

    DirectoryOps -Location $ReportingLocation -Environment $DeviceEnvironment -BFS $IsBFS -SAC $IsSAC -ImgVer $ReleaseVersion

    $DashboardPath = "$ReportingLocation\$SequenceIs\$DeviceEnvironment\$ReleaseVersion\Dashboard.txt"

    $DashboardLocation = "$ReportingLocation\$SequenceIs\$DeviceEnvironment\$ReleaseVersion"

    $WinBuild = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "CurrentBuild" -ErrorAction Ignore

    $WinDisplayVersion = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "DisplayVersion" -ErrorAction Ignore

    $WinEdition = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "EditionID" -ErrorAction Ignore

    $WinType = $WinBuild + ", " + $WinDisplayVersion + " " + $WinEdition

    if($SuccessMarker -eq $FailedStepName)
    {
        debug "Execution Result is a SUCCESS"

        debug "Performing Dashboard file operations..."

        DashboardEntryOps -DashboardPath $DashboardPath -Name $ComputerName -OSVer $WinType -FailedStep "Successful Execution" -ReturnCode "None" -PostOps "No" -PostOpsTime "NULL"

        debug "Performing log retrieval operations..."

        LogRetrievalOps -MachineName $ComputerName -SharePath $DashboardLocation -LocalLogPath $LocalSMSTSLogPath -Mode "Clear"

        debug "Performing registry values branding..."

        RegBrandOps -RegPath $RegistryPath -SequenceType $SequenceIs -Result "SuccessfulExecution" -PostOpsPerformed "No" -PostOpsTime "NULL"

        debug "Script Execution finished. Exiting..."

        exit 0
    }
    else
    {
        debug "Execution Result is a FAILURE"

        DashboardEntryOps -DashboardPath $DashboardPath -Name $ComputerName -OSVer $WinType -FailedStep $FailedStepName -ReturnCode $FailedStepReturnCode -PostOps "No" -PostOpsTime "NULL"

        debug "Performing log retrieval operations..."

        LogRetrievalOps -MachineName $ComputerName -SharePath $DashboardLocation -LocalLogPath $LocalSMSTSLogPath -Mode "Replace"

        debug "Performing registry values branding..."

        RegBrandOps -RegPath $RegistryPath -SequenceType $SequenceIs -Result "Failed_$FailedStepName" -PostOpsPerformed "No" -PostOpsTime "NULL"

        debug "Script Execution finished. Exiting..."

        exit 0
    }
}

if(("No" -eq $IsBFS) -and ("Yes" -eq $IsSAC))
{
    debug "Executing Task Sequence is a SAC Upgrade sequence."

    $SequenceIs = "SAC_Upgrade"

    DirectoryOps -Location $ReportingLocation -Environment $DeviceEnvironment -BFS $IsBFS -SAC $IsSAC -ImgVer $ReleaseVersion

    $DashboardPath = "$ReportingLocation\$SequenceIs\$DeviceEnvironment\$ReleaseVersion\Dashboard.txt"

    $DashboardLocation = "$ReportingLocation\$SequenceIs\$DeviceEnvironment\$ReleaseVersion"

    $WinBuild = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "CurrentBuild" -ErrorAction Ignore

    $WinDisplayVersion = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "DisplayVersion" -ErrorAction Ignore

    $WinEdition = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "EditionID" -ErrorAction Ignore

    $WinType = $WinBuild + ", " + $WinDisplayVersion + " " + $WinEdition

    if($SuccessMarker -eq $FailedStepName)
    {
        debug "Execution Result is a SUCCESS"

        debug "Performing Dashboard file operations..."

        DashboardEntryOps -DashboardPath $DashboardPath -Name $ComputerName -OSVer $WinType -FailedStep "Successful Execution" -ReturnCode "None" -PostOps "No" -PostOpsTime "NULL"

        debug "Performing log retrieval operations..."

        LogRetrievalOps -MachineName $ComputerName -SharePath $DashboardLocation -LocalLogPath $LocalSMSTSLogPath -Mode "Clear"

        debug "Performing registry values branding..."

        RegBrandOps -RegPath $RegistryPath -SequenceType $SequenceIs -Result "SuccessfulExecution" -PostOpsPerformed "No" -PostOpsTime "NULL"

        debug "Script Execution finished. Exiting..."

        exit 0
    }
    else
    {
        debug "Execution Result is a FAILURE"

        DashboardEntryOps -DashboardPath $DashboardPath -Name $ComputerName -OSVer $WinType -FailedStep $FailedStepName -ReturnCode $FailedStepReturnCode -PostOps "No" -PostOpsTime "NULL"

        debug "Performing log retrieval operations..."

        LogRetrievalOps -MachineName $ComputerName -SharePath $DashboardLocation -LocalLogPath $LocalSMSTSLogPath -Mode "Replace"

        debug "Performing registry values branding..."

        RegBrandOps -RegPath $RegistryPath -SequenceType $SequenceIs -Result "Failed_$FailedStepName" -PostOpsPerformed "No" -PostOpsTime "NULL"

        debug "Script Execution finished. Exiting..."

        exit 0
    }
}

if(("Yes" -eq $IsBFS) -and ("Yes" -eq $IsSAC))
{
    debug "Executing Task Sequence is a SAC BFS sequence."

    $SequenceIs = "SAC_BFS"

    DirectoryOps -Location $ReportingLocation -Environment $DeviceEnvironment -BFS $IsBFS -SAC $IsSAC -ImgVer $ReleaseVersion

    $DashboardPath = "$ReportingLocation\$SequenceIs\$DeviceEnvironment\$ReleaseVersion\Dashboard.txt"

    $DashboardLocation = "$ReportingLocation\$SequenceIs\$DeviceEnvironment\$ReleaseVersion"

    $WinBuild = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "CurrentBuild" -ErrorAction Ignore

    $WinDisplayVersion = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "DisplayVersion" -ErrorAction Ignore

    $WinEdition = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "EditionID" -ErrorAction Ignore

    $WinType = $WinBuild + ", " + $WinDisplayVersion + " " + $WinEdition

    if($SuccessMarker -eq $FailedStepName)
    {
        debug "Execution Result is a SUCCESS"

        debug "Performing Dashboard file operations..."

        DashboardEntryOps -DashboardPath $DashboardPath -Name $ComputerName -OSVer $WinType -FailedStep "Successful Execution" -ReturnCode "None" -PostOps "No" -PostOpsTime "NULL"

        debug "Performing log retrieval operations..."

        LogRetrievalOps -MachineName $ComputerName -SharePath $DashboardLocation -LocalLogPath $LocalSMSTSLogPath -Mode "Clear"

        debug "Performing registry values branding..."

        RegBrandOps -RegPath $RegistryPath -SequenceType $SequenceIs -Result "SuccessfulExecution" -PostOpsPerformed "No" -PostOpsTime "NULL"

        debug "Script Execution finished. Exiting..."

        exit 0
    }
    else
    {
        debug "Execution Result is a FAILURE"

        DashboardEntryOps -DashboardPath $DashboardPath -Name $ComputerName -OSVer $WinType -FailedStep $FailedStepName -ReturnCode $FailedStepReturnCode -PostOps "No" -PostOpsTime "NULL"

        debug "Performing log retrieval operations..."

        LogRetrievalOps -MachineName $ComputerName -SharePath $DashboardLocation -LocalLogPath $LocalSMSTSLogPath -Mode "Replace"

        debug "Performing registry values branding..."

        RegBrandOps -RegPath $RegistryPath -SequenceType $SequenceIs -Result "Failed_$FailedStepName" -PostOpsPerformed "No" -PostOpsTime "NULL"

        debug "Script Execution finished. Exiting..."

        exit 0
    }

}
