function FindSolutionPath($path)
{
	Write-Host "FindSolutionPath $path"
	$sln=Get-ChildItem -Name "$path\*.sln"
	if ($sln -eq $null)
	{
		$path=Split-Path $path
		FindSolutionPath $path
	}
	else
	{
		return "$path\$sln"
	}
}

function FindSolutionDirectory($path)
{
	Write-Host "FindSolutionDirectory"
    $solutionPath=FindSolutionPath $path
    $solutionDirectoryPath=(Get-ChildItem $solutionPath).Directory
    return $solutionDirectoryPath
}