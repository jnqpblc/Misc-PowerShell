function Get-Banner
{
    <#
    
    .SYNOPSIS

        Get-Banner.ps1 Function: Get-Banner
        Author: John Cartrett (@jnqpblc)
        License: BSD 3-Clause
        Required Dependencies: None
        Optional Dependencies: None

    .DESCRIPTION

        A primative PowerShell script to test TCP connections and dump its banner. 

    .LINK

        https://myitpath.blogspot.com/2013/02/simple-powershell-tcp-client-for.html

    .PARAMETER Target

	    Target is the IP Address or Hostname to connect too.
      
    .PARAMETER Target

	    Port is the TCP Port number to use.
      
    .EXAMPLE

	    Get-Banner 10.10.10.10 22
	    Get-Banner -Target 10.10.10.10 -Port 22
      
    #>  Param
    (
      [Parameter(Mandatory=$true, Position=0, HelpMessage="Please enter an IP Address or Hostname to connect too.")]
      [string] $Target,
      [Parameter(Mandatory=$true, Position=1, HelpMessage="Please enter a TCP Port number to use.")]
      [int] $Port
    )
  Try
    {
      $Con = New-Object System.Net.Sockets.TcpClient($Target, $Port)
      $Str = $Con.GetStream()
      $Buf = New-Object System.Byte[] 1024
      $Enc = New-Object System.Text.ASCIIEncoding
      Start-Sleep -m 200
      $Out = ""
      While ($Str.DataAvailable -and $Out -NotMatch "Username") {
        $Res = $Str.Read($Buf,0,1024)
        $Out += $Enc.GetString($Buf, 0, $Res)
        Start-Sleep -m 300
      }
      $Con.Close()
      Write-Host "[+] Successfully connected to the remote service."
      if (([string]::IsNullOrEmpty($UserFile))) {
        Write-Host "[!] The remote service did not respond to the inquiry."
        Break
      } else {
        Write-Host "[+] $Out"
      }
    }
  Catch
    {
      Write-Host "[!] Unable resolve or connect to host."
      Break
    }
}
