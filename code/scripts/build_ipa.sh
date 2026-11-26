#!/usr/bin/env bash
# 在 macOS + Xcode 环境下生成 IPA。
# 默认无签名；设置 SIGNING_IDENTITY / PROVISIONING_PROFILE_SPECIFIER 后可产出已签名包。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="$ROOT/build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

if [ ! -d "$ROOT/BarcodeScanner.xcodeproj" ]; then
  xcodegen generate --spec "$ROOT/project.yml" --project "$ROOT/BarcodeScanner.xcodeproj"
fi

SIGN_ARGS=(CODE_SIGNING_ALLOWED=NO)
if [ -n "${SIGNING_IDENTITY:-}" ]; then
  SIGN_ARGS=(CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY="$SIGNING_IDENTITY")
  if [ -n "${PROVISIONING_PROFILE_SPECIFIER:-}" ]; then
    SIGN_ARGS+=(PROVISIONING_PROFILE_SPECIFIER="$PROVISIONING_PROFILE_SPECIFIER")
  fi
fi

xcodebuild \
  -project "$ROOT/BarcodeScanner.xcodeproj" \
  -scheme BarcodeScanner \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$BUILD_DIR/BarcodeScanner.xcarchive" \
  "${SIGN_ARGS[@]}" \
  archive

APP="$BUILD_DIR/BarcodeScanner.xcarchive/Products/Applications/BarcodeScanner.app"
if [ ! -d "$APP" ]; then
  echo "archive failed: $APP not found" >&2
  exit 1
fi

mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP" "$BUILD_DIR/Payload/BarcodeScanner.app"
cd "$BUILD_DIR"
zip -qry BarcodeScanner.ipa Payload
echo "IPA ready: $BUILD_DIR/BarcodeScanner.ipa"
