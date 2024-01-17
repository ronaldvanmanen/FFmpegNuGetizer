using System;
using System.Collections.Generic;
using System.Linq;
using JetBrains.Annotations;
using Nuke.Common;
using Nuke.Common.IO;
using Nuke.Common.Tooling;

class Build : NukeBuild
{
    public static int Main () => Execute<Build>(x => x.BuildPortPackage);

    [Parameter()]
    readonly string VcpkgTriplet;

    [Parameter()]
    readonly string VcpkgFeature;

    [Parameter()]
    readonly string[] VcpkgBinarySources = Array.Empty<string>();

    [Parameter()]
    readonly bool VcpkgDebug;

    AbsolutePath ArtifactsRootDirectory => RootDirectory / "artifacts";

    AbsolutePath VcpkgArtifactsRootDirectory => ArtifactsRootDirectory / "vcpkg";

    AbsolutePath VcpkgBuildtreesRootDirectory => VcpkgArtifactsRootDirectory / VcpkgFeature / VcpkgTriplet / "buildtrees";

    AbsolutePath VcpkgDownloadsRootDirectory => VcpkgArtifactsRootDirectory / VcpkgFeature / VcpkgTriplet / "downloads";

    AbsolutePath VcpkgInstallRootDirectory => VcpkgArtifactsRootDirectory / VcpkgFeature / VcpkgTriplet / "installed";

    AbsolutePath VcpkgPackagesRootDirectory => VcpkgArtifactsRootDirectory / VcpkgFeature / VcpkgTriplet / "packages";

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
}
