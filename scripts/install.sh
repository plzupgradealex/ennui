#!/bin/zsh
# install.sh — Build and install Ennui to /Applications
# Usage: ./scripts/install.sh
#
# Requirements:
#   - macOS 26.0 (Tahoe) or later
#   - Apple Silicon Mac (M1/M2/M3/M4)
#   - Xcode 18 with command-line tools installed
#
set -euo pipefail

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Ennui"
SCHEME="Ennui"
DERIVED_DATA="/tmp/EnnuiBuild-$$"
BUILD_LOG="/tmp/ennui-install-$$.log"

echo ""
echo "${BOLD}  ✦  Ennui — ambient scene viewer${RESET}"
echo "${DIM}  Building from source...${RESET}"
echo ""

# ── Preflight checks ──────────────────────────────────────────

# Check architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "arm64" ]]; then
    echo "${RED}  ✗  Ennui requires Apple Silicon (arm64). This Mac is ${ARCH}.${RESET}"
    exit 1
fi

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion)
MAJOR_VERSION=$(echo "$MACOS_VERSION" | cut -d. -f1)
if [[ "$MAJOR_VERSION" -lt 26 ]]; then
    echo "${RED}  ✗  Ennui requires macOS 26.0 (Tahoe) or later.${RESET}"
    echo "${DIM}     You're running macOS ${MACOS_VERSION}.${RESET}"
    exit 1
fi

# Check Xcode / xcodebuild
if ! command -v xcodebuild &>/dev/null; then
    echo "${RED}  ✗  Xcode command-line tools not found.${RESET}"
    echo "${DIM}     Install Xcode from the App Store, then run:${RESET}"
    echo "${DIM}     xcode-select --install${RESET}"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -1)
echo "${DIM}  ▸ ${XCODE_VERSION}${RESET}"
echo "${DIM}  ▸ macOS ${MACOS_VERSION} (${ARCH})${RESET}"
echo ""

# ── Build ──────────────────────────────────────────────────────

echo "${DIM}  Building ${APP_NAME}...${RESET}"

# Clean any stale derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/Ennui-* 2>/dev/null || true

cd "$PROJECT_DIR"
if xcodebuild \
    -project Ennui.xcodeproj \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    build \
    > "$BUILD_LOG" 2>&1; then
    echo "${GREEN}  ✓  Build succeeded${RESET}"
else
    echo "${RED}  ✗  Build failed${RESET}"
    echo ""
    echo "${DIM}  Errors:${RESET}"
    grep "error:" "$BUILD_LOG" | grep -v "note:" | head -10
    echo ""
    echo "${DIM}  Full log: ${BUILD_LOG}${RESET}"
    exit 1
fi

# ── Install ────────────────────────────────────────────────────

BUILT_APP="$DERIVED_DATA/Build/Products/Release/${APP_NAME}.app"
INSTALL_DIR="/Applications"
INSTALL_PATH="${INSTALL_DIR}/${APP_NAME}.app"

if [[ ! -d "$BUILT_APP" ]]; then
    # Fallback to Debug if Release wasn't configured
    BUILT_APP="$DERIVED_DATA/Build/Products/Debug/${APP_NAME}.app"
fi

if [[ ! -d "$BUILT_APP" ]]; then
    echo "${RED}  ✗  Built app not found at expected path${RESET}"
    echo "${DIM}  Check: ${BUILD_LOG}${RESET}"
    exit 1
fi

# Remove old install if present
if [[ -d "$INSTALL_PATH" ]]; then
    echo "${DIM}  Removing previous install...${RESET}"
    rm -rf "$INSTALL_PATH"
fi

echo "${DIM}  Copying to ${INSTALL_DIR}/...${RESET}"
cp -R "$BUILT_APP" "$INSTALL_PATH"

# Clean up
rm -rf "$DERIVED_DATA"
rm -f "$BUILD_LOG"

echo ""
echo "${GREEN}${BOLD}  ✦  Ennui installed to /Applications${RESET}"
echo ""
echo "${DIM}  To launch:${RESET}"
echo "${DIM}    open /Applications/Ennui.app${RESET}"
echo ""
echo "${DIM}  Keyboard shortcuts:${RESET}"
echo "${DIM}    ← →      Previous / next scene${RESET}"
echo "${DIM}    Space     Show scene picker${RESET}"
echo "${DIM}    H         Toggle haiku overlay${RESET}"
echo "${DIM}    ?         About panel${RESET}"
echo "${DIM}    Click     Scene-specific interaction${RESET}"
echo ""
