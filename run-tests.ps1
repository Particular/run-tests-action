$platform = 'Windows'
if ($PSVersionTable.Platform -eq 'Unix') {
    $platform = 'Linux'
}

$testFrameworks = New-Object Collections.Generic.HashSet[String]
$testProjectNames = New-Object Collections.Generic.List[String]

$explicitFramework = $Env:EXPLICIT_TEST_FRAMEWORK
if (-not ([string]::IsNullOrEmpty($explicitFramework))) {

    $testFrameworks.Add($explicitFramework);
    Write-Ouput "Target framework '$explicitFramework' defined by parameter. This is the only framework that will be tested."

} else {

    $projects = Get-ChildItem -Path src -Include "*.csproj" -Recurse

    $projects | ForEach-Object {
        $filename = $_.Name
        $path = $_.FullName

        $testSdkNodes = Select-Xml -Path $path -XPath "/Project/ItemGroup/PackageReference[@Include='Microsoft.NET.Test.Sdk']"

        if ( $testSdkNodes -ne $null ) {
            $testProjectNames.Add($filename)

            # In case of multiple target frameworks
            Select-Xml -Path $path -XPath "/Project/PropertyGroup/TargetFrameworks" | ForEach-Object {
                $frameworks = $_.node.InnerText -Split ';'
                foreach( $framework in $frameworks) {
                    $testFrameworks.Add($framework) > $null
                }
            }

            # In case of a single target framework
            Select-Xml -Path $path -XPath "/Project/PropertyGroup/TargetFramework" | ForEach-Object {
                $testFrameworks.Add($_.node.InnerText) > $null
            }
        }
    }

    Write-Output "Detected test projects:"
    $testProjectNames | ForEach-Object { Write-Output " - $_" }

    Write-Output "Detected target frameworks:"
    $testFrameworks | ForEach-Object { Write-Output " - $_" }
}

$exitCode = 0
$counter = 0

foreach ($framework in $testFrameworks) {

    $counter = $counter + 1

    if (($PSVersionTable.Platform -eq 'Unix') -and ($framework.StartsWith("net4"))) {
        continue
    }

    Write-Output "::group::Running test suite for $framework on $platform"
    # -m:1 parameter prevents test projects from being run in parallel, which could cause conflicts since PessimisticLocks project shares same tests
    dotnet test src --configuration Release --no-build --framework $framework --logger "GitHubActions;report-warnings=false" -m:1

    if ($LASTEXITCODE -ne 0) {
        $exitCode = 1
    }

    Write-Output "::endgroup::"

    if (($counter -lt $testFrameworks.Count) -and ($Env:HAS_RESET_SCRIPT -eq 'true')) {
        Write-Output "::group::Running reset script"
        Invoke-Expression $Env:RESET_SCRIPT
        if ($LASTEXITCODE -ne 0) {
            $exitCode = 1
        }
        Write-Output "::endgroup::"
    }
}

Write-Output "Exit code = $exitCode"

exit $exitCode