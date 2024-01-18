using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json;
using NuGet.RuntimeModel;
using Nuke.Common.IO;

static class AbsolutePathExtensions
{
    public static IReadOnlyCollection<AbsolutePath> GlobDirectories(this AbsolutePath directory, IEnumerable<string> patterns)
    {
        return Globbing.GlobDirectories(directory, patterns.ToArray());
    }

    public static void WriteRuntimeGraph(this AbsolutePath filePath, RuntimeGraph runtimeGraph)
    {
        using var stream = new FileStream(filePath, FileMode.Create);
        using var textWriter = new StreamWriter(stream);
        using var jsonTextWriter = new JsonTextWriter(textWriter);
        using var jsonObjectWriter = new JsonObjectWriter(jsonTextWriter);
        jsonTextWriter.Formatting = Formatting.Indented;

        jsonObjectWriter.WriteObjectStart();
        JsonRuntimeFormat.WriteRuntimeGraph(jsonObjectWriter, runtimeGraph);
        jsonObjectWriter.WriteObjectEnd();
    }
}