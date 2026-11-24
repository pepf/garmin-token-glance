#!/usr/bin/env bash
# Usage: ./build.sh        build all devices
#        ./build.sh run [device]   build one and launch it in the running simulator
set -euo pipefail
SDK="$(tr -d '\n' < "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")"
cd "$(dirname "$0")"
mkdir -p bin

build() { "$SDK/bin/monkeyc" -f monkey.jungle -d "$1" -o "bin/claude-usage-$1.prg" -y developer_key -l 3 -w; }

if [[ "${1:-}" == run ]]; then
    d="${2:-venu445mm}"
    build "$d"
    "$SDK/bin/monkeydo" "bin/claude-usage-$d.prg" "$d"
else
    for d in venu445mm venu441mm instinct3solar45mm fenix843mm fenix847mm fenix8pro47mm fenix8solar47mm fenix8solar51mm fenix943mm fenix947mm fenix9pro43mm fenix9pro47mm fenix9pro51mm fenix9prosolar47mm fenix9prosolar51mm; do echo "=== $d"; build "$d"; done
fi
