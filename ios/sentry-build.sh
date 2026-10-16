#!/bin/bash
set -euo pipefail
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
cd "$PROJECT_DIR/.."
mkdir -p "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
git describe --always --dirty > "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/build-revision.txt"

# Simulator symbols and builds without reporting need no upload.
if [[ "$PLATFORM_NAME" != iphoneos || -z "${SENTRY_DSN:-}" ]]; then exit 0; fi
if ! command -v sentry >/dev/null || ! sentry auth status >/dev/null 2>&1; then
    echo 'warning: Run sentry auth login; native crash symbols were not uploaded.'
    exit 0
fi
sentry debug-files upload "$DWARF_DSYM_FOLDER_PATH/$DWARF_DSYM_FILE_NAME"
