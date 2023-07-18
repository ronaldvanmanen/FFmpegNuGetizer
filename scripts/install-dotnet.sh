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

RepoRoot="$ScriptRoot/.."

ArtifactsRoot="$RepoRoot/artifacts"
DownloadDir="$ArtifactsRoot/downloads"
InstallDir="$ArtifactsRoot/install/native/dotnet"

MakeDirectory "$ArtifactsRoot" "$DownloadDir" "$InstallDir"

echo "$ScriptName: Installing dotnet ..."
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_MULTILEVEL_LOOKUP=0
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1

DotNetInstallScript="$DownloadDir/dotnet-install.sh"
wget -O "$DotNetInstallScript" "https://dot.net/v1/dotnet-install.sh"

bash "$DotNetInstallScript" --channel 6.0 --version latest --install-dir "$InstallDir"
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to install dotnet 6.0."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Restoring dotnet tools..."
dotnet tool restore
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to restore dotnet tools."
  exit "$LAST_EXITCODE"
fi
