# Import the Active Directory module (if not already imported)
Import-Module ActiveDirectory

# Hashtable to store unique counts
$uniqueCounts = @{}

# Get all computers in the domain with their SPNs
$computers = Get-ADComputer -Filter * -Property servicePrincipalName

foreach ($computer in $computers) {
    # For each computer, process each SPN
    foreach ($spn in $computer.servicePrincipalName) {
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

# Output the counts
$uniqueCounts.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Output "$($_.Key): $($_.Value)"
}
