###################################################################################################################################################
##
##        Script to automatically tag a a machine with the appropriate XD Tag for a successfully built / upgraded device or not (names hardcoded)
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
[string]$ComputerName,
[string]$Mode,
[string]$SequenceType
)

##-------------------------------------------------------------------------------------------------------------------------------------------------

##
##------------------Function for Verbose Logging---------------------------------------------------------------------------------------------------

function debug($message)
{
    Write-Host "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message"
    Add-Content -Path "$PSScriptRoot\ServersideLogs\XD_SuccessFailTag.log" -Value "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message" 
}

##-------------------------------------------------------------------------------------------------------------------------------------------------

##
##------------------Function for Fails Logging-----------------------------------------------------------------------------------------------------

function debug_FailSkip([string]$DCName,[string]$Type,[string]$Reason,[string]$Controller)
{
    $FileExists = Test-Path -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_SuccessFailTag_FailSkip.txt" -PathType Leaf

    if($false -eq $FileExists)
    {
        Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_SuccessFailTag_FailSkip.txt" -Value "--Timestamp(UTC)--`tMachine Name`tType`tReason`tController" 
    }

    Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_SuccessFailTag_FailSkip.txt" -Value "$($(Get-Date).ToUniversalTime())`t$DCName`t$Type`t$Reason`t$Controller" 
}

##-------------------------------------------------------------------------------------------------------------------------------------------------

##
##------------------Function for Success Logging---------------------------------------------------------------------------------------------------

function debug_Success([string]$DCName,[string]$Controller,[string]$Tag)
{
    $FileExists = Test-Path -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_SuccessFailTag_Success.txt" -PathType Leaf

    if($false -eq $FileExists)
    {
        Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_SuccessFailTag_Success.txt" -Value "--Timestamp(UTC)--`tMachine Name`tController`tMaintenance Mode" 
    }

    Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_SuccessFailTag_Success.txt" -Value "$($(Get-Date).ToUniversalTime())`t$DCName`t$Controller`t$Tag" 
}

##-------------------------------------------------------------------------------------------------------------------------------------------------

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
##------------------Setting Template variables for XD Controller and Domain Name-------------------------------------------------------------------

$XDController = "Blank"
$DomainName = "Blank"

##-------------------------------------------------------------------------------------------------------------------------------------------------


##
##------------------Setting constants for the Success/Fail Build Tag names (must already exist at each XD Controller / Site------------------------

$BuildSuccessTagName = "Build Success"
$BuildFailTagName = "Build Fail"

##-------------------------------------------------------------------------------------------------------------------------------------------------


##
##------------------Setting constants for the Success/Fail Upgrade Tag names (must already exist at each XD Controller / Site----------------------

$UpgradeSuccessTagName = "Upgrade Success"
$UpgradeFailTagName = "Upgrade Fail"

##-------------------------------------------------------------------------------------------------------------------------------------------------


##
##------------------Main Script Body---------------------------------------------------------------------------------------------------------------
##

debug "----------------------------Script initiated-----------------------------"

debug "Working on $ComputerName, mode: $Mode, Sequence type: $SequenceType..."

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

debug "Machine Data retrieved."

##
##------------------Logic for handling BFS type sequences---------------------------------------------------------------------------------------------------------------
##

if(($SequenceType -eq "BFS") -or ($SequenceType -eq "SAC_BFS"))
{
    debug "Sequence type is $SequenceType."

    if($Mode -eq "Success")
    {
        debug "Input mode is Success."

        debug "Proceeding to retrieve current tags for $ComputerName..."

        $CurrentTags = Get-BrokerTag -MachineUid $XD_Object.uid -AdminAddress $XDController

        $CurrentTagNames = $CurrentTags.Name

        if($null -ne $CurrentTagNames)
        {
            debug "Converting to a comma-separated string (necessary in case $ComputerName is associated with more than 1 Tag currently)..."

            $CurrentTagString = [System.String]::Join(",",$CurrentTagNames)

            debug "Current tags: $CurrentTagString"
        }
        else
        {
            debug "There aren't any tags associated with the machine."

            $CurrentTagString = "Blank"
        }

        if( ($false -eq ($CurrentTagString.Contains($BuildSuccessTagName))) -and ($false -eq ($CurrentTagString.Contains($BuildFailTagName))) )
        {
            debug "No Build Tags currently associated with $ComputerName."

            debug "Proceeding to associate $ComputerName with the $BuildSuccessTagName Tag..."

            Add-BrokerTag -Name $BuildSuccessTagName -Machine $XD_Object -AdminAddress $XDController

            debug "Proceeding to verify if the association was successful..."

            $OperationCheck = Get-BrokerTag -MachineUid $XD_Object.uid -AdminAddress $XDController | select Name

            if($true -eq (($OperationCheck.Name).Contains($BuildSuccessTagName)))
            {
                debug "Association successful. Appending to the success file..."

                debug_Success -DCName $ComputerName -Controller $XDController -Tag $BuildSuccessTagName

                exit 0
            }
            else
            {
                debug "Failed to associated $ComputerName with tag: $BuildSuccessTagName"

                $FailSkipReason = "Failed to associate the machine with a tag: $BuildSuccessTagName."

                debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController

                exit 0
            }
        }
        else
        {
            debug "Previous Build Success/Fail Tags detected. Clearing..."

            Remove-BrokerTag -Name $BuildSuccessTagName -Machine $XD_Object -AdminAddress $XDController -ErrorAction SilentlyContinue

            Remove-BrokerTag -Name $BuildFailTagName -Machine $XD_Object -AdminAddress $XDController -ErrorAction SilentlyContinue

            debug "Previous Build Success/Fail Tags cleared. debug Proceeding to associate $ComputerName with the $BuildSuccessTagName Tag..."

            Add-BrokerTag -Name $BuildSuccessTagName -Machine $XD_Object -AdminAddress $XDController

            debug "Proceeding to verify if the association was successful..."

            $OperationCheck = Get-BrokerTag -MachineUid $XD_Object.uid -AdminAddress $XDController | select Name

            if($true -eq (($OperationCheck.Name).Contains($BuildSuccessTagName)))
            {
                debug "Association successful. Appending to the success file..."

                debug_Success -DCName $ComputerName -Controller $XDController -Tag $BuildSuccessTagName

                exit 0
            }
            else
            {
                debug "Failed to associated $ComputerName with tag: $BuildSuccessTagName"

                $FailSkipReason = "Failed to associate the machine with a tag: $BuildSuccessTagName."

                debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController

                exit 0
            }
        }


    }
    if($Mode -eq "Fail")
    {
        debug "Input mode is Fail."

        debug "Proceeding to retrieve current tags for $ComputerName..."

        $CurrentTags = Get-BrokerTag -MachineUid $XD_Object.uid -AdminAddress $XDController

        $CurrentTagNames = $CurrentTags.Name

        if($null -ne $CurrentTagNames)
        {
            debug "Converting to a comma-separated string (necessary in case $ComputerName is associated with more than 1 Tag currently)..."

            $CurrentTagString = [System.String]::Join(",",$CurrentTagNames)

            debug "Current tags: $CurrentTagString"
        }
        else
        {
            debug "There aren't any tags associated with the machine."

            $CurrentTagString = "Blank"
        }

        if( ($false -eq ($CurrentTagString.Contains($BuildSuccessTagName))) -and ($false -eq ($CurrentTagString.Contains($BuildFailTagName))) )
        {
            debug "No Build Tags currently associated with $ComputerName."

            debug "Proceeding to associate $ComputerName with the $BuildFailTagName Tag..."

            Add-BrokerTag -Name $BuildFailTagName -Machine $XD_Object -AdminAddress $XDController

            debug "Proceeding to verify if the association was successful..."

            $OperationCheck = Get-BrokerTag -MachineUid $XD_Object.uid -AdminAddress $XDController | select Name

            if($true -eq (($OperationCheck.Name).Contains($BuildFailTagName)))
            {
                debug "Association successful. Appending to the success file..."

                debug_Success -DCName $ComputerName -Controller $XDController -Tag $BuildFailTagName

                exit 0
            }
            else
            {
                debug "Failed to associated $ComputerName with tag: $BuildFailTagName"

                $FailSkipReason = "Failed to associate the machine with a tag: $BuildFailTagName."

                debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController

                exit 0
            }
        }
        else
        {
            debug "Previous Build Success/Fail Tags detected. Clearing..."

            Remove-BrokerTag -Name $BuildSuccessTagName -Machine $XD_Object -AdminAddress $XDController -ErrorAction SilentlyContinue

            Remove-BrokerTag -Name $BuildFailTagName -Machine $XD_Object -AdminAddress $XDController -ErrorAction SilentlyContinue

            debug "Previous Build Success/Fail Tags cleared. debug Proceeding to associate $ComputerName with the $BuildFailTagName Tag..."

            Add-BrokerTag -Name $BuildFailTagName -Machine $XD_Object -AdminAddress $XDController

            debug "Proceeding to verify if the association was successful..."

            $OperationCheck = Get-BrokerTag -MachineUid $XD_Object.uid -AdminAddress $XDController | select Name

            if($true -eq (($OperationCheck.Name).Contains($BuildFailTagName)))
            {
                debug "Association successful. Appending to the success file..."

                debug_Success -DCName $ComputerName -Controller $XDController -Tag $BuildFailTagName

                exit 0
            }
            else
            {
                debug "Failed to associated $ComputerName with tag: $BuildFailTagName"

                $FailSkipReason = "Failed to associate the machine with a tag: $BuildFailTagName."

                debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController

                exit 0
            }
        }


    }
}

##
##------------------Logic for handling Upgrade type sequences---------------------------------------------------------------------------------------------------------------
##

if(($SequenceType -eq "Upgrade") -or ($SequenceType -eq "SAC_Upgrade"))
{
    debug "Sequence type is $SequenceType."

    if($Mode -eq "Success")
    {
        debug "Input mode is Success."

        debug "Proceeding to retrieve current tags for $ComputerName..."

        $CurrentTags = Get-BrokerTag -MachineUid $XD_Object.uid -AdminAddress $XDController

        $CurrentTagNames = $CurrentTags.Name

        if($null -ne $CurrentTagNames)
        {
            debug "Converting to a comma-separated string (necessary in case $ComputerName is associated with more than 1 Tag currently)..."

            $CurrentTagString = [System.String]::Join(",",$CurrentTagNames)

            debug "Current tags: $CurrentTagString"
        }
        else
        {
            debug "There aren't any tags associated with the machine."

            $CurrentTagString = "Blank"
        }

        if( ($false -eq ($CurrentTagString.Contains($UpgradeSuccessTagName))) -and ($false -eq ($CurrentTagString.Contains($UpgradeFailTagName))) )
        {
            debug "No Upgrade Tags currently associated with $ComputerName."

            debug "Proceeding to associate $ComputerName with the $UpgradeSuccessTagName Tag..."

            Add-BrokerTag -Name $UpgradeSuccessTagName -Machine $XD_Object -AdminAddress $XDController

            debug "Proceeding to verify if the association was successful..."

            $OperationCheck = Get-BrokerTag -MachineUid $XD_Object.uid -AdminAddress $XDController | select Name

            if($true -eq (($OperationCheck.Name).Contains($UpgradeSuccessTagName)))
            {
                debug "Association successful. Appending to the success file..."

                debug_Success -DCName $ComputerName -Controller $XDController -Tag $UpgradeSuccessTagName

                exit 0
            }
            else
            {
                debug "Failed to associated $ComputerName with tag: $UpgradeSuccessTagName"

                $FailSkipReason = "Failed to associate the machine with a tag: $UpgradeSuccessTagName."

                debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController

                exit 0
            }
        }
        else
        {
            debug "Previous Upgrade Success/Fail Tags Tags detected. Clearing..."

            Remove-BrokerTag -Name $UpgradeSuccessTagName -Machine $XD_Object -AdminAddress $XDController -ErrorAction SilentlyContinue

            Remove-BrokerTag -Name $UpgradeFailTagName -Machine $XD_Object -AdminAddress $XDController -ErrorAction SilentlyContinue

            debug "Previous Upgrade Success/Fail Tags cleared. Proceeding to associate $ComputerName with the $UpgradeSuccessTagName Tag..."

            Add-BrokerTag -Name $UpgradeSuccessTagName -Machine $XD_Object -AdminAddress $XDController

            debug "Proceeding to verify if the association was successful..."

            $OperationCheck = Get-BrokerTag -MachineUid $XD_Object.uid -AdminAddress $XDController | select Name

            if($true -eq (($OperationCheck.Name).Contains($UpgradeSuccessTagName)))
            {
                debug "Association successful. Appending to the success file..."

                debug_Success -DCName $ComputerName -Controller $XDController -Tag $UpgradeSuccessTagName

                exit 0
            }
            else
            {
                debug "Failed to associated $ComputerName with tag: $UpgradeSuccessTagName"

                $FailSkipReason = "Failed to associate the machine with a tag: $UpgradeSuccessTagName."

                debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController

                exit 0
            }
        }


    }
    if($Mode -eq "Fail")
    {
        debug "Input mode is Fail."

        debug "Proceeding to retrieve current tags for $ComputerName..."

        $CurrentTags = Get-BrokerTag -MachineUid $XD_Object.uid -AdminAddress $XDController

        $CurrentTagNames = $CurrentTags.Name

        if($null -ne $CurrentTagNames)
        {
            debug "Converting to a comma-separated string (necessary in case $ComputerName is associated with more than 1 Tag currently)..."

            $CurrentTagString = [System.String]::Join(",",$CurrentTagNames)

            debug "Current tags: $CurrentTagString"
        }
        else
        {
            debug "There aren't any tags associated with the machine."

            $CurrentTagString = "Blank"
        }

        if( ($false -eq ($CurrentTagString.Contains($UpgradeSuccessTagName))) -and ($false -eq ($CurrentTagString.Contains($UpgradeFailTagName))) )
        {
            debug "No Upgrade Tags currently associated with $ComputerName."

            debug "Proceeding to associate $ComputerName with the $UpgradeFailTagName Tag..."

            Add-BrokerTag -Name $UpgradeFailTagName -Machine $XD_Object -AdminAddress $XDController

            debug "Proceeding to verify if the association was successful..."

            $OperationCheck = Get-BrokerTag -MachineUid $XD_Object.uid -AdminAddress $XDController | select Name

            if($true -eq (($OperationCheck.Name).Contains($UpgradeFailTagName)))
            {
                debug "Association successful. Appending to the success file..."

                debug_Success -DCName $ComputerName -Controller $XDController -Tag $UpgradeFailTagName

                exit 0
            }
            else
            {
                debug "Failed to associated $ComputerName with tag: $UpgradeFailTagName"

                $FailSkipReason = "Failed to associate the machine with a tag: $UpgradeFailTagName."

                debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController

                exit 0
            }
        }
        else
        {
            debug "Previous Upgrade Success/Fail Tags detected. Clearing..."

            Remove-BrokerTag -Name $UpgradeSuccessTagName -Machine $XD_Object -AdminAddress $XDController -ErrorAction SilentlyContinue

            Remove-BrokerTag -Name $UpgradeFailTagName -Machine $XD_Object -AdminAddress $XDController -ErrorAction SilentlyContinue

            debug "Previous Upgrade Success/Fail Tags cleared. Proceeding to associate $ComputerName with the $UpgradeFailTagName Tag..."

            Add-BrokerTag -Name $UpgradeFailTagName -Machine $XD_Object -AdminAddress $XDController

            debug "Proceeding to verify if the association was successful..."

            $OperationCheck = Get-BrokerTag -MachineUid $XD_Object.uid -AdminAddress $XDController | select Name

            if($true -eq (($OperationCheck.Name).Contains($UpgradeFailTagName)))
            {
                debug "Association successful. Appending to the success file..."

                debug_Success -DCName $ComputerName -Controller $XDController -Tag $UpgradeFailTagName

                exit 0
            }
            else
            {
                debug "Failed to associated $ComputerName with tag: $UpgradeFailTagName"

                $FailSkipReason = "Failed to associate the machine with a tag: $UpgradeFailTagName."

                debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController

                exit 0
            }
        }


    }
}