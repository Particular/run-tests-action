using System;
using System.IO;
using System.Threading;
using System.Xml.Linq;

namespace ProjectTests
{
    public class FileContext(string filePath)
    {
        public string FilePath { get; } = filePath;
        public string DirectoryPath { get; } = Path.GetDirectoryName(filePath);
        public bool IsFailed { get; private set; }

        public string FailReason { get; private set; }

        public void Fail(string reason = null)
        {
            IsFailed = true;
            FailReason = reason;
        }

        private Lazy<XDocument> xdoc = new Lazy<XDocument>(() => XDocument.Load(filePath), false);
        public XDocument XDocument => xdoc.Value;

        public override string ToString()
        {
            return IsFailed
                ? $"{FilePath}: Failed: {FailReason ?? "(no reason)"}"
                : $"{FilePath}: OK";
        }
    }
}