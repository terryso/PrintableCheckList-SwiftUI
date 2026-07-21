#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

XCODEGEN_BIN="$(command -v xcodegen || true)"
if [[ -z "$XCODEGEN_BIN" && -x /Users/nick/.local/bin/xcodegen ]]; then
  XCODEGEN_BIN=/Users/nick/.local/bin/xcodegen
fi

if [[ -z "$XCODEGEN_BIN" ]]; then
  echo "xcodegen is required. Set XCODEGEN_BIN or install XcodeGen 2.46+." >&2
  exit 1
fi

"$XCODEGEN_BIN" generate
