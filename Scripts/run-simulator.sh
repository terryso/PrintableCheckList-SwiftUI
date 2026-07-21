#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
./Scripts/generate.sh

SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16 Pro}"
SIMULATOR_OS="${SIMULATOR_OS:-18.5}"
SIMULATOR_ID="$({
  xcrun simctl list devices available | awk \
    -v runtime="-- iOS $SIMULATOR_OS --" \
    -v name="$SIMULATOR_NAME" '
      $0 == runtime { in_runtime = 1; next }
      /^-- / { in_runtime = 0 }
      in_runtime && index($0, "    " name " (") == 1 {
        if (match($0, /[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}/)) {
          print substr($0, RSTART, RLENGTH)
          exit
        }
      }
    '
} || true)"

if [[ -z "$SIMULATOR_ID" ]]; then
  echo "No available $SIMULATOR_NAME simulator with iOS $SIMULATOR_OS." >&2
  exit 1
fi

xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
xcrun simctl bootstatus "$SIMULATOR_ID" -b

xcodebuild \
  -project PrintableCheckList.xcodeproj \
  -scheme PrintableCheckList \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH=build/DerivedData/Build/Products/Debug-iphonesimulator/PrintableCheckList.app
xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" com.wehack.PrintableCheckList
open -a Simulator
