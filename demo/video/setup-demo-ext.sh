#!/usr/bin/env bash
# setup-demo-ext.sh — build the demo extension the VHS tapes record against.
# Produces a clean vanilla MV3 extension + a deliberately-broken manifest,
# both with REAL correct-dimension icons, so every recorded validator run
# shows genuine output. Run this before recording any [VHS] segment.
#
# Usage: bash setup-demo-ext.sh [target-dir]   (default: /tmp/cext-video-demo)

set -euo pipefail
PLUGIN="$(cd "$(dirname "$0")/../.." && pwd)"
DEST="${1:-/tmp/cext-video-demo}"
EXT="$DEST/tab-manager"

rm -rf "$DEST"
mkdir -p "$EXT"
cp -r "$PLUGIN/skills/extension-architect/templates/vanilla/." "$EXT/"
mkdir -p "$EXT/icons"

# Real PNGs at correct pixel dimensions, stdlib only (no Pillow dependency).
python3 - "$EXT" <<'PY'
import zlib, struct, os, sys
ext = sys.argv[1]
def png(size, path):
    def chunk(typ, data):
        c = typ + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    raw = (b"\x00" + bytes((40, 90, 200) * size)) * size
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
                           + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
for s in (16, 32, 48, 128):
    png(s, os.path.join(ext, "icons", f"{s}.png"))
PY

# A deliberately-broken manifest for the "catch a mistake" beat.
python3 - "$EXT" "$DEST" <<'PY'
import json, sys
ext, dest = sys.argv[1], sys.argv[2]
m = json.load(open(f"{ext}/manifest.json"))
m["content_security_policy"] = {"extension_pages": "script-src 'self' 'unsafe-eval'"}
m["permissions"] = ["storage", "activeTab", "tabs", "<all_urls>"]
json.dump(m, open(f"{dest}/broken-manifest.json", "w"), indent=2)
PY

echo "demo ready: $EXT"
echo "broken manifest: $DEST/broken-manifest.json"
