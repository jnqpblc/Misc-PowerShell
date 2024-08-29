# Define the minimum and maximum interval in minutes
$minInterval = 3
$maxInterval = 7

# Convert minutes to milliseconds
$minIntervalMs = $minInterval * 60 * 1000
$maxIntervalMs = $maxInterval * 60 * 1000

# Function to send a keystroke
function Send-KeyStroke {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait("{SCROLLLOCK}")
}

# Infinite loop to keep sending keystrokes
while ($true) {
    # Send the keystroke
    Send-KeyStroke

    # Generate a random interval
    $randomInterval = Get-Random -Minimum $minIntervalMs -Maximum $maxIntervalMs

    # Wait for the random interval
    Start-Sleep -Milliseconds $randomInterval
}
