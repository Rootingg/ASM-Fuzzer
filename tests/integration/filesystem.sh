#!/usr/bin/env bash
# A hidden root cannot open /etc/passwd. A host fallback still can.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build="${BUILD:-build}"
if [[ "$build" = /* ]]; then
    bin="$build"
else
    bin="$root/$build"
fi

fuzzer="$bin/asm-fuzzer"
target="$bin/fs-target"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf 'x' > "$tmp/seed.bin"

echo "filesystem: the reported view matches what the target can open"
set +e
"$fuzzer" --target "$target" --input "$tmp/seed.bin" \
    --output "$tmp/out.bin" --timeout 1000 --iterations 1 \
    >"$tmp/out" 2>"$tmp/err"
status=$?
set -e
[[ "$status" -eq 0 ]]
grep -Eq '^namespaces (full|partial|none)$' "$tmp/err"
if grep -qx 'filesystem hidden' "$tmp/err"; then
    grep -qx 'fs-blocked' "$tmp/err"
elif grep -qx 'filesystem host' "$tmp/err"; then
    grep -qx 'fs-open' "$tmp/err"
else
    echo "missing filesystem mode" >&2
    cat "$tmp/err" >&2
    exit 1
fi
grep -E '^filesystem (hidden|host)$' "$tmp/err"

echo "filesystem checks passed"
