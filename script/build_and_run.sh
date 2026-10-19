#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/Lucius.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/Lucius"
cd "$ROOT_DIR"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
case "$MODE" in run|--verify|--build-only|--stop|--logs|--telemetry|--debug) ;; *) echo 'Usage: build_and_run.sh [--build-only|--verify|--stop|--logs|--telemetry|--debug]' >&2; exit 2;; esac
# Stop only this workspace's exact app binary, never a similarly named app.
while IFS= read -r pid; do
  [[ -z "$pid" ]] && continue
  actual="$(/bin/ps -p "$pid" -o comm= 2>/dev/null || true)"
  if [[ "$actual" == "$APP_BINARY" ]]; then
    kill -TERM "$pid"
    for attempt in {1..30}; do
      if ! kill -0 "$pid" 2>/dev/null; then break; fi
      sleep 0.1
    done
    if kill -0 "$pid" 2>/dev/null; then echo "Lucius did not exit; stopping without force-kill." >&2; exit 1; fi
  fi
done < <(/usr/bin/pgrep -x Lucius || true)
[[ "$MODE" == --stop ]] && exit 0
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/module-cache"
swift build --disable-sandbox
BUILD_BINARY="$(swift build --disable-sandbox --show-bin-path)/Lucius"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_BINARY" "$APP_BINARY"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Lucius</string>
<key>CFBundleIdentifier</key><string>local.lucius.mac</string>
<key>CFBundleName</key><string>Lucius</string>
<key>CFBundleDisplayName</key><string>Lucius</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>AppIcon</string>
</dict></plist>
PLIST
if [[ ! -f "$APP_BUNDLE/Contents/Resources/AppIcon.icns" ]]; then
  swift script/make_icon.swift "$ROOT_DIR/.build/Lucius.iconset"
  /usr/bin/iconutil -c icns "$ROOT_DIR/.build/Lucius.iconset" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi
/usr/bin/codesign --force --sign - "$APP_BUNDLE"
[[ "$MODE" == --build-only ]] && { echo "Built $APP_BUNDLE"; exit 0; }
if [[ "$MODE" == --debug ]]; then /usr/bin/lldb -- "$APP_BINARY"; exit; fi
/usr/bin/open -n "$APP_BUNDLE"
if [[ "$MODE" == --verify ]]; then
  for attempt in {1..30}; do
    if /usr/bin/pgrep -x Lucius >/dev/null; then echo "Lucius launched: $APP_BUNDLE"; exit 0; fi
    sleep 0.1
  done
  echo 'Launch was not verified.' >&2; exit 1
elif [[ "$MODE" == --logs || "$MODE" == --telemetry ]]; then
  /usr/bin/log stream --info --style compact --predicate 'process == "Lucius"'
fi
