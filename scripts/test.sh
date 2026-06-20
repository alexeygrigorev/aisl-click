#!/usr/bin/env bash
# Local tests on the host arch (x86_64) — fast iteration without cross-compiling.
set -euo pipefail
cd "$(dirname "$0")/../redirector"
cargo test
