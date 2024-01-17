using System;
using System.Linq;
using JetBrains.Annotations;
using Nuke.Common;
using Nuke.Common.CI;
using Nuke.Common.Execution;
using Nuke.Common.IO;
using Nuke.Common.ProjectModel;
using Nuke.Common.Tooling;
using Nuke.Common.Utilities.Collections;
using static Nuke.Common.EnvironmentInfo;
using static Nuke.Common.IO.FileSystemTasks;
using static Nuke.Common.IO.PathConstruction;

class Build : NukeBuild
{
    public static int Main () => Execute<Build>(x => x.Clean);

    AbsolutePath ArtifactsRootDirectory => RootDirectory / "artifacts";

    [LocalPath(windowsPath: "vcpkg/bootstrap-vcpkg.bat", unixPath: "vcpkg/bootstrap.sh")]
    readonly Tool BootstrapVcpkg;

    Target Clean => _ => _
        .Executes(() =>
        {
            ArtifactsRootDirectory.CreateOrCleanDirectory();
        });

    [UsedImplicitly]
    Target SetupVcpkg => _ => _
        .Executes(() =>
        {
            BootstrapVcpkg("-disableMetrics");
        });
    
}
