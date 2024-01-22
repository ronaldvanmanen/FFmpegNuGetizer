using System.Diagnostics.CodeAnalysis;
using JetBrains.Annotations;
using Nuke.Common.Tooling;
using Nuke.Common.Tools.NuGet;

[PublicAPI]
[ExcludeFromCodeCoverage]
public static partial class NuGetSetApiKeySettingsExtensions
{
    [Pure]
    public static T SetConfigFile<T>(this T toolSettings, string configFile) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.ConfigFile = configFile;
        return toolSettings;
    }

    [Pure]
    public static T ResetConfigFile<T>(this T toolSettings) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.ConfigFile = null;
        return toolSettings;
    }

    [Pure]
    public static T SetForceEnglishOutput<T>(this T toolSettings, bool? forceEnglishOutput) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.ForceEnglishOutput = forceEnglishOutput;
        return toolSettings;
    }

    [Pure]
    public static T ResetForceEnglishOutput<T>(this T toolSettings) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.ForceEnglishOutput = null;
        return toolSettings;
    }

    [Pure]
    public static T EnableForceEnglishOutput<T>(this T toolSettings) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.ForceEnglishOutput = true;
        return toolSettings;
    }

    [Pure]
    public static T DisableForceEnglishOutput<T>(this T toolSettings) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.ForceEnglishOutput = false;
        return toolSettings;
    }

    [Pure]
    public static T ToggleForceEnglishOutput<T>(this T toolSettings) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.ForceEnglishOutput = !toolSettings.ForceEnglishOutput;
        return toolSettings;
    }

    [Pure]
    public static T SetNonInteractive<T>(this T toolSettings, bool? nonInteractive) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.NonInteractive = nonInteractive;
        return toolSettings;
    }

    [Pure]
    public static T ResetNonInteractive<T>(this T toolSettings) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.NonInteractive = null;
        return toolSettings;
    }

    [Pure]
    public static T EnableNonInteractive<T>(this T toolSettings) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.NonInteractive = true;
        return toolSettings;
    }

    [Pure]
    public static T DisableNonInteractive<T>(this T toolSettings) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.NonInteractive = false;
        return toolSettings;
    }

    [Pure]
    public static T ToggleNonInteractive<T>(this T toolSettings) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.NonInteractive = !toolSettings.NonInteractive;
        return toolSettings;
    }

    [Pure]
    public static T SetVerbosity<T>(this T toolSettings, NuGetVerbosity verbosity) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.Verbosity = verbosity;
        return toolSettings;
    }

    [Pure]
    public static T ResetVerbosity<T>(this T toolSettings) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.Verbosity = null;
        return toolSettings;
    }

    [Pure]
    public static T SetSource<T>(this T toolSettings, string source) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.Source = source;
        return toolSettings;
    }

    [Pure]
    public static T ResetSource<T>(this T toolSettings) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.Source = null;
        return toolSettings;
    }

    [Pure]
    public static T SetApiKey<T>(this T toolSettings, string apiKey) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.ApiKey = apiKey;
        return toolSettings;
    }

    [Pure]
    public static T ResetApiKey<T>(this T toolSettings) where T : NuGetSetApiKeySettings
    {
        toolSettings = toolSettings.NewInstance();
        toolSettings.ApiKey = null;
        return toolSettings;
    }
}


