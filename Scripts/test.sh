#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
./Scripts/generate.sh

SIMULATOR_DESTINATION="${SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5}"
rm -rf build/TestResults.xcresult

xcodebuild \
  -project PrintableCheckList.xcodeproj \
  -scheme PrintableCheckList \
  -configuration Debug \
  -destination "$SIMULATOR_DESTINATION" \
  -derivedDataPath build/DerivedData \
  -resultBundlePath build/TestResults.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  test
