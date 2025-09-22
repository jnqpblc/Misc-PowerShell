param(
    [string]$ConfigPath = "$env:USERPROFILE\.ssh\config"
)

if (-not (Test-Path $ConfigPath)) {
    Write-Error "SSH config file not found at $ConfigPath"
    exit 1
}

$lines = Get-Content $ConfigPath
$session = @{}
[string]$currentHost = $null  # <-- force as string

function Save-Session([string]$sessionName, $session) {
    if (-not $sessionName) { return }

    $safeName = $sessionName.Trim() -replace '[\\/:*?"<>|]', '_'   # sanitize invalid reg chars
    $regPath = "HKCU:\Software\SimonTatham\PuTTY\Sessions\$safeName"

    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }

    if ($session.ContainsKey("HostName")) {
        Set-ItemProperty -Path $regPath -Name "HostName" -Value ([string]$session["HostName"])
    }
    if ($session.ContainsKey("Port")) {
        Set-ItemProperty -Path $regPath -Name "PortNumber" -Type DWord -Value ([int]$session["Port"])
    }
    if ($session.ContainsKey("User")) {
        # PuTTY ignores this, but KiTTY honors it
        Set-ItemProperty -Path $regPath -Name "UserName" -Value ([string]$session["User"])
    }
    if ($session.ContainsKey("IdentityFile")) {
        $ppk = $session["IdentityFile"] + ".ppk"
        if (Test-Path $ppk) {
            Set-ItemProperty -Path $regPath -Name "PublicKeyFile" -Value ([string]$ppk)
        }
    }

    Write-Host "Created PuTTY session: $sessionName → $($session['HostName']):$($session['Port'])"
}

foreach ($line in $lines) {
    $trimmed = $line.Trim()
    if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }

    if ($trimmed -match "^Host\s+(.+)$") {
        # Save previous session
        if ($currentHost -and $session.Count -gt 0) {
            Save-Session $currentHost $session
            $session = @{}
        }
        $currentHost = [string]$matches[1]
    }
    elseif ($trimmed -match "^HostName\s+(.+)$") {
        $session["HostName"] = $matches[1]
    }
    elseif ($trimmed -match "^Port\s+(\d+)$") {
        $session["Port"] = $matches[1]
    }
    elseif ($trimmed -match "^User\s+(.+)$") {
        $session["User"] = $matches[1]
    }
    elseif ($trimmed -match "^IdentityFile\s+(.+)$") {
        try {
            $resolved = Resolve-Path $matches[1] -ErrorAction Stop
            $session["IdentityFile"] = $resolved.Path
        } catch {
            $session["IdentityFile"] = $matches[1]
        }
    }
}

# Save the last one
if ($currentHost -and $session.Count -gt 0) {
    Save-Session $currentHost $session
}
