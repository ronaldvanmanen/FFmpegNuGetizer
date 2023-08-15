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

LibraryName="nasm"

RepoRoot="$ScriptRoot/../.."
ArtifactsRoot="$RepoRoot/artifacts"
SourceDir="$RepoRoot/sources/$LibraryName"
BuildDir="$ArtifactsRoot/build/native/$LibraryName"
InstallDir="$ArtifactsRoot/install/native"

MakeDirectory "$ArtifactsRoot" "$BuildDir" "$InstallDir"

echo "$ScriptName: Installing dependencies needed to build $LibraryName..."
sudo apt-get update && sudo apt-get -y install \
  asciidoc \
  autoconf \
  automake \
  build-essential \
  git \
  xmlto
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to install dependencies needed to build $LibraryName."
  exit "$LAST_EXITCODE"
fi

pushd "$BuildDir"

echo "$ScriptName: Cloning $LibraryName in $BuildDir..."
git clone "$SourceDir" .
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to clone $LibraryName in $BuildDir."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Generating the configure script for $LibraryName in $BuildDir..."
./autogen.sh
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to generate the configure script for $LibraryName in $BuildDir."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Configuring build for $LibraryName in $BuildDir..."
./configure --prefix="$InstallDir" --bindir="$InstallDir/bin"
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to configure build for $LibraryName in $BuildDir."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Building $LibraryName in $BuildDir..."
make all manpages
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build $LibraryName in $BuildDir."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Installing $LibraryName in $BuildDir..."
make install
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to install $LibraryName version in $InstallDir."
  exit "$LAST_EXITCODE"
fi

popd
