# Be like certify.exe to find cert templates

# Define the CA URL
$CAS = "https://SOMECA01.example.com/"

# Get the root of the current domain using the RootDSE object
$rootDSE = [ADSI]"LDAP://RootDSE"

# Retrieve the root domain naming context
$domainDN = $rootDSE.rootDomainNamingContext

# Construct the LDAP path dynamically for the Configuration container
$ldapPath = "LDAP://CN=Configuration,$domainDN"
$searcher = New-Object DirectoryServices.DirectorySearcher
$searcher.SearchRoot = [ADSI]$ldapPath
$searcher.Filter = "(objectclass=pkicertificatetemplate)"
$searcher.PageSize = 1000

# Perform the search and collect certificate template names
$templates = $searcher.FindAll() | ForEach-Object { $_.Properties["cn"] }

# Set location to the certificate store
Set-Location -Path Cert:\CurrentUser\My

# Iterate over each certificate template and request a certificate
foreach ($template in $templates) {
    $templateName = $template.ToString()
    Write-Host "Requesting certificate for template: $templateName"
    try {
        Get-Certificate -Url $CAS -Template $templateName -ErrorAction Stop
        Write-Host "Certificate successfully requested for template: $templateName"
    } catch {
        Write-Warning "Failed to request certificate for template: $templateName. Error: $_"
    }
}
