function Invoke-SharpieExec
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [String] $Command,
        [Parameter(Mandatory=$true)]
        [String] $Blob
    )
    $a=New-Object IO.MemoryStream(,[Convert]::FromBAsE64String($Blob))
    $decompressed = New-Object IO.Compression.GzipStream($a,[IO.Compression.CoMPressionMode]::DEComPress)
    $output = New-Object System.IO.MemoryStream
    $decompressed.CopyTo( $output )
    [byte[]] $byteOutArray = $output.ToArray()
    $assem = [System.Reflection.Assembly]::Load($byteOutArray);
    #$assem.CustomAttributes
    #$assem.EntryPoint |ft Name, ReflectedType, Module, IsPublic
    $OldConsoleOut = [Console]::Out
    $StringWriter = New-Object IO.StringWriter
    [Console]::SetOut($StringWriter)
    ([Type]$assem.EntryPoint.DeclaringType.FullName.ToString())::([String]$assem.EntryPoint.Name).Invoke($Command.Split(" "))
    [Console]::SetOut($OldConsoleOut)
    $Results = $StringWriter.ToString()
    $Results
}
Invoke-SharpieExec -Command "-h" -Blob ""
