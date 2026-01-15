<#
Enables as many of the requested hardening items as PowerShell can reasonably do on a Dell Windows endpoint.
REQS: Install hard_configurator from github, and max out.

Covers:
- Enforce password-protected screen saver (current user + default user)
- Disable Guest account
- Disable Windows crash memory dumps
- Ensure BitLocker is enabled (TPM-based, if possible) -- if Win Home use VeraCrypt FDE
- Enable Windows Firewall + set inbound default block
- Disable AutoRun for all drives
- Enable UAC prompts (ConsentPromptBehaviorAdmin=2, PromptOnSecureDesktop=1)
- Check (not enable) TPM/Secure Boot status (BIOS/UEFI-controlled)

NOT covered (needs BIOS/UEFI / Intune/GPO / process):
- Enabling TPM in BIOS/UEFI
- Secure Boot “Full Security” & External Boot “Disallow”
- Windows Hello for Business full enablement (environment-dependent)
- Enforcing passwords for all local accounts (can’t set passwords without knowing them)
- “Disable all non-required accounts” (too risky to do generically without your allowlist)

Run in an elevated PowerShell session (Admin).
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
  # Screen saver timeout in seconds (example: 900 = 15 minutes)
  [int]$ScreenSaverTimeoutSeconds = 900,

  # Optional: If you want to disable *custom* inbound firewall rules (not built-in),
  # set this to $true. Safer than deleting everything.
  [bool]$DisableCustomInboundFirewallRules = $false,

  # Optional: BitLocker encryption method (XtsAes128 or XtsAes256)
  [ValidateSet("XtsAes128","XtsAes256")]
  [string]$BitLockerEncryptionMethod = "XtsAes256"
)

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err ($msg) { Write-Host "[ERR ] $msg" -ForegroundColor Red }

function Assert-Admin {
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) {
    throw "Please run PowerShell as Administrator."
  }
}

function Set-RegistryValue {
  param(
    [Parameter(Mandatory)] [string]$Path,
    [Parameter(Mandatory)] [string]$Name,
    [Parameter(Mandatory)] $Value,
    [ValidateSet("String","DWord","QWord","Binary","MultiString","ExpandString")]
    [string]$Type = "DWord"
  )
  if ($PSCmdlet.ShouldProcess("$Path\$Name", "Set $Type = $Value")) {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
  }
}

function Enforce-PasswordProtectedScreenSaver {
  param([int]$TimeoutSeconds)

  Write-Info "Enforcing password-protected screen saver (timeout: $TimeoutSeconds seconds)"

  # Current user
  $cu = "HKCU:\Control Panel\Desktop"
  Set-RegistryValue -Path $cu -Name "ScreenSaveActive"     -Value "1"   -Type String
  Set-RegistryValue -Path $cu -Name "ScreenSaverIsSecure"  -Value "1"   -Type String
  Set-RegistryValue -Path $cu -Name "ScreenSaveTimeOut"    -Value "$TimeoutSeconds" -Type String

  # Set a default screensaver if none specified (use built-in blank)
  $scr = (Get-ItemProperty -Path $cu -Name "SCRNSAVE.EXE" -ErrorAction SilentlyContinue)."SCRNSAVE.EXE"
  if (-not $scr) {
    Set-RegistryValue -Path $cu -Name "SCRNSAVE.EXE" -Value "$env:windir\System32\scrnsave.scr" -Type String
  }

  # Default user profile (applies to new profiles)
  # HKU\.DEFAULT is used by the logon desktop; default user template is at:
  $du = "Registry::HKEY_USERS\.DEFAULT\Control Panel\Desktop"
  Set-RegistryValue -Path $du -Name "ScreenSaveActive"     -Value "1"   -Type String
  Set-RegistryValue -Path $du -Name "ScreenSaverIsSecure"  -Value "1"   -Type String
  Set-RegistryValue -Path $du -Name "ScreenSaveTimeOut"    -Value "$TimeoutSeconds" -Type String
  $duScr = (Get-ItemProperty -Path $du -Name "SCRNSAVE.EXE" -ErrorAction SilentlyContinue)."SCRNSAVE.EXE"
  if (-not $duScr) {
    Set-RegistryValue -Path $du -Name "SCRNSAVE.EXE" -Value "$env:windir\System32\scrnsave.scr" -Type String
  }
}

function Disable-GuestAccount {
  Write-Info "Disabling local Guest account (if present)"
  try {
    # Built-in local account 'Guest' exists on most SKUs, even if disabled already.
    if ($PSCmdlet.ShouldProcess("Guest", "Disable local account")) {
      net user Guest /active:no | Out-Null
    }
  } catch {
    Write-Warn "Could not disable Guest via net user. Error: $_"
  }
}

function Disable-MemoryDumps {
  Write-Info "Disabling Windows crash memory dumps (Write debugging information = None)"
  # SystemPropertiesAdvanced > Startup and Recovery maps to CrashControl.
  $cc = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
  # 0 = None, 1 = Complete, 2 = Kernel, 3 = Small, 7 = Automatic
  Set-RegistryValue -Path $cc -Name "CrashDumpEnabled" -Value 0 -Type DWord
  # Also reduce likelihood of creating other dump types
  Set-RegistryValue -Path $cc -Name "LogEvent"         -Value 1 -Type DWord
  Set-RegistryValue -Path $cc -Name "SendAlert"        -Value 0 -Type DWord
}

function Disable-AutoRunAllDrives {
  Write-Info "Disabling AutoRun/AutoPlay from USB/external drives (NoDriveTypeAutoRun=255)"
  $p = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
  Set-RegistryValue -Path $p -Name "NoDriveTypeAutoRun" -Value 255 -Type DWord
}

function Enable-UAC {
  Write-Info "Ensuring UAC is enabled with admin prompt (ConsentPromptBehaviorAdmin=2; PromptOnSecureDesktop=1)"
  $p = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
  Set-RegistryValue -Path $p -Name "EnableLUA"                  -Value 1 -Type DWord
  Set-RegistryValue -Path $p -Name "ConsentPromptBehaviorAdmin" -Value 2 -Type DWord
  Set-RegistryValue -Path $p -Name "PromptOnSecureDesktop"      -Value 1 -Type DWord
}

function Enable-WindowsFirewall {
  Write-Info "Enabling Windows Firewall and setting default inbound to Block"
  if ($PSCmdlet.ShouldProcess("Windows Firewall", "Enable profiles + block inbound by default")) {
    try {
      Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow
    } catch {
      Write-Err "Failed to set firewall profiles. Error: $_"
      return
    }
  }

  if ($DisableCustomInboundFirewallRules) {
    Write-Warn "Disabling *custom* inbound firewall rules (not deleting). This can affect apps that require inbound ports."
    if ($PSCmdlet.ShouldProcess("Custom inbound rules", "Disable")) {
      try {
        # Disable inbound rules that are NOT part of the built-in default rule groups (best-effort heuristic).
        # Many built-in rules are in groups like "@FirewallAPI.dll,-80201" etc. Custom rules often have empty Group.
        Get-NetFirewallRule -Direction Inbound -Action Allow |
          Where-Object { -not $_.Group -or $_.Group.Trim() -eq "" } |
          ForEach-Object { Set-NetFirewallRule -Name $_.Name -Enabled False }
      } catch {
        Write-Warn "Could not disable some custom inbound rules. Error: $_"
      }
    }
  } else {
    Write-Info "Skipping disabling inbound rules. Inbound default is Block (recommended baseline)."
  }
}

function Ensure-BitLockerOn {
  Write-Info "Ensuring BitLocker is enabled on OS drive (C:) when supported"
  $osDrive = $env:SystemDrive

  # Quick status checks
  $tpm = $null
  try { $tpm = Get-Tpm -ErrorAction Stop } catch { }

  if (-not $tpm) {
    Write-Warn "TPM status could not be read (Get-Tpm failed). BitLocker enablement may fail."
  } else {
    if (-not $tpm.TpmPresent) { Write-Warn "TPM not present. BitLocker TPM-protector won't work." }
    elseif (-not $tpm.TpmReady) { Write-Warn "TPM present but not ready. You may need BIOS/UEFI enablement/initialization." }
    else { Write-Info "TPM present & ready." }
  }

  # Secure Boot check (informational)
  try {
    $sb = Confirm-SecureBootUEFI
    Write-Info "Secure Boot enabled: $sb"
  } catch {
    Write-Warn "Secure Boot status could not be checked (likely Legacy BIOS mode or insufficient privileges)."
  }

  # If BitLocker cmdlets available, use them.
  try {
    $bl = Get-BitLockerVolume -MountPoint $osDrive -ErrorAction Stop
  } catch {
    Write-Err "BitLocker cmdlets not available or failed. Are you on a supported Windows edition? Error: $_"
    return
  }

  if ($bl.ProtectionStatus -eq "On") {
    Write-Info "BitLocker already ON for $osDrive"
    return
  }

  # Try to enable BitLocker with TPM protector
  # Note: This can require a reboot depending on hardware/TPM state/policy.
  if ($PSCmdlet.ShouldProcess("BitLocker on $osDrive", "Enable with TPM protector ($BitLockerEncryptionMethod)")) {
    try {
      # Add TPM protector (if not present)
      $hasTpmProtector = $false
      foreach ($kp in $bl.KeyProtector) {
        if ($kp.KeyProtectorType -match "Tpm") { $hasTpmProtector = $true; break }
      }
      if (-not $hasTpmProtector) {
        Add-BitLockerKeyProtector -MountPoint $osDrive -TpmProtector | Out-Null
      }

      Enable-BitLocker -MountPoint $osDrive `
        -EncryptionMethod $BitLockerEncryptionMethod `
        -UsedSpaceOnly `
        -SkipHardwareTest `
        -ErrorAction Stop

      Write-Info "BitLocker enablement initiated. Encryption may continue in background; a reboot may be required."
    } catch {
      Write-Err "Failed to enable BitLocker. Common causes: TPM not ready, Secure Boot off, policy restrictions, or unsupported SKU. Error: $_"
    }
  }
}

function Report-TPMAndSecureBoot {
  Write-Info "Reporting TPM and Secure Boot status (cannot enable BIOS/UEFI settings from here reliably)"
  try {
    $t = Get-Tpm
    Write-Host ("TPM Present: {0}, Ready: {1}, Enabled: {2}, Activated: {3}" -f $t.TpmPresent, $t.TpmReady, $t.TpmEnabled, $t.TpmActivated)
  } catch {
    Write-Warn "Get-Tpm failed: $_"
  }

  try {
    $sb = Confirm-SecureBootUEFI
    Write-Host ("Secure Boot Enabled: {0}" -f $sb)
  } catch {
    Write-Warn "Confirm-SecureBootUEFI failed (may be Legacy BIOS mode): $_"
  }
}

# ---------------- MAIN ----------------
Assert-Admin

Write-Info "Starting endpoint hardening (PowerShell)…"

Enforce-PasswordProtectedScreenSaver -TimeoutSeconds $ScreenSaverTimeoutSeconds
Disable-GuestAccount
Disable-MemoryDumps
Disable-AutoRunAllDrives
Enable-UAC
Enable-WindowsFirewall
Ensure-BitLockerOn
Report-TPMAndSecureBoot

Write-Info "Done. Some settings (BitLocker/TPM readiness) may require reboot or BIOS/UEFI configuration."
