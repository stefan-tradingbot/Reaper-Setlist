#!/bin/bash
# Build-Script für Reaper-Setlist Custom Fork

echo "Building Reaper Setlist Custom Fork..."

# RPC generieren
echo "1. Generating RPC files..."
cd rpc
npm install
npx tsx morph.ts

# Lua-Script bundeln
echo "2. Bundling Lua script..."
cd ../lua
bun x luabundler bundle main.lua -p "?.lua" -p "?/?.lua" -o build/reaper-setlist.lua

# Frontend bauen
echo "3. Building frontend..."
cd ../frontend
bun install
bun run build

# Dateien kopieren
echo "4. Copying files to reapack directory..."
cd ..
mkdir -p reapack/repo/reaper-setlist/files
cp lua/build/reaper-setlist.lua reapack/repo/reaper-setlist/files/
cp html/setlist.html reapack/repo/reaper-setlist/files/
cp -r frontend/build/* reapack/repo/reaper-setlist/files/reaper-setlist/

echo "✅ Build complete!"
echo ""
echo "Next steps:"
echo "1. Git add, commit and push all files"
echo "2. In ReaPack, add this repository URL:"
echo "   https://raw.githubusercontent.com/stefan-tradingbot/Reaper-Setlist/main/reapack/repo/index-dev.xml"
