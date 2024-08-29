function Get-WritableFolders {
    param (
        [string]$Path
    )

    Get-ChildItem -Directory -Recurse -Path $Path -ErrorAction SilentlyContinue | ForEach-Object {
        $folderPath = $_.FullName
        $acl = $null
        try {
            $acl = Get-Acl -Path $folderPath -ErrorAction Stop
        } catch {
            # If an error occurs (e.g., unauthorized access), skip to the next item
            return
        }

        if ($acl) {
            $acl.Access | Where-Object { 
                $_.FileSystemRights -match "Write" -and $_.AccessControlType -eq "Allow" 
            } | ForEach-Object {
                [PSCustomObject]@{
                    FolderPath = $folderPath
                    IdentityReference = $_.IdentityReference
                    FileSystemRights = $_.FileSystemRights
                }
            }
        }
    }
}

# Run the function and output results
#$WritableFolders = Get-WritableFolders -Path "C:\Program Files\"
#$WritableFolders | Format-Table -AutoSize |Out-File $env:TMP\akjshufrben.txt
#Invoke-Item $env:TMP\akjshufrben.txt
