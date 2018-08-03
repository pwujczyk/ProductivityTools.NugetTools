param($installPath, $toolsPath, $package, $project)
Write-Host "started"
function CurrentPath()
{
	return $PSScriptRoot
}

$PSScriptRoot
. "$(CurrentPath).\Tools.ps1"
Write-Host "Tools loaded"
function CreateNugetDirectory($path)
{
    Write-Host "Create NugetDirectory $path"
    $solutionDirectory=FindSolutionDirectory($path)
    Copy-Item -Path "$path\.nuget" -Destination $solutionDirectory -Recurse
}
function AddFileToSolutionFolder($SolutionFolder, $File)
{
    Write-Host "Solution folder $SolutionFolder"
    Write-Host "File $File"
    $FileName = Split-Path -Path $File -Leaf
    Write-Host "FileName $FileName"
    $ProjectItems = Get-Interface $SolutionFolder.ProjectItems ([EnvDTE.ProjectItems])
    Write-Host "Project Items $ProjectItems"
    if($ProjectItems -and $($ProjectItems.GetEnumerator() | Where-Object { $_.FileNames(1) -eq $File }) -eq $null) {
        Write-Host "Adding '$FileName' to solution folder '$($SolutionFolder.Name)'."
        $ProjectItems.AddFromFile($File) | Out-Null
    }
}

function GetSolution()
{
	$vsSolution = Get-Interface $dte.Solution ([EnvDTE80.Solution2])
    return $vsSolution
}

function AddNugetSolutionFolder()
{
    Write-Host "Adding .nuget directory to solution"
    $vsSolution = GetSolution
    $vsProject = $vsSolution.AddSolutionFolder(".nuget")
    Write-Host ".nuget directory to solution added"
    return $vsProject
}

function AddFileToSolutionFolder($vsProject,[string]$fileName)
{  
    $projectItems = Get-Interface $vsProject.ProjectItems ([EnvDTE.ProjectItems])
	
    $solutionPath = GetSolutionPath
    $configurationxmlPath=Join-Path  $solutionPath $fileName
    Write-Host "Adding $configurationxmlPath to solution"
    $projectItems.AddFromFile($configurationxmlPath)
}

function GetSolutionPath()
{
	$vsSolution = GetSolution
    $solutionPath = Split-Path -Path $vsSolution.FullName
	return $solutionPath
}

#I don't know why (havent found any explanation) in nuget you cannot put nuspeck file
function RenameNuspeckFile()
{
	$solutionPath = GetSolutionPath
    $nuspeckFilePathSource=Join-Path  $solutionPath "\.nuget\NugetMetadata.nuspec_"
	$nuspeckFilePathDest=Join-Path  $solutionPath "\.nuget\NugetMetadata.nuspec"
	Rename-Item -LiteralPath $nuspeckFilePathSource -NewName $nuspeckFilePathDest
	
}

function AddSolutionFolder()
{
    $vsProject=AddNugetSolutionFolder
	RenameNuspeckFile "\.nuget\NugetMetadata.nuspec"
    AddFileToSolutionFolder $vsProject "\.nuget\NugetMetadata.nuspec"
}

$currentPath=CurrentPath
Write-Host "current path= $currentPath"
CreateNugetDirectory $currentPath
Write-Host "Nuget directory created"
AddSolutionFolder