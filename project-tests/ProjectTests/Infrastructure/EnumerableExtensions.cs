﻿using System;
using System.Collections.Generic;

namespace ProjectTests
{
    public static class EnumerableExtensions
    {
        public static IEnumerable<T> ForEach<T>(this IEnumerable<T> source, Action<T> action)
        {
            foreach (T element in source)
            {
                action(element);
            }

            return source;
        }
    }
}