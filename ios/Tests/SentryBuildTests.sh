#!/bin/bash
set -euo pipefail
script="$(cd "$(dirname "$0")/.." && pwd)/sentry-build.sh"
trial=$(mktemp -d /tmp/dark-magic-sentry-test.XXXXXX)
trap 'rm -r -- "$trial"' EXIT
mkdir -p "$trial/repo/ios" "$trial/bin"
git -C "$trial/repo" init -q
git -C "$trial/repo" -c user.name=Test -c user.email=test@example.invalid commit -q --allow-empty -m initial
export PROJECT_DIR="$trial/repo/ios" TARGET_BUILD_DIR="$trial/build"
export UNLOCALIZED_RESOURCES_FOLDER_PATH=DarkMagic.app
export DWARF_DSYM_FOLDER_PATH="$trial/build" DWARF_DSYM_FILE_NAME=DarkMagic.app.dSYM
export SENTRY_DSN=https://public@example.invalid/1 SENTRY_AUTH_TOKEN=test-only
export PATH="$trial/bin:$PATH" UPLOAD_RECEIPT="$trial/upload"
cat > "$trial/bin/sentry-cli" <<'CLI'
#!/bin/bash
printf '%s\n' "$@" > "$UPLOAD_RECEIPT"
exit "${UPLOAD_EXIT:-0}"
CLI
chmod +x "$trial/bin/sentry-cli"
export PLATFORM_NAME=iphonesimulator
bash "$script"
test -s "$trial/build/DarkMagic.app/build-revision.txt"
test ! -e "$UPLOAD_RECEIPT"
export PLATFORM_NAME=iphoneos
SENTRY_AUTH_TOKEN= bash "$script" > "$trial/warning"
test ! -e "$UPLOAD_RECEIPT"
rg -q 'symbols were not uploaded' "$trial/warning"
bash "$script"
rg -Fxq "$trial/build/DarkMagic.app.dSYM" "$UPLOAD_RECEIPT"
if UPLOAD_EXIT=7 bash "$script"; then
    echo 'Symbol upload failure must fail the build' >&2
    exit 1
fi
echo 'Sentry build identity, upload gating and failure propagation passed.'
