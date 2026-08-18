#!/bin/zsh
# Runs each backend-owned package test suite independently. A green build that selected no tests is
# a failure: it does not prove the corresponding ownership boundary.
set -e
set -o pipefail

SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SUITES=(Core SwiftUI UIKit Migration Architecture)

for owner in "${SUITES[@]}"; do
    target="GBV3AlertModal${owner}Tests"
    output_file=$(mktemp)
    trap 'rm -f "$output_file"' EXIT

    scheme="GBV3AlertModal${owner}"
    if [ "$owner" = Architecture ]; then
        scheme="GBV3AlertModal-Package"
    fi

    xcodebuild test \
        -scheme "$scheme" \
        -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
        -only-testing:"${target}" | tee "$output_file"

    if ! grep -Eq "Executed [1-9][0-9]* tests?|Test Suite .+ passed" "$output_file"; then
        echo "Expected ${target} to execute at least one test, but no test execution was reported." >&2
        exit 1
    fi
    rm -f "$output_file"
    trap - EXIT
done

# Compatibility is intentionally a separate compile/test witness for the umbrella import.
output_file=$(mktemp)
trap 'rm -f "$output_file"' EXIT
xcodebuild test \
    -scheme GBV3AlertModal \
    -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
    -only-testing:GBV3AlertModalCompatibilityTests | tee "$output_file"
grep -Eq "Executed [1-9][0-9]* tests?|Test Suite .+ passed" "$output_file"
