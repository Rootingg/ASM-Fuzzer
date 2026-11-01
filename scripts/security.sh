#!/usr/bin/env bash
# Static checks for secrets and workflow permissions. This script does not execute targets.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
fail=0

note() {
    printf 'security: %s\n' "$1" >&2
    fail=1
}

key_pattern="$(printf '%s%s%s' '-----BEGIN ' '[A-Z0-9 ]*' 'PRIVATE KEY-----')"
if grep -R -n -E -e "$key_pattern" \
    --exclude-dir=.git \
    --exclude-dir=build \
    --exclude='security.sh' \
    .; then
    note "private key material found"
fi

shell_pattern="$(printf '%s' 'curl[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba)?sh')"
if grep -R -n -E -e "$shell_pattern" scripts tests .github; then
    note "piped remote shell execution found"
fi

while IFS= read -r -d '' workflow; do
    if grep -q 'pull_request_target' "$workflow"; then
        note "$workflow uses pull_request_target"
    fi
    if grep -q 'write-all' "$workflow"; then
        note "$workflow grants write-all permissions"
    fi
    while IFS= read -r line; do
        if [[ "$line" =~ uses:[[:space:]] ]] && [[ ! "$line" =~ uses:[[:space:]]+[^@[:space:]]+@[0-9a-f]{40}([^0-9a-f]|$) ]]; then
            note "$workflow has an unpinned action: ${line// /}"
        fi
    done < "$workflow"
done < <(find .github/workflows -type f -name '*.yml' -print0)

for file in scripts/*.sh tests/integration/*.sh; do
    bash -n "$file"
done

if [[ "$fail" -ne 0 ]]; then
    exit 1
fi

echo "security checks passed"
