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
	Write-Host "Finding solution file (sln) in directory $path"
    if ($path -eq $null)
    {
        $path = CurrentPath
    }
	
	if ($path -match "\\packages\\") 
	{
		Write-Host "Current path contains packages in directory name lets go out of it [$path]"
		$path=Split-Path $path
		return $(FindSolutionDirectory $path)
	}
	
    #Write-Host "FindSolutionDirectory $path"
    $nugetPath="$path\.nuget"
	$nugetDirectory=Test-Path -Path $nugetPath
	if ($nugetDirectory -eq $false)
	{
		Write-Host "Current path doesn't contain sln file lets search upper [$path]"
		$path=Split-Path $path
		return $(FindSolutionDirectory $path)
	}
	else
	{
		Write-Host "Solution directory: $path"
		return $path
	}
}

#search for all folders where NugetMetadata is placed but not packages and not main nuget directory
function FindAllNugetMetadataPreparedProjects()
{
    $projectFileList=@()
    $solutionDirectory=FindSolutionDirectory
    $allNugetMetadata=Get-ChildItem -Recurse -Path "$solutionDirectory\*.nuspec" #|where {$_.DirectoryName -notmatch "\.nuget"}
    foreach($nugetMetadataDirectory in $allNugetMetadata)
    {
        $projectFile=Get-ChildItem $nugetMetadataDirectory.DirectoryName -Filter *.csproj
		if ($projectFile -ne $null)
		{
        	$projectFileList += @{'ProjectFile'=$projectFile;'NugetMetaDataPath'=$nugetMetadataDirectory}
		}
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
    $nuspeckDestination=Join-Path $projectOutputNuspeckPath "$assemblyName.nuspec"
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
				if ($item.Id -eq "NugetPT") { continue}
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

function AddProjectDlls($nugetMetaDataPath, $projectPath,$config, $outputNuspeckPath)
{
		Write-Host $projectPath
		$csprojFullPath=$($projectPath.FullName)
		$csprojDirectoryPath=(Get-ChildItem $csprojFullPath).Directory
		$csproj = [xml](cat $csprojFullPath)
        $ns = @{dns = 'http://schemas.microsoft.com/developer/msbuild/2003'}
        $assemblyName = $csproj | select-xml -xpath '/dns:Project/dns:PropertyGroup/dns:AssemblyName' -Namespace $ns
		$targetFrameworkVersion=$csproj | select-xml -xpath '/dns:Project/dns:PropertyGroup/dns:TargetFrameworkVersion' -Namespace $ns
		$outputXPath = "/dns:Project/dns:PropertyGroup[contains(@Condition, `""+$config+"`")]/dns:OutputPath"
		$outputPath=$csproj | select-xml -xpath $outputXPath -Namespace $ns
        $outputProjectFullPath=[System.IO.Path]::Combine($csprojDirectoryPath,$outputPath)
        
        if ($outputNuspeckPath -eq $null)
        {
            $outputNuspeckPath=CreateNuspeckInOutputDirectory $assemblyName $nugetMetaDataPath $outputProjectFullPath
        }
		ProcessDirectory $outputNuspeckPath $outputProjectFullPath $assemblyName $targetFrameworkVersion
        
        AddDependencies $csprojDirectoryPath  $outputNuspeckPath

        $projectReferences=$csproj | select-xml -XPath '/dns:Project/dns:ItemGroup/dns:ProjectReference/@Include' -Namespace $ns
        foreach($referencedProject in $projectReferences)
        {
            $referencedShortPath=$projectReferences.Node.Value
            $projectFullPath=Get-ChildItem $(join-path $projectPath.DirectoryName $referencedShortPath)
            Write-Host "$projectFullPath"
            AddProjectDlls $nugetMetaDataPath $projectFullPath $config $outputNuspeckPath
        }
        
        CreateNugetFile $outputNuspeckPath

}

function CreateNugetFile()
{
    param($outputNuspeckPath)
	$nugetExePath =CheckNugetExe
	$outputNugetDirectoryPath=$(get-item $outputNuspeckPath).DirectoryName
	$command="$nugetExePath pack $outputNuspeckPath -OutputDirectory $outputNugetDirectoryPath"
	Write-Host "invoking command $command"
	Invoke-Expression -Command $command
}

function GetNugetExePath()
{
    $solutionDirectory=FindSolutionDirectory
    return "$solutionDirectory\.nuget\Nuget.exe"
}

function CheckNugetExe()
{
    $nugetExePath=GetNugetExePath
	if (!$(Test-Path $nugetExePath))
	{
		DownloadLatestNuget $nugetExePath
    }
    return  $nugetExePath
}

function DownloadLatestNuget($nugetExePath)
{
	$url = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
	Invoke-WebRequest -Uri $url -OutFile $nugetExePath
}


function ProcessProjects()
{
	$project=$null
    $projects=FindAllNugetMetadataPreparedProjects
	$projectsCount=$projects.Length
	Write-Host "Found $projectsCount projects ready to be nuspecked"
	if ($projectsCount -eq 0)
	{
		Write-Host "Haven't found any project to be nuspecked, maybe you forgot to copy NugetMetadata.nuspec to your project?"
	}
	
    foreach($nugetProjectFile in $projects)
    {
        Write-Host "Processing Project $($nugetProjectFile.ProjectFile.FullName)"
        AddProjectDlls $($nugetProjectFile.NugetMetaDataPath) $($nugetProjectFile.ProjectFile) "Debug"
    }
}

function CreateNugets()
{
	Write-Host "CreateNugetStarted"
	#$solutionDir=FindSolutionDirectory
	#cd $solutionDir
	ProcessProjects
}

function CreateNugetsAndPushToRepository()
{
    
}


