using System;
using System.Diagnostics.CodeAnalysis;
using JetBrains.Annotations;
using Nuke.Common.Tooling;
using Nuke.Common.Tools.NuGet;

[Serializable]
[PublicAPI]
[ExcludeFromCodeCoverage]
public class NuGetSetApiKeySettings : ToolSettings
{
    public override string ProcessToolPath => base.ProcessToolPath ?? Nuke.Common.Tools.NuGet.NuGetTasks.NuGetPath;

    public override Action<OutputType, string> ProcessLogger => base.ProcessLogger ?? Nuke.Common.Tools.NuGet.NuGetTasks.NuGetLogger;

    public override Action<ToolSettings, IProcess> ProcessExitHandler => base.ProcessExitHandler ?? Nuke.Common.Tools.NuGet.NuGetTasks.NuGetExitHandler;

    public virtual string ConfigFile { get; internal set; }

    public virtual bool? ForceEnglishOutput { get; internal set; }

    public virtual bool? NonInteractive { get; internal set; }

    public virtual NuGetVerbosity Verbosity { get; internal set; }

    public virtual string ApiKey { get; internal set; }

    public virtual string Source { get; internal set; }

    protected override Arguments ConfigureProcessArguments(Arguments arguments)
    {
        arguments.Add("setApiKey {value}", ApiKey)
                 .Add("-ConfigFile {value}", ConfigFile)
                 .Add("-ForceEnglishOutput", ForceEnglishOutput)
                 .Add("-NonInteractive", NonInteractive)
                 .Add("-Verbosity {value}", Verbosity)
                 .Add("-Source {value}", Source);
        return base.ConfigureProcessArguments(arguments);
    }
}
