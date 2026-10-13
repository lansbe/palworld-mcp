#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
python3 scripts/embed_localization.py
xcrun swiftc -swift-version 5 -O -warnings-as-errors src/*.swift build/EmbeddedLocalization.swift -o build/palworld-mcp
codesign --force --sign - build/palworld-mcp
