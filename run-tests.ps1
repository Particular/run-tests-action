$testFrameworks = New-Object Collections.Generic.HashSet[String]
$testProjects = @{}

$explicitFramework = $Env:EXPLICIT_TEST_FRAMEWORK
$isExplicitFramework = -not ([string]::IsNullOrEmpty($explicitFramework))
if ($isExplicitFramework) {

    $testFrameworks.Add($explicitFramework)
    Write-Output "Target framework '$explicitFramework' defined by parameter. This is the only framework that will be tested."

}

Write-Output "Target Platform = $($Env:TARGET_PLATFORM)"

$projects = Get-ChildItem -Path src -Include "*.csproj" -Recurse

$projects | ForEach-Object {
    $project = $_.FullName

    $testSdkNodes = Select-Xml -Path $project -XPath "/Project/ItemGroup/PackageReference[@Include='Microsoft.NET.Test.Sdk']"

    if ( $testSdkNodes -ne $null ) {
        $projectFrameworks = New-Object Collections.Generic.List[String]
        $testProjects.Add($project, $projectFrameworks)

        # In case of multiple target frameworks
        Select-Xml -Path $project -XPath "/Project/PropertyGroup/TargetFrameworks" | ForEach-Object {
            $frameworks = $_.node.InnerText -Split ';'
            foreach( $framework in $frameworks) {
                $testProjects.$project.Add($framework)

                if (-not $isExplicitFramework) {
                    $testFrameworks.Add($framework) > $null
                }
            }
        }

        # In case of a single target framework
        Select-Xml -Path $project -XPath "/Project/PropertyGroup/TargetFramework" | ForEach-Object {
            $testProjects.$project.Add($_.node.InnerText)

            if (-not $isExplicitFramework) {
                $testFrameworks.Add($_.node.InnerText) > $null
            }
        }
    }
}

$testProjects = $testProjects.GetEnumerator() | Sort-Object Name
$testFrameworks = $testFrameworks.GetEnumerator() | Sort-Object
$reportWarnings = 'false'
$filter = ''

if ($Env:FILTER -ne '') {
    $filter = $($Env:FILTER)
}

$exitCode = 0
$counter = 0

foreach ($framework in $testFrameworks) {

    $counter = $counter + 1

    if (($PSVersionTable.Platform -eq 'Unix') -and ($framework.StartsWith("net4"))) {
        continue
    }

    foreach ($project in $testProjects) {

        if (-not $project.Value.Contains($framework)) {
            continue
        }

        Write-Output "::group::Running $(Split-Path $project.Name -leaf) ($framework)"

        $targetPlatformParam = "RunConfiguration.TargetPlatform=$($Env:TARGET_PLATFORM)"

        if ($filter -ne '') {
           dotnet test $project.Name --configuration Release --no-build --filter "$filter" --framework $framework --logger "GitHubActions;report-warnings=$reportWarnings" -- $targetPlatformParam
        }
        else {
            dotnet test $project.Name --configuration Release --no-build --framework $framework --logger "GitHubActions;report-warnings=$reportWarnings" -- $targetPlatformParam
        }
        

        Write-Output "::endgroup::"

        if ($LASTEXITCODE -ne 0) {
            Write-Output "::error::Exit code = $LASTEXITCODE"
            $exitCode = 1
        }
    }

    if (($counter -lt $testFrameworks.Count) -and ($Env:HAS_RESET_SCRIPT -eq 'true')) {
        Write-Output "::group::Running reset script"
        Invoke-Expression $Env:RESET_SCRIPT
        Write-Output "::endgroup::"

        if ($LASTEXITCODE -ne 0) {
            Write-Output "::error::Exit code = $LASTEXITCODE"
            $exitCode = 1
        }
    }
}

exit $exitCode