#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc Sources/MovementSchedule.swift Tests/main.swift -o "$test_dir/schedule-tests"
"$test_dir/schedule-tests"
