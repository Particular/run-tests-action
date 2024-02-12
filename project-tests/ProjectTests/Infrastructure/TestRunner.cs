using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Xml.Linq;
using System.Xml.XPath;
using NUnit.Framework;
using ProjectTests.Infrastructure;

namespace ProjectTests
{
    public class TestRunner
    {
        readonly string name;
        IEnumerable<FileContext> files;

        public TestRunner(string glob, string name)
        {
            this.name = name;
            var filesArray = Directory.GetFiles(TestSetup.RootDirectory, glob, SearchOption.AllDirectories)
                .Select(filePath => new FileContext(filePath))
                .ToArray();

            if (filesArray.Length == 0)
            {
                Assert.Fail($"No files found matching '{glob}'.");
            }

            // If this isn't materialized into an array first some weird multiple enumeration things start to happen
            files = filesArray;
        }

        public TestRunner IgnoreRegex(string pattern, RegexOptions regexOptions = RegexOptions.Singleline | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)
        {
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                pattern = pattern.Replace("\\\\", "/");
            }

            files = files.Where(f => !Regex.IsMatch(f.FilePath, pattern, regexOptions));

            return this;
        }

        public TestRunner IgnoreWildcard(string wildcardExpression)
        {
            var pattern = Regex.Escape(wildcardExpression).Replace(@"\*", ".*").Replace(@"\?", ".");
            return IgnoreRegex(pattern);
        }

        public TestRunner SdkProjects()
        {
            files = files.Where(f => f.XDocument.Root.Attribute("xmlns") is null);
            return this;
        }

        public TestRunner TestProjects()
        {
            files = files.Where(f => f.XDocument.XPathSelectElements("/Project/ItemGroup/PackageReference[@Include='Microsoft.NET.Test.Sdk']").Any());
            return this;
        }

        public TestRunner PackagingProjects()
        {
            bool? customBuildPropsIsPackable = null;
            var customBuildPropsPath = Path.Combine(TestSetup.RootDirectory, "src", "Custom.Build.props");
            if (File.Exists(customBuildPropsPath))
            {
                var customBuildPropsDoc = XDocument.Load(customBuildPropsPath);
                customBuildPropsIsPackable = customBuildPropsDoc.XPathSelectElement("/Project/PropertyGroup/IsPackable").GetBoolean();
            }

            var customBuildProps =
            files = files.Where(f =>
            {
                var doc = f.XDocument;

                var hasParticularPackaging = doc.XPathSelectElement("/Project/ItemGroup/PackageReference[@Include='Particular.Packaging']") is not null;
                var projectIsPackable = doc.XPathSelectElement("/Project/PropertyGroup/IsPackable").GetBoolean();
                var packAsTool = doc.XPathSelectElement("/Project/PropertyGroup/PackAsTool").GetBoolean();

                var isPackable = projectIsPackable ?? customBuildPropsIsPackable ?? packAsTool ?? hasParticularPackaging;
                return isPackable;
            });

            return this;
        }

        public void Run(Action<FileContext> testAction)
        {
            var results = files.ForEach(testAction)
                .Where(f => f.IsFailed)
                .SelectMany(f =>
                {
                    var relativePath = f.FilePath.Substring(TestSetup.RootDirectory.Length + 1);
                    if (!f.FailReasons.Any())
                    {
                        return [relativePath];
                    }

                    return f.FailReasons.Select(reason => $"{relativePath} - {reason}");
                })
                .ToArray();

            if (results.Any())
            {
                Assert.Fail($"{name}:\r\n  > {string.Join("\r\n  > ", results)}");
            };
        }
    }
}