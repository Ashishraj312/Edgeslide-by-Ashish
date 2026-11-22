#!/bin/bash
# EdgeSlide installer: downloads the latest release and installs it to /Applications.
set -e
URL="https://github.com/Ashishraj312/Edgeslide-by-Ashish/releases/latest/download/EdgeSlide.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading EdgeSlide..."
curl -fL "$URL" -o "$TMP/EdgeSlide.zip"

echo "Installing to /Applications..."
pkill -x EdgeSlide 2>/dev/null || true
rm -rf /Applications/EdgeSlide.app
ditto -x -k "$TMP/EdgeSlide.zip" /Applications
xattr -dr com.apple.quarantine /Applications/EdgeSlide.app 2>/dev/null || true

open /Applications/EdgeSlide.app
echo "Done. Look for the hand icon in your menu bar."
