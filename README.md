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
        uses: Particular/run-tests-action@v1.6.0
```

With a reset script between each test run:

```yaml
    steps:
      - name: Run tests
        uses: Particular/run-tests-action@v1.6.0
        with:
          reset-script: |
            echo "Do whatever is necessary to reset the test infrastructure between runs of each framework"
            echo "The script is invoked by PowerShell Invoke-Expression."
```

In cases where the test matrix subdivides by target framework, you can also short-circuit most of what this action does by specifying the framework to use for testing. While sounding counter-intuitive, it helps to keep the arguments given to `dotnet test` consistent with other repositories. (Added in v1.1.0)

```yaml
    steps:
      - name: Run tests
        uses: Particular/run-tests-action@v1.6.0
        with:
          framework: net6.0
```

By default, only failed tests are reported. To report warnings for tests that have neither failed nor succeeded (i.e. skipped or inconclusive):

```yaml
    steps:
      - name: Run tests
        uses: Particular/run-tests-action@v1.6.0
        with:
          report-warnings: true
```

By default, `dotnet test` uses `x64` as the target platform. This can be overridden:

```yaml
    steps:
      - name: Run tests
        uses: Particular/run-tests-action@v1.6.0
        with:
          target-platform: x86
```

## What about filters?

This action does not support the [dotnet test filter syntax](https://learn.microsoft.com/en-us/dotnet/core/testing/selective-unit-tests). This is because it's impossible to distinguish between the following cases:

1. No tests were found in an assembly becuase they did not match the filter, as was intended.
2. No tests were found in an assembly because there was an error in the test adapter package, and valid tests are not being properly executed.

Due to the danger of the second case, filtering is not supported. Instead, attributes that implement NUnit's `IApplyToContext` interface can be applied at the method, class, or assembly level and call `Assert.Ignore(reason)` to ignore groups of tests in certain conditions.

An example of this can be found in SQL Persistence in the [`EngineSpecificTestAttribute`](https://github.com/Particular/NServiceBus.Persistence.Sql/blob/master/src/TestHelper/EngineSpecificTestAttributes/EngineSpecificTestAttribute.cs) class, which is inherited by [other attribute classes](https://github.com/Particular/NServiceBus.Persistence.Sql/tree/master/src/TestHelper/EngineSpecificTestAttributes) for each supported database engine. This makes it possible to use a single `[assembly: SqlServerTest]` to only run tests in that project when a SQL Server connection string is available.

Using this method also results in visual tests summaries that clearly show which tests were run and which were ignored, making it easy to see if any tests are missing.

## License

The scripts and documentation in this project are released under the [MIT License](LICENSE.md).
