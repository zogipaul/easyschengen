#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
qa_dir=$(mktemp -d /private/tmp/easyschengen-checks.XXXXXX)
trap 'rm -rf "$qa_dir"' EXIT
for test in CalendarStayContext TravelStatistics SchengenCalculator; do
    xcrun swiftc -O -module-cache-path "$qa_dir/module-cache" \
        EasySchengen/Models/Trip.swift \
        EasySchengen/Models/TravelStatistics.swift \
        EasySchengen/Models/SchengenCalculator.swift \
        "Tests/${test}Tests.swift" -o "$qa_dir/$test"
    "$qa_dir/$test"
done
if [[ "${1:-}" == "--benchmark" ]]; then
    xcrun swiftc -O -module-cache-path "$qa_dir/module-cache" \
        EasySchengen/Models/Trip.swift EasySchengen/Models/SchengenCalculator.swift \
        Tests/SchengenPerformanceBenchmark.swift -o "$qa_dir/benchmark"
    "$qa_dir/benchmark"
fi
