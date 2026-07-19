# Command-Line Search Tools

Ripgrep is installed on the host at:

`/opt/homebrew/bin/rg`

Before reporting that `rg` is unavailable, try:

`/opt/homebrew/bin/rg --version`

When ripgrep is needed, invoke it using the absolute path:

`/opt/homebrew/bin/rg`

If that exact executable is unavailable or blocked inside the Codex sandbox, report that once and use `find` or `/usr/bin/grep` as the fallback. Do not repeatedly investigate or treat unavailable ripgrep as a task blocker.