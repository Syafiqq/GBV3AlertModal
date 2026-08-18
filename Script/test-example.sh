#!/bin/zsh
# Runs the example-app test suite: project
# `Examples/GBV3AlertModalExample/GBV3AlertModalExample.xcodeproj`, scheme
# `GBV3AlertModalExample` (both `GBV3AlertModalExampleTests` and
# `GBV3AlertModalExampleUITests`).
#
# ~25 MINUTES, vs. seconds for `Script/test-lib.sh`. That asymmetry is exactly why this
# suite keeps getting skipped — it hid a real structural regression for four consecutive
# task gates because nothing forced it to run. Budget the time; do not skip it.
#
# KNOWN FLAKE: this machine's simulator intermittently produces
#   ** TEST FAILED **
# with ZERO tests executed (SpringBoard crash, result-bundle IO fault, boot timeout) —
# not a code failure. `xcrun simctl shutdown all` clears it. This script detects that
# shape (a failing run with no "Test case '...' passed|failed" lines) and retries once
# after shutting the simulators down, so a real code failure and a simulator flake are
# never confused for each other. If it still shows zero executed tests after the retry,
# treat that as an environment problem to fix by hand, NOT as 8 (or however many) failing
# tests — read the actual xcodebuild output before concluding anything failed.
set -o pipefail

SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"

run_tests() {
    xcodebuild test \
        -project Examples/GBV3AlertModalExample/GBV3AlertModalExample.xcodeproj \
        -scheme GBV3AlertModalExample \
        -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}"
}

OUTPUT_FILE=$(mktemp)
trap 'rm -f "$OUTPUT_FILE"' EXIT

run_tests | tee "$OUTPUT_FILE"
STATUS=$?

if [ $STATUS -ne 0 ] && ! grep -qi "Test case '.*' \(passed\|failed\)" "$OUTPUT_FILE"; then
    echo ""
    echo "No test cases executed — this looks like the known simulator flake, not a code"
    echo "failure. Shutting down simulators and retrying once."
    xcrun simctl shutdown all
    run_tests | tee "$OUTPUT_FILE"
    STATUS=$?

    if [ $STATUS -ne 0 ] && ! grep -qi "Test case '.*' \(passed\|failed\)" "$OUTPUT_FILE"; then
        echo ""
        echo "Still zero tests executed after the retry — this is an environment problem" \
            "(simulator/Xcode), not a code failure. Investigate by hand before concluding" \
            "anything actually failed."
    fi
fi

if [ $STATUS -eq 0 ] && ! grep -Eqi "Test case '.*' (passed|failed)|Executed [1-9][0-9]* tests?" "$OUTPUT_FILE"; then
    echo "The example test command succeeded without executing an expected test suite." >&2
    STATUS=1
fi

if [ $STATUS -eq 0 ]; then
    xcodebuild build \
        -project Examples/GBV3AlertModalExample/GBV3AlertModalExample.xcodeproj \
        -scheme GBV3AlertModalSwiftUIExample \
        -destination "generic/platform=iOS Simulator"
fi

exit $STATUS
