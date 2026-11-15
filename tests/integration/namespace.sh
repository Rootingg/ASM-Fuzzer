#!/usr/bin/env bash
# Namespace setup is explicit: full isolation has PID 1, otherwise the mode says none or partial.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build="${BUILD:-build}"
if [[ "$build" = /* ]]; then
    bin="$build"
else
    bin="$root/$build"
fi

fuzzer="$bin/asm-fuzzer"
target="$bin/ns-target"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf 'x' > "$tmp/seed.bin"

echo "namespace: the reported mode matches the PID the target observes"
set +e
"$fuzzer" --target "$target" --input "$tmp/seed.bin" \
    --output "$tmp/out.bin" --timeout 1000 --iterations 1 \
    >"$tmp/out" 2>"$tmp/err"
status=$?
set -e
[[ "$status" -eq 0 ]]
mode=$(grep -E '^namespaces (full|partial|none)$' "$tmp/err")
pid=$(sed -n 's/^observed-pid //p' "$tmp/err")
[[ -n "$mode" ]]
[[ -n "$pid" ]]
case "$mode" in
    "namespaces full")
        [[ "$pid" -eq 1 ]]
        ;;
    "namespaces none")
        [[ "$pid" -ne 1 ]]
        ;;
    "namespaces partial")
        ;;
esac
echo "$mode observed-pid $pid"

echo "namespace checks passed"
