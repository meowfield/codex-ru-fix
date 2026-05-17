#!/bin/zsh
set -euo pipefail
umask 077

script_dir="${0:A:h}"
src="$script_dir/src/fix.applescript"
app_name="Codex RU Dictation Fix"
dst_app="/Applications/$app_name.app"
plist="$HOME/Library/LaunchAgents/com.codex-ru-dictation-fix.plist"
label="com.codex-ru-dictation-fix"
domain="gui/$(id -u)"
codex_dir="$HOME/.codex"
history_file="$HOME/.codex/transcription-history.jsonl"
log_dir="$codex_dir/log"
log_file="$log_dir/codex-ru-dictation-fix.log"
processed_file="$codex_dir/ru-dictation-fix-last-id"

ensure_private_dir() {
	local dir="$1"

	if [[ -L "$dir" || ( -e "$dir" && ! -d "$dir" ) ]]; then
		echo "Небезопасный путь каталога: $dir" >&2
		exit 1
	fi

	mkdir -p "$dir"
	chmod go-rwx "$dir"
}

ensure_private_file() {
	local file="$1"

	if [[ -L "$file" || ( -e "$file" && ! -f "$file" ) ]]; then
		echo "Небезопасный путь файла: $file" >&2
		exit 1
	fi

	: >> "$file"
	chmod go-rwx "$file"
}

if [[ ! -f "$src" ]]; then
	echo "Исходник не найден: $src" >&2
	exit 1
fi

echo "1/6 Компиляция .app..."
mkdir -p "$script_dir/app"
osacompile -o "$script_dir/app/$app_name.app" "$src"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $label" "$script_dir/app/$app_name.app/Contents/Info.plist" 2>/dev/null || \
	/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $label" "$script_dir/app/$app_name.app/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :LSUIElement true" "$script_dir/app/$app_name.app/Contents/Info.plist" 2>/dev/null || \
	/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$script_dir/app/$app_name.app/Contents/Info.plist"

echo "2/6 Подпись .app..."
codesign --force --deep --sign - "$script_dir/app/$app_name.app" >/dev/null 2>&1 || true

echo "3/6 Установка в /Applications..."
if [[ -d "$dst_app" ]]; then
	pkill -f "$app_name.app/Contents/MacOS/applet" 2>/dev/null || true
	rm -rf "$dst_app"
fi
ditto "$script_dir/app/$app_name.app" "$dst_app"
xattr -dr com.apple.quarantine "$dst_app" 2>/dev/null || true
codesign --force --deep --sign - "$dst_app" >/dev/null 2>&1 || true

echo "4/6 Подготовка приватных state-файлов..."
ensure_private_dir "$codex_dir"
ensure_private_dir "$log_dir"
ensure_private_file "$history_file"
ensure_private_file "$log_file"
ensure_private_file "$processed_file"

echo "5/6 Создание LaunchAgent (WatchPaths)..."
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

echo "6/6 Запуск LaunchAgent..."
launchctl bootstrap "$domain" "$plist"

echo ""
echo "Готово! Теперь добавьте приложение в Accessibility:"
echo "  System Settings → Privacy & Security → Accessibility"
echo "  -> + -> $dst_app"
echo ""
echo "Лог: ~/.codex/log/codex-ru-dictation-fix.log"
echo "Удалить: ./uninstall.sh"
