#!/usr/bin/env bash
# An interesting byte is kept and mutated again, which opens the next edge.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build="${BUILD:-build}"
if [[ "$build" = /* ]]; then
    bin="$build"
else
    bin="$root/$build"
fi

fuzzer="$bin/asm-fuzzer"
path_target="$bin/path-target"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf '\x00' > "$tmp/seed.bin"

echo "coverage: a new edge becomes the next mutation base"
set +e
output=$( "$fuzzer" --target "$path_target" --input "$tmp/seed.bin" \
    --output "$tmp/out.bin" --timeout 1000 --iterations 2 )
status=$?
set -e
[[ "$status" -eq 0 ]]
[[ ! -e "$tmp/out.bin" ]]
printf '%s\n' "$output" | grep -Eq '^edges 3$'

echo "coverage: repeated identifiers collapse, and a flood still returns"
printf 'x' > "$tmp/flood.bin"
start=$(date +%s%3N)
set +e
output=$( "$fuzzer" --target "$bin/flood-target" --input "$tmp/flood.bin" \
    --output "$tmp/flood-out.bin" --timeout 1000 --iterations 1 )
status=$?
set -e
end=$(date +%s%3N)
[[ "$status" -eq 0 ]]
[[ $((end - start)) -lt 1500 ]]
printf '%s\n' "$output" | grep -Eq '^edges 2$'

echo "coverage checks passed"
