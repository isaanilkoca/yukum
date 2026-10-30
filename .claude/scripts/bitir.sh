#!/bin/bash
# Gün sonu: iOS derlemesi doğrulanır, graphify güncellenir, API ve SQL konteyneri kapatılır.
# Commit/push bu script'te YOK (günlük metni gerekir; skill'deki adımlarla Claude yapar).
cd "$(dirname "$0")/../.." || exit 1

(cd ios/Yukum && xcodebuild -project Yukum.xcodeproj -scheme Yukum -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD" | sort -u | head -5)
graphify update . 2>&1 | grep -E "Rebuilt|error" | head -2

lsof -ti:5054 | xargs kill 2>/dev/null; lsof -ti:5099 | xargs kill 2>/dev/null
docker stop yukum-sql >/dev/null 2>&1
echo "API: $(lsof -ti:5054 >/dev/null 2>&1 && echo 'hâlâ açık' || echo kapalı) | SQL: $(docker ps --format '{{.Names}}' | grep -q yukum-sql && echo 'hâlâ açık' || echo kapalı)"
git status --short | head -8
