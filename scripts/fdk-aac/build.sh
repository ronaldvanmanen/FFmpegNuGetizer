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

LibraryName='fdk-aac'

LibraryRuntime="linux-$Architecture"

RepoRoot="$ScriptRoot/../.."
ArtifactsRoot="$RepoRoot/artifacts"
SourceDir="$RepoRoot/sources/$LibraryName"
BuildDir="$ArtifactsRoot/build/$LibraryRuntime/$LibraryName"
InstallRoot="$ArtifactsRoot/install"
InstallDir="$InstallRoot/$LibraryRuntime"

MakeDirectory "$ArtifactsRoot" "$BuildDir" "$InstallDir" 

echo "$ScriptName: Installing dependencies needed to build $LibraryName..."
sudo apt-get update && sudo apt-get -y install \
  autoconf \
  automake \
  build-essential \
  git
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to install dependencies needed to build $LibraryName."
  exit "$LAST_EXITCODE"
fi

export PATH="$InstallRoot/bin:$PATH"

pushd "$BuildDir"

echo "$ScriptName: Cloning $LibraryName in $BuildDir..."
git clone "$SourceDir" . 2> /dev/null || git reset --hard && git clean -xfd
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to clone $LibraryName in $BuildDir."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Regenerating build system files of $LibraryName in $BuildDir..."
autoreconf -fiv
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to regenerate build system files of $LibraryName in $BuildDir."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Configuring build for $LibraryName in $BuildDir..."
./configure --prefix="$InstallDir" --disable-shared --with-pic
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to configure build for $LibraryName in $BuildDir."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Building $LibraryName in $BuildDir..."
make
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build $LibraryName in $BuildDir."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Installing $LibraryName in $InstallDir..."
make install
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to install $LibraryName version in $InstallDir."
  exit "$LAST_EXITCODE"
fi

popd
