#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

device_line="$(xcrun simctl list devices available | awk '/iPhone/ && $0 !~ /unavailable/ { print; exit }')"
device_id="$(sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/' <<<"$device_line")"

if [[ ! "$device_id" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
    echo "No available iPhone Simulator was found." >&2
    exit 1
fi

echo "platform=iOS Simulator,id=$device_id"
