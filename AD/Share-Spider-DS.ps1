# Be like MANSPIDER --no-download

# Shhhh, Be quiet!
$ErrorActionPreference = "SilentlyContinue"

# Load necessary assembly if not already loaded
Add-Type -AssemblyName System.DirectoryServices

# Initialize the DirectorySearcher object
$searcher = New-Object System.DirectoryServices.DirectorySearcher
$searcher.Filter = "(&(objectClass=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))"
$searcher.PageSize = 1000

# Retrieve data from the directory
$results = $searcher.FindAll()

# Iterate over each result in the collection
foreach ($result in $results) {
    $dnsHostName = $result.Properties["dnsHostName"][0]

    if ($dnsHostName) {
        Write-Host "[*] Connecting to $dnsHostName..."
        $outFile = "manpowerspider-$dnsHostName.txt"

        # Check and remove existing output file if it exists
        if (Test-Path -Path $outFile -PathType Leaf) {
            Remove-Item -Path $outFile
        }

        # Get the list of shared folders
        $shares = net view \\$dnsHostName /all | Select-Object -Skip 7 | Where-Object { $_ -match 'disk*' } | ForEach-Object { 
            if ($_ -match '^(.+?)\s+Disk*') { 
                $matches[1].Trim()
            }
        }

        # Iterate over each share found
        foreach ($share in $shares) {
            if ($share -notin @("DFS", "SYSVOL", "NETLOGON")) {
                $Msg = "[*] Scanning \\$dnsHostName\$share"
                Write-Host $Msg
                $Msg | Out-File -Append -FilePath $outFile

                # Recursively list files in the share
                $files = Get-ChildItem -Recurse -Depth 42 -FollowSymlink -Path "\\$dnsHostName\$share\" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }

                if ($files) {
                    $files | Out-File -Append -FilePath $outFile
                }
            }
        }
    } else {
        Write-Host "[!] No DNS Hostname found for an entry."
    }
}
