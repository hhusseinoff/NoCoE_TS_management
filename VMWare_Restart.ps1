param(
[string]$Region,
[string]$MachineName,
[string]$Action
)


function debug($message)
{
    write-host "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message"
    Add-Content -Path "$PSScriptRoot\ServersideLogs\VMWare_Restarter.log" -Value "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message" 
}

function debug_FailSkip([string]$DCName,[string]$Type,[string]$Reason)
{
    $FileExists = Test-Path -Path "$PSScriptRoot\ServersideLogs\ShortLogs\VMWare_Restarter_FailSkip.txt" -PathType Leaf

    if($false -eq $FileExists)
    {
        Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\VMWare_Restarter_FailSkip.txt" -Value "--Timestamp(UTC)--`tMachineName`tType`tReason" 
    }

    Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\VMWare_Restarter_FailSkip.txt" -Value "$($(Get-Date).ToUniversalTime())`t$DCName`t$Type`t$Reason" 
}

function debug_Success([string]$Region,[string]$DCName,[string]$RebootType)
{
    $FileExists = Test-Path -Path "$PSScriptRoot\ServersideLogs\ShortLogs\VMWare_Restarter_Success.txt" -PathType Leaf

    if($false -eq $FileExists)
    {
        Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\VMWare_Restarter_Success.txt" -Value "--Timestamp(UTC)--`tRegion`tMachineName`tReboot Type" 
    }

    Add-Content -Path "$PSScriptRoot\ServersideLogs\ShortLogs\VMWare_Restarter_Success.txt" -Value "$($(Get-Date).ToUniversalTime())`t$Region`t$DCName`t$RebootType" 
}

function Connect_E1_Vcenters {

$passwordE1 = ConvertTo-SecureString "something" -AsPlainText -Force


$E1_VMWareCred = New-Object System.Management.Automation.PSCredential ("something_E1",$passwordE1)

Connect-VIServer -Server servername1 -Credential $E1_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername2 -Credential $E1_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername3 -Credential $E1_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername4 -Credential $E1_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername5 -Credential $E1_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername6 -Credential $E1_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername7 -Credential $E1_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername8 -Credential $E1_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername9 -Credential $E1_VMWareCred -ErrorAction SilentlyContinue

}

function Connect_E2_Vcenters{

$passwordE2 = ConvertTo-SecureString "something" -AsPlainText -Force


$E2_VMWareCred = New-Object System.Management.Automation.PSCredential ("something_E2",$passwordE2)

Connect-VIServer -Server servername1 -Credential $E2_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername2 -Credential $E2_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername3 -Credential $E2_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername4 -Credential $E2_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername5 -Credential $E2_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername6 -Credential $E2_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername7 -Credential $E2_VMWareCred -ErrorAction SilentlyContinue

}

function Connect_NA1_Vcenters{

$passwordNA1 = ConvertTo-SecureString "something" -AsPlainText -Force


$NA1_VMWareCred = New-Object System.Management.Automation.PSCredential ("something_NA1",$passwordNA1)

Connect-VIServer -Server servername1 -Credential $NA1_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername2 -Credential $NA1_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername3 -Credential $NA1_VMWareCred -ErrorAction SilentlyContinue

}

function Connect_NA2_Vcenters{

$passwordNA2 = ConvertTo-SecureString "something" -AsPlainText -Force


$NA2_VMWareCred = New-Object System.Management.Automation.PSCredential ("something_NA2",$passwordNA2)

Connect-VIServer -Server servername1 -Credential $NA2_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername2 -Credential $NA2_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername3 -Credential $NA2_VMWareCred -ErrorAction SilentlyContinue

}

function Connect_AP1_Vcenters{

$passwordAP1 = ConvertTo-SecureString "something" -AsPlainText -Force


$AP1_VMWareCred = New-Object System.Management.Automation.PSCredential ("something_AP1",$passwordAP1)

Connect-VIServer -Server servername1 -Credential $AP1_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername2 -Credential $AP1_VMWareCred -ErrorAction SilentlyContinue

}

function Connect_AP2_Vcenters{

$passwordAP2 = ConvertTo-SecureString "something" -AsPlainText -Force


$AP2_VMWareCred = New-Object System.Management.Automation.PSCredential ("something_AP2",$passwordAP2)

Connect-VIServer -Server servername1 -Credential $AP2_VMWareCred -ErrorAction SilentlyContinue
Connect-VIServer -Server servername2 -Credential $AP2_VMWareCred -ErrorAction SilentlyContinue

}


$VCenterConnectionError = "Blank"

debug "----------------------------Script initiated-----------------------------"

debug "Working on: $MachineName in region $Region, restart type: $Action"

debug "Connecting to the appropriate Vcenters for $Region..."

switch -Exact ($Region)
    {
        "E1"
        {
            Connect_E1_Vcenters
        }

        "E2"
        {
            Connect_E2_Vcenters
        }

        "AP1"
        {
            Connect_AP1_Vcenters
        }

        "AP2"
        {
            Connect_AP2_Vcenters
        }

        "NA1"
        {
            Connect_NA1_Vcenters
        }

        "NA2"
        {
            Connect_NA2_Vcenters
        }

        Default
        {
            $VCenterConnectionError = "Error"
        }
    }

if("Error" -eq $VCenterConnectionError)
{
    debug "Invalid Parameter given for a region. Couldn't connect to vcenters."

    $FailSkipReason = "Invalid Parameter given for a region. Couldn't connect to vcenters."

    debug_FailSkip -DCName $MachineName -Type "FAIL" -Reason $FailSkipReason

    exit 0
}

debug "Vcenters connected, Proceeding to obtain machine Data..."

$MachineData = Get-VM -Name $MachineName -ErrorAction SilentlyContinue

if($null -ne $MachineData)
{
    debug "Machine Data obtained. Proceeding to enact action..."
    
    if("Hard" -eq $Action)
    {
        debug "Passed action is $Action. A hard reboot will be attempted..."
        
        $ActionAttempt = Restart-VM -VM $MachineData -Confirm:$false -ErrorAction Ignore -WarningAction Ignore -InformationAction Ignore

        if($null -eq $ActionAttempt)
        {
            debug "Failed to initiate a hard reboot."

            $FailSkipReason = "Failed to initiate a hard reboot."

            debug_FailSkip -DCName $MachineName -Type "FAIL" -Reason $FailSkipReason

            exit 0
        }

        debug "Action Performed."

        debug "Appending Data to the success log..."

        debug_Success -Region $Region -DCName $MachineName -RebootType $Action
    }
    if("Soft" -eq $Action)
    {
        debug "Passed action is $Action. An OS-level restart command will be attempted..."
        
        $ActionAttempt = Restart-VMGuest -VM $MachineData -Confirm:$false -ErrorAction Ignore -WarningAction Ignore -InformationAction Ignore

        if($null -eq $ActionAttempt)
        {
            debug "Failed to initiate a soft reboot."

            $FailSkipReason = "Failed to initiate a soft reboot."

            debug_FailSkip -DCName $MachineName -Type "FAIL" -Reason $FailSkipReason

            exit 0
        }

        debug "Action Performed."

        debug "Appending Data to the success log..."

        debug_Success -Region $Region -DCName $MachineName -RebootType $Action

        exit 0

}
}
else
{
    debug "Failed to get VM data for $MachineName"

    $FailSkipReason = "Failed to get VM data."

    debug_FailSkip -DCName $MachineName -Type "FAIL" -Reason $FailSkipReason

    exit 0
}


