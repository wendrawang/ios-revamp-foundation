#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

destination="${SIMULATOR_DESTINATION:-$(./Scripts/resolve-simulator-destination.sh)}"
quality_root="$repo_root/.derived/quality-gates"
minimum_coverage="${MINIMUM_APP_COVERAGE:-75}"

echo "Using destination: $destination"
./Scripts/check-architecture.sh

package_matrix=(
    "Packages/PlatformKit|PlatformKit-Package|platform"
    "Packages/DesignSystem|DesignSystem|design-system"
    "Packages/SecureWebKit|SecureWebKit|secure-web"
    "Packages/Features/AuthenticationFeature|AuthenticationFeature|authentication"
    "Packages/Features/DashboardFeature|DashboardFeature|dashboard"
    "Packages/Features/FinancialHubFeature|FinancialHubFeature|financial-hub"
    "Packages/Features/TransferFeature|TransferFeature|transfer"
    "Packages/Features/WealthFeature|WealthFeature|wealth"
    "Packages/Features/ScanFeature|ScanFeature|scan"
    "Packages/Features/RewardsFeature|RewardsFeature|rewards"
    "Packages/Features/MoreFeature|MoreFeature|more"
    "Packages/Features/UpgradeServiceFeature|UpgradeServiceFeature|upgrade-service"
)

for item in "${package_matrix[@]}"; do
    IFS='|' read -r package_directory scheme label <<<"$item"
    echo "Testing package: $label"
    (
        cd "$package_directory"
        xcodebuild \
            -scheme "$scheme" \
            -destination "$destination" \
            -derivedDataPath "$quality_root/packages/$label" \
            -enableCodeCoverage YES \
            test -quiet
    )
done

xcodebuild \
    -resolvePackageDependencies \
    -project IOSRevampFoundation.xcodeproj \
    -scheme IOSRevampFoundation \
    -clonedSourcePackagesDirPath "$quality_root/source-packages"

xcodebuild \
    -project IOSRevampFoundation.xcodeproj \
    -scheme IOSRevampFoundation \
    -configuration Debug \
    -destination "$destination" \
    -derivedDataPath "$quality_root/app" \
    build -quiet

xcodebuild \
    -project IOSRevampFoundation.xcodeproj \
    -scheme IOSRevampFoundation \
    -destination "$destination" \
    -derivedDataPath "$quality_root/app" \
    -parallel-testing-enabled NO \
    -enableCodeCoverage YES \
    test -quiet

result_bundle="$(find "$quality_root/app/Logs/Test" -maxdepth 1 -name '*.xcresult' -type d -print | sort | tail -n 1)"
./Scripts/check-coverage.sh "$result_bundle" "$minimum_coverage" \
    | tee "$quality_root/coverage-summary.txt"

echo "All architecture, package, build, app, UI, performance, and coverage gates passed."
