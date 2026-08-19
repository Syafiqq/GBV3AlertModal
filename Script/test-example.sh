#!/bin/zsh
# Runs deterministic example contracts, one UI smoke test, and the independent SwiftUI example
# build as separate stages. Visual comparison is performed manually in the gallery.
set -eu
set -o pipefail

SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
REQUESTED_STAGE="${EXAMPLE_TEST_STAGE:-all}"
PROJECT="Examples/GBV3AlertModalExample/GBV3AlertModalExample.xcodeproj"
SCHEME="GBV3AlertModalExample"
DERIVED_DATA="${EXAMPLE_DERIVED_DATA:-/tmp/gbv3-alert-modal-example-derived}"
OUTPUT_DIRECTORY=$(mktemp -d /tmp/gbv3-example-tests.XXXXXX)
SIMULATOR_UDID=""
LAST_STATUS=0

cleanup() {
    rm -rf "$OUTPUT_DIRECTORY"
}
trap cleanup EXIT INT TERM

resolve_simulator() {
    SIMULATOR_UDID=$(xcrun simctl list devices available -j | jq -r --arg name "$SIMULATOR_NAME" \
        '[.devices[][] | select(.name == $name)][0].udid // empty')
    if [ -z "$SIMULATOR_UDID" ]; then
        print -u2 "No available simulator named '$SIMULATOR_NAME'."
        return 1
    fi
}

recover_simulator() {
    print "Restarting only $SIMULATOR_NAME ($SIMULATOR_UDID) and waiting for boot readiness."
    xcrun simctl shutdown "$SIMULATOR_UDID" >/dev/null 2>&1 || true
    xcrun simctl boot "$SIMULATOR_UDID" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$SIMULATOR_UDID" -b
}

run_with_timeout() {
    local timeout_seconds=$1
    local output_file=$2
    shift 2

    "$@" > "$output_file" 2>&1 &
    local command_pid=$!
    local started_at=$SECONDS

    while kill -0 "$command_pid" >/dev/null 2>&1; do
        if (( SECONDS - started_at >= timeout_seconds )); then
            print -u2 "Timed out after ${timeout_seconds}s: $*"
            kill -TERM "$command_pid" >/dev/null 2>&1 || true
            wait "$command_pid" >/dev/null 2>&1 || true
            LAST_STATUS=124
            return
        fi
        sleep 1
    done

    if wait "$command_pid"; then
        LAST_STATUS=0
    else
        LAST_STATUS=$?
    fi
}

is_infrastructure_failure() {
    local output_file=$1
    if [ $LAST_STATUS -eq 124 ]; then
        return 0
    fi
    if rg -qi \
        'DebuggerVersionStore|no debugger version|Failed to boot|SpringBoard|Lost connection|Early unexpected exit|Failed to launch|Simulator device failed' \
        "$output_file" && ! rg -qi "Test case '.*' failed" "$output_file"; then
        return 0
    fi
    return 1
}

assert_stage_executed() {
    local stage=$1
    local output_file=$2
    case "$stage" in
        contracts)
            rg -q "backendsExposeTheSameSeventyUniqueEntries.*passed" "$output_file" &&
                rg -q "testEveryCatalogEntryBuildsAContainer.*passed" "$output_file"
            ;;
        ui-smoke)
            rg -q "testApplicationLaunches.*passed" "$output_file"
            ;;
        *)
            return 1
            ;;
    esac
}

run_test_stage() {
    local stage=$1
    local timeout_seconds=$2
    shift 2
    local output_file="$OUTPUT_DIRECTORY/${stage}.log"
    local result_bundle="$OUTPUT_DIRECTORY/${stage}.xcresult"
    local attempt=1

    while [ $attempt -le 2 ]; do
        print "Running example stage '$stage' (attempt $attempt/2)."
        rm -rf "$result_bundle"
        run_with_timeout "$timeout_seconds" "$output_file" \
            xcodebuild test \
                -project "$PROJECT" \
                -scheme "$SCHEME" \
                -destination "platform=iOS Simulator,id=${SIMULATOR_UDID}" \
                -derivedDataPath "$DERIVED_DATA" \
                -resultBundlePath "$result_bundle" \
                -parallel-testing-enabled NO \
                "$@"

        if [ $LAST_STATUS -eq 0 ] && assert_stage_executed "$stage" "$output_file"; then
            print "Example stage '$stage' passed."
            return
        fi

        if [ $attempt -eq 1 ] && is_infrastructure_failure "$output_file"; then
            recover_simulator
            attempt=2
            continue
        fi

        if [ $LAST_STATUS -eq 0 ]; then
            print -u2 "Stage '$stage' returned success without its expected tests."
        else
            print -u2 "Stage '$stage' failed with status $LAST_STATUS."
        fi
        tail -120 "$output_file" >&2
        if [ -d "$result_bundle" ]; then
            print -u2 "Structured test failures:"
            xcrun xcresulttool get test-results summary --path "$result_bundle" 2>/dev/null |
                jq -r '.testFailures[]?.failureText' >&2 || true
        fi
        return 1
    done
}

if [[ "$REQUESTED_STAGE" == all || "$REQUESTED_STAGE" == contracts ]]; then
    resolve_simulator
    run_test_stage contracts 300 \
        -only-testing:GBV3AlertModalExampleTests/AlertResolutionTests \
        -only-testing:GBV3AlertModalExampleTests/CatalogContractTests \
        -only-testing:GBV3AlertModalExampleTests/DialogCatalogSmokeTests \
        -only-testing:GBV3AlertModalExampleTests/GenerationGuardTests
fi

if [[ "$REQUESTED_STAGE" == all || "$REQUESTED_STAGE" == ui-smoke ]]; then
    [ -n "$SIMULATOR_UDID" ] || resolve_simulator
    run_test_stage ui-smoke 180 \
        -only-testing:GBV3AlertModalExampleUITests/GBV3AlertModalExampleUITests/testApplicationLaunches
fi

if [[ "$REQUESTED_STAGE" == all || "$REQUESTED_STAGE" == swiftui-build ]]; then
    print "Building the standalone SwiftUI-only example."
    BUILD_LOG="$OUTPUT_DIRECTORY/swiftui-build.log"
    run_with_timeout 300 "$BUILD_LOG" \
        xcodebuild build \
            -project "$PROJECT" \
            -scheme GBV3AlertModalSwiftUIExample \
            -destination 'generic/platform=iOS Simulator' \
            -derivedDataPath "$DERIVED_DATA/swiftui" \
            CODE_SIGNING_ALLOWED=NO
    if [ $LAST_STATUS -ne 0 ]; then
        print -u2 "SwiftUI-only example build failed with status $LAST_STATUS."
        tail -120 "$BUILD_LOG" >&2
        exit $LAST_STATUS
    fi
fi

if [[ "$REQUESTED_STAGE" != all && "$REQUESTED_STAGE" != contracts &&
      "$REQUESTED_STAGE" != ui-smoke && "$REQUESTED_STAGE" != swiftui-build ]]; then
    print -u2 "Unknown EXAMPLE_TEST_STAGE '$REQUESTED_STAGE'."
    print -u2 "Expected: all, contracts, ui-smoke, or swiftui-build."
    exit 2
fi

print "Requested example stage '$REQUESTED_STAGE' passed."
