#!/bin/bash
# Runs the EasySchengenTests target on a simulator; --benchmark also times the calculator.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
destination="${QA_DESTINATION:-platform=iOS Simulator,name=iPhone 17}"
qa_dir=$(mktemp -d /private/tmp/easyschengen-checks.XXXXXX)
trap 'rm -rf "$qa_dir"' EXIT

xcodebuild test \
    -project EasySchengen.xcodeproj \
    -scheme EasySchengen \
    -destination "$destination" \
    -derivedDataPath "$qa_dir/derived-data" \
    -quiet

if [[ "${1:-}" == "--benchmark" ]]; then
    xcrun swiftc -O -module-cache-path "$qa_dir/module-cache" \
        EasySchengen/Models/Trip.swift EasySchengen/Models/SchengenCalculator.swift \
        Tests/SchengenPerformanceBenchmark.swift -o "$qa_dir/benchmark"
    "$qa_dir/benchmark"
fi
