# Get the root of the current domain using the RootDSE object
$rootDSE = [ADSI]"LDAP://RootDSE"

# Retrieve the default naming context (domain DN)
$domainDN = $rootDSE.rootDomainNamingContext

# Construct and access the LDAP path dynamically for the CA container
$objGC = [ADSI]"LDAP://$domainDN";

# Initialize the DirectorySearcher
$Searcher = New-Object DirectoryServices.DirectorySearcher
$Searcher.PageSize = 1000
$Searcher.SearchRoot = $objGC

# Adjust the filter according to what you're looking for within this context
# Since we're in the Configuration container, the objectClass filter might differ
$Searcher.Filter = "(objectClass=*)"

# Specify properties to load
$searcher.PropertiesToLoad.Add("objectClass") > $null

# Find all objects in AD
$results = $searcher.FindAll()

# Create a hashtable to count objects by their objectClass
$objectClassCount = @{}

# Loop through all results and count occurrences of object classes
foreach ($result in $results) {
    $objectClasses = $result.Properties["objectClass"]
    
    foreach ($objectClass in $objectClasses) {
        if ($objectClassCount.ContainsKey($objectClass)) {
            $objectClassCount[$objectClass] += 1
        } else {
            $objectClassCount[$objectClass] = 1
        }
    }
}

# Convert the hashtable to a list of objects and display the results
$objectClassCount.GetEnumerator() | Sort-Object Name | Select-Object Name, Value | 
    Format-Table @{Label = "ObjectClass"; Expression = {$_.Name}}, 
                @{Label = "Count"; Expression = {$_.Value}}
