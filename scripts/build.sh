#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
python3 scripts/embed_localization.py
xcrun swiftc -swift-version 5 -O -warnings-as-errors -target arm64-apple-macos14.0 -file-prefix-map "$(pwd)=." src/*.swift build/EmbeddedLocalization.swift build/BuildInfo.swift -o build/palworld-mcp
codesign --force --sign - build/palworld-mcp
