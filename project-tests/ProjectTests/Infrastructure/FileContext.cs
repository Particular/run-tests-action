﻿using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Xml.Linq;

namespace ProjectTests
{
    public class FileContext(string filePath)
    {
        public string FilePath { get; } = filePath;
        public string DirectoryPath { get; } = Path.GetDirectoryName(filePath);
        public bool IsFailed { get; private set; }

        public List<string> FailReasons { get; } = new();

        public void Fail(string reason = null)
        {
            IsFailed = true;
            if (reason is not null)
            {
                FailReasons.Add(reason);
            }
        }

        private Lazy<XDocument> xdoc = new Lazy<XDocument>(() => XDocument.Load(filePath), false);
        public XDocument XDocument => xdoc.Value;

        public override string ToString()
        {
            if (!IsFailed)
            {
                return "OK";
            }

            return FailReasons.Count switch
            {
                0 => "Failed: (no reason)",
                1 => $"Failed: {FailReasons.First()}",
                _ => $"Failed: {FailReasons.Count} reasons"
            };
        }
    }
}