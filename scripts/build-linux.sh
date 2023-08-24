#!/bin/bash

function MakeDirectory {
  for dirname in "$@"
  do
    if [ ! -d "$dirname" ]
    then
      mkdir -p "$dirname"
    fi
  done  
}

SOURCE="${BASH_SOURCE[0]}"

while [ -h "$SOURCE" ]; do
  # resolve $SOURCE until the file is no longer a symlink
  ScriptRoot="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  [[ $SOURCE != /* ]] && SOURCE="$ScriptRoot/$SOURCE"
done

ScriptRoot="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
ScriptName=$(basename -s '.sh' "$SOURCE")
Help=false
Runtime=''

while [[ $# -gt 0 ]]; do
  lower="$(echo "$1" | awk '{print tolower($0)}')"
  case $lower in
    --help)
      Help=true
      shift 1
      ;;
    --runtime)
      Runtime=$2
      shift 2
      ;;
    *)
      properties="$properties $1"
      shift 1
      ;;
  esac
done

function Help {
  echo "Usage: $ScriptName [OPTION]"
  echo ""
  echo "Options:"
  echo "  --runtime <value>   Specifies the .NET runtime identifier for the package (e.g. linux-x64)"
  echo "  --help              Print help and exit"
}

if $Help; then
  Help
  exit 0
fi

if [[ -z "$Runtime" ]]; then
  echo "$ScriptName: .NET runtime identifier missing."
  Help
  exit 1
fi

if [[ "${Runtime}" == "linux-x64" ]]; then
  VcpkgTriplet="x64-linux-dynamic-release"
else
  echo "$ScriptName: The specified .NET runtime identifier is not yet supported."
  exit 2
fi

RepoRoot="$ScriptRoot/.."

ArtifactsRoot="$RepoRoot/artifacts"

MakeDirectory "$ArtifactsRoot"

VcpkgOverlayTripletsRoot="$RepoRoot/vcpkg-triplets"
VcpkgArtifactsRoot="$ArtifactsRoot/vcpkg"
VcpkgBuildtreesRoot="$VcpkgArtifactsRoot/buildtrees"
VcpkgDownloadsRoot="$VcpkgArtifactsRoot/downloads"
VcpkgInstallRoot="$VcpkgArtifactsRoot/installed"
VcpkgPackagesRoot="$VcpkgArtifactsRoot/packages"

MakeDirectory "$VcpkgArtifactsRoot" "$VcpkgBuildtreesRoot" "$VcpkgDownloadsRoot" "$VcpkgInstallRoot" "$VcpkgPackagesRoot"

NuGetPackageName="FFmpeg.runtime.$Runtime"
NuGetArtifactsRoot="$ArtifactsRoot/nuget"
NuGetBuildRoot="$NuGetArtifactsRoot/build"
NuGetBuildDir="$NuGetBuildRoot/$NuGetPackageName"
NuGetInstallRoot="$NuGetArtifactsRoot/installed"

MakeDirectory "$NuGetArtifactsRoot" "$NuGetBuildRoot" "$NuGetBuildDir" "$NuGetInstallRoot"

echo "$ScriptName: Bootstrapping vcpkg..."
export VCPKG_DISABLE_METRICS=1
./vcpkg/bootstrap-vcpkg.sh -disableMetrics
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to bootstrap vcpkg."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Building FFmpeg using vcpkg..."
./vcpkg/vcpkg install \
  --triplet="$VcpkgTriplet" \
  --overlay-triplets="$VcpkgOverlayTripletsRoot" \
  --downloads-root="$VcpkgDownloadsRoot" \
  --x-buildtrees-root="$VcpkgBuildtreesRoot" \
  --x-install-root="$VcpkgInstallRoot" \
  --x-packages-root="$VcpkgPackagesRoot" \
  --disable-metrics
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build FFmpeg using vcpkg."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Determining FFmpeg runtime package version..."
NuGetPackageVersion=$(dotnet gitversion /output json /showvariable NuGetVersion)
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to determine FFmpeg runtime package version."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Building FFmpeg runtime package folder structure..."
cp -dR "$RepoRoot/packages/$NuGetPackageName/." "$NuGetBuildDir"
mkdir -p "$NuGetBuildDir/runtimes/$Runtime/native" \
  && cp -d "$VcpkgInstallRoot/lib/libavcodec."* $_ \
  && cp -d "$VcpkgInstallRoot/lib/libavdevice."* $_ \
  && cp -d "$VcpkgInstallRoot/lib/libavfilter."* $_ \
  && cp -d "$VcpkgInstallRoot/lib/libavformat."* $_ \
  && cp -d "$VcpkgInstallRoot/lib/libavutil."* $_ \
  && cp -d "$VcpkgInstallRoot/lib/libswresample."* $_ \
  && cp -d "$VcpkgInstallRoot/lib/libswscale."* $_

echo "$ScriptName: Building FFmpeg runtime package..."
nuget pack "$NuGetBuildDir/$NuGetPackageName.nuspec" -Properties "version=$NuGetPackageVersion" -OutputDirectory $NuGetInstallRoot
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build FFmpeg runtime package."
  exit "$LAST_EXITCODE"
fi
