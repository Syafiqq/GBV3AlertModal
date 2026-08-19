#!/bin/zsh
# Authoritative deletion proof for the Core + SwiftUI product slice.
set -eu
set -o pipefail

repo_root=${0:A:h:h}
fixture="$repo_root/Library/GBV3AlertModal/Tests/Architecture/SwiftUIOnlyPackage.swift.fixture"
proof_root=$(mktemp -d /tmp/gbv3-swiftui-independence.XXXXXX)
derived_data="$proof_root/DerivedData"
describe_log="$proof_root/package-description.json"
graph_names="$proof_root/package-graph-names.txt"
package_log="$proof_root/package-build.log"
example_log="$proof_root/example-build.log"

cleanup() {
    rm -rf "$proof_root"
}
trap cleanup EXIT INT TERM

rsync -a \
    --exclude .git \
    --exclude .build \
    --exclude DerivedData \
    "$repo_root/" "$proof_root/checkout/"

checkout="$proof_root/checkout"
cp "$fixture" "$checkout/Package.swift"

# Model the future deletion, rather than merely relying on target selection.
rm -rf \
    "$checkout/Library/GBV3AlertModal/Sources/GBV3AlertModal" \
    "$checkout/Library/GBV3AlertModal/Sources/GBV3AlertModalUIKit" \
    "$checkout/Library/GBV3AlertModal/Sources/GBV3AlertModalMigration" \
    "$checkout/Library/GBV3AlertModal/Tests/GBV3AlertModalUIKitTests" \
    "$checkout/Library/GBV3AlertModal/Tests/GBV3AlertModalMigrationTests" \
    "$checkout/Library/GBV3AlertModal/Tests/GBV3AlertModalCompatibilityTests"

cd "$checkout"
swift package describe --type json > "$describe_log"

assert_graph_clean() {
    local description=$1
    jq -r \
        '.products[].name, .targets[].name, .targets[]?.target_dependencies[]?, .targets[]?.product_dependencies[]?, (.dependencies[]?.identity // empty)' \
        "$description" > "$graph_names"
    ! rg -q '^(SnapKit|snapkit|GBV3AlertModalUIKit|GBV3AlertModalMigration|GBV3AlertModal)$' \
        "$graph_names"
}

if ! assert_graph_clean "$describe_log"; then
    print -u2 "Forbidden product, target, or dependency appeared in the SwiftUI-only package graph."
    exit 1
fi

# The gate itself must reject a temporary SwiftUI -> UIKit dependency leak.
cp Package.swift "$proof_root/Package.swift.clean"
sed 's/dependencies: \["GBV3AlertModalCore"\]/dependencies: ["GBV3AlertModalCore", "GBV3AlertModalUIKit"]/' \
    Package.swift > "$proof_root/Package.swift.probe"
cp "$proof_root/Package.swift.probe" Package.swift
if ! swift package describe --type json > "$proof_root/probe-description.json" 2>/dev/null; then
    : # A manifest validation failure is also a successful rejection.
elif assert_graph_clean "$proof_root/probe-description.json"; then
    print -u2 "The boundary gate accepted the deliberate SwiftUI-to-UIKit dependency probe."
    exit 1
fi
cp "$proof_root/Package.swift.clean" Package.swift
assert_graph_clean "$describe_log"

if ! xcodebuild build-for-testing \
    -scheme GBV3AlertModal-Package \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO > "$package_log" 2>&1; then
    tail -100 "$package_log" >&2
    exit 1
fi

if ! xcodebuild test-without-building \
    -scheme GBV3AlertModal-Package \
    -destination "platform=iOS Simulator,name=${SIMULATOR_NAME:-iPhone 17}" \
    -derivedDataPath "$derived_data" \
    -only-testing:GBV3AlertModalCoreTests \
    -only-testing:GBV3AlertModalSwiftUITests >> "$package_log" 2>&1; then
    tail -100 "$package_log" >&2
    exit 1
fi

if ! rg -q 'Executed [1-9][0-9]* tests?|Test Suite .+ passed' "$package_log"; then
    print -u2 "Core and SwiftUI compiled, but no tests were reported as executed."
    exit 1
fi

if ! xcodebuild build \
    -project Examples/GBV3AlertModalExample/GBV3AlertModalExample.xcodeproj \
    -scheme GBV3AlertModalSwiftUIExample \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$derived_data/example" \
    CODE_SIGNING_ALLOWED=NO > "$example_log" 2>&1; then
    tail -100 "$example_log" >&2
    exit 1
fi

if rg -q "Target '(SnapKit|GBV3AlertModalUIKit|GBV3AlertModalMigration|GBV3AlertModal)'" \
    "$package_log" "$example_log"; then
    print -u2 "A forbidden target participated in the SwiftUI-only build."
    exit 1
fi

if rg -q 'import (UIKit|GBV3AlertModalUIKit|GBV3AlertModalMigration|GBV3AlertModal)$' \
    Library/GBV3AlertModal/Sources/GBV3AlertModalCore \
    Library/GBV3AlertModal/Sources/GBV3AlertModalSwiftUI; then
    print -u2 "A forbidden import remains in Core or SwiftUI production sources."
    exit 1
fi

print "SwiftUI independence proof succeeded."
print "Package graph nodes:"
sort -u "$graph_names"
print "Core and SwiftUI tests executed; GBV3AlertModalSwiftUIExample built."
