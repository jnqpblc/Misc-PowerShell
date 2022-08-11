<#
.SYNOPSIS
	Compresses or decompresses a C# binary for use in a PowerShell script.
.DESCRIPTION
	This PowerShell script has two functions. One to convert a C# binary into a Base64 compressed blob, and the other to reverse that operation.
.EXAMPLE
	PS> insert "Invoke-SharpHound.exe" "Invoke-SharpHound.b64" 
	PS> extract "Invoke-SharpHound.b64" "Invoke-SharpHound.exe"
#>

function insert($i, $o) {
    $i = [IO.File]::ReadAllBytes($i)
    $m = New-Object System.IO.MemoryStream
    $m.Write($i, 0, $i.Length)
    $m.Seek(0,0) | Out-Null
    $r = New-Object System.IO.Compression.DeflateStream($m, [System.IO.Compression.CompressionMode]::Compress)
    $m.CopyTo($r)
    $b = [System.Convert]::ToBase64String($m.ToArray())
    Out-File -FilePath $o
}

function extract($i, $o) {
    # https://gist.github.com/vortexau/13de5b6f9e46cf419f1540753c573206
    $i = (Get-Content -Path $i)
    $o = [System.IO.File]::OpenWrite($o)
    $d = [System.Convert]::FromBase64String($i)
    $m = New-Object System.IO.MemoryStream
    $m.Write($d, 0, $d.Length)
    $m.Seek(0,0) | Out-Null
    $r = New-Object System.IO.Compression.DeflateStream($m, [System.IO.Compression.CompressionMode]::Decompress)
    $r.CopyTo($o)
    $o.Close()
}
