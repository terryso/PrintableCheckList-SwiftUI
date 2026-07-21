#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f Config/Local.xcconfig ]]; then
  echo "Copy Config/Local.xcconfig.example to Config/Local.xcconfig and set DEVELOPMENT_TEAM first." >&2
  exit 2
fi

./Scripts/generate.sh

xcodebuild \
  -project PrintableCheckList.xcodeproj \
  -scheme PrintableCheckList \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Flash.xcarchive \
  -allowProvisioningUpdates \
  archive
