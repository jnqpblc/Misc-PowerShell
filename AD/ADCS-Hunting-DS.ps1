# Get the root of the current domain using the RootDSE object
$rootDSE = [ADSI]"LDAP://RootDSE"

# Retrieve the default naming context (domain DN)
$domainDN = $rootDSE.rootDomainNamingContext

# Construct and access the LDAP path dynamically for the CA container
$objGC = [ADSI]"LDAP://CN=Enrollment Services,CN=Public Key Services,CN=Services,CN=Configuration,$domainDN";

# Initialize the DirectorySearcher
$Searcher = New-Object DirectoryServices.DirectorySearcher
$Searcher.PageSize = 1000
$Searcher.SearchRoot = $objGC

# Adjust the filter according to what you're looking for within this context
# Since we're in the Configuration container, the objectClass filter might differ
$Searcher.Filter = "(objectClass=*)"
$Searcher.PropertiesToLoad.Add("dnshostname") > $Null

# Perform the search and store the results
$results = $Searcher.FindAll()

# Iterate over each result in the collection
foreach ($result in $results) {
    $dnsHostNames = $result.Properties["dnshostname"]
    foreach ($dnsHostName in $dnsHostNames) {
        $Uri = "https://$dnsHostName/"
        Write-Host $Uri
        try {
            Invoke-WebRequest -Uri $Uri -ErrorAction SilentlyContinue
        } catch {
            # Suppress any additional error output
            $null = $_
        }
    }
}
