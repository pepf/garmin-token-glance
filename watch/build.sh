#!/usr/bin/env bash
# Usage: ./build.sh        build both Venu 4 sizes
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
    for d in venu445mm venu441mm; do echo "=== $d"; build "$d"; done
fi
