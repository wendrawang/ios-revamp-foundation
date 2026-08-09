#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
    echo "Usage: $0 <result.xcresult> [minimum-app-coverage-percent]" >&2
    exit 2
fi

result_bundle="$1"
minimum_coverage="${2:-75}"

if [[ ! -d "$result_bundle" ]]; then
    echo "Coverage result bundle does not exist: $result_bundle" >&2
    exit 2
fi

coverage_report="$(xcrun xccov view --report --only-targets "$result_bundle")"
echo "$coverage_report"

app_coverage="$(awk '$2 == "IOSRevampFoundation.app" { value=$4; sub(/%.*/, "", value); print value; exit }' <<<"$coverage_report")"
if [[ -z "$app_coverage" ]]; then
    echo "Unable to find IOSRevampFoundation.app coverage in $result_bundle" >&2
    exit 1
fi

if ! awk -v actual="$app_coverage" -v minimum="$minimum_coverage" 'BEGIN { exit !(actual + 0 >= minimum + 0) }'; then
    echo "COVERAGE FAILURE: app coverage ${app_coverage}% is below ${minimum_coverage}%" >&2
    exit 1
fi

echo "Coverage gate passed: IOSRevampFoundation.app ${app_coverage}% >= ${minimum_coverage}%"
