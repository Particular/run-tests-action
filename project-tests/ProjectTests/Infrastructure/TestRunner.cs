using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Xml.XPath;
using NUnit.Framework;

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

        public void Run(Action<FileContext> testAction)
        {
            var results = files.ForEach(testAction)
                .Where(f => f.IsFailed)
                .Select(f =>
                {
                    var relativePath = f.FilePath.Substring(TestSetup.RootDirectory.Length + 1);
                    if (f.FailReason is null)
                    {
                        return relativePath;
                    }

                    return $"{relativePath} - {f.FailReason}";
                })
                .ToArray();

            if (results.Any())
            {
                Assert.Fail($"{name}:\r\n  > {string.Join("\r\n  > ", results)}");
            };
        }
    }
}