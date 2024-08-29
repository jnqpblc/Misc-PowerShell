function CopyRunDelete {
    param (
        [string]$SourceBinary,
        [string]$DestinationPath
    )

    # Open the folder in Explorer
    Invoke-Item $DestinationPath

    # Copy binary to the destination path
    try {
        Copy-Item -Path $SourceBinary -Destination $DestinationPath -Force -ErrorAction Stop
        Write-Host "$($SourceBinary) copied to $DestinationPath"
    } catch {
        Write-Host "Failed to copy $($SourceBinary): $_"
        return
    }

    # Run the binary
    $SourceBinaryPath = Join-Path $DestinationPath $(Split-Path -Path $SourceBinary -Leaf)
    try {
        Invoke-Item -Path $SourceBinaryPath  -ErrorAction Stop
        Write-Host "$($SourceBinary) executed successfully."
    } catch {
        Write-Host "Failed to execute $($SourceBinary): $_"
        return
    }

    # Attempt to delete the binary
    try {
        Remove-Item -Path $SourceBinaryPath -Force -ErrorAction Stop
        Write-Host "$($SourceBinary) deleted successfully."
    } catch {
        Write-Host "Failed to delete $($SourceBinary): $_"
        # Open the folder in Explorer if deletion fails
        #Invoke-Item $DestinationPath
    }
}

# Run the function with default or provided paths
#CopyRunDelete -SourceBinary "C:\Windows\notepad.exe" -DestinationPath "C:\Windows\Tasks"
