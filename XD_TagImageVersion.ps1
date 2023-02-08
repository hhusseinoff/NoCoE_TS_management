###################################################################################################################################################
##
##        Script to automatically tag a successfully built machine with the appropriate ImgVer XD Tag for the release
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

Param(
	[string]$ImageVersion,
	[string]$ComputerName
	)

##-------------------------------------------------------------------------------------------------------------------------------------------------


##
##------------------Function for Verbose Logging---------------------------------------------------------------------------------------------------

function debug($message)
{
    Write-Host "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message"
    Add-Content -Path "$PSScriptRoot\ServersideLogs\XD_ImgVerTag.log" -Value "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message" 
}

##-------------------------------------------------------------------------------------------------------------------------------------------------


##
##------------------Function for Fails Logging-----------------------------------------------------------------------------------------------------

function debug_FailSkip([string]$DCName,[string]$Type,[string]$Reason,[string]$Controller)
{
    $FileExists = Test-Path -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_ImgVerTag_FailSkip.txt" -PathType Leaf

    if($false -eq $FileExists)
    {
        Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_ImgVerTag_FailSkip.txt" -Value "--Timestamp(UTC)--`tMachine Name`tType`tReason`tController" 
    }

    Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_ImgVerTag_FailSkip.txt" -Value "$($(Get-Date).ToUniversalTime())`t$DCName`t$Type`t$Reason`t$Controller" 
}

##-------------------------------------------------------------------------------------------------------------------------------------------------


##
##------------------Function for Success Logging---------------------------------------------------------------------------------------------------

function debug_Success([string]$DCName,[string]$Controller,[string]$Tag)
{
    $FileExists = Test-Path -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_ImgVerTag_Success.txt" -PathType Leaf

    if($false -eq $FileExists)
    {
        Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_ImgVerTag_Success.txt" -Value "--Timestamp(UTC)--`tMachine Name`tController`tXD ImgVer Tag" 
    }

    Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\XD_ImgVerTag_Success.txt" -Value "$($(Get-Date).ToUniversalTime())`t$DCName`t$Controller`t$Tag" 
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
##------------------Main Script Body---------------------------------------------------------------------------------------------------------------
##

debug "----------------------------Script initiated-----------------------------"

debug "Working on $ComputerName and $ImageVersion..."

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

debug "Machine Data retrieved. Proceeding to check which ImgVer tags $ComputerName is associated with..."

$CurrentTags = Get-BrokerTag -MachineUid $XD_Object.uid -AdminAddress $XDController -ErrorAction SilentlyContinue

$CurrentTagNames = $CurrentTags.Name

if($null -ne $CurrentTagNames)
{
    debug "Converting to a comma-separated string (necessary in case $ComputerName is associated with more than 1 ImgVer Tag currently)..."

    $CurrentTagString = [System.String]::Join(",",$CurrentTags.Name)

    debug "Current tags:"

    debug "$CurrentTagString"
}
else
{
    debug "There aren't any tags associated with the machine."

    $CurrentTagString = "Blank"
}

##
##------------------Logic for handling cases where the machine has no previous XD ImgVer Tags---------------------------------------------------------------------------------------------------------------
##

if( ($false -eq ($CurrentTagString.Contains("ImgVer"))) -or ($null -eq $CurrentTag) )
{
    debug "There aren't any ImgVer tags associated with the machine."

    debug "Checking if a XD ImgVer tag for $ImageVersion exists..."

    $TagExists = Get-BrokerTag -Name "ImgVer $ImageVersion" -AdminAddress $XDController -ErrorAction SilentlyContinue

    if($null -ne $TagExists)
    {
        debug "An ImgVer Tag for $ImageVersion already exists in XD. Proceeding to associate the machine with it..."

        Add-BrokerTag -Name "ImgVer $ImageVersion" -Machine $XD_Object -AdminAddress $XDController

        debug "Proceeding to verify if the association was successful..."

        $OperationCheck = Get-BrokerTag -MachineUid $XD_Object.uid -AdminAddress $XDController -ErrorAction SilentlyContinue | select Name

        if($true -eq (($OperationCheck.Name).Contains("ImgVer $ImageVersion")))
        {
            debug "Association successful. Appending to the success file..."

            debug_Success -DCName $ComputerName -Controller $XDController -Tag "ImgVer $ImageVersion"

            exit 0
        }
        else
        {
            debug "Failed to associated $ComputerName with tag: ImgVer $ImageVersion"

            $FailSkipReason = "Failed to associate the machine with a tag: ImgVer $ImageVersion."

            debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController

            exit 0
        }
    }
    else
    {
        debug "An ImgVer Tag for $ImageVersion has never been created at $XDController before."

        debug "Proceeding to create it..."

        New-BrokerTag -Name "ImgVer $ImageVersion" -AdminAddress $XDController

        debug "Verifying if the creation was successful..."

        $OperationCheck = Get-BrokerTag -Name "ImgVer $ImageVersion" -AdminAddress $XDController -ErrorAction SilentlyContinue | select Name

        if($true -eq (($OperationCheck.Name).Contains("ImgVer $ImageVersion")))
        {
            debug "XD ImgVer tag successfully created. Value:"

            debug "$($OperationCheck.Name)"

            debug "Proceeding to associate the machine with it..."

            Add-BrokerTag -Name "ImgVer $ImageVersion" -Machine $XD_Object -AdminAddress $XDController

            debug "Verifying if association was successful..."

            $OperationCheck = Get-BrokerTag -MachineUid $XD_Object.uid -AdminAddress $XDController -ErrorAction SilentlyContinue

            if($true -eq (($OperationCheck.Name).Contains("ImgVer $ImageVersion")))
            {
                debug "Association successful. Appending to the success file..."

                debug_Success -DCName $ComputerName -Controller $XDController -Tag "ImgVer $ImageVersion"

                exit 0
            }
            else
            {
                debug "Failed to associated $ComputerName with tag: ImgVer $ImageVersion"

                $FailSkipReason = "Failed to associate the machine with a tag: ImgVer $ImageVersion."

                debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController

                exit 0
            }
        }
        else
        {
            debug "Failed to create an ImgVer tag for $ImageVersion."

            $FailSkipReason = "Failed to create and ImgVer tag for $ImageVersion."

            debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController
        }
    }
}
else
{
    ##
    ##------------------Logic for handling cases where the machine has previous XD ImgVer Tags---------------------------------------------------------------------------------------------------------------
    ##
    
    debug "Old ImgVer tags, associated with $ComputerName have been detected."

    debug "Proceeding to remove them."

    foreach($OldTag in $CurrentTags)
    {
        $OldTagName = $OldTag.Name

        if($OldTagName -like "ImgVer *")
        {
            Remove-BrokerTag -Tags $OldTag -Machine $XD_Object -AdminAddress $XDController

            if($Error)
            {
                debug "Failed to remove old ImgVer tags."

                $FailSkipReason = "Failed to remove old ImgVer tags."

                debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController

                exit 0
            }
        }
    }

    debug "Removal Complete."

    debug "Checking if a XD ImgVer tag for $ImageVersion exists..."

    $TagExists = Get-BrokerTag -Name "ImgVer $ImageVersion" -AdminAddress $XDController -ErrorAction SilentlyContinue
    
    if($null -ne $TagExists)
    {
        debug "An ImgVer Tag for $ImageVersion already exists in XD. Proceeding to associate the machine with it..."

        Add-BrokerTag -Name "ImgVer $ImageVersion" -Machine $XD_Object -AdminAddress $XDController

        debug "Proceeding to verify if the association was successful..."

        $OperationCheck = Get-BrokerTag -MachineUid $XD_Object.uid -AdminAddress $XDController -ErrorAction SilentlyContinue | select Name

        if($true -eq (($OperationCheck.Name).Contains("ImgVer $ImageVersion")))
        {
            debug "Association successful. Appending to the success file..."

            debug_Success -DCName $ComputerName -Controller $XDController -Tag "ImgVer $ImageVersion"

            exit 0
        }
        else
        {
            debug "Failed to associated $ComputerName with tag: ImgVer $ImageVersion"

            $FailSkipReason = "Failed to associate the machine with a tag: ImgVer $ImageVersion."

            debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController

            exit 0
        }

    }
    else
    {
        debug "An ImgVer Tag for $ImageVersion has never been created at $XDController before."

        debug "Proceeding to create it..."

        New-BrokerTag -Name "ImgVer $ImageVersion" -AdminAddress $XDController

        debug "Verifying if the creation was successful..."

        $OperationCheck = Get-BrokerTag -Name "ImgVer $ImageVersion" -AdminAddress $XDController -ErrorAction SilentlyContinue | select Name

        if($true -eq (($OperationCheck.Name).Contains("ImgVer $ImageVersion")))
        {
            debug "XD ImgVer tag successfully created. Value:"

            debug "$($OperationCheck.Name)"

            debug "Proceeding to associate the machine with it..."

            Add-BrokerTag -Name "ImgVer $ImageVersion" -Machine $XD_Object -AdminAddress $XDController

            debug "Verifying if association was successful..."

            $OperationCheck = Get-BrokerTag -MachineUid $XD_Object.uid -AdminAddress $XDController -ErrorAction SilentlyContinue

            if($true -eq (($OperationCheck.Name).Contains("ImgVer $ImageVersion")))
            {
                debug "Association successful. Appending to the success file..."

                debug_Success -DCName $ComputerName -Controller $XDController -Tag "ImgVer $ImageVersion"

                exit 0
            }
            else
            {
                debug "Failed to associated $ComputerName with tag: ImgVer $ImageVersion"

                $FailSkipReason = "Failed to associate the machine with a tag: ImgVer $ImageVersion."

                debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController

                exit 0
            }
        }
        else
        {
            debug "Failed to create an ImgVer tag for $ImageVersion."

            $FailSkipReason = "Failed to create and ImgVer tag for $ImageVersion."

            debug_FailSkip -DCName $ComputerName -Type "FAIL" -Reason $FailSkipReason -Controller $XDController
        }


    }
}