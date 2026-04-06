#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE_PATH="$ROOT_DIR/.swiftpm/xcode/package.xcworkspace"
DERIVED_DATA_PATH="$ROOT_DIR/.build/xcode-simulator"
PRODUCTS_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator"
APP_DIR="$PRODUCTS_PATH/ENVI.app"
APP_BINARY="$APP_DIR/ENVI"
INFO_PLIST="$APP_DIR/Info.plist"

DEVICE_ID="${SIMULATOR_ID:-$(xcrun simctl list devices | awk -F '[()]' '/Booted/{print $2; exit}')}"

if [[ -z "$DEVICE_ID" ]]; then
  echo "❌ No booted simulator found." >&2
  echo "Fix: open Simulator.app and boot a device, or set SIMULATOR_ID." >&2
  exit 1
fi

open -a Simulator

if ! xcodebuild \
  -workspace "$WORKSPACE_PATH" \
  -scheme ENVI \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build; then
  echo "❌ Build failed. Check xcodebuild output above." >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Frameworks"

cp "$PRODUCTS_PATH/ENVI" "$APP_BINARY"
cp "$ROOT_DIR/ENVI/Resources/Info.plist" "$INFO_PLIST"
cp -R "$PRODUCTS_PATH/ENVI_ENVI.bundle" "$APP_DIR/"

if [[ -d "$PRODUCTS_PATH/SDWebImage_SDWebImage.bundle" ]]; then
  cp -R "$PRODUCTS_PATH/SDWebImage_SDWebImage.bundle" "$APP_DIR/"
fi

if [[ -d "$PRODUCTS_PATH/Lottie.framework" ]]; then
  cp -R "$PRODUCTS_PATH/Lottie.framework" "$APP_DIR/Frameworks/"
fi

if ! otool -l "$APP_BINARY" | grep -q "@executable_path/Frameworks"; then
  install_name_tool -add_rpath @executable_path/Frameworks "$APP_BINARY"
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable ENVI" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0:UISceneDelegateClassName ENVI.SceneDelegate" "$INFO_PLIST"

xattr -cr "$APP_DIR"
codesign --force --sign - --timestamp=none --deep "$APP_DIR"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST")"

xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$DEVICE_ID" "$APP_DIR"
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"

echo "Installed and launched $BUNDLE_ID on simulator $DEVICE_ID"
