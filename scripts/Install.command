#!/bin/zsh
set -eu
package_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
source_binary="$package_dir/palworld-mcp"
if [[ ! -f "$source_binary" ]]; then source_binary="$package_dir/../build/palworld-mcp"; fi
/usr/bin/codesign --verify --strict "$source_binary"
mkdir -p "$HOME/.local/bin"
staging=$(mktemp "$HOME/.local/bin/.palworld-mcp.XXXXXX")
trap 'rm -f -- "$staging"' EXIT
cp "$source_binary" "$staging"
chmod 755 "$staging"
mv -f "$staging" "$HOME/.local/bin/palworld-mcp"
"$HOME/.local/bin/palworld-mcp" installed
"$HOME/.local/bin/palworld-mcp" config
