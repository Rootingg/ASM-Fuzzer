#!/usr/bin/env bash
# Run the assembled unit binaries. BUILD may be relative to the repo or absolute.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build="${BUILD:-build}"
if [[ "$build" = /* ]]; then
    bin="$build"
else
    bin="$root/$build"
fi

for test_bin in test-mutators test-memory test-signals test-schedule; do
    echo "unit: $test_bin"
    "$bin/$test_bin"
done

echo "unit checks passed"
