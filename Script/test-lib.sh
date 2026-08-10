#!/bin/zsh
# Runs the library test suite (scheme `GBV3AlertModal`, `Package.swift`'s
# `GBV3AlertModalTests` target). Seconds, not minutes — safe to run on every change.
#
# See `Script/test-example.sh` for the example-app suite and why it is a SEPARATE script
# rather than folded into this one.
set -e
set -o pipefail

SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"

xcodebuild test \
    -scheme GBV3AlertModal \
    -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}"
