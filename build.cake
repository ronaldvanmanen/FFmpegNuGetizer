//////////////////////////////////////////////////////////////////////
// ADD-INS
//////////////////////////////////////////////////////////////////////

#addin nuget:?package=Cake.FileHelpers&version=6.1.3
#addin nuget:?package=Cake.Git&version=3.0.0
#addin nuget:?package=NuGet.Packaging&Version=6.6.1&loaddependencies=true

//////////////////////////////////////////////////////////////////////
// TOOLS
//////////////////////////////////////////////////////////////////////

#tool dotnet:?package=GitVersion.Tool&version=5.10.3

//////////////////////////////////////////////////////////////////////
// USINGS
//////////////////////////////////////////////////////////////////////

using Cake.Common.IO.Paths;
using NuGet.RuntimeModel;
using NuGet.Versioning;

//////////////////////////////////////////////////////////////////////
// PATHS
//////////////////////////////////////////////////////////////////////

var repoRoot = GitFindRootFromPath(Context.Environment.WorkingDirectory);

var vcpkgRoot = repoRoot + Directory("vcpkg");

var artifactsRoot = repoRoot + Directory("artifacts");
var vcpkgArtifactsRoot = artifactsRoot + Directory("vcpkg");
var nugetArtifactsRoot = artifactsRoot + Directory("nuget");
var nugetBuildRoot = nugetArtifactsRoot + Directory("build");
var nugetInstallRoot = nugetArtifactsRoot + Directory("installed");

//////////////////////////////////////////////////////////////////////
// METHODS
//////////////////////////////////////////////////////////////////////

internal ConvertableDirectoryPath Directory(string basePath, string childPath, params string[] additionalChildPaths)
{
    var path = Directory(basePath) + Directory(childPath);
    foreach (var additionalChildPath in additionalChildPaths)
    {
        path += Directory(additionalChildPath);
    }
    return path;
}

internal void EnsureDirectoriesExists(params ConvertableDirectoryPath[] paths)
{
    foreach (var path in paths)
    {
        EnsureDirectoryExists(path);
    }
}

internal ConvertableFilePath FindVcpkgExecutable(ConvertableDirectoryPath searchPath)
{
    if (IsRunningOnLinux())
    {
        var scriptPath = searchPath + File("vcpkg");
        if (!FileExists(scriptPath))
        {
            throw new Exception("Could not find `vcpkg`");
        }
        return scriptPath;
    }

    if (IsRunningOnWindows())
    {
        var scriptPath = searchPath + File("vcpkg.exe");
        if (!FileExists(scriptPath))
        {
            throw new Exception("Could not find `vcpkg.exe`");
        }
        return scriptPath;
    }

    throw new PlatformNotSupportedException();
}

internal ConvertableFilePath FindVcpkgNuGetExecutable(ConvertableDirectoryPath searchPath)
{
    var vcpkgExecutable = FindVcpkgExecutable(searchPath);
    var vcpkgExitCode = StartProcess(vcpkgExecutable,
        new ProcessSettings {
            Arguments = new ProcessArgumentBuilder().Append("fetch").Append("nuget"),
            RedirectStandardError = true,
            RedirectStandardOutput = true
        },
        out var vcpkgRedirectedStandardOutput);

    if (vcpkgExitCode != 0)
    {
        throw new Exception("Could not find `nuget.exe`");
    }

    var vcpkgStandardOutput = vcpkgRedirectedStandardOutput.ToList();
    var vcpkgNuGetPath = vcpkgStandardOutput.FirstOrDefault(vcpkgOutputLine => vcpkgOutputLine.Contains("nuget.exe"));
    if (vcpkgNuGetPath is null)
    {
        throw new Exception("Could not find `nuget.exe`");
    }
    return File(vcpkgNuGetPath);
}


internal string DotNetRuntimeIdentifier(string vcpkgTriplet)
{
    if (vcpkgTriplet == "x64-linux-dynamic-release")
    {
        return "linux-x64";
    }

    if (vcpkgTriplet == "x64-windows-release")
    {
        return "win-x64";
    }
    
    if (vcpkgTriplet == "x86-windows-release")
    {
        return "win-x86";
    }

    throw new NotSupportedException($"The vcpkg triplet `{vcpkgTriplet} is not yet supported.");
}

internal string NuGetRuntimePackageName(string vcpkgFeature, string vcpkgTriplet)
{
    var dotnetRuntimeIdentifier = DotNetRuntimeIdentifier(vcpkgTriplet);
    if (vcpkgFeature == "no-deps")
    {
        return $"FFmpeg.runtime.{dotnetRuntimeIdentifier}";
    }
    else
    {
        return $"FFmpeg.{vcpkgFeature}.runtime.{dotnetRuntimeIdentifier}";
    }
}

internal string NuGetMultiplatformPackageName(string vcpkgFeature)
{
    if (vcpkgFeature == "no-deps")
    {
        return $"FFmpeg";
    }
    else
    {
        return $"FFmpeg.{vcpkgFeature}";
    }
}

internal ConvertableDirectoryPath VcpkgBuildtreesRoot(string vcpkgFeature, string vcpkgTriplet)
{
    return vcpkgArtifactsRoot + Directory(vcpkgFeature, vcpkgTriplet, "buildtrees");

}

internal ConvertableDirectoryPath VcpkgDownloadsRoot(string vcpkgFeature, string vcpkgTriplet)
{
    return vcpkgArtifactsRoot + Directory(vcpkgFeature, vcpkgTriplet, "downloads");
}

internal ConvertableDirectoryPath VcpkgInstallRoot(string vcpkgFeature, string vcpkgTriplet)
{
    return vcpkgArtifactsRoot + Directory(vcpkgFeature, vcpkgTriplet, "installed");
}

internal ConvertableDirectoryPath VcpkgPackagesRoot(string vcpkgFeature, string vcpkgTriplet)
{
    return vcpkgArtifactsRoot + Directory(vcpkgFeature, vcpkgTriplet, "packages");
}

internal static ProcessArgumentBuilder AppendRange(this ProcessArgumentBuilder builder, IEnumerable<string> arguments)
{
    foreach (var argument in arguments)
    {
        builder.Append(argument);
    }
    return builder;
}

//////////////////////////////////////////////////////////////////////
// TASKS
//////////////////////////////////////////////////////////////////////

Task("Clean").Does(() => 
{
    CleanDirectory(artifactsRoot);
});

Task("Setup-Vcpkg-NuGet-Credentials").Does(() =>
{
    var nugetExecutablePath = FindVcpkgNuGetExecutable(vcpkgRoot);
    var nugetSourceName = Argument<string>("name");
    var nugetSource = Argument<string>("source");
    var nugetConfigFile = Argument<string>("configfile", null);
    var nugetUsername = Argument<string>("username", null);
    var nugetPassword = Argument<string>("password", null);
    var nugetApiKey = Argument<string>("apikey", null);
    var nugetStorePasswordInClearText = Argument<bool>("storepasswordincleartext", false);
    var nugetSourceSettings = new NuGetSourcesSettings
    {
        IsSensitiveSource = true,
        StorePasswordInClearText = nugetStorePasswordInClearText,
        ToolPath = nugetExecutablePath
    };

    if (nugetConfigFile is not null)
    {
        nugetSourceSettings.ConfigFile = nugetConfigFile;
    }

    if (nugetUsername is not null)
    {
        nugetSourceSettings.UserName = nugetUsername;
    }

    if (nugetPassword is not null)
    {
        nugetSourceSettings.Password = nugetPassword;
    }

    NuGetAddSource(nugetSourceName, nugetSource, nugetSourceSettings);

    if (nugetApiKey is not null)
    {
        var nugetSetApiKeySettings = new NuGetSetApiKeySettings
        {
            ToolPath = nugetExecutablePath
        };

        if (nugetConfigFile is not null)
        {
            nugetSetApiKeySettings.ConfigFile = nugetConfigFile;
        }

        NuGetSetApiKey(nugetApiKey, nugetSource, nugetSetApiKeySettings);
    }
});

Task("Restore").DoesForEach(() => Arguments<string>("triplet"), vcpkgTriplet =>
{
    var vcpkgFeature = Argument<string>("feature");
    var vcpkgBinarySources = Arguments<string>("binarysource");
    var vcpkgDebug = HasEnvironmentVariable("RUNNER_DEBUG");

    var vcpkgBuildtreesRoot = VcpkgBuildtreesRoot(vcpkgFeature, vcpkgTriplet);
    var vcpkgDownloadsRoot = VcpkgDownloadsRoot(vcpkgFeature, vcpkgTriplet);
    var vcpkgInstallRoot = VcpkgInstallRoot(vcpkgFeature, vcpkgTriplet);
    var vcpkgPackagesRoot = VcpkgPackagesRoot(vcpkgFeature, vcpkgTriplet);

    EnsureDirectoriesExists(
        vcpkgBuildtreesRoot,
        vcpkgDownloadsRoot,
        vcpkgInstallRoot,
        vcpkgPackagesRoot);

    var vcpkgExecutable = FindVcpkgExecutable(vcpkgRoot);
    var vcpkgArguments = new ProcessArgumentBuilder()
        .Append($"install")
        .Append($"--only-binarycaching")
        .Append($"--triplet={vcpkgTriplet}")
        .Append($"--downloads-root={vcpkgDownloadsRoot}")
        .Append($"--x-buildtrees-root={vcpkgBuildtreesRoot}")
        .Append($"--x-install-root={vcpkgInstallRoot}")
        .Append($"--x-packages-root={vcpkgPackagesRoot}")
        .Append($"--x-no-default-features")
        .Append($"--x-feature={vcpkgFeature}")
        .Append($"--clean-after-build")
        .Append($"--disable-metrics")
        .AppendRange(vcpkgBinarySources.Select(vcpkgBinarySource => $"--binarysource={vcpkgBinarySource}"));

    if (vcpkgDebug)
    {
        vcpkgArguments.Append("--debug");
    }

    var exitCode = StartProcess(vcpkgExecutable, new ProcessSettings { Arguments = vcpkgArguments });
    if (exitCode != 0)
    {
        throw new Exception("Failed to restore packages.");
    }
});

Task("Build").DoesForEach(() => Arguments<string>("triplet"), vcpkgTriplet =>
{
    var vcpkgFeature = Argument<string>("feature");
    var vcpkgBinarySources = Arguments<string>("binarysource", Array.Empty<string>());
    var vcpkgDebug = HasEnvironmentVariable("RUNNER_DEBUG");

    var vcpkgBuildtreesRoot = VcpkgBuildtreesRoot(vcpkgFeature, vcpkgTriplet);
    var vcpkgDownloadsRoot = VcpkgDownloadsRoot(vcpkgFeature, vcpkgTriplet);
    var vcpkgInstallRoot = VcpkgInstallRoot(vcpkgFeature, vcpkgTriplet);
    var vcpkgPackagesRoot = VcpkgPackagesRoot(vcpkgFeature, vcpkgTriplet);

    EnsureDirectoriesExists(
        vcpkgBuildtreesRoot,
        vcpkgDownloadsRoot,
        vcpkgInstallRoot,
        vcpkgPackagesRoot);

    var vcpkgExecutable = FindVcpkgExecutable(vcpkgRoot);
    var vcpkgArguments = new ProcessArgumentBuilder()
        .Append($"install")
        .Append($"--triplet={vcpkgTriplet}")
        .Append($"--downloads-root={vcpkgDownloadsRoot}")
        .Append($"--x-buildtrees-root={vcpkgBuildtreesRoot}")
        .Append($"--x-install-root={vcpkgInstallRoot}")
        .Append($"--x-packages-root={vcpkgPackagesRoot}")
        .Append($"--x-no-default-features")
        .Append($"--x-feature={vcpkgFeature}")
        .Append($"--clean-after-build")
        .Append($"--disable-metrics")
        .AppendRange(vcpkgBinarySources.Select(vcpkgBinarySource => $"--binarysource={vcpkgBinarySource}"));

    if (vcpkgDebug)
    {
        vcpkgArguments.Append("--debug");
    }

    var exitCode = StartProcess(vcpkgExecutable, new ProcessSettings { Arguments = vcpkgArguments });
    if (exitCode != 0)
    {
        throw new Exception("Failed to build and install packages.");
    }
});

Task("Pack")
    .IsDependentOn("Pack-Multiplatform-Package")
    .IsDependentOn("Pack-Runtime-Package")
    .Does(() => {});

Task("Pack-Multiplatform-Package").Does(() =>
{
    EnsureDirectoriesExists(nugetBuildRoot, nugetInstallRoot);

    var vcpkgFeature = Argument<string>("feature");
    var vcpkgTriplets = Arguments<string>("triplet");
    var gitVersion = GitVersion();

    var nugetPackageVersion = gitVersion.NuGetVersion;
    var nugetPackageLicense = Argument<string>("license");
    var nugetPackageName = NuGetMultiplatformPackageName(vcpkgFeature);
    var nugetPackageDir = nugetBuildRoot + Directory(nugetPackageName);

    EnsureDirectoriesExists(nugetPackageDir);

    var nugetRuntimePackageVersion = new VersionRange(new NuGetVersion("4.4.4"));
    var nugetRuntimeGraph = new RuntimeGraph(
        vcpkgTriplets.Select(vcpkgTriplet => {
            var dotnetRuntimeIdentifier = DotNetRuntimeIdentifier(vcpkgTriplet);
            var nugetRuntimePackageId = $"FFmpeg.{vcpkgFeature}.runtime.{dotnetRuntimeIdentifier}";
            var nugetRuntimePackageDependency = new RuntimePackageDependency(nugetRuntimePackageId, nugetRuntimePackageVersion);
            var nugetRuntimeDependencySet = new RuntimeDependencySet("FFmpeg", new [] { nugetRuntimePackageDependency });
            var nugetRuntimeDescription = new RuntimeDescription(dotnetRuntimeIdentifier, new [] { nugetRuntimeDependencySet });
            return nugetRuntimeDescription;
        }));
    var nugetRuntimeFile = nugetPackageDir + File("runtime.json");

    JsonRuntimeFormat.WriteRuntimeGraph(nugetRuntimeFile, nugetRuntimeGraph);

    var placeholderFile = nugetPackageDir + File("_._");
    
    FileWriteText(placeholderFile, "");

    var nugetPackSettings = new NuGetPackSettings
    {
        Id = nugetPackageName,
        Version = nugetPackageVersion,
        Authors = new[] { "Ronald van Manen" },
        Owners = new[] { "Ronald van Manen" },
        RequireLicenseAcceptance = true,
        Description = "Multi-platform native library for FFmpeg.",
        License = new NuSpecLicense { Type = "expression", Value = nugetPackageLicense },
        ProjectUrl = new Uri("https://github.com/ronaldvanmanen/FFmpeg-packaging"),
        Copyright = "Copyright © Ronald van Manen",
        Repository = new NuGetRepository { Type="git", Url = "https://github.com/ronaldvanmanen/FFmpeg-packaging" },
        Dependencies = new []
        {
            new NuSpecDependency { TargetFramework = ".NETStandard2.0" }
        },
        BasePath = artifactsRoot,
        OutputDirectory = nugetInstallRoot
    };

    if (IsRunningOnWindows())
    {
        nugetPackSettings.Files = new List<NuSpecContent>
        {
            new NuSpecContent
            {
                Source = $"nuget\\build\\{nugetPackageName}\\Runtime.json",
                Target = "."
            },
            new NuSpecContent
            {
                Source = $"nuget\\build\\{nugetPackageName}\\_._",
                Target = "lib\\netstandard2.0"
            }
        };

        var vcpkgTriplet = vcpkgTriplets.First();

        nugetPackSettings.Files.Add(
            new NuSpecContent
            {
                Source = $"vcpkg\\{vcpkgFeature}\\{vcpkgTriplet}\\installed\\{vcpkgTriplet}\\include\\**\\*.h",
                Target = $"build\\native\\include"
            });
    }
    else
    {
        nugetPackSettings.Files = new List<NuSpecContent>
        {
            new NuSpecContent
            {
                Source = $"nuget/build/{nugetPackageName}/Runtime.json",
                Target = "."
            },
            new NuSpecContent
            {
                Source = $"nuget/build/{nugetPackageName}/_._",
                Target = "lib/netstandard2.0"
            }
        };

        var vcpkgTriplet = vcpkgTriplets.First();

        nugetPackSettings.Files.Add(
            new NuSpecContent
            {
                Source = $"vcpkg/{vcpkgFeature}/{vcpkgTriplet}/installed/{vcpkgTriplet}/include/**/*.h",
                Target = $"build/native/include"
            });
    }

    NuGetPack(nugetPackSettings);
});

Task("Pack-Runtime-Package").DoesForEach(() => Arguments<string>("triplet"), (vcpkgTriplet) => 
{
    EnsureDirectoriesExists(nugetArtifactsRoot, nugetInstallRoot);

    var vcpkgFeature = Argument<string>("feature");
    var vcpkgInstallRoot = VcpkgInstallRoot(vcpkgFeature, vcpkgTriplet);
    var gitVersion = GitVersion();
    var dotnetRuntimeIdentifier = DotNetRuntimeIdentifier(vcpkgTriplet);
    var nugetPackageLicense = Argument<string>("license");
    var nugetPackageName = NuGetRuntimePackageName(vcpkgFeature, vcpkgTriplet);
    var nugetPackBasePath = vcpkgInstallRoot + Directory(vcpkgTriplet);
    var nugetPackSettings = new NuGetPackSettings
    {
        Id = nugetPackageName,
        Version = gitVersion.NuGetVersion,
        Authors = new[] { "Ronald van Manen" },
        Owners = new[] { "Ronald van Manen" },
        RequireLicenseAcceptance = true,
        Description = $"{dotnetRuntimeIdentifier} native library for FFmpeg.",
        License = new NuSpecLicense { Type = "expression", Value = nugetPackageLicense },
        ProjectUrl = new Uri("https://github.com/ronaldvanmanen/FFmpeg-packaging"),
        Copyright = "Copyright © Ronald van Manen",
        Repository = new NuGetRepository { Type = "git", Url = "https://github.com/ronaldvanmanen/FFmpeg-packaging" },
        BasePath = nugetPackBasePath,
        OutputDirectory = nugetInstallRoot
    };

    if (IsRunningOnWindows())
    {
        if (vcpkgTriplet.Contains("windows"))
        {
            nugetPackSettings.Files = new []
            {
                new NuSpecContent { Source = "bin\\*.dll", Target = $"runtimes\\{dotnetRuntimeIdentifier}\\native"}
            };
        }
        else
        {
            nugetPackSettings.Files = new []
            {
                new NuSpecContent { Source = "lib\\*.so*", Target = $"runtimes\\{dotnetRuntimeIdentifier}\\native"}
            };
        }
    }
    else
    {
        if (vcpkgTriplet.Contains("windows"))
        {
            nugetPackSettings.Files = new []
            {
                new NuSpecContent { Source = "bin/*.dll", Target = $"runtimes/{dotnetRuntimeIdentifier}/native"}
            };
        }
        else
        {
            nugetPackSettings.Files = new []
            {
                new NuSpecContent { Source = "lib/*.so*", Target = $"runtimes/{dotnetRuntimeIdentifier}/native"},
            };
        }
    }

    NuGetPack(nugetPackSettings);
});

//////////////////////////////////////////////////////////////////////
// EXECUTION
//////////////////////////////////////////////////////////////////////

RunTarget(Argument<string>("target"));