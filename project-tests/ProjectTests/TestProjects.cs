using System.IO;
using System.Xml.XPath;
using NUnit.Framework;

namespace ProjectTests
{
    public class TestProjects
    {
        [Test]
        public void ValidateProjectFrameworks()
        {
            var ciPath = Path.Combine(TestSetup.RootDirectory, ".github", "workflows", "ci.yml");
            if (!File.Exists(ciPath))
            {
                Assert.Ignore("No ci.yml workflow found in root directory");
            }

            new TestRunner("*.csproj", "Find tests")
                .SdkProjects()
                .TestProjects()
                .Run(file =>
                {
                    var frameworksText = file.XDocument.XPathSelectElement("/Project/PropertyGroup/TargetFramework")?.Value
                        ?? file.XDocument.XPathSelectElement("/Project/PropertyGroup/TargetFramework")?.Value;

                    var frameworks = frameworksText.Split(';');

                    file.Fail(frameworksText);
                });
        }
    }
}
