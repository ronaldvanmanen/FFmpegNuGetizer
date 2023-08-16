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
Architecture=''

while [[ $# -gt 0 ]]; do
  lower="$(echo "$1" | awk '{print tolower($0)}')"
  case $lower in
    --help)
      Help=true
      shift 1
      ;;
    --architecture)
      Architecture=$2
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
  echo "  --architecture <value>    Specifies the architecture for the package (e.g. x64)"
  echo "  --help                    Print help and exit"
}

if $Help; then
  Help
  exit 0
fi

if [[ -z "$Architecture" ]]; then
  echo "$ScriptName: architecture missing."
  Help
  exit 1
fi

LibraryName="FFmpeg"
LibraryRuntime="linux-$Architecture"
PackageName="$LibraryName.runtime.$LibraryRuntime"

RepoRoot="$ScriptRoot/../.."
ArtifactsRoot="$RepoRoot/artifacts"
SourceDir="$RepoRoot/sources/ffmpeg"
BuildDir="$ArtifactsRoot/build/$LibraryRuntime/$PackageName.nupkg"
InstallRoot="$ArtifactsRoot/install"
InstallDir="$InstallRoot/$LibraryRuntime"
PackagesDir="$ArtifactsRoot/packages"

MakeDirectory "$ArtifactsRoot" "$BuildDir" "$InstallRoot" "$InstallDir" "$PackagesDir"

echo "$ScriptName: Calculating $LibraryName package version..."
PackageVersion=$(dotnet gitversion /output json /showvariable NuGetVersion)
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to calculate $LibraryName package version."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Producing $LibraryName runtime package folder structure in $BuildDir..."
MakeDirectory "$BuildDir"
cp -dR "$RepoRoot/packages/$PackageName/." "$BuildDir"
cp -d "$SourceDir/LICENSE.md" "$BuildDir"
cp -d "$SourceDir/README.md" "$BuildDir"
mkdir -p "$BuildDir/runtimes/$LibraryRuntime/native" \
  && cp -d "$InstallDir/lib/libavcodec.so"* $_ \
  && cp -d "$InstallDir/lib/libavdevice.so"* $_ \
  && cp -d "$InstallDir/lib/libavfilter.so"* $_ \
  && cp -d "$InstallDir/lib/libavformat.so"* $_ \
  && cp -d "$InstallDir/lib/libavutil.so"* $_ \
  && cp -d "$InstallDir/lib/libpostproc.so"* $_ \
  && cp -d "$InstallDir/lib/libswresample.so"* $_ \
  && cp -d "$InstallDir/lib/libswscale.so"* $_

echo "$ScriptName: Building $LibraryName runtime package..."
nuget pack "$BuildDir/$PackageName.nuspec" -Properties "version=$PackageVersion" -OutputDirectory $PackagesDir
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build $LibraryName runtime package."
  exit "$LAST_EXITCODE"
fi
