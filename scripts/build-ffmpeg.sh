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

RepoRoot="$ScriptRoot/.."
ArtifactsRoot="$RepoRoot/artifacts"
SourceDir="$RepoRoot/sources/ffmpeg"
BuildDir="$ArtifactsRoot/build/$LibraryRuntime/ffmpeg"
InstallRoot="$ArtifactsRoot/install"
InstallDir="$InstallRoot/$LibraryRuntime"
PackagesDir="$ArtifactsRoot/packages"

MakeDirectory "$ArtifactsRoot" "$BuildDir" "$InstallRoot" "$InstallDir" "$PackagesDir"

echo "$ScriptName: Configuring build for $LibraryName in $BuildDir..."
pushd "$BuildDir"
export PATH="$InstallRoot/native/bin:$PATH"
export PKG_CONFIG_PATH="$InstallDir/lib/pkgconfig"
"$SourceDir/configure" \
  --enable-gpl \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libfdk-aac \
  --enable-libopus \
  --enable-libaom \
  --enable-libsvtav1 \
  --enable-libdav1d \
  --enable-libvmaf \
  --enable-nonfree \
  --enable-shared \
  --prefix="$InstallDir" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$InstallRoot/include" \
  --extra-ldflags="-L$InstallRoot/lib" \
  --extra-libs="-lpthread -lm" \
  --ld="g++"
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to configure build for $LibraryName in $BuildDir."
  exit "$LAST_EXITCODE"
fi
popd

echo "$ScriptName: Building $LibraryName in $BuildDir..."
pushd "$BuildDir"
make
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build $LibraryName in $BuildDir."
  exit "$LAST_EXITCODE"
fi
popd

echo "$ScriptName: Installing $LibraryName to $InstallDir..."
pushd "$BuildDir"
make install
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to install $LibraryName version in $InstallDir."
  exit "$LAST_EXITCODE"
fi
popd
