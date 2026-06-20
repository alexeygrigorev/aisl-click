#!/usr/bin/env bash
# Build the Rust redirector for arm64 (Lambda Graviton) and package dist/bootstrap.zip.
# Linker config lives in redirector/.cargo/config.toml (rust-lld, self-contained musl).
set -euo pipefail
cd "$(dirname "$0")/.."

rustup target add aarch64-unknown-linux-musl >/dev/null 2>&1 || true

(cd redirector && cargo build --release --target aarch64-unknown-linux-musl)

mkdir -p dist
python3 - <<'PY'
import zipfile
zipfile.ZipFile("dist/bootstrap.zip", "w", zipfile.ZIP_DEFLATED).write(
    "redirector/target/aarch64-unknown-linux-musl/release/bootstrap", "bootstrap")
print("wrote dist/bootstrap.zip")
PY
