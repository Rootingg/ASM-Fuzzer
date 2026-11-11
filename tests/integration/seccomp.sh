#!/usr/bin/env bash
# An allowed syscall still exits clean. socket is killed when the filter is installed.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build="${BUILD:-build}"
if [[ "$build" = /* ]]; then
    bin="$build"
else
    bin="$root/$build"
fi

fuzzer="$bin/asm-fuzzer"
alive="$bin/sec-target"
denied="$bin/sec-deny-target"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf 'x' > "$tmp/seed.bin"

echo "seccomp: an allowed program still finishes"
set +e
"$fuzzer" --target "$alive" --input "$tmp/seed.bin" \
    --output "$tmp/out.bin" --timeout 1000 --iterations 1 \
    >"$tmp/ok.out" 2>"$tmp/ok.err"
status=$?
set -e
[[ "$status" -eq 0 ]]
grep -Eq '^seccomp (on|none)$' "$tmp/ok.err"
grep -qx 'seccomp-alive' "$tmp/ok.err"
mode=$(grep -E '^seccomp (on|none)$' "$tmp/ok.err")

echo "seccomp: socket matches the reported mode"
set +e
"$fuzzer" --target "$denied" --input "$tmp/seed.bin" \
    --output "$tmp/bad-out" --timeout 1000 --iterations 1 \
    >"$tmp/bad.out" 2>"$tmp/bad.err"
status=$?
set -e
if [[ "$mode" == "seccomp on" ]]; then
    [[ "$status" -eq 2 ]]
    grep -qx 'crash' "$tmp/bad.out"
    if grep -qx 'seccomp-open' "$tmp/bad.err"; then
        echo "socket returned under an active filter" >&2
        exit 1
    fi
else
    [[ "$status" -eq 0 ]]
    grep -qx 'seccomp-open' "$tmp/bad.err"
fi

echo "seccomp checks passed"
