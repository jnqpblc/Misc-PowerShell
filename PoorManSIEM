clear; $ErrorActionPreference = 'SilentlyContinue' 

Function Parse-Event
{
    # Credit: https://github.com/RamblingCookieMonster/PowerShell/blob/master/Get-WinEventData.ps1
    param
    (
        [Parameter(ValueFromPipeline=$true)] $Event
    )

    Process
    {
        foreach ($Entry in $Event)
        {
            $XML = [xml]$Entry.ToXml()
            $X = $XML.Event.EventData.Data
            For ($i=0; $i -lt $X.count; $i++)
            {
                $Entry = Add-Member -InputObject $entry -MemberType NoteProperty -Name "$($X[$i].name)" -Value $X[$i].'#text' -Force -Passthru
            }
            $Entry
        }
    }
}

Function Write-Alert($Type, $Output)
{
    Write-Host "`n`t---------- $($Type) Alert ----------`n"
    Write-Host "`t$($Output)`n"
}

Write-Host "`n`t[+] A Poor Man's SIEM Dashboard! (Ctrl-C to Exit)`n"

$LogSecurityIndex = (Get-WinEvent -FilterHashtable @{Logname="Security";} -MaxEvents 1).RecordId
$LogForwardedEventsIndex  = (Get-WinEvent -FilterHashtable @{Logname="ForwardedEvents";} -MaxEvents 1).RecordId
$LogWindowsPowerShellIndex = (Get-WinEvent -FilterHashtable @{Logname="Windows PowerShell";} -MaxEvents 1).RecordId
$LogWECProcessExecutionIndex = (Get-WinEvent -FilterHashtable @{Logname="WEC-Process-Execution";} -MaxEvents 1).RecordId

while ($true)
{
    Start-Sleep -Seconds 60

    $LogSecurityNewIndex  = (Get-WinEvent -FilterHashtable @{Logname="Security";} -MaxEvents 1).RecordId
    
    #Write-Output "`t[*] Current Log Index: $($LogSecurityNewIndex - $LogSecurityIndex)"
        
    if ($LogSecurityNewIndex -gt $LogSecurityIndex)
    {
        # Credit: https://adsecurity.org/?p=3458
        Get-WinEvent -FilterHashtable @{Logname="Security";} -MaxEvents ($LogSecurityNewIndex - $LogSecurityIndex) | Parse-Event | sort RecordId | % {
           
            if (($_.Id -eq 4624) -and ($_.Message -match "Account Name:\s+Administrator") -and ($_.Message -notmatch "Source Network Address:\s+::1") -and ($_.Message -notmatch "Source Network Address:\s+fe80::")) # An account was successfully logged on.
            {
                Write-Alert "Credential Misuse Detection" "$($_.TimeCreated) - Detected the misuse on the high-vaule account $(($_.Message.Split("`n")[19]).Split("`t")[3])/$(($_.Message.Split("`n")[18]).Split("`t")[3]) from $(($_.Message.Split("`n")[32]).Split("`t")[2])"
            }

            if (($_.Id -eq 4625) -and ($_.Message -match "Account Domain:\s+WORKGROUP")) # An account failed to log on.
            {
                # for u in `<users.txt`; do echo -n "[*] User: $u - " && rpcclient -U "$u%Autumn2019" -c "getusername;quit" x.x.x.x; sleep .3; done
                Write-Alert "RPCClient Password Guessing" "$($_.TimeCreated) - Detected WORKGROUP Domain used by RPCClient for $(($_.Message.split("`n")[12]).split("`t")[3]) from $(($_.Message.split("`n")[26]).split("`t")[2]) with a status $(($_.Message.split("`n")[17]).split("`t")[4])"
            }

            if (($_.Id -eq 4625) -and ($_.Message -match "Authentication Package:\s+NTLM")) # An account failed to log on.
            {
                # nmap -Pn -sS -p 445 --script +smb* --script-args unsafe=1 x.x.x.x
                Write-Alert "Strange SMB Connection" "$($_.TimeCreated) - Detected NTLM Authentication used by $(($_.Message.split("`n")[12]).split("`t")[3]) from $(($_.Message.split("`n")[26]).split("`t")[2]) with a status $(($_.Message.split("`n")[17]).split("`t")[4])"
            }
                     
            # https://yojimbosecurity.ninja/dcsync/
            # https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/c61ae7fd-c50f-4813-a8d2-ef81d4b48499
            # https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/1522b774-6464-41a3-87a5-1e5633c3fbbb
            # Detectable: secretsdump.py -dc-ip x.x.x.x DOMAIN/Administrator:password@x.x.x.x -just-dc-user DCHOSTNAME
            # NOT Detectable: secretsdump.py -dc-ip x.x.x.x -hashes :f496099349aa2c65e5f358c8e281e7e9 DOMAIN/DCHOSTNAME$@x.x.x.x
            if (($_.Id -eq 4662) -and ($_.Message -match "1131f6ad-9c07-11d1-f79f-00c04fc2dcd2")) # An operation was performed on an object.
            {
                Write-Alert "Possible DCSync Detection" "$($_.TimeCreated)) - Detected an unusual replication event with the DS-Replication-Get-Changes-All ACE by $(($_.Message.Split("`n")[5]).Split("`t")[3])/$(($_.Message.Split("`n")[4]).Split("`t")[3]) with the Logon ID of $(($_.Message.Split("`n")[6]).Split("`t")[3])"
            }

            if (($_.Id -eq 4768) -and ($_.Message -match "Ticket Encryption Type:\s+0x17")) # A Kerberos authentication ticket (TGT) was requested.
            {
                # GetNPUsers.py -dc-ip x.x.x.x DOMAIN/Administrator:password -request
                Write-Alert "ASREPRoast Detection" "$($_.TimeCreated)) - Kerberos TGT requested with RC4 (0x17) encryption at $($_.TimeCreated) from $(($_.Message.split("`n")[12]).split(":")[4]) and for$($_.Message.split("`n")[3] -replace "\s",” ”)"
            }

            if (($_.Id -eq 4769) -and ($_.Message -match "Ticket Encryption Type:\s+0x17")) # A Kerberos service ticket was requested.
            {
                # GetUserSPNs.py -dc-ip x.x.x.x DOMAIN/Administrator:password -request
                Write-Alert "Kerberoast Detection" "$($_.TimeCreated)) - Kerberos TGS requested with RC4 (0x17) encryption at $($_.TimeCreated) from $(($_.Message.split("`n")[12]).split(":")[4]) and for$($_.Message.split("`n")[8] -replace "\s",” ”)"
            }

            if (($_.Id -eq 5145) -and ($_.Message -notmatch "Account Name:\s+.+\$") -and (($_.Message -match "Relative Target Name:\s+samr") -or ($_.Message -match "Relative Target Name:\s+lsarpc"))) # A network share object was checked to see whether client can be granted desired access.
            {
                # nmap -Pn -sS -p 445 --script +smb* --script-args unsafe=1 x.x.x.x
                # [0x10002/DELETE] and [0x2000080/MAX_ALLOWED] appear to be specific to nmap.
                Write-Alert "Strange SMB Connection" "$($_.TimeCreated) - $(($_.Message.split("`n")[5]).split("`t")[3])\$(($_.Message.split("`n")[4]).split("`t")[3]) from $(($_.Message.split("`n")[10]).split("`t")[3]) requested $(($_.Message.split("`n")[14]).split("`t")[3]) [$(($_.Message.split("`n")[19]).split("`t")[3])/$(($_.Message.split("`n")[20]).split("`t")[3])]"
            }
        }

        $Security_Events = Get-WinEvent -FilterHashtable @{Logname="Security";} -MaxEvents ($LogSecurityNewIndex - $LogSecurityIndex)
        
        $4624_Events = $Security_Events | Where-Object -FilterScript {($_.Id -eq 4624) -and ($_.Message -notmatch "Account Name:\s+.+\$")} # An account was successfully logged on.
        #Write-Output "`t[+] Collected $($4624_Events.Count) 4624 Events."
        $Users = ForEach ($Event in $4624_Events) {$Event.Message.Split("`n")[18].Split("`t")[3]}
        $Users | Group | Select Count, Name | ?{$_.Count -ge 5} | Sort Count | % {
            Write-Alert "Excessive Authentication" "$($4624_Events[0].TimeCreated) - Detected $($_.Count) login events for $($_.Name) account."
        }

        # Credit: https://www.trimarcsecurity.com/single-post/2018/05/06/Trimarc-Research-Detecting-Password-Spraying-with-Security-Event-Auditing
        $4625_Events = $Security_Events | Where-Object -FilterScript {($_.Id -eq 4625)} # An account failed to log on.
        #Write-Output "`t[+] Collected $($4625_Events.Count) 4625 Events."
        if (($4625_Events.Count -gt 20) -and ($4625_Events.Message -match "Sub Status:\s+0xC000006A")) # An account failed to log on.
        {
            # Tool: https://www.blackhillsinfosec.com/password-spraying-other-fun-with-rpcclient/
            Write-Alert "Password Spraying Detection" "$($4625_Events[0].TimeCreated) - There have been $($4625_Events.Count) account logon failure events in the past one minute from $(($4625_Events[0].Message.Split("`n")[26]).Split("`t")[2])"
        }

        # auditpol /set /category:"Account Logon" /success:enable /failure:enable
        # Kerberos logging needs to be enbled to log event ID 4771 and monitor for "Kerberos preauthentication failed".
        # In the event id 4771 there's a failure code set to "0x18" which means bad password. ~ trimarcsecurity.com
        $4771_Events = $Security_Events | Where-Object -FilterScript {($_.Id -eq 4771)}
        #Write-Output "`t[+] Collected $($4771_Events.Count) 4771 Events."
        if (($4771_Events.Count -gt 20) -and ($4771_Events.Message -match "Failure Code:\s+0x18")) # Kerberos pre-authentication failed.
        {
            # Tool: https://gist.github.com/ropnop/c53bb27678b68435c5537057c585736c
            Write-Alert "Password Spraying Detection" "$($4771_Events[0].TimeCreated) - There have been $($4771_Events.Count) failed Kerberos pre-authentication events in the past one minute from $(($4771_Events[0].Message.Split("`n")[10]).Split("`t")[3])"
        }

    } $LogSecurityIndex = $LogSecurityNewIndex

    $LogWindowsPowerShellNewIndex  = (Get-WinEvent -FilterHashtable @{Logname="Windows PowerShell";} -MaxEvents 1).RecordId

    if ($LogWindowsPowerShellNewIndex -gt $LogWindowsPowerShellIndex)
    {
         Get-WinEvent -FilterHashtable @{Logname="Windows PowerShell"} -MaxEvents ($LogWindowsPowerShellNewIndex - $LogWindowsPowerShellIndex) | Parse-Event | sort RecordId | % {
            # https://docs.microsoft.com/en-us/powershell/scripting/getting-started/starting-the-windows-powershell-2.0-engine
            if (($_.Id -eq 400) -and (($_.Message -match "HostVersion=2.0") -or ($_.Message -match "EngineVersion=2.0"))) # Engine state is changed from None to Available. 
           {
                # C:\> PowerShell.exe -Version 2 OR Start-Job {Get-Process} -PSVersion 2.0
                Write-Alert "PowerShell Version Downgrade" "$($_.TimeCreated)) - Detected a PowerShell version downgrade by $(($_.Message.Split("`n")[9]).Split("`t")[1]), $(($_.Message.Split("`n")[11]).Split("`t")[1]), $(($_.Message.Split("`n")[14]).Split("`t")[1]), $(($_.Message.Split("`n")[13]).Split("`t")[1])"
            }
        }
    } $LogWindowsPowerShellIndex = $LogWindowsPowerShellNewIndex

    $LogForwardedEventsNewIndex  = (Get-WinEvent -FilterHashtable @{Logname="ForwardedEvents";} -MaxEvents 1).RecordId

    if ($LogForwardedEventsNewIndex -gt $LogForwardedEventsIndex)
    {
         Get-WinEvent -FilterHashtable @{Logname="ForwardedEvents"} -MaxEvents ($LogForwardedEventsNewIndex - $LogForwardedEventsIndex) | Parse-Event | sort RecordId | % {
            # https://docs.microsoft.com/en-us/powershell/scripting/getting-started/starting-the-windows-powershell-2.0-engine
            if (($_.Id -eq 400) -and (($_.Message -match "HostVersion=2.0") -or ($_.Message -match "EngineVersion=2.0"))) # Engine state is changed from None to Available. 
           {
                # C:\> PowerShell.exe -Version 2 OR Start-Job {Get-Process} -PSVersion 2.0
                Write-Alert "PowerShell Version Downgrade" "$($_.TimeCreated)) - Detected a PowerShell version downgrade by $(($_.Message.Split("`n")[9]).Split("`t")[1]), $(($_.Message.Split("`n")[11]).Split("`t")[1]), $(($_.Message.Split("`n")[14]).Split("`t")[1]), $(($_.Message.Split("`n")[13]).Split("`t")[1])"
            }
        }
    } $LogForwardedEventsIndex = $LogForwardedEventsNewIndex

    $LogWECProcessExecutionNewIndex  = (Get-WinEvent -FilterHashtable @{Logname="WEC-Process-Execution";} -MaxEvents 1).RecordId

    if ($LogWECProcessExecutionNewIndex -gt $LogWECProcessExecutionIndex)
    {
         Get-WinEvent -FilterHashtable @{Logname="WEC-Process-Execution"} -MaxEvents ($LogWECProcessExecutionNewIndex - $LogWECProcessExecutionIndex) | Parse-Event | sort RecordId | % {
            if (($_.Id -eq 4688) -and ($_.Message -notmatch "Account Name:\s+.+\$") -and (($_.Message -match "\\powershell.*\.exe") -or ($_.Message -match "\\regedit\.exe"))) # Engine state is changed from None to Available. 
           {
                if ($_.Message -like "*Target Subject:*")
                {
                        Write-Alert "Monitored Process Execution" "$($_.TimeCreated) - $(($_.Message.Split("`n")[5]).Split("`t")[3])\$(($_.Message.Split("`n")[4]).Split("`t")[3]) on $($Exe_Event.MachineName) - $(($Exe_Event.Message.Split("`n")[16]).Split("`t")[2]) $(($Exe_Event.Message.Split("`n")[19]).Split("`t")[2])"
                }
                else
                {
                    Write-Alert "Monitored Process Execution" "$($_.TimeCreated) - $(($_.Message.Split("`n")[5]).Split("`t")[3])\$(($_.Message.Split("`n")[4]).Split("`t")[3]) on $($Exe_Event.MachineName) - $(($Exe_Event.Message.Split("`n")[10]).Split("`t")[2]) $(($Exe_Event.Message.Split("`n")[13]).Split("`t")[2])"
                }
            }
        }
    } $LogWECProcessExecutionIndex = $LogWECProcessExecutionNewIndex

    if($Host.UI.RawUI.KeyAvailable -and (3 -eq [int]$Host.UI.RawUI.ReadKey("AllowCtrlC,IncludeKeyUp,NoEcho").Character)){ return; }
}
