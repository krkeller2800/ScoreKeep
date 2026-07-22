# Command-Line Search Tools

Ripgrep is installed on the host at:

`/opt/homebrew/bin/rg`

Before reporting that `rg` is unavailable, try:

`/opt/homebrew/bin/rg --version`

When ripgrep is needed, invoke it using the absolute path:

`/opt/homebrew/bin/rg`

If that exact executable is unavailable or blocked inside the Codex sandbox, report that once and use `find` or `/usr/bin/grep` as the fallback. Do not repeatedly investigate or treat unavailable ripgrep as a task blocker.

Persistent task reports

When a task has an established final-report file, update that file with the current task results before finishing. Do not satisfy this requirement only by returning a report in the conversation.

The established report file may reside inside or outside the repository. If the task prompt, current conversation, or existing workflow identifies a report file by path, filename, or established location, treat that file as the required persistent report artifact.

* Update the existing report file in place.
* Replace the previous report contents with the current final report unless the task explicitly requires appending.
* Preserve the established filename and location.
* Do not create a second report file, numbered copy, timestamped copy, or alternate "latest" report unless the task explicitly requires one.
* If the report file already exists, overwrite it rather than creating a replacement.
* Include the implementation summary, verification performed, exact results, files changed, commit and push results (when applicable), and final Git status appropriate to the task.
* Report the exact path of the updated report file in the final response.
* For report files stored outside the repository, update the file but never attempt to commit or push it.
* For report files stored inside the repository, do not commit or push the report unless the task explicitly authorizes Git changes.
* If the established report file cannot be located or updated, stop and report the problem instead of silently creating a new report or returning only a chat report.

When a task explicitly requires updating an established report file, completion is not achieved until that file has been successfully updated. Returning an equivalent report in the conversation is not an acceptable substitute.
