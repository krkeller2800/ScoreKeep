# Command-Line Search Tools

Ripgrep is installed on the host at:

`/opt/homebrew/bin/rg`

Before reporting that `rg` is unavailable, try:

`/opt/homebrew/bin/rg --version`

When ripgrep is needed, invoke it using the absolute path:

`/opt/homebrew/bin/rg`

If that exact executable is unavailable or blocked inside the Codex sandbox, report that once and use `find` or `/usr/bin/grep` as the fallback. Do not repeatedly investigate or treat unavailable ripgrep as a task blocker.

Persistent task reports

When a task already has an established final-report file in the repository, update that file with the current task results before finishing. Do not satisfy this requirement only by returning a report in the conversation.

* Preserve the existing report file’s structure and location.
* Do not create a new report file unless the task explicitly requires one.
* Include the implementation summary, verification performed, exact results, files changed, and Git status appropriate to the task.
* Report the path of the updated report file in the final response.
* Do not commit or push the report unless the task explicitly authorizes Git changes.
