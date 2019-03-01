function Get-PasswordLastSet
{
    <#
    
    .SYNOPSIS

        Get-PasswordLastSet.ps1 Function: Get-PasswordLastSet
        Author: John Cartrett (@jnqpblc)
        License: BSD 3-Clause
        Required Dependencies: None
        Optional Dependencies: None

    .DESCRIPTION

        Shows similar information to "net accounts /domain" from Windows.

    .LINK

        https://elderec.org/2013/03/powershell-determine-when-active-directory-password-was-last-set/
        https://www.blackops.ca/2013/05/06/cant-change-password-the-password-does-not-meet-the-password-policy-requirements/

    .PARAMETER SAMAccountName

	    SAMAccountName is needed for the user specific information pulled from Active Directory.
      
    .EXAMPLE

	    Get-PasswordLastSet some.user
	    Get-PasswordLastSet -SAMAccountName some.user
      
    #> 

    param (
	    [parameter(Mandatory=$true, HelpMessage="SAMAccountName for user")]
      $SAMAccountName
    )

    $root = [ADSI]''
    $searcher = new-object System.DirectoryServices.DirectorySearcher($root)
    $searcher.filter = "(&(objectClass=user)(sAMAccountName=$SAMAccountName))"
    $user = $searcher.findall()

    $User = [ADSI]$user[0].path

    # get domain password policy (max pw age)
    $CurrentDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
    $Domain = [ADSI]"LDAP://$CurrentDomain"
    $MinPwdLength = $Domain.minPwdLength
    $PwdHistory = $Domain.pwdHistoryLength
    $PwdComplexity = $Domain.pwdProperties.Value
    $LockoutThreshold = $Domain.lockoutThreshold.Value

    $XPA = $Domain.maxPwdAge.Value
    $NPA = $Domain.minPwdAge.Value
    $FLO = $Domain.forceLogoff.Value
    $LDR = $Domain.lockoutDuration.Value
    $LWN = $Domain.lockOutObservationWindow.Value

    # get Int64 (100-nanosecond intervals).
    $lngMaxPwdAge = $Domain.ConvertLargeIntegerToInt64($XPA)
    $lngMinPwdAge = $Domain.ConvertLargeIntegerToInt64($NPA)
    $lngForceLogoff = $Domain.ConvertLargeIntegerToInt64($FLO)
    $lngLockoutDuration = $Domain.ConvertLargeIntegerToInt64($LDR)
    $lngLockoutWindow = $Domain.ConvertLargeIntegerToInt64($LWN)

    # get days
    $MaxPwdAge = -$lngMaxPwdAge/(600000000 * 1440)
    $MinPwdAge = -$lngMinPwdAge/(600000000 * 1440)
    $ForceLogoff = -$lngForceLogoff/(600000000)
    $LockoutDuration = -$lngLockoutDuration/(600000000)
    $LockoutWindow = -$lngLockoutWindow/(600000000)

    # check if password can expire or not
    $UAC = $User.userAccountControl
    $blnPwdExpires = -not (($UAC.Item(0) -band 64) -or ($UAC.Item(0) -band 65536))

    # when was pw last set?
    $PLS = $User.pwdLastSet.Value

    # convert to int64
    $lngPwdLastSet = $User.ConvertLargeIntegerToInt64($PLS)

    # convert to ad date
    $Date = [DateTime]$lngPwdLastSet
    if ($Date -eq 0) {
        $PwdLastSet = "<Never>"
    }
    else {
        $PwdLastSet = $Date.AddYears(1600).ToLocalTime()
    }

    # is the password expired?
    $blnExpired = $False
    $Now = Get-Date
    if ($blnPwdExpires) {
        if ($Date -eq 0) {
            $blnExpired = $True
        }
        else
        {
            if ($PwdLastSet.AddDays($MaxPwdAge) -le $Now) {
                $blnExpired = $True
            }
        }
    }

    Write-Host "Last password set date and time: `t`t`t $PwdLastSet"
    Write-Host "Password expiration setting: `t`t`t $blnPwdExpires"
    Write-Host "Password expiration status: `t`t`t $blnExpired"
    Write-Host "Force user logoff how long after time expires?: `t $ForceLogoff"
    Write-Host "Minimum password age (days): `t`t`t $MinPwdAge"
    Write-Host "Maximum password age (days): `t`t`t $MaxPwdAge"
    Write-Host "Minimum password length: `t`t`t`t $MinPwdLength"
    Write-Host "Password complexity requirement: `t`t`t $PwdComplexity"
    Write-Host "Length of password history maintained: `t`t $PwdHistory"
    Write-Host "Lockout threshold: `t`t`t`t $LockoutThreshold"
    Write-Host "Lockout duration (minutes): `t`t`t $LockoutDuration"
    Write-Host "Lockout observation window (minutes): `t`t $LockoutWindow"
    Write-Host "The command completed successfully."

}
