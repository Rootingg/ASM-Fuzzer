#!/usr/bin/env bash
# The executed target must observe no_new_privs, empty capabilities,
# and no inherited descriptor above the coverage pipe.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build="${BUILD:-build}"
if [[ "$build" = /* ]]; then
    bin="$build"
else
    bin="$root/$build"
fi

fuzzer="$bin/asm-fuzzer"
priv="$bin/priv-target"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf 'x' > "$tmp/seed.bin"

echo "privilege: child runs with no_new_privs and without extra descriptors"
set +e
"$fuzzer" --target "$priv" --input "$tmp/seed.bin" \
    --output "$tmp/out.bin" --timeout 1000 --iterations 1 >/dev/null
status=$?
set -e
[[ "$status" -eq 0 ]]
[[ ! -e "$tmp/out.bin" ]]

echo "privilege checks passed"
