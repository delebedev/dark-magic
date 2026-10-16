#!/bin/bash
set -euo pipefail
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
cd "$PROJECT_DIR/.."
mkdir -p "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
git describe --always --dirty > "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/build-revision.txt"

# Simulator symbols and builds without reporting need no upload.
if [[ "$PLATFORM_NAME" != iphoneos || -z "${SENTRY_DSN:-}" ]]; then exit 0; fi
if [[ -z "${SENTRY_AUTH_TOKEN:-}" ]]; then
    echo 'warning: SENTRY_AUTH_TOKEN absent; native crash symbols were not uploaded.'
    exit 0
fi
sentry-cli debug-files upload "$DWARF_DSYM_FOLDER_PATH/$DWARF_DSYM_FILE_NAME"
