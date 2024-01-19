using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Xml.Linq;
using JetBrains.Annotations;
using NuGet.RuntimeModel;
using NuGet.Versioning;
using Nuke.Common;
using Nuke.Common.IO;
using Nuke.Common.Tooling;
using Nuke.Common.Tools.GitVersion;
using Nuke.Common.Tools.NuGet;
using Nuke.Common.Utilities;
using Nuke.Common.Utilities.Collections;
using static System.Runtime.InteropServices.RuntimeInformation;
using static Nuke.Common.IO.FileSystemTasks;
using static Nuke.Common.Tools.NuGet.NuGetTasks;

class Build : NukeBuild
{
    const string ProjectName = "FFmpeg";

    const string ProjectAuthor = "Ronald van Manen";

    const string ProjectUrl = "https://github.com/ronaldvanmanen/FFmpeg-packaging";

    const string ProjectLicense = "LGPL-2.1-or-later";

    const string RepositoryUrl = "https://github.com/ronaldvanmanen/FFmpeg-packaging";

    public static int Main () => Execute<Build>(x => x.BuildMultiplatformPackage);

    [Parameter(Separator = ",")]
    readonly string[] VcpkgTriplets;

    [Parameter()]
    readonly string VcpkgFeature;

    [Parameter()]
    readonly string[] VcpkgBinarySources = Array.Empty<string>();

    [Parameter()]
    readonly bool VcpkgDebug;
    
    [GitVersion]
    readonly GitVersion GitVersion;

    IEnumerable<string> BuildDependenciesForLinux =>
        new []
        {
            "libgl-dev",
            "libglfw3-dev",
            "nasm"
        };

    AbsolutePath ArtifactsRootDirectory => RootDirectory / "artifacts";

    AbsolutePath VcpkgArtifactsRootDirectory => ArtifactsRootDirectory / "vcpkg";

    AbsolutePath NugetArtifactsRootDirectory => ArtifactsRootDirectory / "nuget";

    AbsolutePath NugetBuildRootDirectory => NugetArtifactsRootDirectory / "build";

    AbsolutePath NugetInstallRootDirectory => NugetArtifactsRootDirectory / "installed";

    AbsolutePath VcpkgBuildRootDirectory(string vcpkgTriplet) =>
        VcpkgArtifactsRootDirectory / VcpkgFeature / GetRuntimeID(vcpkgTriplet);

    AbsolutePath VcpkgBuildtreesRootDirectory(string vcpkgTriplet) =>
        VcpkgBuildRootDirectory(vcpkgTriplet) / "buildtrees";

    AbsolutePath VcpkgDownloadsRootDirectory(string vcpkgTriplet) =>
        VcpkgBuildRootDirectory(vcpkgTriplet) / "downloads";

    AbsolutePath VcpkgInstallRootDirectory(string vcpkgTriplet) =>
        VcpkgBuildRootDirectory(vcpkgTriplet) / "installed";

    AbsolutePath VcpkgInstallDirectory(string vcpkgTriplet) =>
        VcpkgInstallRootDirectory(vcpkgTriplet) / vcpkgTriplet;

    AbsolutePath VcpkgPackagesRootDirectory(string vcpkgTriplet) =>
        VcpkgBuildRootDirectory(vcpkgTriplet) / "packages";

    [LocalPath(windowsPath: "vcpkg/bootstrap-vcpkg.bat", unixPath: "vcpkg/bootstrap.sh")]
    readonly Tool BootstrapVcpkg;

    [LocalPath(windowsPath: "vcpkg/vcpkg.exe", unixPath: "vcpkg/vcpkg")]
    readonly Tool Vcpkg;

    Tool Sudo => ToolResolver.GetPathTool("sudo");

    string GetRuntimeID(string vcpkgTriplet) =>
        vcpkgTriplet switch
        {
            "x64-linux-dynamic-release" => "linux-x64",
            "x64-windows-release" => "win-x64",
            "x86-windows-release" => "win-x86",
            _ => throw new NotSupportedException($"The vcpkg triplet `{vcpkgTriplet} is not yet supported.")
        };

    string GetRuntimePackageID(string vcpkgTriplet) =>
        $"{ProjectName}.runtime.{GetRuntimeID(vcpkgTriplet)}";

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
    
    Target SetupBuildDependencies => _ => _
        .Unlisted()
        .Executes(() => 
        {
            if (IsOSPlatform(OSPlatform.Linux))
            {
                Sudo($"apt-get update");
                var dependencies = string.Join(' ', BuildDependenciesForLinux);
                Sudo($"apt-get -y install {dependencies:nq}");
            }
        });

    Target BuildPortPackage => _ => _
        .After(Clean)
        .DependsOn(SetupVcpkg)
        .DependsOn(SetupBuildDependencies)
        .Requires(() => VcpkgFeature)
        .Requires(() => VcpkgTriplets)
        .Executes(() => VcpkgTriplets.ForEach(vcpkgTriplet =>
        {
            var vcpkgBuildtreesRootDirectory = VcpkgBuildtreesRootDirectory(vcpkgTriplet);
            var vcpkgDownloadsRootDirectory = VcpkgDownloadsRootDirectory(vcpkgTriplet);
            var vcpkgInstallRootDirectory = VcpkgInstallRootDirectory(vcpkgTriplet);
            var vcpkgPackagesRootDirectory = VcpkgPackagesRootDirectory(vcpkgTriplet);

            vcpkgBuildtreesRootDirectory.CreateDirectory();
            vcpkgDownloadsRootDirectory.CreateDirectory();
            vcpkgInstallRootDirectory.CreateDirectory();
            vcpkgPackagesRootDirectory.CreateDirectory();

            var argumentList = new List<string>
            {
                $"install",
                $"--triplet={vcpkgTriplet}",
                $"--downloads-root={vcpkgDownloadsRootDirectory}",
                $"--x-buildtrees-root={vcpkgBuildtreesRootDirectory}",
                $"--x-install-root={vcpkgInstallRootDirectory}",
                $"--x-packages-root={vcpkgPackagesRootDirectory}",
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
        }));

    Target ZipPortPackage => _ => _
        .After(Clean)
        .DependsOn(BuildPortPackage)
        .Requires(() => VcpkgFeature)
        .Requires(() => VcpkgTriplets)
        .Executes(() => VcpkgTriplets.ForEach(vcpkgTriplet =>
        {
            var vcpkgBuildArchive = VcpkgArtifactsRootDirectory / $"vcpkg-{VcpkgFeature}-{vcpkgTriplet}.zip";
            var vcpkgBuildDirectory = VcpkgBuildRootDirectory(vcpkgTriplet);

            VcpkgArtifactsRootDirectory.ZipTo(
                vcpkgBuildArchive,
                filter: filePath => vcpkgBuildDirectory.Contains(filePath),
                compressionLevel: CompressionLevel.NoCompression,
                fileMode: FileMode.Create);

            vcpkgBuildDirectory.DeleteDirectory();
        }));

    Target UnzipPortPackage => _ => _
        .After(Clean)
        .DependsOn(ZipPortPackage)
        .Requires(() => VcpkgFeature)
        .Requires(() => VcpkgTriplets)
        .Executes(() => VcpkgTriplets.ForEach(vcpkgTriplet =>
        {
            var vcpkgBuildDirectory = VcpkgBuildRootDirectory(vcpkgTriplet);
            var vcpkgBuildArchive = VcpkgArtifactsRootDirectory / $"vcpkg-{VcpkgFeature}-{vcpkgTriplet}.zip";
            vcpkgBuildArchive.UnZipTo(VcpkgArtifactsRootDirectory);
            vcpkgBuildArchive.DeleteFile();
        }));

    Target BuildRuntimePackage => _ => _
        .After(Clean)
        .DependsOn(UnzipPortPackage)
        .Requires(() => VcpkgFeature)
        .Requires(() => VcpkgTriplets)
        .Executes(() => VcpkgTriplets.ForEach(vcpkgTriplet =>
        {
            var dotnetRuntimeIdentifier = GetRuntimeID(vcpkgTriplet);
            var packageID = GetRuntimePackageID(vcpkgTriplet);
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
                            new XElement("license", new XAttribute("type", "expression"), ProjectLicense),
                            new XElement("projectUrl", ProjectUrl),
                            new XElement("description", $"{dotnetRuntimeIdentifier} runtime library for {ProjectName}."),
                            new XElement("copyright", $"Copyright © {ProjectAuthor}"),
                            new XElement("repository",
                                new XAttribute("type", "git"),
                                new XAttribute("url", RepositoryUrl)
                            )
                        )
                    )
                )
            );

            var libraryTargetDirectory = packageBuildDirectory / "runtimes" / $"{dotnetRuntimeIdentifier}" / "native";
            var vcpkgInstallRootDirectory = VcpkgInstallDirectory(vcpkgTriplet);
            var libraryFiles = vcpkgInstallRootDirectory.GlobFiles("lib/*.so*", $"bin/*.dll");
            foreach (var libraryFile in libraryFiles)
            {
                CopyFileToDirectory(libraryFile, libraryTargetDirectory);
            }

            var packSettings = new NuGetPackSettings()
                .SetProcessWorkingDirectory(packageBuildDirectory)
                .SetTargetPath(packageSpecFile)
                .SetOutputDirectory(NugetInstallRootDirectory);

            NuGetPack(packSettings);
        }));

    Target BuildMultiplatformPackage => _ => _
        .After(Clean)
        .DependsOn(BuildRuntimePackage)
        .Requires(() => VcpkgFeature)
        .Requires(() => VcpkgTriplets)
        .Executes(() =>
        {
            var packageID = $"{ProjectName}";
            var packageBuildDirectory = NugetBuildRootDirectory / $"{packageID}.nupkg";
            var packageSpecFile = packageBuildDirectory / $"{packageID}.nuspec";
            var packageVersion = GitVersion.NuGetVersion;
            var runtimeSpec = packageBuildDirectory / "runtime.json";
            var runtimePackageVersion = VersionRange.Parse(packageVersion);
            var placeholderFiles = new []
            {
                packageBuildDirectory / "lib" / "netstandard2.0" / "_._"
            };

            packageBuildDirectory.CreateOrCleanDirectory();

            packageSpecFile.WriteXml(
                new XDocument(
                    new XDeclaration("1.0", "utf-8", null),
                    new XElement("{http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd}package",
                        new XElement("metadata",
                            new XAttribute("minClientVersion", "2.12"),
                            new XElement("id", packageID),
                            new XElement("version", packageVersion),
                            new XElement("authors", ProjectAuthor),
                            new XElement("requireLicenseAcceptance", true),
                            new XElement("license", new XAttribute("type", "expression"), ProjectLicense),
                            new XElement("projectUrl", ProjectUrl),
                            new XElement("description", $"Multi-platform native library for {ProjectName}."),
                            new XElement("copyright", $"Copyright © {ProjectAuthor}"),
                            new XElement("repository",
                                new XAttribute("type", "git"),
                                new XAttribute("url", RepositoryUrl)
                            ),
                            new XElement("dependencies",
                                new XElement("group",
                                    new XAttribute("targetFramework", ".NETStandard2.0")
                                )
                            )
                        )
                    )
                )
            );

            var includeTargetDirectory = packageBuildDirectory / "lib" / "native" / "include";
            var includeDirectories = VcpkgTriplets.Select(vcpkgTriplet => VcpkgInstallDirectory(vcpkgTriplet) / "include");
            foreach (var includeDirectory in includeDirectories)
            {
                CopyDirectoryRecursively(includeDirectory, includeTargetDirectory, DirectoryExistsPolicy.Merge, FileExistsPolicy.Skip);
            }

            runtimeSpec.WriteRuntimeGraph(
                new RuntimeGraph(
                    VcpkgTriplets.Select(vcpkgTriplet =>
                    {
                        var runtimeID = GetRuntimeID(vcpkgTriplet);
                        var runtimePackageID = GetRuntimePackageID(vcpkgTriplet);
                        return new RuntimeDescription(runtimeID, new []
                        {
                            new RuntimeDependencySet(packageID, new []
                            {
                                new RuntimePackageDependency(runtimePackageID, runtimePackageVersion)
                            })
                        });
                    })));

            foreach (var placeholder in placeholderFiles)
            {
                placeholder.TouchFile();
            }

            var packSettings = new NuGetPackSettings()
                .SetProcessWorkingDirectory(packageBuildDirectory)
                .SetTargetPath(packageSpecFile)
                .SetOutputDirectory(NugetInstallRootDirectory)
                .SetNoPackageAnalysis(true);

            NuGetPack(packSettings);
        });
}
