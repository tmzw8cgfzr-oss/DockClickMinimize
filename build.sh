#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
APP_NAME="DockClickMinimize"
APP_PATH="$SCRIPT_DIR/$APP_NAME.app"
CONTENTS_PATH="$APP_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
# Every invocation gets a fresh staging bundle. A fixed staging path can retain
# resources removed in a later build and make the signed App non-reproducible.
STAGING_ROOT="$(mktemp -d "${TMPDIR:-/private/tmp}/DockClickMinimize-code-sign.XXXXXX")"
STAGED_APP="$STAGING_ROOT/$APP_NAME.app"
STAGED_CONTENTS="$STAGED_APP/Contents"
STAGED_MACOS="$STAGED_CONTENTS/MacOS"
STAGED_RESOURCES="$STAGED_CONTENTS/Resources"
ARCH="${ARCH:-$(uname -m)}"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

mkdir -p "$STAGED_MACOS" "$STAGED_RESOURCES"

DEBUG_DEFINE="-DNDEBUG"
OPTIMIZATION=(-Os)
BUILD_MODE="${1:-release}"
if [[ "$BUILD_MODE" == "debug" ]]; then
    DEBUG_DEFINE="-DDEBUG"
    # Keep debug logging without emitting a .dSYM inside Contents/MacOS.
    OPTIMIZATION=(-O0)
elif [[ "$BUILD_MODE" != "release" && "$BUILD_MODE" != "install" ]]; then
    print -u2 "usage: ./build.sh [debug|install]"
    exit 2
fi

clang \
    -arch "$ARCH" \
    -isysroot "$SDKROOT" \
    -mmacosx-version-min=13.0 \
    -fobjc-arc \
    "${OPTIMIZATION[@]}" \
    "$DEBUG_DEFINE" \
    -Wall \
    -Wextra \
    -Wpedantic \
    -Wno-unused-parameter \
    -Wl,-dead_strip \
    "$SCRIPT_DIR/main.m" \
    "$SCRIPT_DIR/DockMonitor.m" \
    -framework AppKit \
    -framework ApplicationServices \
    -framework CoreGraphics \
    -o "$STAGED_MACOS/$APP_NAME"

cp "$SCRIPT_DIR/Info.plist" "$STAGED_CONTENTS/Info.plist"
# Keep only the conventional macOS application icon. The menu bar glyph is a
# system template symbol created at runtime, so no extra image resource is
# needed in the bundle.
cp "$SCRIPT_DIR/AppIcon.icns" "$STAGED_RESOURCES/AppIcon.icns"

# Sign in a clean temporary directory. The workspace may attach Finder or
# FileProvider metadata while the bundle is being assembled; codesign rejects
# that metadata even though it is unrelated to the app. The finished bundle is
# then copied back, preserving its embedded Bundle signature and code identity.
/usr/bin/xattr -cr "$STAGED_APP" 2>/dev/null || true
/usr/bin/codesign --force \
    --sign - \
    --identifier local.chatday.DockClickMinimize \
    -r '=designated => identifier "local.chatday.DockClickMinimize"' \
    "$STAGED_APP" >/dev/null

if [[ "$BUILD_MODE" == "install" ]]; then
    USER_APPS_DIR="${USER_APPS_DIR:-$HOME/Applications}"
    INSTALLED_APP="$USER_APPS_DIR/$APP_NAME.app"
    mkdir -p "$USER_APPS_DIR"
    /usr/bin/ditto --noqtn "$STAGED_APP" "$INSTALLED_APP"
    # ditto updates an existing destination in place. Re-sign that exact
    # target so an older copy cannot leave the installed bundle unverifiable.
    /usr/bin/xattr -cr "$INSTALLED_APP" 2>/dev/null || true
    /usr/bin/codesign --force \
        --sign - \
        --identifier local.chatday.DockClickMinimize \
        -r '=designated => identifier "local.chatday.DockClickMinimize"' \
        "$INSTALLED_APP" >/dev/null
    /usr/bin/codesign --verify --deep --strict "$INSTALLED_APP"
    echo "Installed $INSTALLED_APP"
else
    # Keep the plain build command useful for local inspection. The install
    # path above intentionally does not leave a second .app in the source
    # tree, because Tahoe can discover both bundles and create duplicate
    # menu-bar registrations for the same bundle identifier.
    mkdir -p "$MACOS_PATH" "$CONTENTS_PATH/_CodeSignature" "$CONTENTS_PATH/Resources"
    cp "$STAGED_MACOS/$APP_NAME" "$MACOS_PATH/$APP_NAME"
    cp "$STAGED_CONTENTS/Info.plist" "$CONTENTS_PATH/Info.plist"
    cp "$STAGED_RESOURCES/AppIcon.icns" "$CONTENTS_PATH/Resources/AppIcon.icns"
    cp "$STAGED_CONTENTS/_CodeSignature/CodeResources" "$CONTENTS_PATH/_CodeSignature/CodeResources"
    /usr/bin/xattr -cr "$APP_PATH" 2>/dev/null || true
    /usr/bin/xattr -d com.apple.FinderInfo "$APP_PATH" 2>/dev/null || true
    # FileProvider may re-attach provenance to this workspace copy immediately
    # after the xattr cleanup. The install branch below signs and verifies the
    # clean user Applications target, which is the distributable artifact.
    echo "Built $APP_PATH"
fi
