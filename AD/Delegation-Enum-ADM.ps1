$UnconstrainedDelegation = "(userAccountControl:1.2.840.113556.1.4.803:=524288)"
$ConstrainedDelegation = "(msDS-AllowedToDelegateTo=*)"
$ResourceBasedConstrainedDelegation = "(msDS-AllowedToActOnBehalfOfOtherIdentity=*)"

#TrustedForDelegation: Unconstrained delegation; broader and less secure. Should be used with caution due to potential security risks.
#TrustedToAuthForDelegation: Constrained delegation with protocol transition; more restricted and secure, as it limits delegation to specific services.

$Prop = "TrustedForDelegation"
$ErrorActionPreference = "SilentlyContinue"
$computers = Get-ADComputer -LdapFilter $UnconstrainedDelegation |Where-Object { $_.Enabled -eq $true }
$computers.Count

# Count by OperatingSystem
$computers | 
    Where-Object { $_.Enabled -eq $true } | 
    ForEach-Object { Get-ADComputer -Identity $_.Name -Properties * } | 
    Where-Object { $_.$Prop -eq $true } |
    Group-Object -Property OperatingSystem
    Select-Object Name, Count

# Count by isCriticalSystemObject
$computers | 
    Where-Object { $_.Enabled -eq $true } | 
    ForEach-Object { Get-ADComputer -Identity $_.Name -Properties * } | 
    Where-Object { $_.$Prop -eq $true -and $_.OperatingSystem -like "Windows*"} |
    Group-Object -Property isCriticalSystemObject
    Select-Object Name, Count

#Export all to CSV
$computers | 
    Where-Object { $_.Enabled -eq $true } | 
    ForEach-Object { Get-ADComputer -Identity $_.Name -Properties * } | 
    Where-Object { $_.$Prop -eq $true } |
    Export-Csv -Path "output.csv" -NoTypeInformation
