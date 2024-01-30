using Nuke.Common.Tools.NuGet;

class NuGetFeedSettings
{
    public string Name { get; set; }

    public string Source { get; set; }

    public string UserName { get; internal set; }

    public string Password { get; set; }

    public bool? StorePasswordInClearText { get; set; }

    public string ApiKey { get; set; }

    public bool Publish { get; set; }
}