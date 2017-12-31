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

function AddNugetSolutionFolder()
{
    Write-Host "Adding .nuget directory to solution"
    $vsSolution = Get-Interface $dte.Solution ([EnvDTE80.Solution2])
    $vsProject = $vsSolution.AddSolutionFolder(".nuget")
    Write-Host ".nuget directory to solution added"
    return $vsProject
}

function AddFileToSolutionFolder($vsProject,[string]$fileName)
{  
    $projectItems = Get-Interface $vsProject.ProjectItems ([EnvDTE.ProjectItems])
    $solutionPath = Split-Path -Path $vsSolution.FullName
    $configurationxmlPath=Join-Path  $solutionPath $fileName
    Write-Host "Adding $configurationxmlPath to solution"
    $projectItems.AddFromFile($configurationxmlPath)
}
function AddSolutionFolder()
{
    $vsProject=AddNugetSolutionFolder
    AddFileToSolutionFolder $vsProject "\.nuget\NugetConfiguration.xml" 
    AddFileToSolutionFolder $vsProject "\.nuget\NugetMetadata.xml"
}

$currentPath=CurrentPath
Write-Host "current path= $currentPath"
CreateNugetDirectory $currentPath
Write-Host "Nuget directory created"
AddSolutionFolder