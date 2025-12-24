# Code Signing & Notarization Guide

This guide explains how to properly sign VoxScript for distribution outside the Mac App Store.

## Why This Is Needed

- **Code signing** proves the app comes from a known developer
- **Notarization** is Apple's malware scan - required since macOS Catalina
- **Sparkle auto-updates** require Developer ID signing to function

## Prerequisites

- Apple Developer Program membership ($99/year)
- macOS with Xcode installed

## Step 1: Create Developer ID Certificate

1. Go to [developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates)

2. Click **+** to create a new certificate

3. Select **Developer ID Application** (NOT "Mac App Distribution")

4. Generate a Certificate Signing Request (CSR):
   - Open **Keychain Access** app
   - Menu: Keychain Access → Certificate Assistant → **Request a Certificate from a Certificate Authority**
   - Enter your email address
   - Leave CA Email blank
   - Select **Saved to disk**
   - Save the `.certSigningRequest` file

5. Upload the CSR to Apple's developer portal

6. Download the certificate (`.cer` file)

7. Double-click to install it in your Keychain

8. Verify installation:
   ```bash
   security find-identity -v -p codesigning | grep "Developer ID"
   ```
   You should see: `"Developer ID Application: Your Name (TEAM_ID)"`

## Step 2: Create App-Specific Password

Apple requires an app-specific password for notarization (not your regular Apple ID password).

1. Go to [appleid.apple.com](https://appleid.apple.com)

2. Sign in with your Apple ID

3. Go to **Sign-In and Security** → **App-Specific Passwords**

4. Click **+** to generate a new password

5. Name it something like "VoxScript Notarization"

6. Copy and save the generated password securely (you won't see it again)

## Step 3: Store Notarization Credentials

Store your credentials in the macOS Keychain so build scripts can use them:

```bash
xcrun notarytool store-credentials "VoxScript" \
  --apple-id "your-apple-id@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

- **apple-id**: Your Apple ID email
- **team-id**: Found at [developer.apple.com/account](https://developer.apple.com/account) → Membership Details
- **password**: The app-specific password from Step 2

## Step 4: Update Xcode Project

1. Open `VoxScript.xcodeproj` in Xcode

2. Select the **VoxScript** target

3. Go to **Signing & Capabilities** tab

4. Uncheck "Automatically manage signing"

5. Set:
   - **Team**: Your team
   - **Signing Certificate**: Developer ID Application

## Step 5: Build, Sign & Notarize

### Option A: Manual Process

```bash
# 1. Build the archive
xcodebuild -project VoxScript.xcodeproj \
  -scheme VoxScript \
  -configuration Release \
  -archivePath build/VoxScript.xcarchive \
  archive

# 2. Export with Developer ID signing
xcodebuild -exportArchive \
  -archivePath build/VoxScript.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist build/ExportOptions-DevID.plist

# 3. Create DMG
# (use existing build-dmg.sh or create manually)

# 4. Notarize the DMG
xcrun notarytool submit build/VoxScript-1.0.dmg \
  --keychain-profile "VoxScript" \
  --wait

# 5. Staple the notarization ticket to the DMG
xcrun stapler staple build/VoxScript-1.0.dmg
```

### Option B: Automated Script

Once signing is configured, update `build-dmg.sh` to include notarization:

```bash
# Add to build-dmg.sh after DMG creation:

echo "Notarizing DMG..."
xcrun notarytool submit "${BUILD_DIR}/${DMG_NAME}" \
  --keychain-profile "VoxScript" \
  --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "${BUILD_DIR}/${DMG_NAME}"
```

## Step 6: Enable Sparkle Auto-Updates

After the app is properly signed, re-enable Sparkle:

1. In `VoxScript/VoxScriptApp.swift`, change:
   ```swift
   updaterController = SPUStandardUpdaterController(
       startingUpdater: true,  // Change from false to true
       updaterDelegate: nil,
       userDriverDelegate: nil
   )
   ```

2. In `VoxScript/Info.plist`, change:
   ```xml
   <key>SUEnableAutomaticChecks</key>
   <true/>  <!-- Change from false to true -->
   ```

## Verification

After building with Developer ID signing:

```bash
# Check code signature
codesign -dv --verbose=4 /path/to/VoxScript.app

# Verify notarization
spctl -a -v /path/to/VoxScript.app
# Should say: "accepted" and "source=Notarized Developer ID"

# Check DMG notarization
spctl -a -t open --context context:primary-signature /path/to/VoxScript.dmg
```

## Troubleshooting

### "Developer ID Application" certificate not showing
- Make sure you downloaded and installed the certificate
- Check Keychain Access → My Certificates
- Try: `security find-identity -v -p codesigning`

### Notarization fails
- Check Apple's status: [developer.apple.com/system-status](https://developer.apple.com/system-status/)
- View detailed log: `xcrun notarytool log <submission-id> --keychain-profile "VoxScript"`
- Common issues: unsigned nested code, hardened runtime not enabled

### "App is damaged" error on user's Mac
- DMG wasn't notarized, or notarization ticket wasn't stapled
- Re-run: `xcrun stapler staple /path/to/VoxScript.dmg`

## ExportOptions-DevID.plist

Create `build/ExportOptions-DevID.plist` for Developer ID export:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
```

## Summary Checklist

- [ ] Developer ID Application certificate created and installed
- [ ] App-specific password generated
- [ ] Notarization credentials stored with `notarytool store-credentials`
- [ ] Xcode project configured for Developer ID signing
- [ ] ExportOptions-DevID.plist created
- [ ] Build, notarize, and staple DMG
- [ ] Re-enable Sparkle auto-updates
- [ ] Test on a fresh Mac to verify Gatekeeper accepts the app
