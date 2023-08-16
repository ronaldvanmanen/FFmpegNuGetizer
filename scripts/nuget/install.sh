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

RepoRoot="$ScriptRoot/../.."
ArtifactsRoot="$RepoRoot/artifacts"
InstallRoot="$ArtifactsRoot/install"
InstallDir="$InstallRoot/native/nuget"

MakeDirectory "$ArtifactsRoot" "$InstallRoot" "$InstallDir"

if command -v nuget &> /dev/null; then
  echo "$ScriptName: Found 'nuget'..."
  exit 0
fi

echo "$ScriptName: Installing dependencies needed to run 'nuget'..."
sudo apt-get -y install mono-devel
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to installed dependencies needed to run 'nuget'."
  exit "$LAST_EXITCODE"
fi

NuGetUrl='https://dist.nuget.org/win-x86-commandline/latest/nuget.exe'
NuGetInstallPath="$InstallDir/nuget.exe"
echo "$ScriptName: Downloading latest stable 'nuget.exe' from $NuGetUrl to $NuGetInstallPath..."
sudo curl -o $NuGetInstallPath $NuGetUrl
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to download 'nuget.exe' from $NuGetUrl to $NuGetInstallPath."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Creating alias for 'nuget' installed in $NuGetInstallPath..."
shopt -s expand_aliases
alias nuget="mono $NuGetInstallPath"
