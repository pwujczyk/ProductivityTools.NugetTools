function ScriptPath()
{
    $scriptPath=$PSScriptRoot
    Write-Host "ScriptPath: $scriptPath"
	return $scriptPath
}


function Create-Nugets()
{
	write-host "NugetPTRunner"
	$scriptPath=ScriptPath
	. "$scriptPath\NugetPTBody.ps1"
	CreateNugets
}


Export-ModuleMember Create-Nugets

