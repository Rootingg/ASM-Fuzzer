#!/usr/bin/env bash
# Campaign against the in-repo demo target only.
# A known fault must be found and replayed. A harmless seed must stay clean.
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
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf 'hello' > "$tmp/safe.bin"
printf 'BRSH' > "$tmp/near.bin"
printf 'CRSH' > "$tmp/oracle.bin"

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

echo "integration: safe input does not fault"
set +e
"$demo" < "$tmp/safe.bin"
safe_status=$?
set -e
[[ "$safe_status" -eq 0 ]]

echo "integration: oracle input faults with SIGSEGV"
set +e
"$demo" < "$tmp/oracle.bin"
oracle_status=$?
set -e
[[ "$oracle_status" -eq 139 ]]

echo "integration: harmless seed is not reported as a crash"
expect_status 0 "$fuzzer" "$demo" "$tmp/safe.bin" "$tmp/false.bin"
[[ ! -e "$tmp/false.bin" ]]

echo "integration: one-bit neighbour of BRSH is discovered"
expect_status 2 "$fuzzer" "$demo" "$tmp/near.bin" "$tmp/found.bin"
[[ -f "$tmp/found.bin" ]]
cmp -s "$tmp/oracle.bin" "$tmp/found.bin"

echo "integration: saved crash replays to SIGSEGV"
set +e
"$demo" < "$tmp/found.bin"
replay_status=$?
set -e
[[ "$replay_status" -eq 139 ]]

echo "integration checks passed"
