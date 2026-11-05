#!/bin/sh
# Installs the latest ClaudeUsage release into /Applications.
set -eu

URL="https://github.com/Throover/ClaudeUsage/releases/latest/download/ClaudeUsage.zip"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Downloading ClaudeUsage..."
curl -fsSL "$URL" -o "$TMP/ClaudeUsage.zip"
ditto -x -k "$TMP/ClaudeUsage.zip" "$TMP"

pkill -x ClaudeUsage 2>/dev/null || true
rm -rf /Applications/ClaudeUsage.app
mv "$TMP/ClaudeUsage.app" /Applications/
open /Applications/ClaudeUsage.app
echo "Installed. Look for the S | W rings in your menu bar."
