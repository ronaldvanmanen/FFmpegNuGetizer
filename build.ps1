$ErrorActionPreference = 'Stop'

Set-Location -LiteralPath $PSScriptRoot

$env:VCPKG_DISABLE_METRICS = 1
.\vcpkg\bootstrap-vcpkg.bat -disableMetrics
if ($LastExitCode -ne 0) {
    exit $LASTEXITCODE
}

$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'

dotnet tool restore
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

dotnet cake -- @args
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
