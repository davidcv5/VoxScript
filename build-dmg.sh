#!/bin/bash
# VoxScript DMG Build Script
# Creates a distributable DMG installer

set -e  # Exit on error

# Configuration
APP_NAME="VoxScript"
VERSION="1.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR="build"
DMG_DIR="${BUILD_DIR}/dmg"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"

echo "=== Building ${APP_NAME} ${VERSION} ==="

# Step 1: Clean previous builds
echo "Cleaning previous builds..."
rm -rf "${BUILD_DIR}/dmg"
rm -rf "${ARCHIVE_PATH}"
rm -f "${BUILD_DIR}/${DMG_NAME}"

# Step 2: Build Release Archive
echo "Building Release archive..."
xcodebuild -project VoxScript.xcodeproj \
    -scheme VoxScript \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    archive

# Step 3: Export the app from archive
echo "Exporting app from archive..."
mkdir -p "${BUILD_DIR}/export"
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${BUILD_DIR}/export" \
    -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist"

# Step 4: Prepare DMG contents
echo "Preparing DMG contents..."
mkdir -p "${DMG_DIR}"
cp -R "${BUILD_DIR}/export/${APP_NAME}.app" "${DMG_DIR}/"
ln -sf /Applications "${DMG_DIR}/Applications"

# Step 5: Create DMG
echo "Creating DMG..."
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov -format UDZO \
    "${BUILD_DIR}/${DMG_NAME}"

# Step 6: Cleanup
echo "Cleaning up..."
rm -rf "${BUILD_DIR}/export"

echo ""
echo "=== Build Complete ==="
echo "DMG created at: ${BUILD_DIR}/${DMG_NAME}"
echo ""
ls -lh "${BUILD_DIR}/${DMG_NAME}"
