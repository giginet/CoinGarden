#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$PROJECT_DIR"
mkdir -p build/web build/templates
touch build/.gdignore
if [[ ! -f build/templates/web_nothreads_release.zip ]]; then
  python3 tools/download_web_templates.py
fi
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release Web build/web/index.html
cp assets/pixel/coins/500.png build/web/coin.png
cp web/README.md build/web/README.md
touch build/web/.nojekyll
echo "Web build: $PROJECT_DIR/build/web/index.html"
