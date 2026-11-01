#!/usr/bin/env bash
# Build the fuzzer and run the unit binaries plus the controlled campaign.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

export BUILD="${BUILD:-build}"

make tools
bash "$root/scripts/run-units.sh"
bash "$root/tests/integration/campaign.sh"
