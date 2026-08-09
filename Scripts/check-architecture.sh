#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

failure=0

./Scripts/check-swift-style.rb
./Scripts/check-swift-format.sh

report_matches() {
    local message="$1"
    shift
    local matches
    matches="$("$@" 2>/dev/null || true)"
    if [[ -n "$matches" ]]; then
        echo "ARCHITECTURE VIOLATION: $message"
        echo "$matches"
        failure=1
    fi
}

report_matches \
    "Core targets must not import feature modules." \
    rg -n '^import [A-Za-z0-9]+Feature$' Packages/PlatformKit/Sources

report_matches \
    "Feature implementations must not import other feature implementations." \
    rg -n '^import [A-Za-z0-9]+Feature$' Packages/Features --glob '**/Sources/**/*.swift'

report_matches \
    "SecureWebKit must remain feature agnostic." \
    rg -n '^import (Authentication|Dashboard|FinancialHub|Transfer|Wealth|Scan|Rewards|More|UpgradeService)Feature$' Packages/SecureWebKit/Sources

report_matches \
    "Routine AnyView routing is forbidden." \
    rg -n '\bAnyView\b' App Packages --glob '*.swift'

navigation_stack_count="$(rg -n 'NavigationStack\(' App --glob '*.swift' | wc -l | tr -d ' ')"
if [[ "$navigation_stack_count" != "2" ]]; then
    echo "ARCHITECTURE VIOLATION: expected exactly 2 primary NavigationStack declarations, found $navigation_stack_count"
    failure=1
fi

for forbidden in CoreStorage BankingPrimitives NavigationKit Common Utils; do
    if find Packages -type d -name "$forbidden" -print -quit | grep -q .; then
        echo "ARCHITECTURE VIOLATION: forbidden speculative/dumping-ground module exists: $forbidden"
        failure=1
    fi
done

feature_package_count=0
while IFS= read -r feature_directory; do
    feature_package_count=$((feature_package_count + 1))
    if [[ ! -f "$feature_directory/Package.swift" ]]; then
        echo "ARCHITECTURE VIOLATION: domain is not an independent Local SPM: $feature_directory"
        failure=1
    fi
    if ! find "$feature_directory/Tests" -type f -name '*.swift' -print0 2>/dev/null \
        | xargs -0 rg -l '@Test|XCTestCase' >/dev/null 2>&1; then
        echo "ARCHITECTURE VIOLATION: domain package has no executable tests: $feature_directory"
        failure=1
    fi
done < <(find Packages/Features -mindepth 1 -maxdepth 1 -type d | sort)

if [[ "$feature_package_count" == "0" ]]; then
    echo "ARCHITECTURE VIOLATION: no independent feature packages found"
    failure=1
fi

report_matches \
    "Feature package manifests must not depend on another feature package." \
    rg -n '\.package\(path:.*Feature' Packages/Features --glob 'Package.swift'

while IFS= read -r manifest; do
    package_directory="$(dirname "$manifest")"
    (cd "$package_directory" && swift package dump-package >/dev/null)
done < <(find Packages -name Package.swift -print | sort)

if [[ "$failure" != "0" ]]; then
    exit 1
fi

echo "Architecture checks passed: Swift style, independent domain SPMs, package manifests, dependency imports, and exactly two primary NavigationStacks are valid."
