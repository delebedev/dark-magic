#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

package=./mobile
case "${1:-}" in
  "") ;;
  --smoke) package=./mobile/smoke ;;
  *) echo 'Usage: ios/build.sh [--smoke]' >&2; exit 2 ;;
esac

if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
  echo 'Full Xcode with the iOS SDK is required. Command Line Tools are insufficient.' >&2
  exit 1
fi
export GOTOOLCHAIN=go1.25.12
mkdir -p ios/Assets
go install github.com/hajimehoshi/ebiten/v2/cmd/ebitenmobile@v2.9.9
go_bin="$(go env GOPATH)/bin/ebitenmobile"
if [[ -n "$(go env GOBIN)" ]]; then go_bin="$(go env GOBIN)/ebitenmobile"; fi
"$go_bin" bind -target ios -iosversion 13.0 -tags ebitengine \
  -o ios/Darkmagicmobile.xcframework "$package"
