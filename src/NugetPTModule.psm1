function ScriptPath()
{
    $scriptPath=$PSScriptRoot
    Write-Host "ScriptPath: $scriptPath"
	return $scriptPath
}

function Init()
{
	write-host "NugetPTRunner"

}


function Create-Nugets()
{
	write-host "NugetPTRunner-Create-Nugets"
	
	$scriptPath=ScriptPath
	. "$scriptPath\NugetPTBody.ps1"
	CreateNugets
}

function Set-ApiKey()
{
	param([string]$apiKey)
	
	write-host "NugetPTRunner-Set-ApiKey"
	
	$scriptPath=ScriptPath
	. "$scriptPath\NugetPTBody.ps1"
	SetApiKey $apiKey
	
}
	

function Push-Nugets()
{
	param($repositoryPath)
	
	write-host "NugetPTRunner-Push-Nugets"
	
	$scriptPath=ScriptPath
	. "$scriptPath\NugetPTBody.ps1"
	PushNugets $repositoryPath
}


Export-ModuleMember Create-Nugets
Export-ModuleMember Push-Nugets
Export-ModuleMember Set-ApiKey

