#!/bin/zsh
set -euo pipefail

app_name="Codex RU Dictation Fix"
dst_app="/Applications/$app_name.app"
plist="$HOME/Library/LaunchAgents/com.codex-ru-dictation-fix.plist"
domain="gui/$(id -u)"

echo "Остановка LaunchAgent..."
launchctl bootout "$domain" "$plist" 2>/dev/null || true

echo "Завершение приложения..."
pkill -f "$app_name.app/Contents/MacOS/applet" 2>/dev/null || true

echo "Удаление LaunchAgent..."
rm -f "$plist"

echo "Удаление .app..."
rm -rf "$dst_app"

echo ""
echo "Удалено. Если приложение есть в Accessibility — удалите вручную:"
echo "  System Settings → Privacy & Security → Accessibility"
