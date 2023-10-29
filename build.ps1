$ErrorActionPreference = 'Stop'

Set-Location -LiteralPath $PSScriptRoot

# Note: In order for aom to build on Windows x86 we need to increase
# virtual memory and limit the concurrency, otherwise the aom build
# will fail due to the compiler running out of heap space.
#
# See the following issues:
# https://github.com/microsoft/vcpkg/issues/28389
# https://github.com/microsoft/vcpkg/issues/31823
$env:VCPKG_MAX_CONCURRENCY = '1'

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
