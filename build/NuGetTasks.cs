using System.Collections.Generic;
using Nuke.Common.Tooling;

static class NuGetTasks
{
    public static IReadOnlyCollection<Output> NuGetSetApiKey(NuGetSetApiKeySettings toolSettings = null)
    {
        toolSettings ??= new NuGetSetApiKeySettings();
        using IProcess process = ProcessTasks.StartProcess(toolSettings);
        toolSettings.ProcessExitHandler(toolSettings, process.AssertWaitForExit());
        return process.Output;
    }

    public static IReadOnlyCollection<Output> NuGetSetApiKey(Configure<NuGetSetApiKeySettings> configurator)
    {
        return NuGetSetApiKey(configurator(new NuGetSetApiKeySettings()));
    }

    public static IEnumerable<(NuGetSetApiKeySettings Settings, IReadOnlyCollection<Output> Output)> NuGetSetApiKey(CombinatorialConfigure<NuGetSetApiKeySettings> configurator, int degreeOfParallelism = 1, bool completeOnFailure = false)
    {
        return configurator.Invoke(NuGetSetApiKey, Nuke.Common.Tools.NuGet.NuGetTasks.NuGetLogger, degreeOfParallelism, completeOnFailure);
    }
}