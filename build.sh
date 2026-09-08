#!/usr/bin/env bash
# Build script for boilerplate-cli-ui-zig
set -euo pipefail
cd "$(dirname "$0")"

ZIG="${ZIG:-zig}"
command -v "$ZIG" >/dev/null 2>&1 || { echo "error: '$ZIG' not found (set ZIG=/path/to/zig)" >&2; exit 1; }

APP_NAME="boilerplate-cli-ui-zig"

echo "Building ${APP_NAME}..."
"$ZIG" build -Doptimize=ReleaseSmall
cp "zig-out/bin/${APP_NAME}" "./${APP_NAME}"

echo "Built: ./${APP_NAME}"
ls -lh "${APP_NAME}"
