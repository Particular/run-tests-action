using System;
using System.Collections.Generic;
using System.Linq;
using System.Xml.XPath;
using NUnit.Framework;

namespace ProjectTests
{
    public class PackageReferences
    {
        [Test]
        public void PrivateAssetsAsAttributesNotElements()
        {
            new TestRunner("*.csproj", "Package references should have PrivateAssets/IncludeAssets as attributes, not child elements")
                .SdkProjects()
                .Run(file =>
                {
                    var privateAssetElements = file.XDocument.XPathSelectElements("/Project/ItemGroup/PackageReference/PrivateAssets");
                    var includeAssetElements = file.XDocument.XPathSelectElements("/Project/ItemGroup/PackageReference/IncludeAssets");

                    if (privateAssetElements.Any() || includeAssetElements.Any())
                    {
                        file.Fail();
                    }
                });

        }

        [Test]
        public void DoNotMixReferenceTypes()
        {
            new TestRunner("*.csproj", "PackageReference, ProjectReference, and other item types should not be mixed within the same ItemGroup")
                .SdkProjects()
                .Run(file =>
                {
                    var itemGroups = file.XDocument.XPathSelectElements("/Project/ItemGroup");

                    foreach (var itemGroup in itemGroups)
                    {
                        if (itemGroup.HasElements)
                        {
                            var childNames = itemGroup.Elements().Select(e => e.Name.LocalName).Distinct().ToArray();

                            if (childNames.Length > 1 && childNames.Any(name => ReferenceElementNames.Contains(name)))
                            {
                                file.Fail("ItemGroup mixes " + string.Join(", ", childNames));
                                return;
                            }
                        }
                    }
                });
        }

        // Other possibilities: Content, None, EmbeddedResource, Compile, InternalsVisibleTo, Artifact, RemoveSourceFileFromPackage, Folder
        static readonly HashSet<string> ReferenceElementNames = ["ProjectReference", "PackageReference", "Reference", "FrameworkReference"];
    }
}
