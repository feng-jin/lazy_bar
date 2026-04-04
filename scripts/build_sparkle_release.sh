#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
PROJECT_PATH="$REPO_ROOT/lazy_bar.xcodeproj"
SCHEME="lazy_bar"
CONFIGURATION="Release"

VERSION="${1:-}"
UPDATE_DIR="${2:-$REPO_ROOT/release/updates}"
APP_DERIVED_DATA_PATH="${APP_DERIVED_DATA_PATH:-/tmp/lazy-bar-release}"
SPARKLE_DERIVED_DATA_PATH="${SPARKLE_DERIVED_DATA_PATH:-/tmp/sparkle-tools}"
SPARKLE_CHECKOUT_PATH="${SPARKLE_CHECKOUT_PATH:-}"

usage() {
    cat <<EOF
Usage:
  $(basename "$0") <version> [update-dir]

Examples:
  $(basename "$0") 1.0
  $(basename "$0") 1.0 "$REPO_ROOT/release/updates"

Environment overrides:
  SPARKLE_CHECKOUT_PATH      Sparkle checkout path. If omitted, the script will try to find one in DerivedData.
  SPARKLE_DERIVED_DATA_PATH  DerivedData path used when building Sparkle CLI tools.
  APP_DERIVED_DATA_PATH      DerivedData path used when building the app.
EOF
}

if [[ -z "$VERSION" ]]; then
    usage
    exit 1
fi

if [[ "$VERSION" == *"/"* || "$VERSION" == *".."* ]]; then
    echo "Version must be a plain release version like 0.1.0 and must not contain path separators." >&2
    exit 1
fi

find_sparkle_checkout() {
    find "$HOME/Library/Developer/Xcode/DerivedData" \
        -path "*SourcePackages/checkouts/Sparkle" \
        -type d \
        2>/dev/null \
        | head -n 1
}

if [[ -z "$SPARKLE_CHECKOUT_PATH" ]]; then
    SPARKLE_CHECKOUT_PATH=$(find_sparkle_checkout)
fi

if [[ -z "$SPARKLE_CHECKOUT_PATH" || ! -d "$SPARKLE_CHECKOUT_PATH" ]]; then
    echo "Could not find Sparkle checkout. Set SPARKLE_CHECKOUT_PATH first." >&2
    exit 1
fi

SPARKLE_PROJECT_PATH="$SPARKLE_CHECKOUT_PATH/Sparkle.xcodeproj"
GENERATE_APPCAST_BIN="$SPARKLE_DERIVED_DATA_PATH/Build/Products/Release/generate_appcast"

resolve_product_name() {
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -showBuildSettings 2>/dev/null \
        | awk -F' = ' '/^[[:space:]]*PRODUCT_NAME = / { print $2; exit }'
}

PRODUCT_NAME=$(resolve_product_name)

if [[ -z "$PRODUCT_NAME" ]]; then
    echo "Could not resolve PRODUCT_NAME from Xcode build settings." >&2
    exit 1
fi

APP_BUILD_PATH="$APP_DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$PRODUCT_NAME.app"
ARCHIVE_NAME="$PRODUCT_NAME-$VERSION.zip"
ARCHIVE_PATH="$UPDATE_DIR/$ARCHIVE_NAME"

remove_conflicting_archives() {
    local archive

    setopt local_options null_glob
    for archive in "$UPDATE_DIR"/*-"$VERSION".zip; do
        if [[ "$archive" != "$ARCHIVE_PATH" ]]; then
            echo "==> Removing conflicting archive for version $VERSION: $(basename "$archive")"
            rm -f "$archive"
        fi
    done
}

echo "==> Sparkle checkout: $SPARKLE_CHECKOUT_PATH"
echo "==> Product name: $PRODUCT_NAME"
echo "==> Update directory: $UPDATE_DIR"
echo "==> Building generate_appcast"
xcodebuild \
    -project "$SPARKLE_PROJECT_PATH" \
    -scheme generate_appcast \
    -configuration Release \
    -derivedDataPath "$SPARKLE_DERIVED_DATA_PATH" \
    build

if [[ ! -x "$GENERATE_APPCAST_BIN" ]]; then
    echo "generate_appcast was not produced at $GENERATE_APPCAST_BIN" >&2
    exit 1
fi

echo "==> Building $SCHEME ($CONFIGURATION)"
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$APP_DERIVED_DATA_PATH" \
    build

if [[ ! -d "$APP_BUILD_PATH" ]]; then
    echo "Built app was not found at $APP_BUILD_PATH" >&2
    exit 1
fi

mkdir -p "$UPDATE_DIR"

echo "==> Packaging app to $ARCHIVE_PATH"
rm -f "$ARCHIVE_PATH"
ditto -c -k --sequesterRsrc --keepParent \
    "$APP_BUILD_PATH" \
    "$ARCHIVE_PATH"

remove_conflicting_archives

echo "==> Generating appcast.xml"
"$GENERATE_APPCAST_BIN" "$UPDATE_DIR"

echo
echo "Done."
echo "Archive: $ARCHIVE_PATH"
echo "Appcast: $UPDATE_DIR/appcast.xml"
