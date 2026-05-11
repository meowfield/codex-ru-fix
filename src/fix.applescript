on run
	set historyPath to (POSIX path of (path to home folder)) & ".codex/transcription-history.jsonl"
	set logPath to (POSIX path of (path to home folder)) & ".codex/log/codex-ru-dictation-fix.log"

	if not my isRussianLayout() then
		my logMessage("skip: non-russian layout", logPath)
		return
	end if

	delay 0.3

	set lastLine to ""
	try
		set lastLine to do shell script "/usr/bin/tail -n 1 " & quoted form of historyPath
	on error
		my logMessage("skip: no history", logPath)
		return
	end try
	if lastLine is "" then return

	set parsed to my parseLine(lastLine)
	if parsed is missing value then
		my logMessage("skip: parse failed", logPath)
		return
	end if

	set itemText to item 2 of parsed
	if itemText is "" then return

	try
		set the clipboard to itemText
		delay 0.1
		tell application "System Events" to key code 124
		delay 0.05
		tell application "System Events" to key code 9 using command down
		my logMessage("pasted: " & itemText, logPath)
	on error errMsg
		my logMessage("paste failed: " & errMsg, logPath)
	end try
end run

on parseLine(lineText)
	set py to "import json, os" & linefeed & ¬
		"line = os.environ.get('CODEX_DICTATION_JSON', '')" & linefeed & ¬
		"try:" & linefeed & ¬
		" item = json.loads(line)" & linefeed & ¬
		" print(str(item.get('id','')) + '\\t' + str(item.get('text','')))" & linefeed & ¬
		"except Exception:" & linefeed & ¬
		" pass"
	try
		set outputText to do shell script "CODEX_DICTATION_JSON=" & quoted form of lineText & " /usr/bin/python3 -c " & quoted form of py
	on error
		return missing value
	end try
	if outputText does not contain tab then return missing value
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to tab
	set parts to text items of outputText
	set AppleScript's text item delimiters to oldDelims
	if (count of parts) is less than 2 then return missing value
	return {item 1 of parts, item 2 of parts}
end parseLine

on isRussianLayout()
	try
		do shell script "/usr/bin/defaults read \"$HOME/Library/Preferences/com.apple.HIToolbox.plist\" AppleSelectedInputSources 2>/dev/null | /usr/bin/grep -Eq 'KeyboardLayout Name\\\"? = Russian'"
		return true
	on error
		return false
	end try
end isRussianLayout

on logMessage(msg, logPath)
	try
		do shell script "/bin/mkdir -p " & quoted form of ((POSIX path of (path to home folder)) & ".codex/log") & "; /bin/echo " & quoted form of ((do shell script "/bin/date '+%Y-%m-%d %H:%M:%S'") & " " & msg) & " >> " & quoted form of logPath
	end try
end logMessage
