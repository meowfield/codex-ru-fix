#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

app_path="$tmp_dir/Codex RU Dictation Fix.app"
osacompile -o "$app_path" "$repo_dir/src/fix.applescript"
decompiled="$(osadecompile "$app_path")"

require_contains() {
	local needle="$1"
	local label="$2"

	if [[ "$decompiled" != *"$needle"* ]]; then
		echo "Missing $label: $needle" >&2
		exit 1
	fi
}

require_absent() {
	local needle="$1"
	local label="$2"

	if [[ "$decompiled" == *"$needle"* ]]; then
		echo "Unexpected $label: $needle" >&2
		exit 1
	fi
}

require_contains 'key code 9 using command down' 'layout-independent paste'
require_contains 'com.openai.codex' 'Codex bundle guard'
require_contains 'skip: frontmost Codex' 'Codex-frontmost skip log'
require_absent 'key code 124' 'right-arrow key press'
