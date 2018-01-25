clear
.\Tools.ps1
function CreateNuspeckFile($config)
{
	CheckNugetExe
	CheckNuspeckPrototype
	CopyNuspeckToOutputDirectory
	AddFilesNode
	#ClearNuspeckPrototype
	UpdateNuspeckWithConfiguration
	AddProjectDlls $config
}



function CheckNugetExe()
{
	
	if (!$(Test-Path $nugetExePath))
	{
		DownloadLatestNuget
	}
}

function DownloadLatestNuget()
{
	$url = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
	Invoke-WebRequest -Uri $url -OutFile $nugetExePath
}

function CheckNuspeckPrototype()
{
	if (!$(Test-Path $nuspecPrototypePath))
	{
		CreateNuspeckPrototype
	}
}

function CreateNuspeckPrototype()
{
	& $nugetExePath spec
}

function CopyNuspeckToOutputDirectory()
{
	Copy-Item $nuspecPrototypePath $outputNuspeckPath
}

function AddFilesNode()
{
	[xml]$nuspeck=Get-Content $outputNuspeckPath
	$element=$nuspeck.CreateElement("files")
	$nuspeck.package.AppendChild($element)
	$nuspeck.Save($outputNuspeckPath)
}

#function ClearNuspeckPrototype()
#{
#	[xml]$xml=Get-Content -Path $outputNuspeckPath
#	$xmlMetaData=$xml.package.metadata
#
#	$nodesToRemove=@('licenseUrl','projectUrl','copyright')
#	foreach($item in $nodesToRemove)
#	{
#		$parent_xpath = $item
#	 	$nodes = $xmlMetaData.SelectNodes($parent_xpath)
#	 	$xmlMetaData.RemoveChild($nodes[0])
#	}
#	$xml.Save($outputNuspeckPath)
#}

function UpdateNuspeckWithConfiguration()
{
	[xml]$ConfigrationFile=Get-Content $nugetMetadataFilePath
	$nodesToRemove=@()
		
	[xml]$outputNuspeck=Get-Content $outputNuspeckPath
	$outputNuspeckMetaData=$outputNuspeck.package.metadata	
	foreach($item in $outputNuspeckMetaData.ChildNodes)
	{

		Write-Host  $item.Name
		$variable=$ConfigrationFile | select-xml -xpath "/package/metadata/$($item.Name)" 
		$node = $outputNuspeckMetaData.ChildNodes | where {$_.Name -eq "$($item.Name)"}
		if ($variable -eq $null)
		{
			$nodesToRemove+=$node
		}
		else
		{
			$node.InnerText=$variable
		}
		
	}
	$nodesToRemove | %{$outputNuspeckMetaData.RemoveChild($_)}
	
	$outputNuspeck.Save($outputNuspeckPath)	
}



function GetDoNotIncludeProjects()
{
	[xml]$nugetConfiguration=Get-Content $nugetConfigurationFilePath
	$doNotIncludeProjects=$nugetConfiguration.SelectNodes("NugetConfiguration/DoNotIncludeProjects/ProjectPath") |%{$_.InnerText}
	return $doNotIncludeProjects
}

function AddProjectDlls($config)
{
	
	$doNotIncludeProjects=GetDoNotIncludeProjects
	#$solutionPath=FindSolutionPath $currentPath
	#$solutionDirectoryPath=(Get-ChildItem $solutionPath).Directory
	$solutionDirectoryPath=FindSolutionDirectory $currentPath
    $projectsList =  @();
    cat $solutionPath | where {$_.Contains(".csproj")} | foreach { $projectsList+= ($_.Split('"')[5]) }
	foreach ($project in $projectsList) 
    {
		Write-Host $project
		if ($doNotIncludeProjects -contains $project) { continue }
		$csprojFullPath=[System.IO.Path]::Combine($solutionDirectoryPath,$project)
		$csprojDirectoryPath=(Get-ChildItem $csprojFullPath).Directory
		$csproj = [xml] (cat $file$project)
        $ns = @{dns = 'http://schemas.microsoft.com/developer/msbuild/2003'}
        $assemblyName = $csproj | select-xml -xpath '/dns:Project/dns:PropertyGroup/dns:AssemblyName' -Namespace $ns
		$targetFrameworkVersion=$csproj | select-xml -xpath '/dns:Project/dns:PropertyGroup/dns:TargetFrameworkVersion' -Namespace $ns
		$outputXPath = "/dns:Project/dns:PropertyGroup[contains(@Condition, `""+$config+"`")]/dns:OutputPath"
		$outputPath=$csproj | select-xml -xpath $outputXPath -Namespace $ns
		$outputProjectFullPath=[System.IO.Path]::Combine($csprojDirectoryPath,$outputPath)
		ProcessDirectory $outputProjectFullPath $assemblyName $targetFrameworkVersion
		
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
}

function ProcessDirectory($directory, $assemblyName, $targetFrameworkVersion)
{
	$allItems=Get-Item "$directory$assemblyName*"
	$libDirectory='lib\$targetFrameworkVersion\'
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

function GetConfigurationProjectPath([string]$path,[string]$patterh)
{
	$configurationProjectPath=Get-ChildItem -Recurse -Path "$path\*$nugetMetadataXmlPattern"
	if ($configurationProjectPath -eq $null)
	{
		$parentPath=Split-Path $path
		return GetConfigurationProjectPath $parentPath $patterh
	}
	else
	{
		return $configurationProjectPath.DirectoryName
	}
}

function GetOutputConfigurationProjectDirectory($config)
{
	$configurationProjectPath=Get-ChildItem -Path "$nugetMetadataXmlConfigurationDirectoryPath\*.csproj"
	$csproj = [xml] (cat $configurationProjectPath)
	
	  $ns = @{dns = 'http://schemas.microsoft.com/developer/msbuild/2003'}
      #$assemblyName = $csproj | select-xml -xpath '/dns:Project/dns:PropertyGroup/dns:AssemblyName' -Namespace $ns
	  $outputXPath = "/dns:Project/dns:PropertyGroup[contains(@Condition, `""+$config+"`")]/dns:OutputPath"
	  $outputPath=$csproj | select-xml -xpath $outputXPath -Namespace $ns
	  $parentPath=Split-Path $outputPath
	  $nugetDirectory="$nugetMetadataXmlConfigurationDirectoryPath\$parentPath\nuget"
	  if (!(Test-Path $nugetDirectory))
	  {
	  	New-Item -ItemType directory -Path $nugetDirectory
	  }
	  return $nugetDirectory
}

function CreateNugetFile()
{
	$nugetExePath
	$outputDirectory
	Invoke-Expression -Command "$nugetExePath pack $outputNuspeckPath -OutputDirectory $outputNuspeckDirectoryPath"
}
$config="Debug"
$nugetMetadataXmlPattern="NugetMetadata.xml"
$nugetConfigurationXmlPattern="NugetConfiguration.xml"
$currentPath=CurrentPath
cd $currentPath

$nugetExePath="$currentPath\nuget.exe"
$nuspecPrototypePath="$currentPath\Package.nuspec"
$nugetMetadataXmlConfigurationDirectoryPath=GetConfigurationProjectPath $currentPath $nugetMetadataXmlPattern
$nugetMetadataFilePath="$nugetMetadataXmlConfigurationDirectoryPath\$nugetMetadataXmlPattern"
$nugetConfigurationFilePath="$nugetMetadataXmlConfigurationDirectoryPath\$nugetConfigurationXmlPattern"
$outputNuspeckDirectoryPath=GetOutputConfigurationProjectDirectory $config
$outputNuspeckPath="$outputNuspeckDirectoryPath\output.nuspec"

CreateNuspeckFile $config
CreateNugetFile