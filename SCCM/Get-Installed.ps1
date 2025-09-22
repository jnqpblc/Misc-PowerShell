<#
.SYNOPSIS
    Query the local or remote ConfigMgr client for the items shown in Software Center.

.DESCRIPTION
    Uses the Client SDK WMI/CIM namespace (ROOT\ccm\ClientSDK) to enumerate:
      - CCM_Application  (available/installed apps that Software Center knows about)
      - CCM_SoftwareUpdate (software updates shown in Software Center)

    Note: Some user-targeted apps may not appear unless the user's policy has been evaluated in their user context.
.PARAMETER ComputerName
    Remote computer to query (default: localhost).
.PARAMETER IncludeUpdates
    Include software updates from CCM_SoftwareUpdate.
.PARAMETER ExportCsv
    Path to export the results to CSV.
#>

param(
    [string]$ComputerName = 'localhost',
    [switch]$IncludeUpdates,
    [string]$ExportCsv
)

function Get-ClientSdkInstances {
    param(
        [string]$ClassName,
        [string]$Computer = 'localhost'
    )
    try {
        # Prefer Get-CimInstance (modern). Fall back to Get-WmiObject if unavailable.
        return Get-CimInstance -Namespace 'ROOT\ccm\ClientSDK' -ClassName $ClassName -ComputerName $Computer -ErrorAction Stop
    }
    catch {
        try {
            return Get-WmiObject -Namespace 'ROOT\ccm\ClientSDK' -Class $ClassName -ComputerName $Computer -ErrorAction Stop
        }
        catch {
            Write-Verbose "Unable to query $ClassName on $($Computer): $_"
            return @()
        }
    }
}

Write-Host "Querying Software Center data on $ComputerName..." -ForegroundColor Cyan

# 1) Applications (CCM_Application)
$appObjs = Get-ClientSdkInstances -ClassName 'CCM_Application' -Computer $ComputerName

$apps = foreach ($a in $appObjs) {
    [PSCustomObject]@{
        Type           = 'Application'
        Id             = ($a.Id -as [string]) -replace '[\r\n\t]',''
        Name           = ($a.FullName -or $a.Name) -as [string]
        Publisher      = ($a.Publisher) -as [string]
        Version        = ($a.SoftwareVersion) -as [string]
        Revision       = ($a.Revision) -as [string]
        InstallState   = ($a.InstallState) -as [int]    # 0=Unknown, 1=Detected, 2=NotDetected, 3=Initializing, etc. (see client docs)
        IsMachineTarget= ($a.IsMachineTarget) -as [bool]
        IsUserTarget   = -not ($a.IsMachineTarget)
        Source         = 'CCM_Application'
    }
}

# Optionally get Software Updates
$updates = @()
if ($IncludeUpdates) {
    $updObjs = Get-ClientSdkInstances -ClassName 'CCM_SoftwareUpdate' -Computer $ComputerName
    $updates = foreach ($u in $updObjs) {
        [PSCustomObject]@{
            Type         = 'SoftwareUpdate'
            Id           = ($u.ArticleID -as [string]) -replace '[\r\n\t]',''
            Name         = ($u.Name) -as [string]
            Publisher    = ($u.Publisher -as [string])
            Version      = ($null)
            Revision     = ($null)
            InstallState = ($u.InstallState -as [int])
            IsMachineTarget = $true
            IsUserTarget = $false
            Source       = 'CCM_SoftwareUpdate'
        }
    }
}

$all = $apps + $updates

if (-not $all) {
    Write-Warning "No Software Center items returned from the client SDK WMI. This can happen if: 
 - the ConfigMgr client is not installed/running, 
 - policy hasn't been applied for the user, 
 - you're querying a remote machine and permissions/firewall block WMI/CIM, or
 - some items are user-targeted and you queried as SYSTEM/another user."
}

# Present a human-friendly table
$all | Sort-Object Type, Name |
    Select-Object Type, Name, Publisher, Version, InstallState, IsMachineTarget, Source |
    Format-Table -AutoSize

# Export to CSV if requested
if ($ExportCsv) {
    try {
        $all | Sort-Object Type, Name | Export-Csv -Path $ExportCsv -NoTypeInformation -Force
        Write-Host "Exported results to $ExportCsv" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to export CSV: $_"
    }
}
