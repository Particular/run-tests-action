using System.IO;
using NUnit.Framework;

[assembly: Parallelizable(ParallelScope.All)]
[assembly: FixtureLifeCycle(LifeCycle.InstancePerTestCase)]

namespace ProjectTests
{
    [SetUpFixture]
    public class TestSetup
    {
        internal static string RootDirectory;
        internal static string ActionRootPath;

        [OneTimeSetUp]
        public void SetupRootDirectories()
        {
            var currentDirectory = TestContext.CurrentContext.TestDirectory;
            ActionRootPath = Path.GetFullPath(Path.Combine(currentDirectory, "..", "..", "..", "..", ".."));

#if DEBUG
            // For local testing, set to the path of a specific repo, or your whole projects directory, whatever works
            RootDirectory = @"P:\NServiceBus";
#else
            RootDirectories = Environment.CurrentDirectory;
#endif
        }
    }
}