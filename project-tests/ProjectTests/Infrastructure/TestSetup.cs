﻿using System.IO;
using NUnit.Framework;

[assembly: Parallelizable(ParallelScope.All)]
[assembly: FixtureLifeCycle(LifeCycle.InstancePerTestCase)]

namespace ProjectTests
{
    [SetUpFixture]
    public class TestSetup
    {
        public static string RootDirectory { get; private set; }
        public static string ActionRootPath { get; private set; }

        [OneTimeSetUp]
        public void SetupRootDirectories()
        {
            var currentDirectory = TestContext.CurrentContext.TestDirectory;
            ActionRootPath = Path.GetFullPath(Path.Combine(currentDirectory, "..", "..", "..", "..", ".."));

#if DEBUG
            // For local testing, set to the path of a specific repo, or your whole projects directory, whatever works
            RootDirectory = @"P:\NServiceBus";
#else
            RootDirectory = System.Environment.GetEnvironmentVariable("GITHUB_WORKSPACE")
                ?? System.Environment.CurrentDirectory;
#endif
            Console.WriteLine($"RootDirectory = {RootDirectory}");
        }
    }
}