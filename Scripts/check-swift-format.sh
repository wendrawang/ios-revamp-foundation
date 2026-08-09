#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

find App AppTests AppUITests Packages -type f -name '*.swift' \
    -not -path '*/.derived/*' \
    -not -path '*/.build/*' \
    -not -path '*/.swiftpm/*' \
    -print0 \
    | xargs -0 xcrun swift-format lint \
        --strict \
        --parallel \
        --configuration .swift-format

echo "Apple swift-format checks passed."
