on run
	set historyPath to (POSIX path of (path to home folder)) & ".codex/transcription-history.jsonl"
	set logPath to (POSIX path of (path to home folder)) & ".codex/log/codex-ru-dictation-fix.log"
	set processedPath to (POSIX path of (path to home folder)) & ".codex/ru-dictation-fix-last-id"
	set lockPath to (POSIX path of (path to home folder)) & ".codex/ru-dictation-fix.lock"

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

	set itemId to item 1 of parsed
	set itemText to item 2 of parsed
	if itemText is "" then return

	if not my acquireLock(lockPath) then
		my logMessage("skip: another instance is running", logPath)
		return
	end if

	if itemId is not "" and itemId is my readFileText(processedPath) then
		my logMessage("skip: already processed id " & itemId, logPath)
		my releaseLock(lockPath)
		return
	end if

	try
		set the clipboard to itemText
		delay 0.1
		tell application "System Events" to key code 9 using command down
		if itemId is not "" then my writeFileText(itemId, processedPath)
		my logMessage("pasted: " & itemText, logPath)
		my releaseLock(lockPath)
	on error errMsg
		my logMessage("paste failed: " & errMsg, logPath)
		my releaseLock(lockPath)
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

on acquireLock(lockPath)
	try
		do shell script "/usr/bin/find " & quoted form of lockPath & " -type d -mmin +1 -exec /bin/rm -rf {} + 2>/dev/null; /bin/mkdir " & quoted form of lockPath
		return true
	on error
		return false
	end try
end acquireLock

on releaseLock(lockPath)
	try
		do shell script "/bin/rm -rf " & quoted form of lockPath
	end try
end releaseLock

on readFileText(filePath)
	try
		return do shell script "/bin/cat " & quoted form of filePath & " 2>/dev/null || true"
	on error
		return ""
	end try
end readFileText

on writeFileText(textValue, filePath)
	try
		do shell script "/bin/mkdir -p " & quoted form of ((POSIX path of (path to home folder)) & ".codex") & "; /bin/echo -n " & quoted form of textValue & " > " & quoted form of filePath
	end try
end writeFileText

on logMessage(msg, logPath)
	try
		do shell script "/bin/mkdir -p " & quoted form of ((POSIX path of (path to home folder)) & ".codex/log") & "; /bin/echo " & quoted form of ((do shell script "/bin/date '+%Y-%m-%d %H:%M:%S'") & " " & msg) & " >> " & quoted form of logPath
	end try
end logMessage
