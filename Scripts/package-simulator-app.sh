#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
REPOSITORY_ROOT=${SCRIPT_DIR:h}
OUTPUT_DIRECTORY=${1:-"${REPOSITORY_ROOT}/dist"}
DERIVED_DATA_PATH=/private/tmp/ReviewTrace-Simulator-Package
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Release-iphonesimulator/ReviewTrace.app"
ARCHIVE_PATH="${OUTPUT_DIRECTORY}/ReviewTrace-Simulator.app.zip"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"

mkdir -p "${OUTPUT_DIRECTORY}"

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project "${REPOSITORY_ROOT}/OpenAi_ReviewTrace.xcodeproj" \
  -scheme ReviewTrace \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  build

ditto -c -k --norsrc --keepParent "${APP_PATH}" "${ARCHIVE_PATH}"
ARCHIVE_CHECKSUM=$(shasum -a 256 "${ARCHIVE_PATH}" | awk '{print $1}')
printf '%s  %s\n' "${ARCHIVE_CHECKSUM}" "${ARCHIVE_PATH:t}" > "${CHECKSUM_PATH}"

echo "Created ${ARCHIVE_PATH}"
echo "Created ${CHECKSUM_PATH}"
