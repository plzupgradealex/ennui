#!/bin/zsh
# Build script for Ennui — outputs results to _build/ in project root
set -e
cd "$(dirname "$0")/.."
mkdir -p _build

# Clean DerivedData if it exists and is locked
rm -rf ~/Library/Developer/Xcode/DerivedData/Ennui-* 2>/dev/null || true
sleep 1

# Build
set +e
/usr/bin/xcodebuild -project Ennui.xcodeproj -scheme Ennui -configuration Debug build > _build/full.log 2>&1
EXIT_CODE=$?

# Extract errors and warnings (use strings to handle any binary chars)
strings _build/full.log | grep "error:" | grep -v "note:" | grep -v "unable to attach" | grep -v "accessing build database" > _build/errors.log 2>/dev/null
strings _build/full.log | grep "warning:" > _build/warnings.log 2>/dev/null
strings _build/full.log | grep -E "BUILD SUCCEEDED|BUILD FAILED" > _build/status.log 2>/dev/null

echo "EXIT:$EXIT_CODE" >> _build/status.log
echo "Build finished with exit code $EXIT_CODE"
