<#
    .SYNOPSIS
        Removes the switch parameters that were passed with the value $false.

    .DESCRIPTION
        PowerShell keeps an explicitly passed switch in $PSBoundParameters even when its value is
        $false, for example -DisableTelemetry:$false. Win11Debloat reads $script:Params by key, so
        such a switch would count as requested. The elevated relaunch in Win11Debloat.ps1 and
        Scripts/Get.ps1 start the script with powershell.exe -File, which cannot pass a value to a
        switch, so they already leave these switches out. Removing them once, where $script:Params
        is created, gives the same result however the script is started: a switch with the value
        $false counts as not passed.

        The dictionary is changed in place. Values that are not switches are kept as they are.

    .PARAMETER Parameters
        The parameter dictionary to clean up, normally $script:Params (the script's $PSBoundParameters).
#>
function Remove-FalseSwitchParameters {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Parameters
    )

    # Copy the keys first, a dictionary cannot change while it is enumerated
    foreach ($name in @($Parameters.Keys)) {
        $value = $Parameters[$name]
        if ($value -is [System.Management.Automation.SwitchParameter] -and -not $value.IsPresent) {
            [void]$Parameters.Remove($name)
        }
    }
}
