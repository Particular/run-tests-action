# Runs dotnet test for the test projects in the repository.
#
# Two execution modes:
#
#  * Sequential (MAX_PARALLEL == 1, the default and historic behavior) -- runs `dotnet test` once
#    per (project, framework), grouped by framework, and invokes RESET_SCRIPT between consecutive
#    frameworks when one was supplied. This path is preserved verbatim from the pre-v1.8.0 action so
#    existing consumers see no change.
#
#  * Parallel (MAX_PARALLEL > 1) -- runs several `dotnet test` processes at once, buffering each
#    run's stdout/stderr to temp files and replaying it inside a ::group:: on completion, because
#    interleaved live `dotnet test` output is unreadable. Ported from ServiceControl's
#    tools/run-tests.ps1. reset-script is ignored in this mode (with a warning), because running it
#    concurrently with in-flight test processes is unsafe and "between frameworks" has no meaning
#    once runs are flattened.
#
# Per-run parallel index:
#
#  Every spawned `dotnet test` process (in both modes) has PARTICULAR_RUN_TESTS_ACTION_PARALLEL_INDEX
#  set to its 0-based position in the flattened run list immediately before it is spawned, so the
#  child inherits the value. The index is unique across all runs in the invocation, so concurrent
#  runs always see distinct indices. In sequential mode the index is always 0 (only one run is
#  active at a time). Consumers that need per-run distinct resources -- e.g. ServiceControl derives
#  its RavenDB port as 33334 + (index * 10) -- read this env var; the action itself does no port
#  arithmetic.
#
# Project selection:
#
#  * If TEST_PROJECTS is set, it is a newline- or semicolon-delimited list of project paths; discovery is skipped
#    and only those projects are tested.
#  * Otherwise, today's discovery is used: every *.csproj under src/ that references
#    Microsoft.NET.Test.Sdk.
#
# EXPLICIT_TEST_FRAMEWORK short-circuits framework discovery to a single value in both modes.

$ErrorActionPreference = 'Stop'

$explicitFramework = $Env:EXPLICIT_TEST_FRAMEWORK
$isExplicitFramework = -not ([string]::IsNullOrEmpty($explicitFramework))

$testFrameworks = New-Object Collections.Generic.HashSet[String]

if ($isExplicitFramework) {
    $testFrameworks.Add($explicitFramework) > $null
    Write-Output "Target framework '$explicitFramework' defined by parameter. This is the only framework that will be tested."
}

Write-Output "Target Platform = $($Env:TARGET_PLATFORM)"

# --- Project selection --------------------------------------------------------
$explicitProjectsRaw = $Env:TEST_PROJECTS
$hasExplicitProjects = -not ([string]::IsNullOrEmpty($explicitProjectsRaw))

$testProjects = @{}

if ($hasExplicitProjects) {
    $projectPaths = $explicitProjectsRaw -Split "[\n;]" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    Write-Output "Using explicit project list ($($projectPaths.Count) project(s)) supplied via 'projects' input; project discovery is skipped."

    foreach ($project in $projectPaths) {
        $projectFrameworks = New-Object Collections.Generic.List[String]

        # In case of multiple target frameworks
        Select-Xml -Path $project -XPath "/Project/PropertyGroup/TargetFrameworks" | ForEach-Object {
            $frameworks = $_.node.InnerText -Split ';'
            foreach ($framework in $frameworks) {
                $projectFrameworks.Add($framework)
            }
        }

        # In case of a single target framework
        Select-Xml -Path $project -XPath "/Project/PropertyGroup/TargetFramework" | ForEach-Object {
            $projectFrameworks.Add($_.node.InnerText)
        }

        if ($isExplicitFramework) {
            # Honor the framework override: keep only the explicit framework, and only if the
            # project actually targets it. Mirrors the Contains($framework) check the discovery
            # path uses when iterating.
            $filtered = New-Object Collections.Generic.List[String]
            foreach ($f in $projectFrameworks) {
                if ($f -eq $explicitFramework) {
                    $filtered.Add($f)
                }
            }
            $projectFrameworks = $filtered
        }
        else {
            foreach ($f in $projectFrameworks) {
                $testFrameworks.Add($f) > $null
            }
        }

        $testProjects.Add($project, $projectFrameworks)
    }
}
else {
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
                foreach ($framework in $frameworks) {
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
}

$reportWarnings = 'false'
if ($Env:REPORT_WARNINGS -eq 'true') {
    $reportWarnings = 'true'
}

$maxParallel = [Math]::Max(1, [int]$Env:MAX_PARALLEL)
if ($maxParallel -eq 1) {
    # --- Sequential path: historic behavior, reset-script between frameworks ---
    $testProjectsSorted = $testProjects.GetEnumerator() | Sort-Object Name
    $testFrameworksSorted = $testFrameworks.GetEnumerator() | Sort-Object

    $exitCode = 0
    $counter = 0

    foreach ($framework in $testFrameworksSorted) {

        $counter = $counter + 1

        if (($PSVersionTable.Platform -eq 'Unix') -and ($framework.StartsWith("net4") -or $framework.Contains("-windows"))) {
            continue
        }

        foreach ($project in $testProjectsSorted) {

            if (-not $project.Value.Contains($framework)) {
                continue
            }

            Write-Output "::group::Running $(Split-Path $project.Name -leaf) ($framework)"

            $targetPlatformParam = "RunConfiguration.TargetPlatform=$($Env:TARGET_PLATFORM)"

            $Env:PARTICULAR_RUN_TESTS_ACTION_PARALLEL_INDEX = '0'

            dotnet test $project.Name --configuration Release --no-build --framework $framework --logger "GitHubActions;report-warnings=$reportWarnings" -- RunConfiguration.TreatNoTestsAsError=true $targetPlatformParam

            Write-Output "::endgroup::"

            if ($LASTEXITCODE -ne 0) {
                Write-Output "::error::Exit code = $LASTEXITCODE"
                $exitCode = 1
            }
        }

        if (($counter -lt $testFrameworksSorted.Count) -and ($Env:HAS_RESET_SCRIPT -eq 'true')) {
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
}
else {
    # --- Parallel path: ported from ServiceControl tools/run-tests.ps1 ---
    Write-Output "Max parallel test runs = $maxParallel"

    if ($Env:HAS_RESET_SCRIPT -eq 'true') {
        Write-Output "::warning::reset-script is ignored when max-parallel > 1. Running it concurrently with in-flight test processes is unsafe, and 'between frameworks' has no meaning once runs are flattened."
    }

    $isUnix = $PSVersionTable.Platform -eq 'Unix'

    $testProjectsSorted = $testProjects.GetEnumerator() | Sort-Object Name
    $testFrameworksSorted = $testFrameworks.GetEnumerator() | Sort-Object

    # Flatten into a list of (Label, Project, Framework) runs, ordered by framework then project,
    # skipping frameworks that cannot run on this platform. Each run is tagged with its 0-based
    # Index in this flattened list, which is exposed to consumers via
    # PARTICULAR_RUN_TESTS_ACTION_PARALLEL_INDEX (see D3) so concurrent runs can derive distinct
    # per-run resources (ports, temp dirs, etc.) from it.
    $runs = [Collections.Generic.List[object]]::new()
    $runIndex = 0

    foreach ($framework in $testFrameworksSorted) {
        if ($isUnix -and ($framework.StartsWith('net4') -or $framework.Contains('-windows'))) {
            continue
        }

        foreach ($project in $testProjectsSorted) {
            if (-not $project.Value.Contains($framework)) {
                continue
            }

            $runs.Add([pscustomobject]@{
                    Label     = "$(Split-Path $project.Name -Leaf) ($framework)"
                    Project   = $project.Name
                    Framework = $framework
                    Index     = $runIndex
                })
            $runIndex++
        }
    }

    if ($runs.Count -eq 0) {
        throw 'No test projects were runnable on this platform.'
    }

    # Per-run parallel index. Concurrent runs need to distinguish themselves (e.g. so suites that
    # bind a fixed port like ServiceControl's RavenDB.Embedded tests do not all probe-and-bind the
    # same port). Rather than bake port arithmetic into the action, each run is tagged with its
    # 0-based position in the flattened run list (unique across the whole invocation) and that value
    # is exposed via PARTICULAR_RUN_TESTS_ACTION_PARALLEL_INDEX immediately before spawning, so the
    # child inherits it. Consumers derive whatever per-run distinct resource they need from the
    # index. The action itself does no port arithmetic. (See design decision D3.)
    $exitCode = 0

    # Buffered output lives in a fixed place with readable names, and a run's files are only removed
    # once its output has been replayed, so a run that never completes, because the job was cancelled
    # or hit its timeout, leaves its files behind for the final step of the action to show.
    $outputDirectory = Join-Path ($Env:RUNNER_TEMP ?? [IO.Path]::GetTempPath()) 'run-tests-action'
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

    function Complete-Run($run) {
        Write-Output "::group::Running $($run.Label)"
        foreach ($stream in @($run.OutFile, $run.ErrFile)) {
            if ((Test-Path $stream) -and (Get-Item $stream).Length -gt 0) {
                Get-Content -Path $stream | Write-Output
            }
            Remove-Item -Path $stream -Force -ErrorAction SilentlyContinue
        }
        Write-Output '::endgroup::'

        if ($run.ExitCode -ne 0) {
            Write-Output "::error::$($run.Label) exit code = $($run.ExitCode)"
            $script:exitCode = 1
        }
    }

    $runs `
        | ForEach-Object -ThrottleLimit $maxParallel -Parallel {
            $run = $_
            $rw = $using:reportWarnings

            $outputName = "$($run.Index)-$([IO.Path]::GetFileNameWithoutExtension($run.Project)).$($run.Framework)"
            $run | Add-Member -NotePropertyName OutFile -NotePropertyValue (Join-Path $using:outputDirectory "$outputName.out.log")
            $run | Add-Member -NotePropertyName ErrFile -NotePropertyValue (Join-Path $using:outputDirectory "$outputName.err.log")

            $arguments = @(
                'test', $run.Project
                '--configuration', 'Release'
                '--no-build'
                '--framework', $run.Framework
                '--logger', "GitHubActions;report-warnings=$rw"
                '--'
                'RunConfiguration.TreatNoTestsAsError=true'
                "RunConfiguration.TargetPlatform=$($Env:TARGET_PLATFORM)"
            )

            # Write-Host bypasses the pipeline so the message is not mistaken for a run
            # object by the sequential ForEach-Object stage below.
            Write-Host "Starting $($run.Label)"

            $process = Start-Process -FilePath 'dotnet' -ArgumentList $arguments -NoNewWindow -PassThru `
                    -RedirectStandardOutput $run.OutFile -RedirectStandardError $run.ErrFile `
                    -Environment @{ PARTICULAR_RUN_TESTS_ACTION_PARALLEL_INDEX = "$($run.Index)" }

            while (-not $process.HasExited) {
                Start-Sleep -Milliseconds 500
            }

            # Bounded on purpose. The parameterless WaitForExit() also waits for the redirected streams to
            # reach EOF, and on Linux Start-Process pumps them through a pipe, so a test that leaves behind
            # a child holding the inherited handle blocks it forever. HasExited has already told us the
            # test process itself is done; this only gives the pump a moment to drain.
            [void]$process.WaitForExit(5000)

            $run | Add-Member -NotePropertyName ExitCode -NotePropertyValue $process.ExitCode
            $run
        } `
        # Stage 2 (sequential): replay each run's buffered output so it doesn't interleave.
        | ForEach-Object { Complete-Run $_ }

    exit $exitCode
}
