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

  $RepoRoot = Join-Path -Path $PSScriptRoot -ChildPath ".."

  $ArtifactsRoot = Join-Path -Path $RepoRoot -ChildPath "artifacts"

  New-Directory -Path $ArtifactsRoot

  $NuGetPackageName = "FFmpeg"
  $NuGetArtifactsRoot = Join-Path $ArtifactsRoot -ChildPath "nuget"
  $NuGetBuildRoot = Join-Path $NuGetArtifactsRoot -ChildPath "build"
  $NuGetBuildDir = Join-Path $NuGetBuildRoot -ChildPath $NuGetPackageName
  $NuGetInstallRoot = Join-Path $NuGetArtifactsRoot -ChildPath "installed"
  
  New-Directory -Path $NuGetArtifactsRoot, $NuGetBuildRoot, $NuGetInstallRoot

  Write-Host "${ScriptName}: Determining NuGet version for FFmpeg multi-platform package..." -ForegroundColor Yellow
  $NuGetPackageVersion = dotnet gitversion /showvariable NuGetVersion /output json
  if ($LastExitCode -ne 0) {
    throw "${ScriptName}: Failed determine NuGet version for FFmpeg multi-platform package."
  }

  Write-Host "${ScriptName}: Producing FFmpeg multi-platform package folder structure..." -ForegroundColor Yellow

  Copy-File -Path "$RepoRoot\packages\FFmpeg\*" -Destination $NuGetBuildDir -Force -Recurse

  $VcpkgTriplet="x86-windows-release"
  $VcpkgArtifactsRoot = Join-Path $ArtifactsRoot -ChildPath "vcpkg"
  $VcpkgInstallRoot = Join-Path $VcpkgArtifactsRoot -ChildPath "installed"

  Copy-File -Path "$VcpkgInstallRoot\$VcpkgTriplet\include\libavcodec" "$NuGetBuildDir\build\native\include" -Force -Recurse
  Copy-File -Path "$VcpkgInstallRoot\$VcpkgTriplet\include\libavdevice" "$NuGetBuildDir\build\native\include" -Force -Recurse
  Copy-File -Path "$VcpkgInstallRoot\$VcpkgTriplet\include\libavfilter" "$NuGetBuildDir\build\native\include" -Force -Recurse
  Copy-File -Path "$VcpkgInstallRoot\$VcpkgTriplet\include\libavformat" "$NuGetBuildDir\build\native\include" -Force -Recurse
  Copy-File -Path "$VcpkgInstallRoot\$VcpkgTriplet\include\libavutil" "$NuGetBuildDir\build\native\include" -Force -Recurse
  Copy-File -Path "$VcpkgInstallRoot\$VcpkgTriplet\include\libswresample" "$NuGetBuildDir\build\native\include" -Force -Recurse
  Copy-File -Path "$VcpkgInstallRoot\$VcpkgTriplet\include\libswscale" "$NuGetBuildDir\build\native\include" -Force -Recurse

  Write-Host "${ScriptName}: Replacing variable `$version`$ in runtime.json with value '$NuGetPackageVersion'..." -ForegroundColor Yellow
  $RuntimeContent = Get-Content $NuGetBuildDir\runtime.json -Raw
  $RuntimeContent = $RuntimeContent.replace('$version$', $NuGetPackageVersion)
  Set-Content $NuGetBuildDir\runtime.json $RuntimeContent

  Write-Host "${ScriptName}: Building FFmpeg multi-platform package..." -ForegroundColor Yellow
  & nuget pack $NuGetBuildDir\FFmpeg.nuspec -Properties version=$NuGetPackageVersion -OutputDirectory $NuGetInstallRoot
  if ($LastExitCode -ne 0) {
    throw "${ScriptName}: Failed to build FFmpeg multi-platform package."
  }
}
catch {
  Write-Host -Object $_ -ForegroundColor Red
  Write-Host -Object $_.Exception -ForegroundColor Red
  Write-Host -Object $_.ScriptStackTrace -ForegroundColor Red
  exit 1
}