#!/usr/bin/env bash
set -euox pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1

dotnet tool restore
LAST_EXITCODE=$?
if [ "$LAST_EXITCODE" != 0 ]; then
    return "$LAST_EXITCODE"
fi

dotnet cake "$@"
LAST_EXITCODE=$?
if [ "$LAST_EXITCODE" != 0 ]; then
    return "$LAST_EXITCODE"
fi
