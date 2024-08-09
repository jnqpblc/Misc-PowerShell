# Load necessary assembly if not already loaded
Add-Type -AssemblyName System.DirectoryServices

# Initialize the DirectorySearcher object
$searcher = New-Object System.DirectoryServices.DirectorySearcher
$searcher.Filter = "(&(objectClass=computer)(servicePrincipalName=*))"
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Add("servicePrincipalName")

# Hashtable to store unique counts
$uniqueCounts = @{}

# Use a do-while loop to retrieve data in pages
$results = $searcher.FindAll()
do {
    foreach ($result in $results) {
        $spns = $result.Properties["servicePrincipalName"]
        foreach ($spn in $spns) {
            # Split the SPN by '/' and take the first part
            $spnPrefix = $spn -split '/' | Select-Object -First 1
            
            # Increment the count for this SPN prefix
            if ($uniqueCounts.ContainsKey($spnPrefix)) {
                $uniqueCounts[$spnPrefix]++
            } else {
                $uniqueCounts[$spnPrefix] = 1
            }
        }
    }

    # Continue searching for next page
    $searcher.SearchRoot = $results[$results.Count - 1].Properties["adspath"][0]
    $results = $searcher.FindAll()
} while ($results.Count -eq $searcher.PageSize)

# Output the counts
$uniqueCounts.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Output "$($_.Key): $($_.Value)"
}
