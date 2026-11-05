#!/bin/bash
set -e
CDN="${GODOT_ENGINE_CDN_URL:-https://pub-265459c7a52643fbaf39d59c99be6a7e.r2.dev/godot/4.6.2.stable}"
godot --headless --import 2>/dev/null
godot --headless --export-release "Web" index.html
sed -i "s|<script src=\"index.js\"></script>|<script src=\"${CDN}/godot.js\"></script>|" index.html
rm -f index.js index.wasm index.audio.worklet.js index.audio.position.worklet.js
