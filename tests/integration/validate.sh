#!/usr/bin/env bash
# Release gate. Checks the whole fuzzer, not one feature at a time.
# Targets are built from this repository.
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
path_target="$bin/path-target"
spin="$bin/spin-target"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf 'BRSH' > "$tmp/near.bin"
printf 'CRSH' > "$tmp/oracle.bin"
printf 'hello' > "$tmp/blind.bin"
printf '\x00' > "$tmp/path.bin"
printf 'x' > "$tmp/one.bin"

field() {
    local name="$1"
    local file="$2"
    local value
    value=$(sed -n "s/^${name} //p" "$file" | head -n 1)
    if [[ -z "$value" ]]; then
        echo "missing ${name} in fuzzer output" >&2
        cat "$file" >&2
        exit 1
    fi
    printf '%s' "$value"
}

assert_gone() {
    local needle="$1"
    if pgrep -f -- "$needle" >/dev/null 2>&1; then
        echo "process still running: $needle" >&2
        pgrep -af -- "$needle" >&2 || true
        exit 1
    fi
}

echo "evaluation: a discovered crash replays as SIGSEGV"
set +e
"$fuzzer" --target "$demo" --input "$tmp/near.bin" \
    --output "$tmp/found.bin" --timeout 1000 --iterations 64 \
    >"$tmp/replay.out" 2>"$tmp/replay.err"
status=$?
set -e
[[ "$status" -eq 2 ]]
cmp -s "$tmp/oracle.bin" "$tmp/found.bin"
set +e
"$demo" < "$tmp/found.bin"
replay=$?
set -e
[[ "$replay" -eq 139 ]]
assert_gone "$demo"
assert_gone "$fuzzer"

echo "evaluation: instrumented edges beat a blind target"
set +e
"$fuzzer" --target "$path_target" --input "$tmp/path.bin" \
    --output "$tmp/path-out.bin" --timeout 1000 --iterations 8 \
    >"$tmp/path.out" 2>"$tmp/path.err"
status=$?
set -e
[[ "$status" -eq 0 ]]
path_edges=$(field edges "$tmp/path.out")
set +e
"$fuzzer" --target "$demo" --input "$tmp/blind.bin" \
    --output "$tmp/blind-out.bin" --timeout 1000 --iterations 8 \
    >"$tmp/blind.out" 2>"$tmp/blind.err"
status=$?
set -e
[[ "$status" -eq 0 ]]
blind_edges=$(field edges "$tmp/blind.out")
[[ "$path_edges" -ge 3 ]]
[[ "$blind_edges" -eq 0 ]]
[[ "$path_edges" -gt "$blind_edges" ]]

echo "evaluation: 256 executions stay fast, and the sandbox mode is explicit"
start=$(date +%s%3N)
"$fuzzer" --target "$demo" --input "$tmp/blind.bin" \
    --output "$tmp/long-out.bin" --timeout 1000 --iterations 256 \
    >"$tmp/long.out" 2>"$tmp/long.err" &
pid=$!
rss=0
while kill -0 "$pid" 2>/dev/null; do
    hwm=$(awk '/^VmHWM:/ {print $2}' "/proc/${pid}/status" 2>/dev/null || true)
    if [[ -n "${hwm:-}" && "$hwm" -gt "$rss" ]]; then
        rss=$hwm
    fi
    sleep 0.02
done
set +e
wait "$pid"
status=$?
set -e
end=$(date +%s%3N)
elapsed=$((end - start))
[[ "$status" -eq 0 ]]
[[ "$elapsed" -lt 15000 ]]
[[ "$rss" -gt 0 ]]
[[ "$rss" -lt 65536 ]]
execs=$(field execs "$tmp/long.out")
rate=$(field rate "$tmp/long.out")
[[ "$execs" -eq 256 ]]
[[ "$rate" -ge 50 ]]
grep -Eq '^namespaces (full|partial|none)$' "$tmp/long.err"
grep -Eq '^filesystem (hidden|host)$' "$tmp/long.err"
grep -Eq '^seccomp (on|none)$' "$tmp/long.err"
ns=$(grep -E '^namespaces (full|partial|none)$' "$tmp/long.err")
fs=$(grep -E '^filesystem (hidden|host)$' "$tmp/long.err")
sc=$(grep -E '^seccomp (on|none)$' "$tmp/long.err")

echo "evaluation: a timed-out child is not left behind"
set +e
"$fuzzer" --target "$spin" --input "$tmp/one.bin" \
    --output "$tmp/spin.bin" --timeout 300 --iterations 1 \
    >"$tmp/spin.out" 2>"$tmp/spin.err"
status=$?
set -e
[[ "$status" -eq 3 ]]
[[ ! -e "$tmp/spin.bin" ]]
assert_gone "$spin"
assert_gone "$fuzzer"

echo "evaluation summary: execs ${execs} rate ${rate} elapsed ${elapsed}ms path-edges ${path_edges} blind-edges ${blind_edges} rss-kb ${rss}"
echo "evaluation summary: ${ns}; ${fs}; ${sc}"
echo "evaluation checks passed"
