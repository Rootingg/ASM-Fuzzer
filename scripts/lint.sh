#!/usr/bin/env bash
# Assemble every translation unit with warnings as errors and check text hygiene.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

note() {
    printf 'lint: %s\n' "$1" >&2
    fail=1
}

while IFS= read -r -d '' file; do
    if [[ -s "$file" ]]; then
        last="$(tail -c 1 "$file" || true)"
        if [[ "$last" != $'\n' ]]; then
            note "missing final newline: $file"
        fi
    fi
    if grep -q $'\r' "$file"; then
        note "CRLF line ending: $file"
    fi
    if grep -n -E '[[:blank:]]+$' "$file" >/dev/null; then
        note "trailing whitespace: $file"
    fi
done < <(find . -type f \
    -not -path './.git/*' \
    -not -path './build/*' \
    \( -name '*.asm' -o -name '*.inc' -o -name '*.sh' -o -name '*.yml' -o -name '*.md' \
       -o -name 'Makefile' -o -name '.editorconfig' -o -name '.gitattributes' -o -name '.gitignore' \))

nasm_flags=(-f elf64 -I include/ -w+all -w+error)
printf 'bits 64\nnop\n' > "$tmp/probe.asm"
if nasm -f elf64 -w+error -w-reloc-rel-dword -o "$tmp/probe.o" "$tmp/probe.asm" >/dev/null 2>&1; then
    nasm_flags+=(-w-reloc-rel-dword)
fi

shopt -s globstar nullglob
for file in **/*.asm; do
    if [[ "$file" == build/* ]]; then
        continue
    fi
    if ! nasm "${nasm_flags[@]}" "$file" -o "$tmp/lint.o"; then
        note "assembly failed: $file"
    fi
done

for file in scripts/*.sh tests/integration/*.sh; do
    bash -n "$file"
done

if [[ "$fail" -ne 0 ]]; then
    exit 1
fi

echo "lint checks passed"
