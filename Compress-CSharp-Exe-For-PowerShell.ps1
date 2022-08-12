<#
.SYNOPSIS
	Compresses or decompresses a C# binary for use in a PowerShell script.
.DESCRIPTION
	This PowerShell script has two functions. One to convert a C# binary into a Base64 compressed blob, and the other to reverse that operation.
.EXAMPLE
	PS> insert "Invoke-SharpHound.exe" "Invoke-SharpHound.b64" 
	PS> extract "Invoke-SharpHound.b64" "Invoke-SharpHound.exe"
.LINK
	https://gist.github.com/vortexau/13de5b6f9e46cf419f1540753c573206
	https://gist.github.com/marcgeld/bfacfd8d70b34fdf1db0022508b02aca
#>

function decompress($i, $o) {
	$blob = (Get-Content -Path $i)
	$decoded = [IO.MemoryStream][Convert]::FromBase64String($blob)
	$output = New-Object System.IO.MemoryStream
	$gzipStream = New-Object System.IO.Compression.GzipStream $decoded, ([IO.Compression.CompressionMode]::Decompress)
	$gzipStream.CopyTo($output)
	$gzipStream.Close()
	$decoded.Close()
	[byte[]] $byteOutArray = $output.ToArray()
	[System.IO.File]::WriteAllBytes($o,$byteOutArray)
	$output.Close()
}

function compress($i, $o) {
	$bytes = [IO.File]::ReadAllBytes($i)
	$output = New-Object System.IO.MemoryStream
	$gzipStream = New-Object System.IO.Compression.GzipStream $output, ([IO.Compression.CompressionMode]::Compress)
	$gzipStream.Write( $bytes, 0, $bytes.Length )
	$gzipStream.Close()
	$encoded = [System.Convert]::ToBase64String($output.ToArray())
	Out-File -FilePath $o -InputObject $encoded -Encoding ASCII
	$output.Close()
}
 
function download_raw_and_compress($i, $o) {
	[byte[]] $bytes = (New-Object System.Net.WebClient).DownloadData($i)
	$output = New-Object System.IO.MemoryStream
	$gzipStream = New-Object System.IO.Compression.GzipStream $output, ([IO.Compression.CompressionMode]::Compress)
	$gzipStream.Write( $bytes, 0, $bytes.Length )
	$gzipStream.Close()
	$encoded = [System.Convert]::ToBase64String($output.ToArray())
	Out-File -FilePath $o -InputObject $encoded -Encoding ASCII
	$output.Close()
}

function download_compressed_and_extract($i, $o) {
	$blob = (New-Object System.Net.WebClient).DownloadString($i)
	$decoded = [IO.MemoryStream][Convert]::FromBase64String($blob)
	$output = New-Object System.IO.MemoryStream
	$gzipStream = New-Object System.IO.Compression.GzipStream $decoded, ([IO.Compression.CompressionMode]::Decompress)
	$gzipStream.CopyTo($output)
	$gzipStream.Close()
	$decoded.Close()
	[byte[]] $byteOutArray = $output.ToArray()
	[System.IO.File]::WriteAllBytes($o,$byteOutArray)
	$output.Close()
} 
