#!/usr/bin/env bash
# Several seeds, minimized crashes, and an execution rate.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build="${BUILD:-build}"
if [[ "$build" = /* ]]; then
    bin="$build"
else
    bin="$root/$build"
fi

fuzzer="$bin/asm-fuzzer"
multi="$bin/multi-target"
shrink="$bin/shrink-target"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/seeds" "$tmp/out"
printf '\x03' > "$tmp/seeds/a.bin"
printf '\x00' > "$tmp/seeds/b.bin"
printf '\x00\x11\xA5\x22\x33' > "$tmp/padded.bin"
printf '\xA5' > "$tmp/minimal.bin"
printf '\x02' > "$tmp/segv.bin"
printf '\x01' > "$tmp/ill.bin"

echo "corpus: every sorted seed is fuzzed"
set +e
output=$( "$fuzzer" --target "$multi" --input "$tmp/seeds" \
    --output "$tmp/out" --timeout 1000 --iterations 1 --no-stop-on-crash )
status=$?
set -e
[[ "$status" -eq 2 ]]
cmp -s "$tmp/segv.bin" "$tmp/out/sig11-0"
cmp -s "$tmp/ill.bin" "$tmp/out/sig4-0"
printf '%s\n' "$output" | grep -Eq '^execs [0-9]+$'
printf '%s\n' "$output" | grep -Eq '^rate [0-9]+$'

echo "corpus: a crashing input shrinks to the byte that faults"
expect_file=$tmp/minimal.bin
set +e
"$fuzzer" --target "$shrink" --input "$tmp/padded.bin" \
    --output "$tmp/shrunk.bin" --timeout 1000 --iterations 1 >/dev/null
status=$?
set -e
[[ "$status" -eq 2 ]]
cmp -s "$expect_file" "$tmp/shrunk.bin"

echo "corpus checks passed"
