using System;
using System.Collections.Generic;
using System.Linq;
using System.Xml.Linq;
using JetBrains.Annotations;
using Nuke.Common;
using Nuke.Common.IO;
using Nuke.Common.Tooling;
using Nuke.Common.Tools.GitVersion;
using Nuke.Common.Tools.NuGet;
using Nuke.Common.Utilities;
using static Nuke.Common.IO.FileSystemTasks;
using static Nuke.Common.Tools.NuGet.NuGetTasks;

class Build : NukeBuild
{
    const string ProjectName = "FFmpeg";

    const string ProjectAuthor = "Ronald van Manen";

    const string ProjectUrl = "https://github.com/ronaldvanmanen/FFmpeg-packaging";

    const string RepositoryUrl = "https://github.com/ronaldvanmanen/FFmpeg-packaging";

    public static int Main () => Execute<Build>(x => x.BuildRuntimePackage);

    [Parameter()]
    readonly string VcpkgTriplet;

    [Parameter()]
    readonly string VcpkgFeature;

    [Parameter()]
    readonly string[] VcpkgBinarySources = Array.Empty<string>();

    [Parameter()]
    readonly bool VcpkgDebug;
    
    [GitVersion]
    readonly GitVersion GitVersion;

    string DotNetRuntimeIdentifier =>
        VcpkgTriplet switch
        {
            "x64-linux-dynamic-release" => "linux-x64",
            "x64-windows-release" => "win-x64",
            "x86-windows-release" => "win-x86",
            _ => throw new NotSupportedException($"The vcpkg triplet `{VcpkgTriplet} is not yet supported.")
        };

    AbsolutePath ArtifactsRootDirectory => RootDirectory / "artifacts";

    AbsolutePath VcpkgArtifactsRootDirectory => ArtifactsRootDirectory / "vcpkg";

    AbsolutePath VcpkgBuildtreesRootDirectory => VcpkgArtifactsRootDirectory / VcpkgFeature / VcpkgTriplet / "buildtrees";

    AbsolutePath VcpkgDownloadsRootDirectory => VcpkgArtifactsRootDirectory / VcpkgFeature / VcpkgTriplet / "downloads";

    AbsolutePath VcpkgInstallRootDirectory => VcpkgArtifactsRootDirectory / VcpkgFeature / VcpkgTriplet / "installed";

    AbsolutePath VcpkgInstallDirectory => VcpkgInstallRootDirectory / VcpkgTriplet;

    AbsolutePath VcpkgPackagesRootDirectory => VcpkgArtifactsRootDirectory / VcpkgFeature / VcpkgTriplet / "packages";

    AbsolutePath NugetArtifactsRootDirectory => ArtifactsRootDirectory / "nuget";

    AbsolutePath NugetBuildRootDirectory => NugetArtifactsRootDirectory / "build";

    AbsolutePath NugetInstallRootDirectory => NugetArtifactsRootDirectory / "installed";

    [LocalPath(windowsPath: "vcpkg/bootstrap-vcpkg.bat", unixPath: "vcpkg/bootstrap.sh")]
    readonly Tool BootstrapVcpkg;

    [LocalPath(windowsPath: "vcpkg/vcpkg.exe", unixPath: "vcpkg/vcpkg")]
    readonly Tool Vcpkg;

    [UsedImplicitly]
    Target Clean => _ => _
        .Executes(() =>
        {
            ArtifactsRootDirectory.CreateOrCleanDirectory();
        });

    Target SetupVcpkg => _ => _
        .Unlisted()
        .Executes(() =>
        {
            BootstrapVcpkg("-disableMetrics");
        });
    
    Target BuildPortPackage => _ => _
        .DependsOn(SetupVcpkg)
        .Requires(() => VcpkgTriplet)
        .Requires(() => VcpkgFeature)
        .Executes(() =>
        {
            VcpkgBuildtreesRootDirectory.CreateDirectory();
            VcpkgDownloadsRootDirectory.CreateDirectory();
            VcpkgInstallRootDirectory.CreateDirectory();
            VcpkgPackagesRootDirectory.CreateDirectory();

            var argumentList = new List<string>
            {
                $"install",
                $"--triplet={VcpkgTriplet}",
                $"--downloads-root={VcpkgDownloadsRootDirectory}",
                $"--x-buildtrees-root={VcpkgBuildtreesRootDirectory}",
                $"--x-install-root={VcpkgInstallRootDirectory}",
                $"--x-packages-root={VcpkgPackagesRootDirectory}",
                $"--x-no-default-features",
                $"--x-feature={VcpkgFeature}",
                $"--clean-after-build",
                $"--disable-metrics",
            };

            argumentList.AddRange(
                VcpkgBinarySources.Select(vcpkgBinarySource => $"--binarysource={vcpkgBinarySource}")
            );

            if (VcpkgDebug)
            {
                argumentList.Add("--debug");
            }

            // NOTE: ArgumentStringHandler assumes our arguments must be double qouted because we
            // pass our arguments as a single string. To prevent this from happening we explicity
            // create an ArgumentStringHandler and append our arguments as a string literal.
            var argumentString = string.Join(' ', argumentList);
            ArgumentStringHandler arguments = "";
            arguments.AppendLiteral(argumentString);

            Vcpkg(arguments);
        });


    Target BuildRuntimePackage => _ => _
        .Unlisted()
        .DependsOn(BuildPortPackage)
        .Requires(() => VcpkgTriplet)
        .Requires(() => VcpkgFeature)
        .Executes(() =>
        {
            var packageID = $"{ProjectName}.runtime.{DotNetRuntimeIdentifier}";
            var packageBuildDirectory = NugetBuildRootDirectory / $"{packageID}.nupkg";
            var packageSpecFile = packageBuildDirectory / $"{packageID}.nuspec";

            packageBuildDirectory.CreateOrCleanDirectory();

            packageSpecFile.WriteXml(
                new XDocument(
                    new XDeclaration("1.0", "utf-8", null),
                    new XElement("{http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd}package",
                        new XElement("metadata",
                            new XAttribute("minClientVersion", "2.12"),
                            new XElement("id", packageID),
                            new XElement("version", GitVersion.NuGetVersion),
                            new XElement("authors", ProjectAuthor),
                            new XElement("requireLicenseAcceptance", true),
                            new XElement("license", new XAttribute("type", "expression"), "LGPL-2.1-or-later"),
                            new XElement("projectUrl", ProjectUrl),
                            new XElement("description", $"{DotNetRuntimeIdentifier} runtime library for {ProjectName}."),
                            new XElement("copyright", $"Copyright © {ProjectAuthor}"),
                            new XElement("repository",
                                new XAttribute("type", "git"),
                                new XAttribute("url", RepositoryUrl)
                            )
                        )
                    )
                )
            );

            var libraryTargetDirectory = packageBuildDirectory / "runtimes" / $"{DotNetRuntimeIdentifier}" / "native";

            var libraryFiles = VcpkgInstallDirectory.GlobFiles("lib/*.so*", $"bin/*.dll");
            foreach (var libraryFile in libraryFiles)
            {
                CopyFileToDirectory(libraryFile, libraryTargetDirectory);
            }

            var packSettings = new NuGetPackSettings()
                .SetProcessWorkingDirectory(packageBuildDirectory)
                .SetTargetPath(packageSpecFile)
                .SetOutputDirectory(NugetInstallRootDirectory);

            NuGetPack(packSettings);
        });
}
