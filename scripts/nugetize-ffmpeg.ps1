function New-Directory([string[]] $Path) {
  if (!(Test-Path -Path $Path)) {
    New-Item -Path $Path -Force -ItemType "Directory" | Out-Null
  }
}

function Copy-File([string[]] $Path, [string] $Destination, [switch] $Force) {
  if (!(Test-Path -Path $Destination)) {
    New-Item -Path $Destination -Force:$Force -ItemType "Directory" | Out-Null
  }
  Copy-Item -Path $Path -Destination $Destination -Force:$Force
}

try {
  $RepoRoot = Join-Path -Path $PSScriptRoot -ChildPath ".."

  $PackagesDir = Join-Path -Path $RepoRoot -ChildPath "packages"

  $ArtifactsDir = Join-Path -Path $RepoRoot -ChildPath "artifacts"
  New-Directory -Path $ArtifactsDir

  $ArtifactsPkgDir = Join-Path $ArtifactsDir -ChildPath "pkg"
  New-Directory -Path $ArtifactsPkgDir

  $StagingDir = Join-Path -Path $RepoRoot -ChildPath "staging"
  New-Directory $StagingDir

  $DownloadsDir = Join-Path -Path $RepoRoot -ChildPath "downloads"
  New-Directory -Path $DownloadsDir

  & dotnet tool restore

  $GitVersionRaw = dotnet gitversion /output json
  Write-Host "GitVersion output: $GitVersionRaw ..." -ForegroundColor Yellow
  $GitVersion = $GitVersionRaw | ConvertFrom-Json
  $MajorMinorPatch = $GitVersion.MajorMinorPatch
  $PackageVersion = $GitVersion.NuGetVersion

  Write-Host "Get FFmpeg release for version $MajorMinorPatch..." -ForegroundColor Yellow
  $Release = Invoke-RestMethod -Headers @{ 'Accept'='application/vnd.github+json'} -Uri "https://api.github.com/repos/GyanD/codexffmpeg/releases/tags/$MajorMinorPatch"
  $Asset = $Release.assets | Where-Object { $_.name -Like "ffmpeg-$MajorMinorPatch-full_build-shared.zip" }
  $AssetName = $Asset.name
  $BrowserDownloadUrl = $Asset.browser_download_url

  $ZipDownloadPath = Join-Path $DownloadsDir $AssetName

  if (!(Test-Path $ZipDownloadPath)) {
    Write-Host "Downloading FFmpeg development libraries version '$LatestVersion' from '$BrowserDownloadUrl'..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $BrowserDownloadUrl -OutFile $ZipDownloadPath
  }

  Write-Host "Extracting FFmpeg development libraries to '$DownloadsDir'..." -ForegroundColor Yellow
  $ExpandedFiles = Expand-Archive -Path $ZipDownloadPath -DestinationPath $DownloadsDir -Force -Verbose *>&1

  Write-Host "Staging FFmpeg development libraries to '$StagingDir'..." -ForegroundColor Yellow
  Copy-Item -Path $PackagesDir\FFmpeg -Destination $StagingDir -Force -Recurse
  Copy-Item -Path $PackagesDir\FFmpeg.runtime.win-x64 -Destination $StagingDir -Force -Recurse

  $ExpandedFiles | Foreach-Object {
    if ($_.message -match "Created '(.*)'.*") {
      $ExpandedFile = $Matches[1]

      if (($ExpandedFile -like '*\LICENSE') -or
          ($ExpandedFile -like '*\README.txt')) {
        Copy-File -Path $ExpandedFile -Destination $StagingDir\FFmpeg -Force
        Copy-File -Path $ExpandedFile -Destination $StagingDir\FFmpeg.runtime.win-x64 -Force
      }
      elseif ($ExpandedFile -like '*\include\libavcodec\*.h') {
        Copy-File -Path $ExpandedFile -Destination $StagingDir\FFmpeg\lib\native\include\libavcodec -Force
      }
      elseif ($ExpandedFile -like '*\include\libavdevice\*.h') {
        Copy-File -Path $ExpandedFile -Destination $StagingDir\FFmpeg\lib\native\include\libavdevice -Force
      }
      elseif ($ExpandedFile -like '*\include\libavfilter\*.h') {
        Copy-File -Path $ExpandedFile -Destination $StagingDir\FFmpeg\lib\native\include\libavfilter -Force
      }
      elseif ($ExpandedFile -like '*\include\libavformat\*.h') {
        Copy-File -Path $ExpandedFile -Destination $StagingDir\FFmpeg\lib\native\include\libavformat -Force
      }
      elseif ($ExpandedFile -like '*\include\libavutil\*.h') {
        Copy-File -Path $ExpandedFile -Destination $StagingDir\FFmpeg\lib\native\include\libavutil -Force
      }
      elseif ($ExpandedFile -like '*\include\libpostproc\*.h') {
        Copy-File -Path $ExpandedFile -Destination $StagingDir\FFmpeg\lib\native\include\libpostproc -Force
      }
      elseif ($ExpandedFile -like '*\include\libswresample\*.h') {
        Copy-File -Path $ExpandedFile -Destination $StagingDir\FFmpeg\lib\native\include\libswresample -Force
      }
      elseif ($ExpandedFile -like '*\include\libswscale\*.h') {
        Copy-File -Path $ExpandedFile -Destination $StagingDir\FFmpeg\lib\native\include\libswscale -Force
      }
      elseif ($ExpandedFile -like '*\bin\*.dll') {
        Copy-File -Path $ExpandedFile -Destination $StagingDir\FFmpeg.runtime.win-x64\runtimes\win-x64\native -Force
      }
    }
  }

  Write-Host "Replace variable `$version`$ in runtime.json with value '$PackageVersion'..." -ForegroundColor Yellow
  $RuntimeContent = Get-Content "$StagingDir\FFmpeg\runtime.json" -Raw
  $RuntimeContent = $RuntimeContent.replace('$version$', $PackageVersion)
  Set-Content "$StagingDir\FFmpeg\runtime.json" $RuntimeContent

  Write-Host "Build 'FFmpeg' package..." -ForegroundColor Yellow
  & nuget pack "$StagingDir\FFmpeg\FFmpeg.nuspec" -Properties version=$PackageVersion -OutputDirectory "$ArtifactsPkgDir"
  if ($LastExitCode -ne 0) {
    throw "'nuget pack' failed for 'FFmpeg.nuspec'"
  }
  
  Write-Host "Build 'FFmpeg.runtime.win-x64' package..." -ForegroundColor Yellow
  & nuget pack "$StagingDir\FFmpeg.runtime.win-x64\FFmpeg.runtime.win-x64.nuspec" -Properties version=$PackageVersion -OutputDirectory "$ArtifactsPkgDir"
  if ($LastExitCode -ne 0) {
    throw "'nuget pack' failed for 'FFmpeg.runtime.win-x64.nuspec'"
  }
}
catch {
  Write-Host -Object $_
  Write-Host -Object $_.Exception
  Write-Host -Object $_.ScriptStackTrace
  exit 1
}
