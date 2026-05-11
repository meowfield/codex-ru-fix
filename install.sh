#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
src="$script_dir/src/fix.applescript"
app_name="Codex RU Dictation Fix"
dst_app="/Applications/$app_name.app"
plist="$HOME/Library/LaunchAgents/com.codex-ru-dictation-fix.plist"
label="com.codex-ru-dictation-fix"
domain="gui/$(id -u)"
history_file="$HOME/.codex/transcription-history.jsonl"

if [[ ! -f "$src" ]]; then
	echo "Исходник не найден: $src" >&2
	exit 1
fi

echo "1/5 Компиляция .app..."
mkdir -p "$script_dir/app"
osacompile -o "$script_dir/app/$app_name.app" "$src"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $label" "$script_dir/app/$app_name.app/Contents/Info.plist" 2>/dev/null || \
	/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $label" "$script_dir/app/$app_name.app/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :LSUIElement true" "$script_dir/app/$app_name.app/Contents/Info.plist" 2>/dev/null || \
	/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$script_dir/app/$app_name.app/Contents/Info.plist"

echo "2/5 Подпись .app..."
codesign --force --deep --sign - "$script_dir/app/$app_name.app" >/dev/null 2>&1 || true

echo "3/5 Установка в /Applications..."
if [[ -d "$dst_app" ]]; then
	pkill -f "$app_name.app/Contents/MacOS/applet" 2>/dev/null || true
	rm -rf "$dst_app"
fi
ditto "$script_dir/app/$app_name.app" "$dst_app"
xattr -dr com.apple.quarantine "$dst_app" 2>/dev/null || true
codesign --force --deep --sign - "$dst_app" >/dev/null 2>&1 || true

touch "$history_file" 2>/dev/null || true

echo "4/5 Создание LaunchAgent (WatchPaths)..."
mkdir -p "$HOME/Library/LaunchAgents"
launchctl bootout "$domain" "$plist" 2>/dev/null || true

cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>${label}</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/open</string>
		<string>-g</string>
		<string>${dst_app}</string>
	</array>
	<key>WatchPaths</key>
	<array>
		<string>${history_file}</string>
	</array>
</dict>
</plist>
PLIST

echo "5/5 Запуск LaunchAgent..."
launchctl bootstrap "$domain" "$plist"

echo ""
echo "Готово! Теперь добавьте приложение в Accessibility:"
echo "  System Settings → Privacy & Security → Accessibility"
echo "  -> + -> $dst_app"
echo ""
echo "Лог: ~/.codex/log/codex-ru-dictation-fix.log"
echo "Удалить: ./uninstall.sh"
