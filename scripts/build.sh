#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
xcrun swiftc -swift-version 5 -O -warnings-as-errors src/*.swift -o build/palworld-mcp
codesign --force --sign - build/palworld-mcp
