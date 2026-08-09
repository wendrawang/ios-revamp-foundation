#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

failure=0

./Scripts/check-swift-style.rb
./Scripts/check-swift-format.sh

# Mencari source Swift dengan ripgrep bila tersedia dan grep bawaan sebagai fallback CI.
search_swift() {
    local pattern="$1"
    shift
    if command -v rg >/dev/null 2>&1; then
        rg -n --glob '*.swift' "$pattern" "$@"
        return
    fi
    find "$@" -type f -name '*.swift' \
        -not -path '*/.build/*' \
        -not -path '*/.derived/*' \
        -not -path '*/.swiftpm/*' \
        -exec grep -H -n -E "$pattern" {} + || true
}

# Mencari dependency path hanya di manifest package tanpa bergantung pada ripgrep.
search_feature_manifests() {
    local pattern="$1"
    if command -v rg >/dev/null 2>&1; then
        rg -n --glob 'Package.swift' "$pattern" Packages/Features
        return
    fi
    find Packages/Features -type f -name 'Package.swift' \
        -not -path '*/.build/*' \
        -not -path '*/.swiftpm/*' \
        -exec grep -H -n -E "$pattern" {} + || true
}

# Memastikan package memiliki deklarasi test yang dapat dieksekusi oleh XCTest atau Swift Testing.
has_executable_tests() {
    local tests_directory="$1"
    if command -v rg >/dev/null 2>&1; then
        rg -l --glob '*.swift' '@Test|XCTestCase' "$tests_directory" >/dev/null
        return
    fi
    local matches
    matches="$(find "$tests_directory" -type f -name '*.swift' \
        -exec grep -l -E '@Test|XCTestCase' {} + || true)"
    [[ -n "$matches" ]]
}

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
    search_swift '^import [A-Za-z0-9]+Feature$' Packages/PlatformKit/Sources

report_matches \
    "Feature implementations must not import other feature implementations." \
    search_swift '^import [A-Za-z0-9]+Feature$' Packages/Features/*/Sources

report_matches \
    "SecureWebKit must remain feature agnostic." \
    search_swift '^import (Authentication|Dashboard|FinancialHub|Transfer|Wealth|Scan|Rewards|More|UpgradeService)Feature$' Packages/SecureWebKit/Sources

report_matches \
    "Routine AnyView routing is forbidden." \
    search_swift '(^|[^[:alnum:]_])AnyView([^[:alnum:]_]|$)' App Packages

navigation_matches="$(search_swift 'NavigationStack\(' App || true)"
navigation_stack_count="$(printf '%s\n' "$navigation_matches" | awk 'NF { count += 1 } END { print count + 0 }')"
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
    if ! has_executable_tests "$feature_directory/Tests"; then
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
    search_feature_manifests '\.package\(path:.*Feature'

while IFS= read -r manifest; do
    package_directory="$(dirname "$manifest")"
    (cd "$package_directory" && swift package dump-package >/dev/null)
done < <(find Packages -name Package.swift -print | sort)

if [[ "$failure" != "0" ]]; then
    exit 1
fi

echo "Architecture checks passed: Swift style, independent domain SPMs, package manifests, dependency imports, and exactly two primary NavigationStacks are valid."
