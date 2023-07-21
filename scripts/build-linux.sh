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

echo "$ScriptName: Installing dotnet ..."
$ScriptRoot/install-dotnet.sh
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to install dotnet."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Restoring dotnet tools ..."
$ScriptRoot/restore-dotnet-tools.sh
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to restore dotnet tools."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Installing nuget..."
$ScriptRoot/install-nuget.sh
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to install nuget."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Installing dependencies needed to build FFmpeg..."
$ScriptRoot/install-dependencies.sh
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to install dependencies needed to build FFmpeg."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Building NASM..."
$ScriptRoot/build-nasm.sh
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build NASM."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Building libx264..."
$ScriptRoot/build-libx264.sh --architecture $Architecture
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build libx264."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Building libx265..."
$ScriptRoot/build-libx265.sh --architecture $Architecture
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build libx265."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Building libvpx..."
$ScriptRoot/build-libvpx.sh --architecture $Architecture
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build libvpx."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Building libfdk-aac..."
$ScriptRoot/build-libfdk-aac.sh --architecture $Architecture
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build libfdk-aac."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Building libopus..."
$ScriptRoot/build-libopus.sh --architecture $Architecture
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build libopus."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Building libaom..."
$ScriptRoot/build-libaom.sh --architecture $Architecture
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build libaom."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Building libsvt-av1..."
$ScriptRoot/build-libsvt-av1.sh --architecture $Architecture
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build libsvt-av1."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Building libdav1d..."
$ScriptRoot/build-libdav1d.sh --architecture $Architecture
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build libdav1d."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Building libvmaf..."
$ScriptRoot/build-libvmaf.sh --architecture $Architecture
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build libvmaf."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Building FFmpeg..."
$ScriptRoot/build-ffmpeg.sh --architecture $Architecture
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build FFmpeg."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Packing FFmpeg..."
$ScriptRoot/pack-ffmpeg.sh --architecture $Architecture
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to pack FFmpeg."
  exit "$LAST_EXITCODE"
fi
