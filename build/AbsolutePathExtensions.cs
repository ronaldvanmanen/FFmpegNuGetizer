using System.Collections.Generic;
using System.Linq;
using Nuke.Common.IO;

static class AbsolutePathExtensions
{
    public static IReadOnlyCollection<AbsolutePath> GlobDirectories(this AbsolutePath directory, IEnumerable<string> patterns)
    {
        return Globbing.GlobDirectories(directory, patterns.ToArray());
    }
}