<#
  .SYNOPSIS
  Builds an FFmpeg runtime package for the specified .NET runtime.

  .DESCRIPTION
  Builds an FFmpeg runtime package for the specified .NET runtime.

  .PARAMETER runtime
  Specifies the .NET runtime identifier for the package (e.g. win-x64, win-x86).

  .PARAMETER feature
  Specifies the vcpkg feature for the package (e.g. none, all-lgpl, all-gpl).

  .INPUTS
  None.

  .OUTPUTS
  None.

  .EXAMPLE
  PS> .\build-runtime -runtime win-x64 -feature none

  .EXAMPLE
  PS> .\build-runtime -runtime win-x86 -feature all-lgpl

  .EXAMPLE
  PS> .\build-runtime -runtime win-x64 -feature all-gpl
#>

[CmdletBinding(PositionalBinding=$false)]
Param(
  [Parameter(Mandatory)][ValidateSet("win-x64", "win-x86")][string] $Runtime = "",
  [Parameter(Mandatory)][ValidateSet("none", "all-lgpl", "all-gpl")][string] $Feature = "none"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function New-Directory([string[]] $Path) {
  if (!(Test-Path -Path $Path)) {
    New-Item -Path $Path -Force -ItemType "Directory" | Out-Null
  }
}

function Copy-File([string[]] $Path, [string] $Destination, [switch] $Force, [switch] $Recurse) {
  if (!(Test-Path -Path $Destination)) {
    New-Item -Path $Destination -Force:$Force -ItemType "Directory" | Out-Null
  }
  Copy-Item -Path $Path -Destination $Destination -Force:$Force -Recurse:$Recurse
}

try {
  $ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)

  if ($Runtime -eq "win-x64") {
    $VcpkgTriplet="x64-windows-release"
  } elseif ($Runtime -eq "win-x86") {
    $VcpkgTriplet="x86-windows-release"
  } else {
    throw "${ScriptName}: The specified .NET runtime identifier is not yet supported."
  }

  $RepoRoot = Join-Path -Path $PSScriptRoot -ChildPath ".."
  
  $ArtifactsRoot = Join-Path -Path $RepoRoot -ChildPath "artifacts"

  New-Directory -Path $ArtifactsRoot

  $VcpkgArtifactsRoot = Join-Path $ArtifactsRoot -ChildPath "vcpkg"
  $VcpkgBuildtreesRoot = Join-Path $VcpkgArtifactsRoot -ChildPath "buildtrees"
  $VcpkgDownloadsRoot = Join-Path $VcpkgArtifactsRoot -ChildPath "downloads"
  $VcpkgInstallRoot = Join-Path $VcpkgArtifactsRoot -ChildPath "installed"
  $VcpkgPackagesRoot = Join-Path $VcpkgArtifactsRoot -ChildPath "packages"

  New-Directory -Path $VcpkgArtifactsRoot, $VcpkgBuildtreesRoot, $VcpkgDownloadsRoot, $VcpkgInstallRoot, $VcpkgPackagesRoot
 
  $NuGetPackageName = ($Feature -eq "none") ? "FFmpeg.runtime.$Runtime" : "FFmpeg.$Feature.runtime.$Runtime"
  $NuGetArtifactsRoot = Join-Path $ArtifactsRoot -ChildPath "nuget"
  $NuGetBuildRoot = Join-Path $NuGetArtifactsRoot -ChildPath "build"
  $NuGetBuildDir = Join-Path $NuGetBuildRoot -ChildPath $NuGetPackageName
  $NuGetInstallRoot = Join-Path $NuGetArtifactsRoot -ChildPath "installed"
  
  New-Directory -Path $NuGetArtifactsRoot, $NuGetBuildRoot, $NuGetInstallRoot

  Write-Host "${ScriptName}: Bootstrapping vcpkg..."
  $env:VCPKG_DISABLE_METRICS = 1
  .\vcpkg\bootstrap-vcpkg.bat -disableMetrics
  if ($LastExitCode -ne 0) {
    throw "${ScriptName}: Failed to bootstrap vcpkg."
  }

  Write-Host "${ScriptName}: Building FFmpeg using vcpkg..."
  .\vcpkg\vcpkg install `
    --triplet="$VcpkgTriplet" `
    --downloads-root="$VcpkgDownloadsRoot" `
    --x-buildtrees-root="$VcpkgBuildtreesRoot" `
    --x-install-root="$VcpkgInstallRoot" `
    --x-packages-root="$VcpkgPackagesRoot" `
    --x-no-default-features `
    --x-feature="$Feature" `
    --disable-metrics
  if ($LastExitCode -ne 0) {
    throw "${ScriptName}: Failed to build FFmpeg using vcpkg."
  }

  Write-Host "${ScriptName}: Determining NuGet version for FFmpeg runtime package..." -ForegroundColor Yellow
  $NuGetPackageVersion = dotnet gitversion /showvariable NuGetVersion /output json
  if ($LastExitCode -ne 0) {
    throw "${ScriptName}: Failed determine NuGet version for FFmpeg runtime package."
  }

  Write-Host "${ScriptName}: Build FFmpeg runtime package folder structure..." -ForegroundColor Yellow
  Copy-File -Path "$RepoRoot\packages\$NuGetPackageName\*" -Destination $NuGetBuildDir -Force -Recurse
  Copy-File -Path "$VcpkgInstallRoot\$VcpkgTriplet\bin\avcodec*.dll" "$NuGetBuildDir\runtimes\$Runtime\native" -Force
  Copy-File -Path "$VcpkgInstallRoot\$VcpkgTriplet\bin\avdevice*.dll" "$NuGetBuildDir\runtimes\$Runtime\native" -Force
  Copy-File -Path "$VcpkgInstallRoot\$VcpkgTriplet\bin\avfilter*.dll" "$NuGetBuildDir\runtimes\$Runtime\native" -Force
  Copy-File -Path "$VcpkgInstallRoot\$VcpkgTriplet\bin\avformat*.dll" "$NuGetBuildDir\runtimes\$Runtime\native" -Force
  Copy-File -Path "$VcpkgInstallRoot\$VcpkgTriplet\bin\avutil*.dll" "$NuGetBuildDir\runtimes\$Runtime\native" -Force
  Copy-File -Path "$VcpkgInstallRoot\$VcpkgTriplet\bin\swresample*.dll" "$NuGetBuildDir\runtimes\$Runtime\native" -Force
  Copy-File -Path "$VcpkgInstallRoot\$VcpkgTriplet\bin\swscale*.dll" "$NuGetBuildDir\runtimes\$Runtime\native" -Force

  Write-Host "${ScriptName}: Building FFmpeg runtime package..." -ForegroundColor Yellow
  & nuget pack $NuGetBuildDir\$NuGetPackageName.nuspec -Properties version=$NuGetPackageVersion -OutputDirectory $NuGetInstallRoot
  if ($LastExitCode -ne 0) {
    throw "${ScriptName}: Failed to build FFmpeg runtime package."
  }
}
catch {
  Write-Host -Object $_ -ForegroundColor Red
  Write-Host -Object $_.Exception -ForegroundColor Red
  Write-Host -Object $_.ScriptStackTrace -ForegroundColor Red
  exit 1
}
