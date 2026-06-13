property appRoot : "/Users/jesse/Applications/codex-app-proxy"
property nodeBin : "/opt/homebrew/bin/node"

on run
	set launchCommand to "cd " & quoted form of appRoot & " && clear && " & quoted form of nodeBin & " src/server.js"
	tell application "Terminal"
		activate
		do script launchCommand
	end tell
end run
