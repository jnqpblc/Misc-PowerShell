# Define the registry path for AMSI providers
$amsiRegistryPath = "HKLM:\SOFTWARE\Microsoft\AMSI\Providers"

# Check if the AMSI Providers registry key exists
if (Test-Path $amsiRegistryPath) {
    # Retrieve each AMSI provider's GUID
    Get-ChildItem -Path $amsiRegistryPath | ForEach-Object {
        $providerGUID = $_.PSChildName

        # Construct the full HKEY_CLASSES_ROOT registry path to find details about the provider
        $clsidPath = "Registry::HKEY_CLASSES_ROOT\CLSID\$providerGUID"
        
        if (Test-Path $clsidPath) {
            # Get provider details from the CLSID path
            $providerDetails = Get-ItemProperty -Path $clsidPath
            [PSCustomObject]@{
                ProviderGUID = $providerGUID
                ProviderName = $providerDetails."(Default)" -as [string]
                InprocServer32 = (Get-ItemProperty -Path "$clsidPath\InprocServer32" -ErrorAction SilentlyContinue)."(Default)" -as [string]
            }
        } else {
            Write-Output "No CLSID entry found for GUID $providerGUID"
        }
    } | Format-Table -AutoSize
} else {
    Write-Output "No AMSI providers found or AMSI is not enabled on this system."
}
