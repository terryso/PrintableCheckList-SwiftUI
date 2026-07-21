#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
./Scripts/generate.sh

xcodebuild \
  -project PrintableCheckList.xcodeproj \
  -scheme PrintableCheckList \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
