# run-tests-action

This action runs tests for Particular Software repos according to our conventions:

1. Finds test projects by location *.csproj files that have a `PackageReference` for `Microsoft.NET.Test.Sdk`
2. Finds all the target frameworks for the test projects
3. Runs `dotnet test` for each target framework, skipping `net4*` on Windows

## Usage

Basic:

```yaml
steps:
  - name: Run tests
    uses: Particular/run-tests-action@v1.0.0
```

With a reset script between each test run:

```yaml
steps:
  - name: Run tests
    uses: Particular/run-tests-action@v1.0.0
    with:
      reset-script: |
        echo "Do whatever is necessary to reset the test infrastructure between runs of each framework"
        echo "The script is invoked by PowerShell Invoke-Expression."
```

## License

The scripts and documentation in this project are released under the [MIT License](LICENSE.md).