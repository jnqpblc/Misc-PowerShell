$PreauthNotRequired = "(userAccountControl:1.2.840.113556.1.4.803:=4194304)"
$ErrorActionPreference = "SilentlyContinue"
$users = Get-ADUser -LdapFilter $PreauthNotRequired |Where-Object { $_.Enabled -eq $true }
$users.Count
