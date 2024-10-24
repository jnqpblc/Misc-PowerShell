
$Exclusions = @("SYSTEM", "Administrators", "Domain Admins", "Enterprise Admins")
$Forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
$DomainList = @($Forest.Domains)
$Domains = $DomainList |foreach { $_.GetDirectoryEntry() }
$AllForestGpoACLs = @()
foreach ($Domain in $Domains) {
    $Filter = "(&(objectCategory=groupPolicyContainer)(displayname=*))"
    $Searcher = New-Object System.DirectoryServices.DirectorySearcher
    $Searcher.SearchRoot = $Domain
    $Searcher.Filter = $Filter
    $Searcher.PageSize = 1000
    $Searcher.SearchScope = "Subtree"
    $listGPO = $Searcher.FindAll()
    $AllDomainGpoACLs = @()
    foreach ($GPO in $listGPO){
        $ACL = ([ADSI]$GPO.path).ObjectSecurity.Access |? {$_.ActiveDirectoryRights -match "Write" -and $_.AccessControlType -eq "Allow" -and $Exclusions -notcontains $_.IdentityReference.toString().split("\")[1] -and $_.IdentityReference -ne "CREATOR OWNER"}
        if ($ACL -ne $null){
            $GpoACL = New-Object psobject
            $GpoACL |Add-Member Noteproperty "Domain" $Domain.distinguishedName
            $GpoACL |Add-Member Noteproperty "DisplayName" $GPO.Properties.displayname
            $GpoACL |Add-Member Noteproperty "IdentityReference" $ACL.IdentityReference
            $AllDomainGpoACLs += $GpoACL
        }
    }
    $AllForestGpoACLs += $AllDomainGpoACLs
    Write-Output "`n`n###`n###`t[+] Got GPOs for $($Domain.distinguishedName):`n###`n"
    $AllDomainGpoACLs |Select-Object -ExpandProperty IdentityReference |Group-Object -Property Value |
    Select-Object Name, Count |Sort-Object -Property Count -Descending
    #Get-ADUser REPLACEWITHUSER -Properties AccountNotDelegated,adminCount,Description,DistinguishedName,DoesNotRequirePreAuth,Enabled,HomeDirectory,HomeDrive,HomePage,LastBadPasswordAttempt,LastLogonDate,MemberOf,Name,PasswordExpired,PasswordLastSet,PasswordNeverExpires,PasswordNotRequired,pwdLastSet,PrincipalsAllowedToDelegateToAccount,ScriptPath,ServicePrincipalNames,SmartcardLogonRequired,Title
    #$AllForestGpoACLs |Where-Object { $_.IdentityReference -like "*REPLACEWITHUSER*" } |Select-Object Domain, DisplayName
}
