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
        uses: Particular/run-tests-action@v1.3.0
```

With a reset script between each test run:

```yaml
    steps:
      - name: Run tests
        uses: Particular/run-tests-action@v1.3.0
        with:
          reset-script: |
            echo "Do whatever is necessary to reset the test infrastructure between runs of each framework"
            echo "The script is invoked by PowerShell Invoke-Expression."
```

In cases where the test matrix subdivides by target framework, you can also short-circuit most of what this action does by specifying the framework to use for testing. While sounding counter-intuitive, it helps to keep the arguments given to `dotnet test` consistent with other repositories. (Added in v1.1.0)

```yaml
    steps:
      - name: Run tests
        uses: Particular/run-tests-action@v1.3.0
        with:
          framework: net6.0
```

By default, only failed tests are reported. To report warnings for tests that have neither failed nor succeeded (i.e. skipped or inconclusive):

```yaml
    steps:
      - name: Run tests
        uses: Particular/run-tests-action@v1.3.0
        with:
          report-warnings: true
```

By default, `dotnet test` uses `x64` as the target platform. This can be overridden:

```yaml
    steps:
      - name: Run tests
        uses: Particular/run-tests-action@v1.3.0
        with:
          target-platform: x86
```

## License

The scripts and documentation in this project are released under the [MIT License](LICENSE.md).
