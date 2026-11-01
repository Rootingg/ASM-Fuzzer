#!/usr/bin/env bash
# Wall-clock timeout, non-blocking writes, and child reaping.
# Every target here is built from this repository.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build="${BUILD:-build}"
if [[ "$build" = /* ]]; then
    bin="$build"
else
    bin="$root/$build"
fi

fuzzer="$bin/asm-fuzzer"
spin="$bin/spin-target"
stall="$bin/stall-target"
blocked="$bin/block-read-target"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf 'x' > "$tmp/one.bin"
# Larger than the default 64 KiB pipe, so a blocking write would stall the parent.
dd if=/dev/zero of="$tmp/big.bin" bs=100000 count=1 status=none

expect_status() {
    local want="$1"
    shift
    set +e
    timeout 3s "$@"
    local got=$?
    set -e
    if [[ "$got" -ne "$want" ]]; then
        printf 'expected exit %s, got %s for:' "$want" "$got" >&2
        printf ' %q' "$@" >&2
        printf '\n' >&2
        exit 1
    fi
}

assert_gone() {
    local needle="$1"
    if pgrep -f -- "$needle" >/dev/null 2>&1; then
        echo "child still running: $needle" >&2
        pgrep -af -- "$needle" >&2 || true
        exit 1
    fi
}

run_timed() {
    local label="$1"
    shift
    local start end elapsed
    start=$(date +%s%3N)
    expect_status 3 "$@"
    end=$(date +%s%3N)
    elapsed=$((end - start))
    if [[ "$elapsed" -ge 1000 ]]; then
        echo "$label took ${elapsed}ms, wall-clock timeout did not fire first" >&2
        exit 1
    fi
    echo "$label stopped in ${elapsed}ms"
}

echo "timeout: spinning target is killed by the wall clock"
run_timed "spin" "$fuzzer" --target "$spin" --input "$tmp/one.bin" \
    --output "$tmp/spin.bin" --timeout 300 --iterations 1
[[ ! -e "$tmp/spin.bin" ]]
assert_gone "$spin"

echo "timeout: a full pipe does not block the parent"
run_timed "stall" "$fuzzer" --target "$stall" --input "$tmp/big.bin" \
    --output "$tmp/stall.bin" --timeout 300 --iterations 1
[[ ! -e "$tmp/stall.bin" ]]
assert_gone "$stall"

echo "timeout: a target blocked after EOF is killed and reaped"
run_timed "block-read" "$fuzzer" --target "$blocked" --input "$tmp/one.bin" \
    --output "$tmp/block.bin" --timeout 300 --iterations 1
[[ ! -e "$tmp/block.bin" ]]
assert_gone "$blocked"

echo "timeout checks passed"
