# run-tests-action

This action runs tests for Particular Software repos according to our conventions:

1. Finds test projects by locating *.csproj files that have a `PackageReference` for `Microsoft.NET.Test.Sdk`
2. Finds all the target frameworks for the test projects
3. Runs `dotnet test` for each target framework, skipping `net4*` on Linux

## Usage

Basic:

```yaml
    steps:
      - name: Run tests
        uses: Particular/run-tests-action@v1.8.0
```

With a reset script between each test run:

```yaml
    steps:
      - name: Run tests
        uses: Particular/run-tests-action@v1.8.0
        with:
          reset-script: |
            echo "Do whatever is necessary to reset the test infrastructure between runs of each framework"
            echo "The script is invoked by PowerShell Invoke-Expression."
```

In cases where the test matrix subdivides by target framework, you can also short-circuit most of what this action does by specifying the framework to use for testing. While sounding counter-intuitive, it helps to keep the arguments given to `dotnet test` consistent with other repositories. (Added in v1.1.0)

```yaml
    steps:
      - name: Run tests
        uses: Particular/run-tests-action@v1.8.0
        with:
          framework: net6.0
```

By default, only failed tests are reported. To report warnings for tests that have neither failed nor succeeded (i.e. skipped or inconclusive):

```yaml
    steps:
      - name: Run tests
        uses: Particular/run-tests-action@v1.8.0
        with:
          report-warnings: true
```

By default, `dotnet test` uses `x64` as the target platform. This can be overridden:

```yaml
    steps:
      - name: Run tests
        uses: Particular/run-tests-action@v1.8.0
        with:
          target-platform: x86
```

## Running a subset of projects

By default the action discovers every `*.csproj` under `src/` that references `Microsoft.NET.Test.Sdk` and runs all of them. Pass `projects` to run an explicit, newline-delimited list of project paths instead, skipping discovery entirely. (Added in v1.8.0)

This is the intended integration point for repositories that subdivide their test suite by category and select a subset of assemblies per matrix job. For example, ServiceControl's [`tools/select-test-projects.ps1`](https://github.com/Particular/ServiceControl/blob/master/tools/select-test-projects.ps1) writes each category's project list to `$GITHUB_OUTPUT` as a multiline `test-projects` value, which can be passed straight through:

```yaml
    steps:
      - id: select
        shell: pwsh
        run: ./tools/select-test-projects.ps1
      - name: Run tests
        uses: Particular/run-tests-action@v1.8.0
        with:
          projects: ${{ steps.select.outputs.test-projects }}
```

When `projects` is combined with `framework`, each listed project is run only against that framework (projects that do not target it are skipped), mirroring the behavior of the discovery path.

## Parallel execution

By default the action runs `dotnet test` sequentially. Pass `max-parallel` (1–16) to run several test assemblies concurrently. (Added in v1.8.0)

```yaml
    steps:
      - name: Run tests
        uses: Particular/run-tests-action@v1.8.0
        with:
          projects: ${{ steps.select.outputs.test-projects }}
          max-parallel: 4
```

When `max-parallel > 1`, each run's stdout and stderr are buffered to temp files and replayed inside a `::group::` block once that run completes, because interleaved live `dotnet test` output is unreadable. The step fails if any run exits non-zero.

### Per-run parallel index

Every spawned `dotnet test` process has the environment variable `PARTICULAR_RUN_TESTS_ACTION_PARALLEL_INDEX` set to its 0-based position in the flattened run list, immediately before it is spawned (so the child inherits it). The value is unique across all runs in the invocation, so concurrent runs always see distinct indices. In sequential mode (`max-parallel == 1`) the index is always `0`.

Consumers that need per-run distinct resources — ports, temp directories, or anything else — can read this env var and derive what they need from the index. The action itself does no port arithmetic, keeping it repository-agnostic. For example, a suite using RavenDB.Embedded (which binds a fixed port and would otherwise collide across concurrent runs) can compute its port from the index:

```csharp
var index = int.Parse(Environment.GetEnvironmentVariable("PARTICULAR_RUN_TESTS_ACTION_PARALLEL_INDEX") ?? "0");
var port = 33334 + (index * 10);
```

Consumers that do not need per-run distinction simply ignore the variable.

### Interaction with `reset-script`

`reset-script` runs between consecutive target frameworks on the sequential path (`max-parallel == 1`), as it always has. When `max-parallel > 1`, runs are flattened across frameworks, so "between frameworks" no longer has a meaningful boundary and running the script concurrently with in-flight test processes is unsafe. In that case the reset script is ignored and the action emits a `::warning::` to make the skip visible. If you need a reset between batches, run sequential (`max-parallel: 1`) or invoke the reset script from a separate workflow step.

## What about filters?

This action does not support the [dotnet test filter syntax](https://learn.microsoft.com/en-us/dotnet/core/testing/selective-unit-tests). This is because it's impossible to distinguish between the following cases:

1. No tests were found in an assembly becuase they did not match the filter, as was intended.
2. No tests were found in an assembly because there was an error in the test adapter package, and valid tests are not being properly executed.

Due to the danger of the second case, filtering is not supported. Instead, attributes that implement NUnit's `IApplyToContext` interface can be applied at the method, class, or assembly level and call `Assert.Ignore(reason)` to ignore groups of tests in certain conditions.

An example of this can be found in SQL Persistence in the [`EngineSpecificTestAttribute`](https://github.com/Particular/NServiceBus.Persistence.Sql/blob/master/src/TestHelper/EngineSpecificTestAttributes/EngineSpecificTestAttribute.cs) class, which is inherited by [other attribute classes](https://github.com/Particular/NServiceBus.Persistence.Sql/tree/master/src/TestHelper/EngineSpecificTestAttributes) for each supported database engine. This makes it possible to use a single `[assembly: SqlServerTest]` to only run tests in that project when a SQL Server connection string is available.

Using this method also results in visual tests summaries that clearly show which tests were run and which were ignored, making it easy to see if any tests are missing.

## License

The scripts and documentation in this project are released under the [MIT License](LICENSE.md).
