on run
	set codexPath to (POSIX path of (path to home folder)) & ".codex"
	set historyPath to codexPath & "/transcription-history.jsonl"
	set logPath to codexPath & "/log/codex-ru-dictation-fix.log"
	set processedPath to codexPath & "/ru-dictation-fix-last-id"
	set lockPath to codexPath & "/ru-dictation-fix.lock"

	if not my preparePrivateState(codexPath, logPath) then return

	if not my isRussianLayout() then
		my logMessage("skip: non-russian layout", logPath)
		return
	end if

	delay 0.3

	if not my isSafeHistoryPath(codexPath, historyPath) then
		my logMessage("skip: unsafe history path", logPath)
		return
	end if

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
		my logMessage("skip: already processed id", logPath)
		my releaseLock(lockPath)
		return
	end if

	try
		set the clipboard to itemText
		delay 0.1
		tell application "System Events" to key code 9 using command down
		if itemId is not "" then my writeFileText(itemId, processedPath)
		set idStatus to "none"
		if itemId is not "" then set idStatus to "present"
		my logMessage("pasted: id=" & idStatus & " chars=" & (count of characters of itemText), logPath)
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

on preparePrivateState(codexPath, logPath)
	set logDir to codexPath & "/log"
	try
		do shell script "umask 077; codex=" & quoted form of codexPath & "; logdir=" & quoted form of logDir & "; log=" & quoted form of logPath & "; " & ¬
			"if [ -L \"$codex\" ] || { [ -e \"$codex\" ] && [ ! -d \"$codex\" ]; }; then exit 1; fi; " & ¬
			"if [ ! -d \"$codex\" ]; then /bin/mkdir -m 700 \"$codex\"; fi; " & ¬
			"[ \"$(/usr/bin/stat -f %u \"$codex\")\" = \"$(/usr/bin/id -u)\" ] || exit 1; " & ¬
			"/bin/chmod go-rwx \"$codex\"; " & ¬
			"if [ -L \"$logdir\" ] || { [ -e \"$logdir\" ] && [ ! -d \"$logdir\" ]; }; then exit 1; fi; " & ¬
			"/bin/mkdir -p \"$logdir\"; /bin/chmod go-rwx \"$logdir\"; " & ¬
			"if [ -L \"$log\" ] || { [ -e \"$log\" ] && [ ! -f \"$log\" ]; }; then exit 1; fi; " & ¬
			": >> \"$log\"; /bin/chmod go-rwx \"$log\""
		return true
	on error
		return false
	end try
end preparePrivateState

on isSafeHistoryPath(codexPath, historyPath)
	try
		do shell script "uid=$(/usr/bin/id -u); codex=" & quoted form of codexPath & "; history=" & quoted form of historyPath & "; " & ¬
			"for p in \"$codex\" \"$history\"; do " & ¬
			"[ -e \"$p\" ] || exit 1; " & ¬
			"[ ! -L \"$p\" ] || exit 1; " & ¬
			"[ \"$(/usr/bin/stat -f %u \"$p\")\" = \"$uid\" ] || exit 1; " & ¬
			"case \"$(/usr/bin/stat -f %SMp%SLp \"$p\")\" in *w*) exit 1;; esac; " & ¬
			"done; " & ¬
			"[ -d \"$codex\" ] || exit 1; [ -f \"$history\" ] || exit 1"
		return true
	on error
		return false
	end try
end isSafeHistoryPath

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
		return do shell script "file=" & quoted form of filePath & "; [ -f \"$file\" ] && [ ! -L \"$file\" ] || exit 0; /bin/cat \"$file\" 2>/dev/null || true"
	on error
		return ""
	end try
end readFileText

on writeFileText(textValue, filePath)
	try
		do shell script "umask 077; file=" & quoted form of filePath & "; dir=$(/usr/bin/dirname \"$file\"); " & ¬
			"if [ -L \"$dir\" ] || { [ -e \"$dir\" ] && [ ! -d \"$dir\" ]; }; then exit 1; fi; " & ¬
			"/bin/mkdir -p \"$dir\"; /bin/chmod go-rwx \"$dir\"; " & ¬
			"if [ -L \"$file\" ] || { [ -e \"$file\" ] && [ ! -f \"$file\" ]; }; then exit 1; fi; " & ¬
			"/usr/bin/printf '%s' " & quoted form of textValue & " > \"$file\"; /bin/chmod go-rwx \"$file\""
	end try
end writeFileText

on logMessage(msg, logPath)
	try
		set codexPath to (POSIX path of (path to home folder)) & ".codex"
		if not my preparePrivateState(codexPath, logPath) then return
		do shell script "log=" & quoted form of logPath & "; /usr/bin/printf '%s\n' " & quoted form of ((do shell script "/bin/date '+%Y-%m-%d %H:%M:%S'") & " " & msg) & " >> \"$log\"; /bin/chmod go-rwx \"$log\""
	end try
end logMessage
