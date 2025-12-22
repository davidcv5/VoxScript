#!/bin/bash
# Sign a DMG file for Sparkle updates
# Usage: ./sign-update.sh <path-to-dmg>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-dmg>"
    echo "Example: $0 build/VoxScript-1.0.dmg"
    exit 1
fi

DMG_PATH="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KEYS_DIR="$PROJECT_DIR/.sparkle-keys"
PRIVATE_KEY="$KEYS_DIR/sparkle_private_key"

# Verify DMG exists
if [ ! -f "$DMG_PATH" ]; then
    echo "ERROR: DMG file not found: $DMG_PATH"
    exit 1
fi

# Verify private key exists
if [ ! -f "$PRIVATE_KEY" ]; then
    echo "ERROR: Private key not found at $PRIVATE_KEY"
    echo "Run ./scripts/sparkle-setup.sh first to generate keys."
    exit 1
fi

# Find Sparkle tools
SPARKLE_TOOLS=$(echo ~/Library/Developer/Xcode/DerivedData/VoxScript-*/SourcePackages/artifacts/sparkle/Sparkle/bin)

if [ ! -d "$SPARKLE_TOOLS" ]; then
    echo "ERROR: Sparkle tools not found."
    echo "Please build the project in Xcode first."
    exit 1
fi

echo "Signing: $DMG_PATH"
echo ""

# Sign the DMG
SIGNATURE=$("$SPARKLE_TOOLS/sign_update" "$DMG_PATH" -f "$PRIVATE_KEY")

echo "=== Signature Generated ==="
echo ""
echo "Add this to your appcast.xml enclosure:"
echo ""
echo "sparkle:edSignature=\"$SIGNATURE\""
echo ""

# Also output the file size
FILE_SIZE=$(stat -f%z "$DMG_PATH")
echo "File size (for length attribute): $FILE_SIZE"
echo ""
echo "Complete enclosure example:"
echo "<enclosure"
echo "    url=\"https://github.com/YOUR_USER/vox-script-claude/releases/download/vX.Y/$(basename "$DMG_PATH")\""
echo "    sparkle:edSignature=\"$SIGNATURE\""
echo "    length=\"$FILE_SIZE\""
echo "    type=\"application/octet-stream\"/>"
