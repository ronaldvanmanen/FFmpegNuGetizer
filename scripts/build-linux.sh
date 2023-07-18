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

Runtime="linux-$architecture"

RepoRoot="$ScriptRoot/.."
SourceRoot="$RepoRoot/sources"
SourceDir="$SourceRoot/FFmpeg"

ArtifactsRoot="$RepoRoot/artifacts"
BuildRoot="$ArtifactsRoot/build"
BuildDir="$BuildRoot/FFmpeg/$Runtime"
InstallRoot="$ArtifactsRoot/install"
InstallDir="$InstallRoot/FFmpeg/$Runtime"
PackageRoot="$ArtifactsRoot/packages"

MakeDirectory "$ArtifactsRoot" "$BuildRoot" "$BuildDir" "$InstallRoot" "$InstallDir" "$PackageRoot"

echo "$ScriptName: Installing dotnet ..."
$ScriptRoot/install-dotnet.sh
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to install dotnet."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Restoring dotnet tools ..."
dotnet tool restore
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to restore dotnet tools."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Updating package list before installating dependencies needed to build FFmpeg..."
sudo apt-get update
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to update package list before installating dependencies needed to build FFmpeg."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Installing dependencies needed to build FFmpeg..."
sudo apt-get -y install \
  asciidoc \
  autoconf \
  automake \
  build-essential \
  cmake \
  git \
  libass-dev \
  libfreetype6-dev \
  libgnutls28-dev \
  libmp3lame-dev \
  libsdl2-dev \
  libtool \
  libva-dev \
  libvdpau-dev \
  libvorbis-dev \
  libxcb1-dev \
  libxcb-shm0-dev \
  libxcb-xfixes0-dev \
  meson \
  ninja-build \
  pkg-config \
  texinfo \
  wget \
  xmlto \
  yasm \
  zlib1g-dev
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to install dependencies needed to build FFmpeg."
  exit "$LAST_EXITCODE"
fi

if ! command -v nuget &> /dev/null; then
  echo "$ScriptName: Installing packages needed to pack FFmpeg..."
  sudo apt-get -y install mono-devel
  LAST_EXITCODE=$?
  if [ $LAST_EXITCODE != 0 ]; then
    echo "$ScriptName: Failed to installed packages needed pack FFmpeg."
    exit "$LAST_EXITCODE"
  fi

  NuGetUrl='https://dist.nuget.org/win-x86-commandline/latest/nuget.exe'
  NuGetInstallPath="$ArtifactsRoot/nuget.exe"
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

echo "$ScriptName: Configuring build for FFmpeg in $BuildDir..."
pushd "$BuildDir"
export PATH="$InstallRoot/bin:$PATH"
export PKG_CONFIG_PATH="$InstallRoot/lib/pkgconfig"
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
popd
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to configure build for FFmpeg in $BuildDir."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Building FFmpeg in $BuildDir..."
pushd "$BuildDir"
make
popd
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build FFmpeg in $BuildDir."
  exit "$LAST_EXITCODE"
fi

echo "$ScriptName: Installing FFmpeg to $InstallDir..."
pushd "$BuildDir"
make install
popd
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to install FFmpeg version in $InstallDir."
  exit "$LAST_EXITCODE"
fi

NuGetVersion=$(nuget ? | grep -oP 'NuGet Version: \K.+')

echo "$ScriptName: Calculating FFmpeg package version..."
PackageVersion=$(dotnet gitversion /output json /showvariable NuGetVersion)
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to calculate FFmpeg package version."
  exit "$LAST_EXITCODE"
fi

RuntimePackageName="FFmpeg.runtime.$Runtime"
RuntimePackageBuildDir="$BuildRoot/$RuntimePackageName.nupkg"

echo "$ScriptName: Producing FFmpeg runtime package folder structure in $RuntimePackageBuildDir..."
MakeDirectory "$RuntimePackageBuildDir"
cp -dR "$RepoRoot/packages/$RuntimePackageName/." "$RuntimePackageBuildDir"
cp -d "$SourceDir/LICENSE.md" "$RuntimePackageBuildDir"
cp -d "$SourceDir/README.md" "$RuntimePackageBuildDir"
mkdir -p "$RuntimePackageBuildDir/runtimes/$Runtime/native" && cp -d "$InstallDir/lib/"*"so"* $_

echo "$ScriptName: Building FFmpeg runtime package (using NuGet $NuGetVersion)..."
nuget pack "$RuntimePackageBuildDir/$RuntimePackageName.nuspec" -Properties "version=$PackageVersion" -OutputDirectory $PackageRoot
LAST_EXITCODE=$?
if [ $LAST_EXITCODE != 0 ]; then
  echo "$ScriptName: Failed to build FFmpeg runtime package."
  exit "$LAST_EXITCODE"
fi
