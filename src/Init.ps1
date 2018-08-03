function ScriptPath()
{
    $scriptPath=$PSScriptRoot
    Write-Host "ScriptPath: $scriptPath"
	return $scriptPath
}


write-host "init"
$scriptPath=ScriptPath
Import-Module "$scriptPath\NugetPTModule.psm1"