#!/bin/bash
# EdgeSlide build script — run on your Mac:  bash build.sh
set -e
cd "$(dirname "$0")"
if ! command -v swiftc >/dev/null 2>&1; then
  echo "Swift compiler not found. First run:  xcode-select --install   (then run build.sh again)"
  exit 1
fi
APP="build/EdgeSlide.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos13.0" main.swift -o "$APP/Contents/MacOS/EdgeSlide"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
(cd build && ditto -c -k --keepParent EdgeSlide.app EdgeSlide.zip)
echo "✅ Done: $(pwd)/build/EdgeSlide.app  and  build/EdgeSlide.zip"
if [ -z "$CI" ]; then open build; fi
