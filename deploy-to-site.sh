#!/bin/bash
# Deploy Godot web export to HAIL_MARY site
# Run this after exporting from Godot: Project > Export > Web

set -e

DEST="/Users/michellepaulson/HAIL_MARY/public/game"
SITE="/Users/michellepaulson/HAIL_MARY"

# Copy game files
mkdir -p "$DEST"
cp index.html "$DEST/"
cp index.js "$DEST/"
cp index.wasm "$DEST/"
cp index.pck "$DEST/"
cp index.png "$DEST/"
cp index.icon.png "$DEST/"
cp index.apple-touch-icon.png "$DEST/"
cp index.audio.worklet.js "$DEST/"
cp index.audio.position.worklet.js "$DEST/"
echo "Game files copied to $DEST"

# Commit and push HAIL_MARY
cd "$SITE"
git add public/game/
git commit -m "Update Market Rally game build"
git push
echo "Deployed! Game will be live after Firebase rebuilds."
