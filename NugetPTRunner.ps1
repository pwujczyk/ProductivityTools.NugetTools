function ScriptPath()
{
    $scriptPath=$PSScriptRoot
    Write-Host "ScriptPath: $scriptPath"
	return $scriptPath
}


clear
write-host "NugetPTRunner"
$scriptPath=ScriptPath
cd $scriptPath
. .\NugetPTBody.ps1
CreateNugets
