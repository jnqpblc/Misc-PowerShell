# Create a directory searcher using System.DirectoryServices
$domain = "LDAP://$env:USERDOMAIN"
$searcher = New-Object DirectoryServices.DirectorySearcher
$searcher.SearchRoot = New-Object DirectoryServices.DirectoryEntry($domain)

# Set filter to retrieve all objects
$searcher.Filter = "(objectClass=*)"

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
