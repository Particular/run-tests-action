$platform = 'Windows'
if ($PSVersionTable.Platform -eq 'Unix') {
    $platform = 'Linux'
}

$projects = Get-ChildItem -Include "*Tests.csproj" -Recurse

$testFrameworks = New-Object Collections.Generic.HashSet[String]

Write-Output "Detected test projects:"

$projects | ForEach-Object {
    $filename = $_.Name
    Write-Output " - $filename"
    $path = $_.FullName
    Select-Xml -Path $path -XPath "/Project/PropertyGroup/TargetFrameworks" | ForEach-Object {
        $frameworks = $_.node.InnerText -Split ';'
        foreach( $framework in $frameworks) {
            $testFrameworks.Add($framework) > $null
        }
    }
}

Write-Output "Detected target frameworks:"
$testFrameworks | ForEach-Object { Write-Output " - $_"}

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