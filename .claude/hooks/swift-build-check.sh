#!/bin/bash
# PostToolUse (Edit|Write): bir .swift dosyası değişince iOS projesini derler.
# Başarıda SESSİZ (token harcamaz); hata varsa yalnız "error:" satırlarını stderr'e yazar, exit 2 → hata Claude'a döner.
f=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty')
case "$f" in
  */ios/*.swift) ;;   # yalnız iOS Swift dosyaları
  *) exit 0 ;;
esac
cd "$(dirname "$0")/../../ios/Yukum" || exit 0
# Ayrı DerivedData: Xcode'un kendi derlemesiyle çakışmasın
out=$(xcodebuild -project Yukum.xcodeproj -scheme Yukum -destination 'generic/platform=iOS Simulator' -derivedDataPath "${TMPDIR:-/tmp}/yukum-dd" build 2>&1)
if echo "$out" | grep -q "BUILD SUCCEEDED"; then exit 0; fi
echo "$out" | grep -E "error:" | sort -u | head -10 >&2
exit 2
