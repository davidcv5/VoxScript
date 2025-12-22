#!/bin/bash
# Sparkle Setup Script for VoxScript
# Generates EdDSA signing keys for Sparkle updates

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KEYS_DIR="$PROJECT_DIR/.sparkle-keys"

echo "=== Sparkle Setup for VoxScript ==="
echo ""

# Check if Sparkle tools are available
SPARKLE_TOOLS="$HOME/Library/Developer/Xcode/DerivedData/VoxScript-*/SourcePackages/artifacts/sparkle/Sparkle/bin"
SPARKLE_TOOLS=$(echo $SPARKLE_TOOLS)

if [ ! -d "$SPARKLE_TOOLS" ]; then
    echo "Sparkle tools not found. Building project first..."
    cd "$PROJECT_DIR"
    xcodebuild -project VoxScript.xcodeproj -scheme VoxScript -configuration Release build
    SPARKLE_TOOLS=$(echo ~/Library/Developer/Xcode/DerivedData/VoxScript-*/SourcePackages/artifacts/sparkle/Sparkle/bin)
fi

if [ ! -d "$SPARKLE_TOOLS" ]; then
    echo "ERROR: Sparkle tools not found even after build."
    echo "Please build the project in Xcode first to download Sparkle."
    exit 1
fi

echo "Found Sparkle tools at: $SPARKLE_TOOLS"

# Create keys directory
mkdir -p "$KEYS_DIR"

# Check if keys already exist
if [ -f "$KEYS_DIR/sparkle_private_key" ]; then
    echo ""
    echo "WARNING: Signing keys already exist at $KEYS_DIR"
    echo "To regenerate, delete the existing keys first."
    echo ""
    echo "Your public key (for Info.plist SUPublicEDKey):"
    cat "$KEYS_DIR/sparkle_public_key"
    exit 0
fi

# Generate new keys (stores in macOS Keychain)
echo ""
echo "Generating new EdDSA signing keys..."
echo "(You may be prompted by Keychain Access to allow this operation)"
echo ""

# Run generate_keys with no args - this creates key in Keychain and prints the public key
OUTPUT=$("$SPARKLE_TOOLS/generate_keys" 2>&1)
echo "$OUTPUT"
echo ""

# Extract public key from <string>...</string> format
PUBLIC_KEY=$(echo "$OUTPUT" | grep -o '<string>[^<]*</string>' | sed 's/<string>//;s/<\/string>//')

if [ -z "$PUBLIC_KEY" ]; then
    echo "ERROR: Could not extract public key from output."
    exit 1
fi

# Save public key to file
echo "$PUBLIC_KEY" > "$KEYS_DIR/sparkle_public_key"

# Export private key from Keychain to file for backup/CI
echo ""
echo "Exporting private key from Keychain..."
"$SPARKLE_TOOLS/generate_keys" -x "$KEYS_DIR/sparkle_private_key"

echo ""
echo "=== Keys Generated Successfully ==="
echo ""
echo "Private key saved to: $KEYS_DIR/sparkle_private_key"
echo "Public key saved to: $KEYS_DIR/sparkle_public_key"
echo ""
echo "IMPORTANT: Keep the private key secure! Add .sparkle-keys to .gitignore"
echo ""
echo "Your public key (add this to Info.plist SUPublicEDKey):"
echo "---"
cat "$KEYS_DIR/sparkle_public_key"
echo "---"
echo ""
echo "Next steps:"
echo "1. Copy the public key above to Info.plist under SUPublicEDKey"
echo "2. Use ./scripts/sign-update.sh to sign your DMG releases"
