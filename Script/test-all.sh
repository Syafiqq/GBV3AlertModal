#!/bin/zsh
# Runs both test suites: the library (seconds) and the example app (~25 minutes — see
# `Script/test-example.sh` for why that number matters). Mirrors `Script/lint-all.sh`.
Script/test-lib.sh
Script/test-example.sh
