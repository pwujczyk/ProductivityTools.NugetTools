function CurrentPath()
{
    #$currentPath=$PSScriptRoot
    $currentPath=Get-Location
    Write-Host "CurrentPath: $currentPath"
	return $currentPath
}

#it finds folder where .nuget file is stored
function FindSolutionDirectory($path)
{
    if ($path -eq $null)
    {
        $path = CurrentPath
    }
    Write-Host "FindSolutionDirectory $path"
    $nugetPath="$path\.nuget"
	$nugetDirectory=Test-Path -Path $nugetPath
	if ($nugetDirectory -eq $false)
	{
		$path=Split-Path $path
		FindSolutionDirectory $path
	}
	else
	{
		return $path
	}
}

#search for all folders where NugetMetadata is placed but not packages and not main nuget directory
function FindAllNugetMetadataPreparedProjects()
{
    $projectFileList=@()
    $solutionDirectory=FindSolutionDirectory
    $allNugetMetadata=Get-ChildItem -Recurse -Path "$solutionDirectory\*NugetMetadata.xml" |where {$_.DirectoryName -notmatch ".nuget"}
    foreach($nugetMetadataDirectory in $allNugetMetadata)
    {
        $projectFile=Get-ChildItem $nugetMetadataDirectory.DirectoryName -Filter *.csproj
        $projectFileList += @{'ProjectFile'=$projectFile;'NugetMetaDataPath'=$nugetMetadataDirectory}
    }
    return $projectFileList
}

function AddFilesNode()
{
    param($outputNuspeckPath)
    [xml]$nuspeck=Get-Content $outputNuspeckPath
    $files = $nuspeck.SelectSingleNode("//files")
    if ($files -eq $null)
    {
	    $element=$nuspeck.CreateElement("files")
	    $nuspeck.package.AppendChild($element)
        $nuspeck.Save($outputNuspeckPath)
    }
}

function ProcessDirectory($outputNuspeckPath,$directory, $assemblyName, $targetFrameworkVersion)
{
	$allItems=Get-Item "$directory$assemblyName*"
    $libDirectory='lib\$targetFrameworkVersion\'
    AddFilesNode $outputNuspeckPath
    [xml]$nuspeckFile=get-content $outputNuspeckPath
	$files = $nuspeckFile.SelectSingleNode("//files")
	foreach($item in $allItems)
	{
		$elem = $nuspeckFile.CreateElement('file')
		$elem.SetAttribute('src',$item)
		$elem.SetAttribute('target',"lib\$targetFrameworkVersion\")
		$files.AppendChild($elem)	
	}
	$nuspeckFile.Save($outputNuspeckPath)
}

function CreateNuspeckInOutputDirectory()
{
    param([string]$assemblyName, [string]$projectNuspeckPath,[string]$projectOutputDirectory)
    #$nuspeckName=split-path $projectNuspeckPath -Leaf
    $projectOutputNuspeckPath= $( $projectOutputDirectory.trim('\')+"Nuget")
    if ((Test-Path $projectOutputNuspeckPath)-eq $false)
    {
        New-Item -ItemType Directory -Path $projectOutputNuspeckPath |Out-Null
    }
    $nuspeckDestination=Join-Path $projectOutputNuspeckPath "$assemblyName.xml"
   Copy-Item $projectNuspeckPath $nuspeckDestination -Force |Out-Null
   return $nuspeckDestination
}

function AddDependencies()
{
    param($csprojDirectoryPath, $outputNuspeckPath)
	    $packagesConfigPath = "$csprojDirectoryPath\packages.config"
		if (Test-Path $packagesConfigPath)
		{
			[XML]$packagesConfigXml=Get-Content $packagesConfigPath
			[xml]$nuspeckFile=get-content $outputNuspeckPath
			foreach($item in $packagesConfigXml.packages.ChildNodes)
			{
				$elem = $nuspeckFile.CreateElement('dependency')
				$elem.SetAttribute('id',$item.Id)
				$elem.SetAttribute('version',$item.Version)
				$metadata=$nuspeckFile.package.metadata
				$dependencies=$nuspeckFile.SelectSingleNode("/package/metadata/dependencies")
				$dependencies.AppendChild($elem)	
			}
			$nuspeckFile.Save($outputNuspeckPath)
		}		
}

function AddProjectDlls($project,$config)
{
		Write-Host $project
		$csprojFullPath=$($project.ProjectFile.FullName)
		$csprojDirectoryPath=(Get-ChildItem $csprojFullPath).Directory
		$csproj = [xml](cat $csprojFullPath)
        $ns = @{dns = 'http://schemas.microsoft.com/developer/msbuild/2003'}
        $assemblyName = $csproj | select-xml -xpath '/dns:Project/dns:PropertyGroup/dns:AssemblyName' -Namespace $ns
		$targetFrameworkVersion=$csproj | select-xml -xpath '/dns:Project/dns:PropertyGroup/dns:TargetFrameworkVersion' -Namespace $ns
		$outputXPath = "/dns:Project/dns:PropertyGroup[contains(@Condition, `""+$config+"`")]/dns:OutputPath"
		$outputPath=$csproj | select-xml -xpath $outputXPath -Namespace $ns
        $outputProjectFullPath=[System.IO.Path]::Combine($csprojDirectoryPath,$outputPath)
        
        $outputNuspeckPath=CreateNuspeckInOutputDirectory $assemblyName $($project.NugetMetaDataPath) $outputProjectFullPath
		ProcessDirectory $outputNuspeckPath $outputProjectFullPath $assemblyName $targetFrameworkVersion
        
        AddDependencies $csprojDirectoryPath  $outputNuspeckPath
	
	
}

function ProcessProjects()
{
    $projects=FindAllNugetMetadataPreparedProjects
    foreach($nugetProjectFile in $projects)
    {
        Write-Host "Processing Project $($nugetProjectFile.ProjectFile.FullName)"
        AddProjectDlls $nugetProjectFile "Debug"
    }
}


clear
cd D:\trash\ClassLibrary11\Project2\
ProcessProjects
