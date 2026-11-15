#!/usr/bin/env bash
# Mutators in the campaign, reproducible seeds, and one saved input per signal.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build="${BUILD:-build}"
if [[ "$build" = /* ]]; then
    bin="$build"
else
    bin="$root/$build"
fi

fuzzer="$bin/asm-fuzzer"
demo="$bin/demo-target"
multi="$bin/multi-target"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf 'AAAA' > "$tmp/wide.bin"
printf '\x00' > "$tmp/zero.bin"

expect_status() {
    local want="$1"
    shift
    set +e
    "$@"
    local got=$?
    set -e
    if [[ "$got" -ne "$want" ]]; then
        printf 'expected exit %s, got %s for:' "$want" "$got" >&2
        printf ' %q' "$@" >&2
        printf '\n' >&2
        exit 1
    fi
}

echo "mutations: iterations continue past the bit neighbourhood"
expect_status 0 "$fuzzer" --target "$demo" --input "$tmp/wide.bin" \
    --output "$tmp/none.bin" --timeout 1000 --iterations 100
[[ ! -e "$tmp/none.bin" ]]

echo "mutations: distinct signals are saved once each"
mkdir -p "$tmp/crashes"
expect_status 2 "$fuzzer" --target "$multi" --input "$tmp/zero.bin" \
    --output "$tmp/crashes" --timeout 1000 --iterations 12 --no-stop-on-crash
[[ -f "$tmp/crashes/sig4-0" ]]
[[ -f "$tmp/crashes/sig11-1" ]]
[[ ! -e "$tmp/crashes/sig4-9" ]]
count=$(find "$tmp/crashes" -type f | wc -l)
[[ "$count" -eq 2 ]]
printf '\x01' > "$tmp/ill.bin"
printf '\x02' > "$tmp/segv.bin"
cmp -s "$tmp/ill.bin" "$tmp/crashes/sig4-0"
cmp -s "$tmp/segv.bin" "$tmp/crashes/sig11-1"

echo "mutations: the same seed reproduces the crash input"
mkdir -p "$tmp/a" "$tmp/b"
expect_status 2 "$fuzzer" --target "$multi" --input "$tmp/zero.bin" \
    --output "$tmp/a" --timeout 1000 --iterations 1 --seed 1 --no-stop-on-crash
expect_status 2 "$fuzzer" --target "$multi" --input "$tmp/zero.bin" \
    --output "$tmp/b" --timeout 1000 --iterations 1 --seed 1 --no-stop-on-crash
cmp -s "$tmp/a/sig11-0" "$tmp/b/sig11-0"
cmp -s "$tmp/segv.bin" "$tmp/a/sig11-0"

echo "mutation checks passed"
