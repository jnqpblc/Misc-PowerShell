# Enable audit process creation on success
#AuditPol /set /subcategory:"Process Creation" /success:enable

# Define a hashtable to store unique entries
$uniqueProcesses = @{}

# Retrieve all Event ID 4688 entries from the Security log
Get-WinEvent -LogName Security | Where-Object { $_.Id -eq 4688 } | ForEach-Object {
    # Parse the message for 'New Process Name' and 'Process Command Line'
    $message = $_.Message
    if ($message -match 'New Process Name:\s+(.+)$') {
        $newProcessName = $matches[1]
    }
    if ($message -match 'Process Command Line:\s+(.+)$') {
        $processCommandLine = $matches[1]
    }

    # Combine 'New Process Name' and 'Process Command Line' as a unique key
    $uniqueKey = "$newProcessName | $processCommandLine"

    # Add to hashtable if the combination is unique
    if ($newProcessName -and $processCommandLine -and -not $uniqueProcesses.ContainsKey($uniqueKey)) {
        $uniqueProcesses[$uniqueKey] = [PSCustomObject]@{
            "New Process Name" = $newProcessName
            "Process Command Line" = $processCommandLine
        }
    }
}

# Output all unique entries
$uniqueProcesses.Values | Format-Table -AutoSize
